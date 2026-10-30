"""Turn messages posted in Telegram groups/channels into GenZoo news posts.

Run by .github/workflows/genzoo-notifications.yml right before
send_notifications.py. Every new post is created with `notified: false`, so the
existing notification step pushes it to the students' phones.

Rules
- Only real text messages (or media captions) become posts. Service messages
  such as "X joined the group", "X left", pinned/renamed notices have no text
  and are ignored. Bot messages and /commands are ignored too.
- No duplicates:
  1. a Telegram message is stored once (document id = chat id + message id),
     so re-delivered updates are skipped;
  2. identical text posted again within 48 hours (any group) is skipped;
  3. an edited Telegram message updates the existing post instead of creating
     a new one (and does not notify again);
  4. albums produce a single post (only the item that has the caption).
- Posts that an admin edited inside the app are not overwritten.
- Files: photos become the post's pictures, other files (PDF, Word, video,
  audio...) become attachments. They are saved to Google Drive through the
  Apps Script (scripts/drive_upload.gs) and linked in the post. Telegram bots
  can download up to 20 MB and the script accepts up to 15 MB; larger files
  stay in Telegram and the post links back to the message.
- Albums (several photos/files sent together) become ONE post.

Environment
  TELEGRAM_BOT_TOKEN           required (script exits quietly when missing)
  GENZOO_FCM_SERVICE_ACCOUNT   required, same secret as the notification step
  TELEGRAM_CHAT_IDS            optional, comma separated allow-list of chat ids
  TELEGRAM_ONLY_ADMINS         optional, "true" = only messages sent by group
                               admins (or the channel itself) become posts
  GENZOO_UPLOAD_SECRET         optional, same value as UPLOAD_SECRET inside
                               scripts/drive_upload.gs. Without it, files are
                               not copied and the post links to Telegram.
"""
import base64
import datetime as dt
import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

import firebase_admin
from firebase_admin import credentials, firestore
from google.api_core.exceptions import AlreadyExists

PROJECT_ID = "genzoo-app"
DUPLICATE_WINDOW = dt.timedelta(hours=48)
MAX_MESSAGE_AGE = dt.timedelta(hours=24)  # never announce very old backlog
STATE_DOC = ("system", "telegram_sync")


def tg(token: str, method: str, **params):
    url = f"https://api.telegram.org/bot{token}/{method}"
    data = urllib.parse.urlencode(
        {k: json.dumps(v) if isinstance(v, (list, dict)) else v for k, v in params.items()}
    ).encode()
    try:
        with urllib.request.urlopen(urllib.request.Request(url, data=data), timeout=30) as r:
            body = json.load(r)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "ignore")[:300]
        raise RuntimeError(f"Telegram {method} failed: HTTP {exc.code} {detail}") from None
    if not body.get("ok"):
        raise RuntimeError(f"Telegram {method} failed: {body.get('description')}")
    return body["result"]


MAX_FILE_BYTES = 15 * 1024 * 1024
FILE_KINDS = ("document", "video", "audio", "voice", "animation", "video_note")
KIND_LABEL = {"document": "ملف", "video": "فيديو", "audio": "ملف صوتي", "voice": "رسالة صوتية",
              "animation": "صورة متحركة", "video_note": "فيديو"}
EXT_BY_MIME = {"video/mp4": "mp4", "audio/mpeg": "mp3", "audio/ogg": "ogg", "application/pdf": "pdf",
               "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}


def media_of(msg: dict) -> list:
    """Files attached to a message: [{kind, file_id, name, mime, size, is_image}]."""
    items = []
    photos = msg.get("photo")
    if photos:
        best = photos[-1]  # the last size is the biggest
        items.append({"kind": "photo", "file_id": best["file_id"], "name": f"photo_{msg['message_id']}.jpg",
                      "mime": "image/jpeg", "size": best.get("file_size") or 0, "is_image": True})
    for kind in FILE_KINDS:
        f = msg.get(kind)
        if not f:
            continue
        mime = f.get("mime_type") or "application/octet-stream"
        name = f.get("file_name")
        if not name:
            ext = EXT_BY_MIME.get(mime, "bin")
            name = f"{kind}_{msg['message_id']}.{ext}"
        items.append({"kind": kind, "file_id": f["file_id"], "name": name, "mime": mime,
                      "size": f.get("file_size") or 0, "is_image": mime.startswith("image/")})
    return items


def download_file(token: str, file_id: str) -> bytes:
    info = tg(token, "getFile", file_id=file_id)
    url = f"https://api.telegram.org/file/bot{token}/{info['file_path']}"
    with urllib.request.urlopen(url, timeout=120) as r:
        return r.read()


def upload_to_drive(endpoint: str, secret: str, name: str, mime: str, data: bytes) -> dict:
    payload = json.dumps({"secret": secret, "name": name, "mimeType": mime,
                          "data": base64.b64encode(data).decode()}).encode()
    req = urllib.request.Request(endpoint, data=payload, headers={"Content-Type": "text/plain;charset=utf-8"})
    # Apps Script answers a POST with a redirect; urllib follows it with a GET.
    with urllib.request.urlopen(req, timeout=180) as r:
        body = json.load(r)
    if not body.get("ok"):
        raise RuntimeError(f"upload refused: {body.get('error')}")
    return {"name": body.get("name", name), "url": body["url"], "size": body.get("size", len(data))}


def save_media(token: str, endpoint, secret, msg: dict, link):
    """Copies the message files to Drive. Returns (images, attachments, notes)."""
    images, attachments, notes = [], [], []
    for m in media_of(msg):
        label = "صورة" if m["kind"] == "photo" else KIND_LABEL.get(m["kind"], "ملف")
        if not endpoint or not secret:
            notes.append(f"📎 {label}: {m['name']} (افتحه من تليجرام)")
            continue
        if m["size"] and m["size"] > MAX_FILE_BYTES:
            notes.append(f"📎 {label} كبير الحجم: {m['name']} (افتحه من تليجرام)")
            continue
        try:
            data = download_file(token, m["file_id"])
            if len(data) > MAX_FILE_BYTES:
                notes.append(f"📎 {label} كبير الحجم: {m['name']} (افتحه من تليجرام)")
                continue
            saved = upload_to_drive(endpoint, secret, m["name"], m["mime"], data)
            (images if m["is_image"] else attachments).append(saved)
        except Exception as exc:  # one failing file must not lose the whole post
            print(f"File copy failed ({m['name']}): {exc}")
            notes.append(f"📎 {label}: {m['name']} (تعذّر نسخه، افتحه من تليجرام)")
    return images, attachments, notes


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip().lower()


def sender_name(msg: dict) -> str:
    sender = msg.get("from") or {}
    name = " ".join(p for p in (sender.get("first_name"), sender.get("last_name")) if p)
    return name or (msg.get("sender_chat") or {}).get("title") or (msg.get("chat") or {}).get("title") or "تليجرام"


def is_allowed_sender(token: str, msg: dict, cache: dict) -> bool:
    chat = msg["chat"]
    if chat.get("type") == "channel":
        return True
    sender_chat = msg.get("sender_chat")
    if sender_chat and sender_chat.get("id") == chat.get("id"):
        return True  # anonymous admin posting as the group
    user = msg.get("from") or {}
    key = (chat["id"], user.get("id"))
    if key not in cache:
        try:
            member = tg(token, "getChatMember", chat_id=chat["id"], user_id=user.get("id"))
            cache[key] = member.get("status") in ("creator", "administrator")
        except Exception as exc:
            print(f"getChatMember failed ({exc}); treating sender as non-admin")
            cache[key] = False
    return cache[key]


def main() -> int:
    token = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
    if not token:
        print("TELEGRAM_BOT_TOKEN is not set; Telegram sync skipped.")
        return 0

    raw = os.environ.get("GENZOO_FCM_SERVICE_ACCOUNT")
    if not raw:
        raise RuntimeError("GitHub secret GENZOO_FCM_SERVICE_ACCOUNT is missing.")
    service_data = json.loads(raw)
    if service_data.get("project_id") != PROJECT_ID:
        raise RuntimeError("Service account project ID does not match.")

    allowed_chats = {
        c.strip() for c in os.environ.get("TELEGRAM_CHAT_IDS", "").split(",") if c.strip()
    }
    only_admins = os.environ.get("TELEGRAM_ONLY_ADMINS", "").strip().lower() in ("1", "true", "yes")

    app = firebase_admin.initialize_app(
        credentials.Certificate(service_data), options={"projectId": PROJECT_ID}
    )
    db = firestore.client(app=app)
    upload_secret = os.environ.get("GENZOO_UPLOAD_SECRET", "").strip()
    try:
        upload_endpoint = ((db.collection("config").document("upload").get().to_dict() or {}).get("url") or "").strip()
    except Exception as exc:
        print(f"Could not read the upload address: {exc}")
        upload_endpoint = ""
    state_ref = db.collection(STATE_DOC[0]).document(STATE_DOC[1])
    offset = int((state_ref.get().to_dict() or {}).get("offset", 0))

    now = dt.datetime.now(dt.timezone.utc)
    created = updated = skipped = 0
    admin_cache: dict = {}
    last_id = None

    while True:
        updates = tg(
            token,
            "getUpdates",
            offset=offset,
            limit=100,
            timeout=0,
            allowed_updates=["message", "edited_message", "channel_post", "edited_channel_post"],
        )
        if not updates:
            break

        for upd in updates:
            last_id = upd["update_id"]
            offset = last_id + 1
            is_edit = "edited_message" in upd or "edited_channel_post" in upd
            msg = (
                upd.get("message")
                or upd.get("edited_message")
                or upd.get("channel_post")
                or upd.get("edited_channel_post")
            )
            if not msg:
                continue
            chat = msg.get("chat") or {}
            if chat.get("type") == "private":
                continue
            if allowed_chats and str(chat.get("id")) not in allowed_chats:
                skipped += 1
                continue
            # Join/leave/pin/rename notices carry no text -> ignored here.
            text = (msg.get("text") or msg.get("caption") or "").strip()
            has_media = bool(media_of(msg))
            if (not text and not has_media) or text.startswith("/"):
                skipped += 1
                continue
            if (msg.get("from") or {}).get("is_bot"):
                skipped += 1
                continue
            if only_admins and not is_allowed_sender(token, msg, admin_cache):
                skipped += 1
                continue

            sent_at = dt.datetime.fromtimestamp(msg["date"], dt.timezone.utc)
            doc_id = f"tg_{str(chat['id']).replace('-', 'm')}_{msg['message_id']}"
            ref = db.collection("news").document(doc_id)
            snap = ref.get()

            gid = msg.get("media_group_id")
            if not snap.exists and gid and not is_edit:
                # Another file of an album that already became a post: add to it.
                found = list(db.collection("news").where("telegramGroupId", "==", str(gid)).limit(1).stream())
                if found:
                    username = chat.get("username")
                    link = f"https://t.me/{username}/{msg['message_id']}" if username else None
                    imgs, atts, notes = save_media(token, upload_endpoint, upload_secret, msg, link)
                    changes = {}
                    if imgs:
                        changes["images"] = firestore.ArrayUnion(imgs)
                    if atts:
                        changes["attachments"] = firestore.ArrayUnion(atts)
                    prev = found[0].to_dict() or {}
                    if text and (not prev.get("content") or prev.get("content", "").startswith("📎")):
                        changes["content"] = text
                    if changes:
                        found[0].reference.update(changes)
                        updated += 1
                    else:
                        skipped += 1
                    continue

            if snap.exists:
                existing = snap.to_dict() or {}
                if is_edit and text and not existing.get("manuallyEdited") and existing.get("content") != text:
                    ref.update({"content": text, "edited": True,
                                "editedAt": firestore.SERVER_TIMESTAMP})
                    updated += 1
                else:
                    skipped += 1
                continue

            if now - sent_at > MAX_MESSAGE_AGE:
                skipped += 1
                continue

            # Same text posted again (another group, a repost, a forward).
            # Posts that carry files are never treated as duplicates.
            if text and not has_media:
                digest = hashlib.sha256(normalize(text).encode()).hexdigest()[:40]
                hash_ref = db.collection("telegram_hashes").document(digest)
                try:
                    hash_ref.create({"newsId": doc_id, "createdAt": now})
                except AlreadyExists:
                    prev = (hash_ref.get().to_dict() or {}).get("createdAt")
                    if prev and now - prev < DUPLICATE_WINDOW:
                        print(f"Duplicate text skipped ({doc_id})")
                        skipped += 1
                        continue
                    hash_ref.set({"newsId": doc_id, "createdAt": now})

            username = chat.get("username")
            link = f"https://t.me/{username}/{msg['message_id']}" if username else None
            images, attachments, notes = save_media(token, upload_endpoint, upload_secret, msg, link)
            body_text = text
            if notes:
                body_text = (text + "\n\n" if text else "") + "\n".join(notes)
            if not body_text:
                body_text = "📎 مرفقات جديدة من تليجرام"
            ref.set(
                {
                    "title": str(chat.get("title") or "رسالة من تليجرام")[:100],
                    "content": body_text,
                    "images": images,
                    "attachments": attachments,
                    "telegramGroupId": str(gid) if gid else None,
                    "category": "عام",
                    "isPinned": False,
                    "authorName": sender_name(msg),
                    "imageUrl": None,
                    "externalUrl": link,
                    "publishedAt": sent_at,
                    "notified": False,  # picked up by send_notifications.py
                    "source": "telegram",
                    "telegramChatId": chat["id"],
                    "telegramMessageId": msg["message_id"],
                }
            )
            created += 1
            print(f"New post from Telegram: {doc_id}")

    if last_id is not None:
        state_ref.set({"offset": offset, "updatedAt": firestore.SERVER_TIMESTAMP})
    print(f"Telegram sync: {created} new, {updated} edited, {skipped} ignored.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
