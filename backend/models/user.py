from pydantic import BaseModel
from typing import Optional


class UserProfile(BaseModel):
    uid: str
    email: Optional[str] = None
    display_name: Optional[str] = None
    phone: Optional[str] = None
    role: str = "customer"  # customer | store_owner | delivery | admin
    is_active: bool = True
    created_at: Optional[int] = None  # epoch ms


class TokenVerifyResponse(BaseModel):
    uid: str
    email: str
    display_name: str
    role: str
    is_active: bool
