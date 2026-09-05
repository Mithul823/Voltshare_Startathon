from functools import lru_cache
from typing import Literal

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_env: Literal["development", "demo", "test", "production"] = "development"
    app_name: str = "VoltShare API"
    api_v1_prefix: str = "/api/v1"
    log_level: str = "INFO"

    supabase_url: str = ""
    supabase_anon_key: str = ""
    supabase_service_role_key: str = ""
    supabase_jwks_url: str = ""
    supabase_jwt_secret: str = ""

    gemini_api_key: str = ""
    gemini_model: str = ""
    ai_enabled: bool = True
    hmac_secret: str = ""
    marketplace_platform_fee_percent: int = 5
    cors_origins_raw: str = Field(
        default="http://localhost:3000,http://localhost:8080",
        validation_alias="CORS_ORIGINS",
    )
    enable_demo_endpoints: bool = True
    emergency_max_allocation_kwh: float = 10000.0
    version: str = "0.6.1"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="",
        case_sensitive=False,
        extra="ignore",
    )

    @property
    def api_prefix(self) -> str:
        return self.api_v1_prefix

    @property
    def cors_origins(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins_raw.split(",") if origin.strip()]

    @property
    def is_production(self) -> bool:
        return self.app_env == "production"

    @property
    def is_demo_mode(self) -> bool:
        return self.app_env in {"development", "demo", "test"} and self.enable_demo_endpoints

    @property
    def expected_issuer(self) -> str:
        return f"{self.supabase_url.rstrip('/')}/auth/v1" if self.supabase_url else ""

    def validate_startup(self) -> None:
        missing = []
        if not self.hmac_secret and self.is_production:
            missing.append("HMAC_SECRET")
        if self.is_production:
            for key, value in {
                "SUPABASE_URL": self.supabase_url,
                "SUPABASE_ANON_KEY": self.supabase_anon_key,
                "SUPABASE_SERVICE_ROLE_KEY": self.supabase_service_role_key,
                "SUPABASE_JWKS_URL": self.supabase_jwks_url,
            }.items():
                if not value:
                    missing.append(key)
        if missing:
            raise RuntimeError(f"Missing required configuration: {', '.join(missing)}")

    def public_dict(self) -> dict[str, object]:
        return {
            "app_env": self.app_env,
            "app_name": self.app_name,
            "api_v1_prefix": self.api_v1_prefix,
            "log_level": self.log_level,
            "cors_origins": self.cors_origins,
            "enable_demo_endpoints": self.enable_demo_endpoints,
            "supabase_configured": bool(self.supabase_url and self.supabase_anon_key),
            "supabase_jwks_configured": bool(self.supabase_jwks_url),
            "ai_enabled": self.ai_enabled,
            "gemini_configured": bool(self.gemini_api_key),
            "gemini_model": self.gemini_model,
            "marketplace_platform_fee_percent": self.marketplace_platform_fee_percent,
            "emergency_max_allocation_kwh": self.emergency_max_allocation_kwh,
        }


@lru_cache
def get_settings() -> Settings:
    return Settings()
