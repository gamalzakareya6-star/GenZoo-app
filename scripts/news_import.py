"""Shared helper: create a news post from a Telegram message (used by both
telegram_sync.py and telegram_user_sync.py). Handles duplicate detection."""
import datetime as dt
import hashlib
import re

from firebase_admin import firestore
from google.api_core.exceptions import AlreadyExists

DUPLICATE_WINDOW = dt.timedelta(hours=48)


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip().lower()


def doc_id_for(chat_id: int, message_id: int) -> str:
    return f"tg_{str(chat_id).replace('-', 'm')}_{message_id}"


def create_post(db, *, now, doc_id, chat_id, chat_title, message_id, text,
                author, sent_at, link=None) -> bool:
    """Returns True when a new post was created, False when skipped as duplicate."""
    # Same text posted again (another group, a repost, a forward).
    digest = hashlib.sha256(normalize(text).encode()).hexdigest()[:40]
    hash_ref = db.collection("telegram_hashes").document(digest)
    try:
        hash_ref.create({"newsId": doc_id, "createdAt": now})
    except AlreadyExists:
        prev = (hash_ref.get().to_dict() or {}).get("createdAt")
        if prev and now - prev < DUPLICATE_WINDOW:
            print(f"Duplicate text skipped ({doc_id})")
            return False
        hash_ref.set({"newsId": doc_id, "createdAt": now})

    db.collection("news").document(doc_id).set(
        {
            "title": str(chat_title or "رسالة من تليجرام")[:100],
            "content": text,
            "category": "عام",
            "isPinned": False,
            "authorName": author,
            "imageUrl": None,
            "externalUrl": link,
            "publishedAt": sent_at,
            "notified": False,  # picked up by send_notifications.py
            "source": "telegram",
            "telegramChatId": chat_id,
            "telegramMessageId": message_id,
        }
    )
    print(f"New post from Telegram: {doc_id}")
    return True
