from typing import Optional
from pydantic import BaseModel


class CallInitiateResponse(BaseModel):
    """Returned to the app after a masked call is placed. Deliberately contains
    NO real phone numbers — only the masking metadata the app may show."""
    ok: bool
    status: str                       # initiated | failed | disabled
    masked: bool = True
    call_id: Optional[str] = None     # our call_logs id
    virtual_number: Optional[str] = None
    message: Optional[str] = None     # human-readable reason on failure
