from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Firebase — file path used locally; JSON string used on Railway (see firebase_init.py)
    firebase_service_account: str = "firebase-service-account.json"
    firebase_project_id: str = "dhav-quick-commerce"
    firebase_database_url: str = "https://dhav-quick-commerce-default-rtdb.firebaseio.com"
    firebase_storage_bucket: str = "dhav-quick-commerce.appspot.com"

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

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()
