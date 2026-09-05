import asyncio

import httpx
from fastapi.testclient import TestClient

from app.core.config import get_settings
from app.schemas.common import UserRole
from app.schemas.forecast import ForecastHorizon, ForecastMetric
from app.schemas.ai import AnomalySeverity
from app.schemas.ai import AssistantChatRequest
from app.services.ai_context_builder import ai_context_builder
from app.services.forecasting_service import forecasting_service
from app.services.gemini_assistant_service import gemini_assistant_service
from app.services.pricing_intelligence_service import pricing_intelligence_service
from app.services.smart_alert_service import smart_alert_service
from app.services.sustainability_service import sustainability_service
from app.schemas.recommendation import PricingSuggestionRequest
from app.core.security import AuthenticatedUser
from tests.conftest import auth_headers, seed_profile


def _user(user_id: str, role: UserRole) -> AuthenticatedUser:
    return AuthenticatedUser(user_id=user_id, email=f"{user_id}@example.com", role=role, token="token")


def test_consumption_forecast_with_sufficient_data_and_confidence() -> None:
    forecast = forecasting_service.forecast("forecast-user", ForecastMetric.consumption, ForecastHorizon.twenty_four_hours)
    assert forecast.data_points_used >= 24
    assert forecast.confidence > 0.5
    assert forecast.model == "weighted_moving_average"
    assert forecast.forecast[0].unit == "kWh"


def test_generation_price_and_battery_forecasts() -> None:
    assert forecasting_service.forecast("forecast-user", ForecastMetric.generation, ForecastHorizon.six_hours).forecast
    assert forecasting_service.forecast("forecast-user", ForecastMetric.price, ForecastHorizon.six_hours).forecast[0].value > 0
    assert forecasting_service.forecast("forecast-user", ForecastMetric.battery, ForecastHorizon.next_hour).forecast[0].unit == "%"


def test_forecast_insufficient_history_has_low_confidence(monkeypatch) -> None:
    monkeypatch.setattr("app.services.forecasting_service.dashboard_repository.get_dashboard_summary", lambda user_id: [])
    forecast = forecasting_service.forecast("empty-user", ForecastMetric.consumption, ForecastHorizon.seven_days)
    assert forecast.fallback_used is True
    assert forecast.confidence <= 0.42
    assert forecast.limitations


def test_role_recommendations_and_pricing_suggestion(client: TestClient) -> None:
    for role in [UserRole.consumer, UserRole.producer, UserRole.prosumer, UserRole.technician, UserRole.grid_operator, UserRole.admin]:
        seed_profile(f"rec-{role.value}", role)
        response = client.get("/api/v1/recommendations", headers=auth_headers(f"rec-{role.value}"))
        assert response.status_code == 200
        assert response.json()
    price = pricing_intelligence_service.suggest(PricingSuggestionRequest(quantity_kwh=2))
    assert price.suggested_price > 0
    assert price.minimum_recommended_price <= price.suggested_price <= price.maximum_recommended_price


def test_sustainability_score_weights_and_carbon_assumptions() -> None:
    score = sustainability_service.score("sustain-user")
    summary = sustainability_service.summary("sustain-user")
    assert set(sustainability_service.weights) <= set(score.factor_scores)
    assert 0 <= score.total_score <= 100
    assert any("0.7 kg CO2e" in item for item in summary.assumptions)


def test_gemini_key_missing_and_transaction_boundary_fallback(monkeypatch) -> None:
    settings = get_settings()
    monkeypatch.setattr(settings, "gemini_api_key", "")
    user = _user("ai-user", UserRole.consumer)
    response = client_response = asyncio.run(
        gemini_assistant_service.chat(user, AssistantChatRequest(message="buy it for me"))
    )
    assert response.fallback_used is True
    assert "cannot execute" in client_response.answer.lower() or "cannot" in client_response.answer.lower()


def test_gemini_default_model_is_supported_flash() -> None:
    assert "gemini-2.5-flash" in gemini_assistant_service._default_model()


def test_ai_disabled_returns_fallback(monkeypatch) -> None:
    settings = get_settings()
    monkeypatch.setattr(settings, "ai_enabled", False)
    monkeypatch.setattr(settings, "gemini_api_key", "configured")
    user = _user("ai-disabled-user", UserRole.consumer)
    response = asyncio.run(
        gemini_assistant_service.chat(user, AssistantChatRequest(message="How should I optimize today?"))
    )
    assert response.fallback_used is True
    assert response.fallback_reason == "ai_disabled"


def test_successful_gemini_response_is_not_fallback(monkeypatch) -> None:
    settings = get_settings()
    monkeypatch.setattr(settings, "ai_enabled", True)
    monkeypatch.setattr(settings, "gemini_api_key", "configured")
    monkeypatch.setattr(settings, "gemini_model", "gemini-test")

    async def fake_generate(*, model: str, api_key: str, prompt: str) -> str:
        return "Use stored solar during the evening peak and list surplus before 6 PM."

    monkeypatch.setattr(gemini_assistant_service, "_generate_with_gemini", fake_generate)
    user = _user("ai-success-user", UserRole.prosumer)
    response = asyncio.run(
        gemini_assistant_service.chat(user, AssistantChatRequest(message="How can I optimize energy today?"))
    )
    assert response.fallback_used is False
    assert response.provider == "gemini"
    assert response.model == "gemini-test"
    assert response.fallback_reason is None
    assert "solar" in response.answer.lower()


def test_gemini_timeout_returns_fallback(monkeypatch) -> None:
    settings = get_settings()
    monkeypatch.setattr(settings, "ai_enabled", True)
    monkeypatch.setattr(settings, "gemini_api_key", "configured")

    async def fake_generate(*, model: str, api_key: str, prompt: str) -> str:
        raise httpx.TimeoutException("timeout")

    monkeypatch.setattr(gemini_assistant_service, "_generate_with_gemini", fake_generate)
    user = _user("ai-timeout-user", UserRole.consumer)
    response = asyncio.run(
        gemini_assistant_service.chat(user, AssistantChatRequest(message="How can I reduce cost?"))
    )
    assert response.fallback_used is True
    assert response.fallback_reason == "gemini_timeout"


def test_gemini_exception_returns_fallback(monkeypatch) -> None:
    settings = get_settings()
    monkeypatch.setattr(settings, "ai_enabled", True)
    monkeypatch.setattr(settings, "gemini_api_key", "configured")

    async def fake_generate(*, model: str, api_key: str, prompt: str) -> str:
        raise httpx.ConnectError("dns failure")

    monkeypatch.setattr(gemini_assistant_service, "_generate_with_gemini", fake_generate)
    user = _user("ai-network-user", UserRole.consumer)
    response = asyncio.run(
        gemini_assistant_service.chat(user, AssistantChatRequest(message="How can I reduce cost?"))
    )
    assert response.fallback_used is True
    assert response.fallback_reason == "gemini_network_error"


def test_empty_gemini_response_returns_fallback(monkeypatch) -> None:
    settings = get_settings()
    monkeypatch.setattr(settings, "ai_enabled", True)
    monkeypatch.setattr(settings, "gemini_api_key", "configured")

    async def fake_generate(*, model: str, api_key: str, prompt: str) -> str:
        return ""

    monkeypatch.setattr(gemini_assistant_service, "_generate_with_gemini", fake_generate)
    user = _user("ai-empty-user", UserRole.consumer)
    response = asyncio.run(
        gemini_assistant_service.chat(user, AssistantChatRequest(message="How can I reduce cost?"))
    )
    assert response.fallback_used is True
    assert response.fallback_reason == "empty_gemini_response"


def test_unauthorized_ai_endpoint_and_role_permissions(client: TestClient) -> None:
    assert client.get("/api/v1/forecasts/consumption").status_code == 401
    seed_profile("grid-denied", UserRole.consumer)
    assert client.get("/api/v1/grid/ai/forecast", headers=auth_headers("grid-denied")).status_code == 403
    seed_profile("admin-ok", UserRole.admin)
    assert client.get("/api/v1/admin/ai/anomalies", headers=auth_headers("admin-ok")).status_code == 200


def test_smart_alert_deduplication_and_private_context() -> None:
    user = _user("alert-user", UserRole.consumer)
    first = smart_alert_service.create(user, alert_type="price_spike", severity=AnomalySeverity.medium, title="Price spike", message="Advisory alert.")
    second = smart_alert_service.create(user, alert_type="price_spike", severity=AnomalySeverity.medium, title="Price spike", message="Advisory alert.")
    assert first.id == second.id
    context = ai_context_builder.sanitize({"access_token": "secret", "dashboard": {"refresh_token": "secret", "value": 1}})
    assert "access_token" not in context
    assert "refresh_token" not in context["dashboard"]


def test_phase66_api_contracts(client: TestClient) -> None:
    seed_profile("phase66-user", UserRole.prosumer)
    headers = auth_headers("phase66-user")
    endpoints = [
        "/api/v1/forecasts/summary",
        "/api/v1/pricing/intelligence",
        "/api/v1/sustainability/summary",
        "/api/v1/sustainability/score",
        "/api/v1/insights/daily",
    ]
    for endpoint in endpoints:
        assert client.get(endpoint, headers=headers).status_code == 200
    chat = client.post("/api/v1/ai/chat", headers=headers, json={"message": "How can I reduce cost?"})
    assert chat.status_code == 200
    assert chat.json()["fallback_used"] in {True, False}
