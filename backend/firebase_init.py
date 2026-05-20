import json
import os
import firebase_admin
from firebase_admin import credentials, db, storage

from config import get_settings

_initialized = False


def _build_credentials() -> credentials.Certificate:
    """
    Support two ways to supply the Firebase service account:

    1. FIREBASE_SERVICE_ACCOUNT_JSON  — the full JSON as a string (Railway / CI env var)
    2. FIREBASE_SERVICE_ACCOUNT       — a file path (local dev default)

    Railway can't mount files, so we read the JSON from an env var there.
    Locally the file path still works as before.
    """
    json_str = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()
    if json_str:
        service_account_info = json.loads(json_str)
        return credentials.Certificate(service_account_info)

    settings = get_settings()
    return credentials.Certificate(settings.firebase_service_account)


def init_firebase() -> None:
    global _initialized
    if _initialized:
        return

    settings = get_settings()
    cred = _build_credentials()
    firebase_admin.initialize_app(cred, {
        "databaseURL": settings.firebase_database_url,
        "storageBucket": settings.firebase_storage_bucket,
    })
    _initialized = True


def get_db():
    return db


def get_storage():
    return storage
