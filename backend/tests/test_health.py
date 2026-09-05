"""Tests for the /health and /api/v1/health endpoints."""

from fastapi.testclient import TestClient

from app.core.config import get_settings


def test_root_health_returns_200_and_structured_response(client: TestClient, monkeypatch) -> None:
    async def fake_supabase(_settings):
        return {"status": "ok", "reason": "mocked", "latency_ms": 42, "rest_api": "ok"}

    monkeypatch.setattr("app.api.routes.health.check_supabase_reachable", fake_supabase)
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["service"] == "VoltShare API"
    assert body["version"] == get_settings().version
    assert "runtime_mode" in body
    assert "persistence_layer" in body
    assert body["services"]["api"]["status"] == "ok"
    assert body["services"]["supabase"]["status"] == "ok"
    assert body["services"]["database"]["status"] == "ok"
    assert body["services"]["realtime"]["status"] == "active"
    # supabase_configured depends on the test environment — accept either


def test_api_v1_health_returns_same_structure(client: TestClient, monkeypatch) -> None:
    async def fake_supabase(_settings):
        return {"status": "ok", "reason": "mocked", "latency_ms": 42, "rest_api": "ok"}

    monkeypatch.setattr("app.api.v1.health.check_supabase_reachable", fake_supabase)
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["runtime_mode"] in {"demo", "production"}
    assert "persistence_layer" in body
    assert "services" in body


def test_health_shows_degraded_when_supabase_unreachable(client: TestClient, monkeypatch) -> None:
    async def fake_unreachable(_settings):
        return {"status": "unreachable", "reason": "HTTPError: Connection refused"}

    monkeypatch.setattr("app.api.routes.health.check_supabase_reachable", fake_unreachable)
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "degraded"
    assert body["services"]["supabase"]["status"] == "unreachable"
    assert body["services"]["database"]["status"] == "unavailable"
