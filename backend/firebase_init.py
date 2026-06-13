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


def get_service_account_info() -> dict:
    """
    Return the raw Firebase service-account JSON as a dict.

    Same two sources as the credentials below — used by services that need to
    mint their own OAuth2 tokens (e.g. the Remote Config REST API in
    services/remote_config.py), since the admin SDK doesn't expose those scopes.
    """
    json_str = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip().lstrip("﻿")
    if json_str:
        return json.loads(json_str)
    with open(get_settings().firebase_service_account, encoding="utf-8") as f:
        return json.load(f)


def _build_credentials() -> credentials.Certificate:
    """
    Support two credential sources:
    1. FIREBASE_SERVICE_ACCOUNT_JSON  — full JSON string (Railway env var)
    2. FIREBASE_SERVICE_ACCOUNT       — file path (local dev)
    """
    return credentials.Certificate(get_service_account_info())


def init_firebase() -> None:
    global _initialized
    if _initialized:
        return
    cred = _build_credentials()
    firebase_admin.initialize_app(cred, {
        "projectId": get_settings().firebase_project_id,
    })
    _initialized = True
