from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from firebase_admin import auth as firebase_auth

from models.user import TokenVerifyResponse
from services.cache import catalog_cache, USER_PROFILE_TTL
from services.db import pool

_bearer = HTTPBearer()

VALID_ROLES = {"customer", "store_owner", "delivery", "admin"}


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
) -> TokenVerifyResponse:
    token = credentials.credentials
    if not token or token.lower() in ("null", "undefined", ""):
        raise HTTPException(status_code=401, detail="Missing token")
    try:
        decoded = firebase_auth.verify_id_token(token, clock_skew_seconds=60)
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    uid = decoded["uid"]

    cache_key = f"user:{uid}"
    cached = catalog_cache.get(cache_key)
    if cached is not None:
        return cached

    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM users WHERE uid = $1", uid)

    if row is None:
        raise HTTPException(
            status_code=404,
            detail="User profile not found. Call /auth/verify-token first.",
        )

    user_data = dict(row)
    role = user_data.get("role", "customer")
    if role not in VALID_ROLES:
        role = "customer"

    result = TokenVerifyResponse(
        uid=uid,
        email=user_data.get("email", ""),
        display_name=user_data.get("name", ""),
        role=role,
        is_active=user_data.get("is_active", True),
    )
    catalog_cache.set(cache_key, result, ttl=USER_PROFILE_TTL)
    return result


def require_role(*roles: str):
    def _checker(user: TokenVerifyResponse = Depends(get_current_user)) -> TokenVerifyResponse:
        if user.role not in roles:
            raise HTTPException(status_code=403, detail=f"Access denied. Required role: {list(roles)}")
        if not user.is_active:
            raise HTTPException(status_code=403, detail="Account is inactive or suspended")
        return user
    return _checker
