"""Pushes an FCM alert to admins when a student submits a file for review.

Run by .github/workflows/genzoo-notifications.yml, right after
send_notifications.py. Every pending request in `material_submissions` that
has not been flagged yet gets one push to the `admins` topic (devices signed
in as an admin/super-admin subscribe to it from the app), then is marked
`adminNotified: true` so it is not sent twice. If sending fails the flag
stays false and the next run retries it.
"""
import json
import os
import sys

import firebase_admin
from firebase_admin import credentials, firestore, messaging
from google.cloud.firestore_v1.base_query import FieldFilter

PROJECT_ID = "genzoo-app"
TOPIC = "admins"
CHANNEL_ID = "genzoo_admin"  # created in MainActivity.kt


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
        db.collection("material_submissions")
        .where(filter=FieldFilter("status", "==", "pending"))
        .where(filter=FieldFilter("adminNotified", "==", False))
        .stream()
    )
    if not pending:
        print("No new submissions awaiting admin review.")
        return 0

    failures = 0
    for doc in pending:
        data = doc.to_dict() or {}
        submitter = str(data.get("submitterName") or "طالب")
        title = str(data.get("title") or "ملف جديد")

        message = messaging.Message(
            topic=TOPIC,
            notification=messaging.Notification(
                title="طلب رفع ملف جديد",
                body=f"{submitter} يريد رفع: {title}",
            ),
            data={"submissionId": doc.id, "type": "material_submission"},
            android=messaging.AndroidConfig(
                priority="high",
                ttl=24 * 60 * 60,
                notification=messaging.AndroidNotification(channel_id=CHANNEL_ID, priority="high"),
            ),
        )
        try:
            message_id = messaging.send(message, app=app)
        except Exception as exc:  # leave adminNotified=false so the next run retries
            failures += 1
            print(f"FAILED submission {doc.id}: {exc}")
            continue

        doc.reference.update({"adminNotified": True})
        print(f"Notified admins for submission {doc.id} (FCM {message_id})")

    print(f"Processed {len(pending)} submission(s), {failures} failure(s).")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
