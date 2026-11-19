"""Pushes FCM alerts for new student contributions awaiting admin review.

Only documents explicitly marked adminNotified=false are sent. The flag is
updated after FCM accepts the message, so failed sends are retried next run.
"""
import json
import os
import sys

import firebase_admin
from firebase_admin import credentials, firestore, messaging

PROJECT_ID = "genzoo-app"
TOPIC = "admins"
CHANNEL_ID = "genzoo_admin"

# collection, type, notification title, body builder
PENDING_TYPES = (
    (
        "material_submissions",
        "material_submission",
        "طلب رفع ملف جديد",
        lambda d: f"{d.get('submitterName') or 'طالب'} أرسل الملف: {d.get('title') or 'ملف جديد'}",
    ),
    (
        "subject_opinions",
        "subject_opinion",
        "رأي جديد يحتاج مراجعة",
        lambda d: f"{d.get('userName') or 'طالب'} أرسل رأيًا عن مادة: {d.get('subjectName') or 'مادة'}",
    ),
    (
        "material_reviews",
        "material_review",
        "تقييم جديد يحتاج مراجعة",
        lambda d: f"{d.get('userName') or 'طالب'} قيّم: {d.get('materialTitle') or 'مادة دراسية'}",
    ),
)


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

    failures = 0
    sent_count = 0

    for collection_name, notification_type, title, body_builder in PENDING_TYPES:
        # Filter adminNotified locally to avoid requiring a composite index.
        pending_docs = db.collection(collection_name).where("status", "==", "pending").stream()

        for doc in pending_docs:
            data = doc.to_dict() or {}
            if data.get("adminNotified") is not False:
                continue

            message = messaging.Message(
                topic=TOPIC,
                notification=messaging.Notification(
                    title=title,
                    body=body_builder(data)[:180],
                ),
                data={
                    "documentId": doc.id,
                    "collection": collection_name,
                    "type": notification_type,
                },
                android=messaging.AndroidConfig(
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
                doc.reference.update({"adminNotified": True})
                sent_count += 1
                print(
                    f"Notified admins: {collection_name}/{doc.id} "
                    f"(FCM {message_id})"
                )
            except Exception as exc:
                failures += 1
                print(f"FAILED {collection_name}/{doc.id}: {exc}")

    print(f"Sent {sent_count} admin notification(s); {failures} failure(s).")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
