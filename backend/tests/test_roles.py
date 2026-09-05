from fastapi.testclient import TestClient

from app.schemas.common import UserRole
from tests.conftest import auth_headers, seed_profile


def test_non_admin_receives_403_from_admin_only(client: TestClient) -> None:
    seed_profile("plain-user", UserRole.consumer)
    response = client.get("/api/v1/auth/admin-only", headers=auth_headers("plain-user"))
    assert response.status_code == 403


def test_admin_can_access_admin_only(client: TestClient) -> None:
    seed_profile("admin-user", UserRole.admin)
    response = client.get("/api/v1/auth/admin-only", headers=auth_headers("admin-user"))
    assert response.status_code == 200
    assert response.json()["role"] == "admin"
