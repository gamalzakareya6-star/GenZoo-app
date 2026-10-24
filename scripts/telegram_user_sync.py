"""Read private Telegram groups with YOUR OWN account (Telethon) and turn their
messages into GenZoo news posts. Use only for groups where the bot cannot be added.

Keep the load tiny to protect the account: it runs at most once every 5 minutes,
makes one connection, and only asks for messages newer than the last one seen.
The first run only remembers the latest message of each chat (no backlog).

Environment (GitHub secrets)
  TELETHON_API_ID, TELETHON_API_HASH   from https://my.telegram.org
  TELETHON_SESSION                     StringSession made by telegram_login_helper.py
  TELETHON_CHAT_IDS                    comma separated chat ids to follow
  GENZOO_FCM_SERVICE_ACCOUNT           same secret as the other steps
Nothing happens (exit 0) when TELETHON_SESSION is missing.
"""
import asyncio
import datetime as dt
import json
import os
import sys

import firebase_admin
from firebase_admin import credentials, firestore

import news_import

PROJECT_ID = "genzoo-app"
MIN_INTERVAL = dt.timedelta(minutes=5)
MAX_AGE = dt.timedelta(hours=24)


async def run(db, state_ref, state) -> int:
    from telethon import TelegramClient
    from telethon.sessions import StringSession

    chat_ids = [int(c) for c in os.environ.get("TELETHON_CHAT_IDS", "").replace(" ", "").split(",") if c]
    if not chat_ids:
        print("TELETHON_CHAT_IDS is empty; nothing to follow.")
        return 0

    client = TelegramClient(
        StringSession(os.environ["TELETHON_SESSION"].strip()),
        int(os.environ["TELETHON_API_ID"]),
        os.environ["TELETHON_API_HASH"].strip(),
    )
    now = dt.datetime.now(dt.timezone.utc)
    last_seen = dict(state.get("chats") or {})
    created = skipped = 0

    async with client:
        dialogs = {d.id: d for d in await client.get_dialogs(limit=300)}
        for chat_id in chat_ids:
            dialog = dialogs.get(chat_id)
            if dialog is None:
                print(f"Chat {chat_id} not found in your dialogs; skipped.")
                continue
            key = str(chat_id)
            if key not in last_seen:
                latest = await client.get_messages(dialog.entity, limit=1)
                last_seen[key] = latest[0].id if latest else 0
                print(f"Following {dialog.name} from now on (no backlog).")
                continue

            messages = await client.get_messages(
                dialog.entity, min_id=last_seen[key], limit=50
            )
            username = getattr(dialog.entity, "username", None)
            for m in sorted(messages, key=lambda x: x.id):
                last_seen[key] = max(last_seen[key], m.id)
                text = (m.message or "").strip()
                if m.action is not None or not text or text.startswith("/"):
                    skipped += 1  # join/leave/pin notices, media without text
                    continue
                sender = await m.get_sender()
                if getattr(sender, "bot", False):
                    skipped += 1
                    continue
                sent_at = m.date.astimezone(dt.timezone.utc)
                if now - sent_at > MAX_AGE:
                    skipped += 1
                    continue
                doc_id = news_import.doc_id_for(chat_id, m.id)
                if db.collection("news").document(doc_id).get().exists:
                    skipped += 1
                    continue
                name = " ".join(
                    p for p in (getattr(sender, "first_name", None), getattr(sender, "last_name", None)) if p
                ) or getattr(sender, "title", None) or dialog.name
                if news_import.create_post(
                    db,
                    now=now,
                    doc_id=doc_id,
                    chat_id=chat_id,
                    chat_title=dialog.name,
                    message_id=m.id,
                    text=text,
                    author=name,
                    sent_at=sent_at,
                    link=f"https://t.me/{username}/{m.id}" if username else None,
                ):
                    created += 1
                else:
                    skipped += 1

    state_ref.set({"lastRun": now, "chats": last_seen})
    print(f"Telegram user sync: {created} new, {skipped} ignored.")
    return 0


def main() -> int:
    if not os.environ.get("TELETHON_SESSION", "").strip():
        print("TELETHON_SESSION is not set; private-group sync skipped.")
        return 0
    raw = os.environ.get("GENZOO_FCM_SERVICE_ACCOUNT")
    if not raw:
        raise RuntimeError("GitHub secret GENZOO_FCM_SERVICE_ACCOUNT is missing.")
    service_data = json.loads(raw)
    if service_data.get("project_id") != PROJECT_ID:
        raise RuntimeError("Service account project ID does not match.")

    app = firebase_admin.initialize_app(
        credentials.Certificate(service_data), options={"projectId": PROJECT_ID}
    )
    db = firestore.client(app=app)
    state_ref = db.collection("system").document("telethon_sync")
    state = state_ref.get().to_dict() or {}

    last_run = state.get("lastRun")
    if last_run and dt.datetime.now(dt.timezone.utc) - last_run < MIN_INTERVAL:
        print("Ran less than 5 minutes ago; skipped.")
        return 0
    return asyncio.run(run(db, state_ref, state))


if __name__ == "__main__":
    sys.exit(main())
