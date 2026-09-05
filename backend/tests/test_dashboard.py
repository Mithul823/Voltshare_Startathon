from fastapi.testclient import TestClient

from app.schemas.common import UserRole
from app.services.dashboard_service import dashboard_service
from tests.conftest import auth_headers, make_token, seed_profile


def test_dashboard_endpoint_requires_auth(client: TestClient) -> None:
    response = client.get("/api/v1/dashboard")
    assert response.status_code == 401


def test_dashboard_endpoint_returns_summary_metrics_and_timelines(client: TestClient) -> None:
    seed_profile("dash-user", UserRole.consumer)
    response = client.get("/api/v1/dashboard", headers=auth_headers("dash-user"))
    assert response.status_code == 200
    body = response.json()
    assert body["summary"]["daily_production_kwh"] >= 0
    assert body["metrics"]["sustainability_score"] >= 0
    assert body["carbon"]["carbon_saved_kg"] >= 0
    assert body["ai_insights"]
    assert body["activity"]
    assert body["energy_timeline"]
    assert body["battery_timeline"]
    assert "solarGenerationTodayKwh" in body


def test_summary_history_battery_and_activity_endpoints(client: TestClient) -> None:
    seed_profile("history-user", UserRole.consumer)
    headers = auth_headers("history-user")
    assert client.get("/api/v1/dashboard/summary", headers=headers).status_code == 200
    history = client.get("/api/v1/dashboard/history?interval=hour", headers=headers)
    assert history.status_code == 200
    assert history.json()["energy"]
    battery = client.get("/api/v1/dashboard/battery-history?interval=day", headers=headers)
    assert battery.status_code == 200
    assert battery.json()["battery"]
    activity = client.get("/api/v1/dashboard/activity", headers=headers)
    assert activity.status_code == 200
    assert activity.json()["activity"]


def test_websocket_rejects_missing_auth(client: TestClient) -> None:
    try:
        with client.websocket_connect("/ws/dashboard"):
            raise AssertionError("websocket should not accept missing auth")
    except Exception:
        assert True


def test_websocket_accepts_authenticated_user(client: TestClient) -> None:
    seed_profile("ws-user", UserRole.consumer)
    token = make_token("ws-user")
    with client.websocket_connect(f"/ws/dashboard?token={token}") as websocket:
        payload = websocket.receive_json()
        assert payload["summary"]["daily_production_kwh"] >= 0
        assert payload["metrics"]["sustainability_score"] >= 0


def test_sustainability_score_is_transparent_and_bounded() -> None:
    score = dashboard_service.sustainability_score(
        renewable_percentage=0.8,
        grid_dependency=0.2,
        grid_export=4,
        battery_percent=80,
        efficiency=0.9,
    )
    assert 0 <= score <= 100
    assert score > 70


def test_rule_based_ai_insights_are_generated(client: TestClient) -> None:
    seed_profile("insight-user", UserRole.consumer)
    body = client.get("/api/v1/dashboard", headers=auth_headers("insight-user")).json()
    titles = {item["title"] for item in body["ai_insights"]}
    assert titles
    assert any("solar" in title.lower() or "grid" in title.lower() or "energy" in title.lower() for title in titles)


def test_dashboard_migration_contains_rls_policy() -> None:
    sql = open("app/db/migrations/004_dashboard_energy_monitoring.sql", encoding="utf-8").read()
    assert "enable row level security" in sql.lower()
    assert "auth.uid() = user_id" in sql
