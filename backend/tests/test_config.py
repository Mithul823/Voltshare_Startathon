from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.main import app


def test_configuration_public_dict_does_not_expose_secrets() -> None:
    public = get_settings().public_dict()
    joined = repr(public).lower()
    assert "service_role" not in joined
    assert "gemini_api_key" not in joined
    assert "hmac_secret" not in joined


def test_cors_is_configured_from_environment() -> None:
    settings = get_settings()
    cors_middleware = [
        middleware for middleware in app.user_middleware if middleware.cls is CORSMiddleware
    ]
    assert cors_middleware
    assert cors_middleware[0].kwargs["allow_origins"] == settings.cors_origins
