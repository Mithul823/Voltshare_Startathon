from dataclasses import dataclass
from datetime import datetime, timezone
from functools import lru_cache
from typing import Iterable

import jwt
from fastapi.security import HTTPAuthorizationCredentials
from jwt import PyJWKClient

from app.core.config import Settings
from app.core.exceptions import ApiError, ErrorCode
from app.schemas.common import UserRole


@dataclass(frozen=True)
class TokenClaims:
    subject: str
    email: str | None
    issuer: str | None


@dataclass(frozen=True)
class AuthenticatedUser:
    user_id: str
    email: str | None
    role: UserRole
    token: str


@lru_cache(maxsize=4)
def jwks_client(jwks_url: str) -> PyJWKClient:
    return PyJWKClient(jwks_url, cache_keys=True)


def decode_supabase_token(token: str, settings: Settings) -> TokenClaims:
    if not token:
        raise ApiError(401, ErrorCode.AUTH_INVALID_TOKEN, "The access token is invalid or expired.")
    try:
        header = jwt.get_unverified_header(token)
        algorithm = str(header.get("alg", ""))

        # Determine issuer verification — only verify when a JWKS URL is
        # explicitly configured to avoid rejecting tokens that lack the `iss`
        # claim (possible for some Supabase projects).
        expected_issuer = settings.expected_issuer if settings.supabase_jwks_url else None
        verify_iss = bool(expected_issuer)
        verify_aud = False  # Supabase tokens use "authenticated" but we don't enforce it

        if algorithm.startswith(("RS", "ES")):
            if not settings.supabase_jwks_url:
                raise ApiError(500, ErrorCode.CONFIGURATION_ERROR, "Supabase JWKS URL is not configured.")
            try:
                signing_key = jwks_client(settings.supabase_jwks_url).get_signing_key_from_jwt(token)
            except Exception as exc:
                raise ApiError(401, ErrorCode.AUTH_INVALID_TOKEN,
                               "Cannot verify access token signature.") from exc
            payload = jwt.decode(
                token,
                signing_key.key,
                algorithms=[algorithm],
                options={
                    "verify_aud": verify_aud,
                    "verify_iss": verify_iss,
                    "verify_exp": True,
                    "verify_iat": True,
                },
                issuer=expected_issuer,
            )
        elif settings.supabase_jwt_secret:
            payload = jwt.decode(
                token,
                settings.supabase_jwt_secret,
                algorithms=["HS256"],
                options={
                    "verify_aud": False,
                    "verify_iss": verify_iss,
                    "verify_exp": True,
                    "verify_iat": True,
                },
                issuer=expected_issuer,
            )
        elif settings.app_env in {"development", "demo", "test"}:
            payload = jwt.decode(token, options={
                "verify_signature": False,
                "verify_aud": False,
                "verify_iss": False,
                "verify_exp": True,
                "verify_iat": True,
            })
        else:
            raise ApiError(500, ErrorCode.CONFIGURATION_ERROR, "JWT verification is not configured.")
    except ApiError:
        raise
    except jwt.ExpiredSignatureError as exc:
        raise ApiError(401, ErrorCode.AUTH_INVALID_TOKEN, "The access token is invalid or expired.") from exc
    except jwt.InvalidTokenError as exc:
        raise ApiError(401, ErrorCode.AUTH_INVALID_TOKEN, "The access token is invalid or expired.") from exc

    subject = payload.get("sub")
    if not subject:
        raise ApiError(401, ErrorCode.AUTH_INVALID_TOKEN, "The access token is missing a subject.")
    exp = payload.get("exp")
    if exp and datetime.fromtimestamp(int(exp), tz=timezone.utc) < datetime.now(timezone.utc):
        raise ApiError(401, ErrorCode.AUTH_INVALID_TOKEN, "The access token is invalid or expired.")
    return TokenClaims(subject=str(subject), email=payload.get("email"), issuer=payload.get("iss"))


def token_from_credentials(credentials: HTTPAuthorizationCredentials | None, settings: Settings) -> tuple[str, TokenClaims]:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise ApiError(401, ErrorCode.AUTH_REQUIRED, "Bearer authentication is required.")
    return credentials.credentials, decode_supabase_token(credentials.credentials, settings)


def ensure_roles(user: AuthenticatedUser, allowed: Iterable[UserRole]) -> None:
    if user.role == UserRole.admin:
        return
    if user.role not in set(allowed):
        raise ApiError(403, ErrorCode.ACCESS_DENIED, "This role is not allowed to perform this action.")


def ensure_owner_or_admin(user: AuthenticatedUser, owner_id: str) -> None:
    if user.role != UserRole.admin and user.user_id != owner_id:
        raise ApiError(403, ErrorCode.ACCESS_DENIED, "You can only access your own resource.")
