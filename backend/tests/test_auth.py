from fastapi.testclient import TestClient
import jwt
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric import rsa

from app.core.config import Settings
from app.core.security import decode_supabase_token
from app.schemas.common import UserRole
from tests.conftest import auth_headers, make_token, seed_profile


def test_missing_authorization_returns_401(client: TestClient) -> None:
    response = client.get("/api/v1/auth/me")
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "AUTH_REQUIRED"


def test_invalid_token_returns_401(client: TestClient) -> None:
    response = client.get("/api/v1/auth/me", headers={"Authorization": "Bearer invalid-token"})
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "AUTH_INVALID_TOKEN"


def test_expired_token_returns_401(client: TestClient) -> None:
    response = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {make_token('expired-user', expired=True)}"})
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "AUTH_INVALID_TOKEN"


def test_authenticated_user_can_access_me(client: TestClient) -> None:
    seed_profile("auth-user", UserRole.consumer)
    response = client.get("/api/v1/auth/me", headers=auth_headers("auth-user"))
    assert response.status_code == 200
    assert response.json()["id"] == "auth-user"
    assert response.json()["role"] == "consumer"


def test_rs256_token_uses_jwks_verification(monkeypatch) -> None:
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public_key = private_key.public_key()

    class FakeSigningKey:
        key = public_key

    class FakeJwksClient:
        def get_signing_key_from_jwt(self, _token):
            return FakeSigningKey()

    monkeypatch.setattr("app.core.security.jwks_client", lambda _url: FakeJwksClient())
    settings = Settings(
        app_env="test",
        supabase_url="https://example.supabase.co",
        supabase_jwks_url="https://example.supabase.co/auth/v1/.well-known/jwks.json",
    )
    token = jwt.encode(
        {
            "sub": "jwks-user",
            "email": "jwks-user@example.com",
            "iss": settings.expected_issuer,
            "aud": "authenticated",
            "exp": 4102444800,
        },
        private_key,
        algorithm="RS256",
        headers={"kid": "test-key"},
    )
    claims = decode_supabase_token(token, settings)
    assert claims.subject == "jwks-user"


def test_es256_token_uses_jwks_verification(monkeypatch) -> None:
    private_key = ec.generate_private_key(ec.SECP256R1())
    public_key = private_key.public_key()

    class FakeSigningKey:
        key = public_key

    class FakeJwksClient:
        def get_signing_key_from_jwt(self, _token):
            return FakeSigningKey()

    monkeypatch.setattr("app.core.security.jwks_client", lambda _url: FakeJwksClient())
    settings = Settings(
        app_env="test",
        supabase_url="https://example.supabase.co",
        supabase_jwks_url="https://example.supabase.co/auth/v1/.well-known/jwks.json",
    )
    token = jwt.encode(
        {
            "sub": "jwks-es-user",
            "email": "jwks-es-user@example.com",
            "iss": settings.expected_issuer,
            "aud": "authenticated",
            "exp": 4102444800,
        },
        private_key,
        algorithm="ES256",
        headers={"kid": "test-es-key"},
    )
    claims = decode_supabase_token(token, settings)
    assert claims.subject == "jwks-es-user"


def test_user_cannot_modify_role_through_profile_update(client: TestClient) -> None:
    seed_profile("profile-user", UserRole.consumer)
    response = client.patch(
        "/api/v1/users/me",
        headers=auth_headers("profile-user"),
        json={"full_name": "Updated Name", "role": "admin", "is_active": False},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["full_name"] == "Updated Name"
    assert body["role"] == "consumer"
    assert body["is_active"] is True


def test_unsigned_fallback_is_disabled_in_all_environments():
    import pytest
    from app.core.exceptions import ApiError

    forged = jwt.encode({"sub": "existing-user", "exp": 4102444800}, "attacker-key-for-signature-test-only", algorithm="HS256")
    for environment in ("development", "demo", "test", "production"):
        settings = Settings(_env_file=None, app_env=environment, supabase_jwt_secret="", supabase_jwks_url="")
        with pytest.raises(ApiError) as error:
            decode_supabase_token(forged, settings)
        assert error.value.status_code == 500


def test_wrong_signature_is_rejected():
    import pytest
    from app.core.exceptions import ApiError

    settings = Settings(_env_file=None, supabase_jwt_secret="trusted-signing-key-for-test-only")
    forged = jwt.encode({"sub": "existing-user", "exp": 4102444800}, "attacker-signing-key-for-test-only", algorithm="HS256")
    with pytest.raises(ApiError) as error:
        decode_supabase_token(forged, settings)
    assert error.value.status_code == 401



def test_suspended_user_cannot_access_wallet(client):
    from app.repositories.profile_repository import profile_repository
    from app.schemas.profile import Profile
    profile_repository.set_test_profile(Profile(id="suspended", email="suspended@example.com", full_name="Suspended", role=UserRole.consumer, email_verified=True, is_active=False))
    response = client.get("/api/v1/wallet", headers=auth_headers("suspended"))
    assert response.status_code == 403
