from fastapi.testclient import TestClient
from app.core.config import get_settings
from app.main import create_app


def test_mock_routes_absent_when_demo_disabled(monkeypatch):
    monkeypatch.setattr(get_settings(), "enable_demo_endpoints", False)
    client = TestClient(create_app())
    assert client.get("/api/v1/mock/listings").status_code == 404
    assert client.post("/api/v1/mock/purchases", json={}).status_code == 404


def test_dispute_and_default_details_require_authentication(client):
    for path in ("/api/v1/disputes/unknown", "/api/v1/default-cases", "/api/v1/default-cases/unknown"):
        assert client.get(path).status_code == 401
