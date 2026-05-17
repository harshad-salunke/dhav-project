import firebase_admin
from firebase_admin import credentials, db, storage

from config import get_settings

_initialized = False


def init_firebase() -> None:
    global _initialized
    if _initialized:
        return

    settings = get_settings()
    cred = credentials.Certificate(settings.firebase_service_account)
    firebase_admin.initialize_app(cred, {
        "databaseURL": settings.firebase_database_url,
        "storageBucket": settings.firebase_storage_bucket,
    })
    _initialized = True


def get_db():
    return db


def get_storage():
    return storage
