"""
Privacy-preserving call masking (Blinkit / Swiggy / Ola style).

WHAT
----
When a deliverer and a customer need to talk, neither should see the other's
real phone number. A cloud-telephony provider places TWO call legs and bridges
them through a VIRTUAL NUMBER:

    deliverer ──leg A──►  [ Exotel ]  ──leg B──► customer
                          CallerId = virtual number
    (both parties' phones show the virtual number, never each other's real one)

WHY A SERVICE ABSTRACTION
-------------------------
`CallService` is provider-agnostic. Today we ship `ExotelCallService` (cheapest
for our low, pay-per-use volume; India-registered, required by TRAI for domestic
masking) plus a `MockCallService` so the whole feature is testable BEFORE any
credentials exist. Swapping to another provider later = one new subclass + a
config flag, with zero changes in the routers or the apps.

The actual call is Exotel's "Connect two numbers" API: we give it both real
numbers + our ExoPhone (CallerId); it dials leg A (the initiator) first, then
bridges leg B. Because Exotel originates both legs, neither caller ever receives
the other's number — they only see the ExoPhone.
"""
import logging
import random
from abc import ABC, abstractmethod
from dataclasses import dataclass

import httpx

from config import get_settings

log = logging.getLogger("call_masking")


# ── Phone normalisation ───────────────────────────────────────────────────────

def normalize_in_phone(raw: str | None) -> str | None:
    """Normalise an Indian phone number to E.164 (+91XXXXXXXXXX).

    Store/customer numbers arrive in mixed shapes ("+91 98…", "098…",
    "98…"). Exotel accepts E.164, so we standardise. Returns None if we can't
    confidently produce a 10-digit Indian mobile number.
    """
    if not raw:
        return None
    digits = "".join(ch for ch in str(raw) if ch.isdigit())
    if len(digits) == 12 and digits.startswith("91"):
        digits = digits[2:]
    elif len(digits) == 11 and digits.startswith("0"):
        digits = digits[1:]
    if len(digits) != 10:
        return None
    return f"+91{digits}"


def pick_virtual_number() -> str | None:
    """Pick a masking number from the configured pool (round-robin-ish).

    One ExoPhone is enough to start — Exotel bridges each call as a discrete
    two-leg session, so a single CallerId handles concurrent masked calls. A
    pool just spreads load / number-health risk; we pick randomly from it.
    """
    s = get_settings()
    nums = [n.strip() for n in (s.call_virtual_numbers or "").split(",") if n.strip()]
    return random.choice(nums) if nums else None


# ── Result type ───────────────────────────────────────────────────────────────

@dataclass
class CallResult:
    ok: bool
    provider: str
    call_sid: str | None = None
    virtual_number: str | None = None
    status: str = "initiated"
    error: str | None = None


# ── Provider interface ────────────────────────────────────────────────────────

class CallService(ABC):
    provider_name: str = "base"

    @abstractmethod
    async def connect(
        self,
        caller_phone: str,
        callee_phone: str,
        virtual_number: str,
        status_callback_url: str,
        order_id: str,
    ) -> CallResult:
        """Ring `caller_phone` (leg A) first, then bridge `callee_phone`
        (leg B), both masked behind `virtual_number`."""
        raise NotImplementedError


class MockCallService(CallService):
    """No real telephony. Used until Exotel credentials are configured so the
    end-to-end flow (button → endpoint → log) works in dev/demo without spend."""
    provider_name = "mock"

    async def connect(self, caller_phone, callee_phone, virtual_number,
                      status_callback_url, order_id) -> CallResult:
        log.info(
            "[MockCall] order=%s would bridge A=%s -> B=%s via %s",
            order_id, caller_phone, callee_phone, virtual_number,
        )
        return CallResult(
            ok=True, provider="mock",
            call_sid=f"mock_{order_id}",
            virtual_number=virtual_number,
            status="initiated",
        )


class ExotelCallService(CallService):
    """Real masked calls via Exotel's 'Connect two numbers' voice API."""
    provider_name = "exotel"

    def __init__(self, sid: str, api_key: str, api_token: str, subdomain: str):
        self._sid = sid
        self._key = api_key
        self._token = api_token
        self._subdomain = subdomain

    async def connect(self, caller_phone, callee_phone, virtual_number,
                      status_callback_url, order_id) -> CallResult:
        url = f"https://{self._subdomain}/v1/Accounts/{self._sid}/Calls/connect.json"
        data = {
            "From": caller_phone,        # leg A — rings first (the initiator)
            "To": callee_phone,          # leg B — bridged once A answers
            "CallerId": virtual_number,  # the ExoPhone both parties see
            "CallType": "trans",         # transactional
            "TimeLimit": "1800",         # hard cap a call at 30 min
            "StatusCallback": status_callback_url,
        }
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.post(url, data=data, auth=(self._key, self._token))
        except Exception as e:  # network / DNS / timeout
            log.warning("[ExotelCall] order=%s request failed: %s", order_id, e)
            return CallResult(ok=False, provider="exotel", error=str(e), status="failed")

        if resp.status_code >= 400:
            log.warning("[ExotelCall] order=%s HTTP %s: %s", order_id, resp.status_code, resp.text[:300])
            return CallResult(ok=False, provider="exotel",
                              error=f"HTTP {resp.status_code}: {resp.text[:200]}", status="failed")

        try:
            call = resp.json().get("Call", {})
        except Exception:
            call = {}
        return CallResult(
            ok=True, provider="exotel",
            call_sid=call.get("Sid"),
            virtual_number=virtual_number,
            status=(call.get("Status") or "initiated"),
        )


# ── Factory ───────────────────────────────────────────────────────────────────

def get_call_service() -> CallService:
    """Return the configured provider, falling back to Mock when Exotel is
    selected but credentials are missing (so a half-configured deploy degrades
    to a no-op instead of 500-ing)."""
    s = get_settings()
    if s.call_provider == "exotel" and s.exotel_sid and s.exotel_api_key and s.exotel_api_token:
        return ExotelCallService(
            sid=s.exotel_sid,
            api_key=s.exotel_api_key,
            api_token=s.exotel_api_token,
            subdomain=s.exotel_subdomain,
        )
    return MockCallService()
