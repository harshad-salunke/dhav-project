from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Firebase — Auth + FCM only (RTDB and Storage removed)
    firebase_service_account: str = "firebase-service-account.json"
    firebase_project_id: str = "dhav-quick-commerce"

    # Supabase PostgreSQL
    # transaction-mode pooler (port 6543) — used for all app queries
    database_url: str = ""
    # session-mode pooler (port 5432) — used for migrations/DDL only
    direct_url: str = ""

    # Supabase Storage
    supabase_url: str = "https://kkenbavduuttrocaaqsj.supabase.co"
    supabase_service_key: str = ""    # Dashboard → Settings → API → service_role

    # Redis — leave empty for single-worker / local dev (bus auto-disables).
    redis_url: str = ""

    # Broadcasting waves
    broadcast_wave1_radius_km: float = 1.0
    broadcast_wave1_timeout_seconds: int = 45
    broadcast_wave2_radius_km: float = 2.0
    broadcast_wave2_timeout_seconds: int = 45
    broadcast_wave3_radius_km: float = 3.0
    broadcast_wave3_timeout_seconds: int = 60

    # Geofencing
    geohash_precision: int = 6
    default_city_lat: float = 18.5204
    default_city_lng: float = 73.8567

    # Fees
    platform_fee_percentage: float = 5.0
    base_delivery_fee: float = 10.0
    delivery_fee_per_km: float = 5.0
    onboarding_grace_days: int = 30

    # Penalties
    max_strikes_before_suspend: int = 3
    max_total_strikes_before_ban: int = 5
    suspension_days: int = 7
    auto_fail_hours: int = 3

    # Settlement
    settlement_day: str = "MONDAY"

    # ── Call masking (privacy-preserving deliverer <-> customer calls) ────────
    # Provider-agnostic: switch `call_provider` without touching app code.
    #   "exotel" → real masked calls (needs the credentials below)
    #   "mock"   → no real call; logs + returns a stub (default until creds set)
    call_masking_enabled: bool = True
    call_provider: str = "mock"            # "exotel" | "mock"
    # The virtual number(s) both parties see as caller ID. Comma-separated pool;
    # one is enough to start. MUST be an Exotel ExoPhone you own.
    call_virtual_numbers: str = ""
    # Exotel API credentials — Dashboard → Settings → API Settings.
    exotel_sid: str = ""                   # account SID (subdomain)
    exotel_api_key: str = ""               # API key  (basic-auth username)
    exotel_api_token: str = ""             # API token (basic-auth password)
    exotel_subdomain: str = "api.exotel.com"   # region host (api.exotel.com / api.in.exotel.com)
    # Public base URL of THIS backend, so Exotel can POST call status callbacks.
    backend_public_url: str = "https://dhav-backend.onrender.com"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()
