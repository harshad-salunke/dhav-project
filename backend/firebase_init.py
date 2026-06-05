"""
Firebase initialization — Auth + FCM only.

Firebase Realtime Database and Storage have been migrated to Supabase.
This module only initializes the Firebase Admin SDK for:
  - Token verification: firebase_admin.auth.verify_id_token()
  - Creating Auth users: firebase_admin.auth.create_user()
  - FCM push notifications: via services/notifications.py
"""
import json
import os
import firebase_admin
from firebase_admin import credentials

from config import get_settings

_initialized = False


def _build_credentials() -> credentials.Certificate:
    """
    Support two credential sources:
    1. FIREBASE_SERVICE_ACCOUNT_JSON  — full JSON string (Railway env var)
    2. FIREBASE_SERVICE_ACCOUNT       — file path (local dev)
    """
    json_str = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip().lstrip("﻿")
    if json_str:
        return credentials.Certificate(json.loads(json_str))
    return credentials.Certificate(get_settings().firebase_service_account)


def init_firebase() -> None:
    global _initialized
    if _initialized:
        return
    cred = _build_credentials()
    firebase_admin.initialize_app(cred, {
        "projectId": get_settings().firebase_project_id,
    })
    _initialized = True
