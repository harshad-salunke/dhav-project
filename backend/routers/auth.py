from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from firebase_admin import auth as firebase_auth, db

from models.user import TokenVerifyResponse
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
        # Token expired but within grace window — try once more without grace
        # (clock_skew_seconds already handled it above; this branch means truly expired)
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

    user_ref = db.reference(f"users/{uid}")
    user_data = user_ref.get()

    if user_data is None:
        # First login — check if this email belongs to a pre-registered delivery boy.
        # Store owners add delivery boys by email before they ever log in, so we
        # need to promote them to 'delivery' role here rather than defaulting to 'customer'.
        role_on_create = "customer"
        store_id_on_create = None
        all_boys = db.reference("delivery_boys").get() or {}
        for boy_id, boy in all_boys.items():
            if boy.get("google_account_email", "").lower() == email.lower():
                role_on_create = "delivery"
                store_id_on_create = boy.get("store_id")
                # Link the Firebase UID back to the delivery_boys record
                db.reference(f"delivery_boys/{boy_id}").update({"uid": uid})
                break

        user_data = {
            "uid": uid,
            "email": email,
            "display_name": decoded.get("name", ""),
            "role": role_on_create,
            "created_at": now_ms(),
            "is_active": True,
        }
        if store_id_on_create:
            user_data["store_id"] = store_id_on_create
        user_ref.set(user_data)

    role = user_data.get("role", "customer")
    if role not in VALID_ROLES:
        role = "customer"

    return TokenVerifyResponse(
        uid=uid,
        email=user_data.get("email", email),
        display_name=user_data.get("display_name", ""),
        role=role,
        is_active=user_data.get("is_active", True),
    )
