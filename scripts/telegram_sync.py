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

Environment
  TELEGRAM_BOT_TOKEN           required (script exits quietly when missing)
  GENZOO_FCM_SERVICE_ACCOUNT   required, same secret as the notification step
  TELEGRAM_CHAT_IDS            optional, comma separated allow-list of chat ids
  TELEGRAM_ONLY_ADMINS         optional, "true" = only messages sent by group
                               admins (or the channel itself) become posts
"""
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
            if not text or text.startswith("/"):
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

            if snap.exists:
                existing = snap.to_dict() or {}
                if is_edit and not existing.get("manuallyEdited") and existing.get("content") != text:
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
            ref.set(
                {
                    "title": str(chat.get("title") or "رسالة من تليجرام")[:100],
                    "content": text,
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
