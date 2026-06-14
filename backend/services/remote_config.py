"""
Firebase Remote Config management via the REST API.

The customer app's home top-section — header gradient colours, greeting text,
search hint, and the promo banner carousel — is driven by Firebase Remote
Config. This service lets the ADMIN DASHBOARD read the current values and
publish new ones without anyone opening the Firebase console. End to end:

    admin web  ──PUT /admin/home-config──▶  this service  ──▶  Remote Config
    customer app  ◀──fetchAndActivate()──  Remote Config

Why the REST API (and not the Python admin SDK): the firebase-admin Python SDK
can only *evaluate* a server template, it can't publish the project template.
So we call the Remote Config REST endpoint directly, authenticating with an
OAuth2 access token minted from the same service account the backend already
uses for Auth/FCM — just with the extra `firebase.remoteconfig` scope.
"""
import json
from typing import Any

import httpx
from google.oauth2 import service_account
from google.auth.transport.requests import Request as GoogleAuthRequest

from config import get_settings
from firebase_init import get_service_account_info
from services import cache

_SCOPES = ["https://www.googleapis.com/auth/firebase.remoteconfig"]
_RC_URL = (
    "https://firebaseremoteconfig.googleapis.com/v1/projects/{project}/remoteConfig"
)

# The Remote Config keys that make up the customer-app home top-section. Each
# one has a matching in-app default in customer_app's ui_config_provider.dart,
# so the app still works even if a key was never published.
HOME_KEYS = [
    "home_header_color_start",
    "home_header_color_end",
    "home_greeting_title",
    "home_greeting_subtitle",
    "home_search_hint",
    "home_banners",
    "home_deal_enabled",
    "home_deal_title",
    # Deal of the Day: the admin pins one catalog item, the % off, and when the
    # deal ends. The customer app applies the discount to that item's price in
    # the deal card and counts down to `home_deal_ends_at` (epoch millis, UTC).
    "home_deal_item_id",
    "home_deal_discount_percent",
    "home_deal_ends_at",
]


def _access_token() -> str:
    """Mint a short-lived OAuth2 token for the Remote Config scope.

    `refresh()` does a blocking network call; this runs on FastAPI's threadpool
    because the endpoints below are plain `def`-free `async` handlers that await
    only the httpx calls — the token mint is fast and admin-only, so the small
    blocking cost is acceptable.
    """
    creds = service_account.Credentials.from_service_account_info(
        get_service_account_info(), scopes=_SCOPES
    )
    creds.refresh(GoogleAuthRequest())
    return creds.token


def _url() -> str:
    return _RC_URL.format(project=get_settings().firebase_project_id)


async def get_home_config(use_cache: bool = True) -> dict[str, Any]:
    """Return the current home-section values + the template etag.

    Served from the shared in-memory TTLCache (same one the catalog uses) so the
    admin "Home UI" screen loads instantly instead of paying an OAuth mint + REST
    round-trip every open. `update_home_config` keeps the cache fresh on publish,
    so the only time we hit Firebase is a cold cache or a console-side edit.

    The etag isn't strictly needed by the reader, but returning it lets the admin
    client round-trip it back on save for safe optimistic concurrency.
    """
    if use_cache:
        cached = cache.catalog_cache.get(cache.HOME_CONFIG_KEY)
        if cached is not None:
            return cached

    token = _access_token()
    async with httpx.AsyncClient(timeout=15) as client:
        resp = await client.get(_url(), headers={"Authorization": f"Bearer {token}"})
    resp.raise_for_status()
    template = resp.json()
    etag = resp.headers.get("ETag", "*")
    params = template.get("parameters", {}) or {}
    values: dict[str, str] = {}
    for key in HOME_KEYS:
        default_value = (params.get(key) or {}).get("defaultValue") or {}
        values[key] = default_value.get("value", "")
    result = {"etag": etag, "values": values}
    cache.catalog_cache.set(cache.HOME_CONFIG_KEY, result, cache.HOME_CONFIG_TTL)
    return result


async def update_home_config(values: dict[str, str]) -> dict[str, Any]:
    """Merge the given home-section values into the live template and publish.

    We read the current template first so we only ever touch the home keys and
    never clobber other parameters, parameter groups, or conditions.
    """
    token = _access_token()
    headers = {"Authorization": f"Bearer {token}"}
    async with httpx.AsyncClient(timeout=20) as client:
        get_resp = await client.get(_url(), headers=headers)
        get_resp.raise_for_status()
        template = get_resp.json()
        etag = get_resp.headers.get("ETag", "*")

        params = template.get("parameters", {}) or {}
        for key in HOME_KEYS:
            if key not in values or values[key] is None:
                continue
            param = params.get(key, {})
            param["defaultValue"] = {"value": str(values[key])}
            param.setdefault("valueType", "STRING")
            params[key] = param
        template["parameters"] = params

        put_resp = await client.put(
            _url(),
            headers={
                **headers,
                "Content-Type": "application/json; UTF-8",
                "If-Match": etag,
            },
            content=json.dumps(template),
        )
    put_resp.raise_for_status()
    new_etag = put_resp.headers.get("ETag", etag)

    # Refresh the cache so the next read is instant AND correct. We rebuild the
    # full home-section view from the template we just published (not just the
    # changed keys), then:
    #  • drop the key on every worker (cross-worker invalidate), then
    #  • write the fresh value through on THIS worker for an instant admin reload.
    fresh_values: dict[str, str] = {}
    published = template.get("parameters", {}) or {}
    for key in HOME_KEYS:
        dv = (published.get(key) or {}).get("defaultValue") or {}
        fresh_values[key] = dv.get("value", "")
    result = {"etag": new_etag, "values": fresh_values}

    await cache.invalidate("home_config")
    cache.catalog_cache.set(cache.HOME_CONFIG_KEY, result, cache.HOME_CONFIG_TTL)
    return {"etag": new_etag}
