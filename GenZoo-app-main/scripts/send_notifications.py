"""Send an FCM notification for every news post that has notified == False.

Run by .github/workflows/genzoo-notifications.yml. The admin app creates each
post with `notified: false`; this script sends it and flips the flag to true.
If sending fails the flag stays false, so the next run retries it.
Posts created before this change have no `notified` field and are ignored.
"""
import json
import os
import sys

import firebase_admin
from firebase_admin import credentials, firestore, messaging
from google.cloud.firestore_v1.base_query import FieldFilter

PROJECT_ID = "genzoo-app"
TOPIC = "news"
CHANNEL_ID = "genzoo_news"  # created in MainActivity.kt


def main() -> int:
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

    pending = list(
        db.collection("news")
        .where(filter=FieldFilter("notified", "==", False))
        .stream()
    )
    if not pending:
        print("No pending posts.")
        return 0

    pending.sort(key=lambda d: str((d.to_dict() or {}).get("publishedAt") or ""))
    failures = 0

    for doc in pending:
        data = doc.to_dict() or {}
        title = str(data.get("title") or "منشور جديد في GenZoo")
        body = str(data.get("content") or "")[:180] or (
            "تم نشر محتوى جديد. افتح GenZoo للاطلاع عليه."
        )

        message = messaging.Message(
            topic=TOPIC,
            notification=messaging.Notification(title=title[:100], body=body),
            data={"postId": doc.id},
            android=messaging.AndroidConfig(
                # High priority: delivered immediately even in Doze mode.
                priority="high",
                ttl=24 * 60 * 60,
                notification=messaging.AndroidNotification(
                    channel_id=CHANNEL_ID,
                    priority="high",
                ),
            ),
        )

        try:
            message_id = messaging.send(message, app=app)
        except Exception as exc:  # leave notified=false so the next run retries
            failures += 1
            print(f"FAILED post {doc.id}: {exc}")
            continue

        doc.reference.update(
            {"notified": True, "notifiedAt": firestore.SERVER_TIMESTAMP}
        )
        print(f"Sent post {doc.id} (FCM {message_id})")

    print(f"Processed {len(pending)} post(s), {failures} failure(s).")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
