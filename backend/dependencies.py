from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from firebase_admin import auth as firebase_auth, db

from models.user import TokenVerifyResponse

_bearer = HTTPBearer()

VALID_ROLES = {"customer", "store_owner", "delivery", "admin"}


def get_current_user(
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
    user_data = db.reference(f"users/{uid}").get()

    if user_data is None:
        raise HTTPException(status_code=404, detail="User profile not found. Call /auth/verify-token first.")

    role = user_data.get("role", "customer")
    if role not in VALID_ROLES:
        role = "customer"

    return TokenVerifyResponse(
        uid=uid,
        email=user_data.get("email", ""),
        display_name=user_data.get("display_name", ""),
        role=role,
        is_active=user_data.get("is_active", True),
    )


def require_role(*roles: str):
    def _checker(user: TokenVerifyResponse = Depends(get_current_user)) -> TokenVerifyResponse:
        if user.role not in roles:
            raise HTTPException(status_code=403, detail=f"Access denied. Required role: {list(roles)}")
        if not user.is_active:
            raise HTTPException(status_code=403, detail="Account is inactive or suspended")
        return user
    return _checker
