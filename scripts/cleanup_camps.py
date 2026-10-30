"""Deletes study camps that ended more than 3 days ago (field `deleteAfter`),
together with their tasks, files, members and invite code."""
import json
import os
import sys
import datetime as dt

import firebase_admin
from firebase_admin import credentials, firestore

PROJECT_ID = "genzoo-app"


def delete_collection(coll) -> int:
    n = 0
    for doc in coll.stream():
        doc.reference.delete()
        n += 1
    return n


def main() -> int:
    raw = os.environ.get("GENZOO_FCM_SERVICE_ACCOUNT", "").strip()
    if not raw:
        print("GENZOO_FCM_SERVICE_ACCOUNT is not set.")
        return 1
    data = json.loads(raw)
    if data.get("project_id") != PROJECT_ID:
        raise RuntimeError("Service account project ID does not match.")
    app = firebase_admin.initialize_app(credentials.Certificate(data), options={"projectId": PROJECT_ID})
    db = firestore.client(app=app)

    now = dt.datetime.now(dt.timezone.utc)
    removed = 0
    for camp in db.collection("camps").where("deleteAfter", "<=", now).stream():
        info = camp.to_dict() or {}
        for sub in ("tasks", "files", "members", "messages", "typing"):
            delete_collection(camp.reference.collection(sub))
        code = info.get("inviteCode")
        if code:
            db.collection("camp_codes").document(code).delete()
        camp.reference.delete()
        removed += 1
        print(f"Deleted camp {camp.id} ({info.get('name', '')})")
    print(f"Done. Removed {removed} camp(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
