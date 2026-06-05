from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from firebase_admin import auth as firebase_auth

from models.user import TokenVerifyResponse
from services.db import pool
from utils.helpers import now_ms

router = APIRouter()
_bearer = HTTPBearer()

VALID_ROLES = {"customer", "store_owner", "delivery", "admin"}


def _verify_firebase_token(credentials: HTTPAuthorizationCredentials = Depends(_bearer)) -> dict:
    token = credentials.credentials
    if not token or token.lower() in ("null", "undefined", ""):
        raise HTTPException(status_code=401, detail="Missing token")
    try:
        return firebase_auth.verify_id_token(token, clock_skew_seconds=60)
    except firebase_auth.ExpiredIdTokenError:
        raise HTTPException(status_code=401, detail="Token expired — please sign in again")
    except firebase_auth.RevokedIdTokenError:
        raise HTTPException(status_code=401, detail="Token revoked")
    except firebase_auth.InvalidIdTokenError as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}")
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Token verification failed: {e}")


@router.post("/verify-token", response_model=TokenVerifyResponse)
async def verify_token(decoded: dict = Depends(_verify_firebase_token)):
    uid = decoded["uid"]
    email = decoded.get("email", "")

    async with pool().acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM users WHERE uid = $1", uid)

    if row is None:
        # First login — check if this email belongs to a pre-registered delivery boy
        role_on_create = "customer"
        store_id_on_create = None

        async with pool().acquire() as conn:
            boy_row = await conn.fetchrow(
                "SELECT id, store_id FROM delivery_boys WHERE lower(google_account_email) = lower($1) LIMIT 1",
                email,
            )
            if boy_row:
                role_on_create = "delivery"
                store_id_on_create = boy_row["store_id"]
                # Link the Firebase UID back to the delivery_boys record
                await conn.execute(
                    "UPDATE delivery_boys SET uid = $1 WHERE id = $2",
                    uid, boy_row["id"],
                )

        async with pool().acquire() as conn:
            await conn.execute("""
                INSERT INTO users (uid, email, name, role, store_id, is_active, created_at)
                VALUES ($1, $2, $3, $4, $5, true, $6)
                ON CONFLICT (uid) DO NOTHING
            """, uid, email, decoded.get("name", ""), role_on_create, store_id_on_create, now_ms())

        user_data = {
            "uid": uid, "email": email, "name": decoded.get("name", ""),
            "role": role_on_create, "store_id": store_id_on_create, "is_active": True,
        }
    else:
        user_data = dict(row)

    role = user_data.get("role", "customer")
    if role not in VALID_ROLES:
        role = "customer"

    return TokenVerifyResponse(
        uid=uid,
        email=user_data.get("email", email),
        display_name=user_data.get("name", "") or user_data.get("display_name", ""),
        role=role,
        is_active=user_data.get("is_active", True),
    )
