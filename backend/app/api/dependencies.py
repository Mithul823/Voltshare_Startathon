from collections.abc import Callable

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.config import Settings, get_settings
from app.core.security import AuthenticatedUser, ensure_owner_or_admin, ensure_roles, token_from_credentials
from app.schemas.common import UserRole
from app.services.user_service import user_service

bearer = HTTPBearer(auto_error=False)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    settings: Settings = Depends(get_settings),
) -> AuthenticatedUser:
    token, claims = token_from_credentials(credentials, settings)
    return await user_service.user_from_claims(token, claims)


async def get_current_user_id(user: AuthenticatedUser = Depends(get_current_user)) -> str:
    return user.user_id


require_authenticated_user = get_current_user


def require_role(role: UserRole) -> Callable[[AuthenticatedUser], AuthenticatedUser]:
    def guard(user: AuthenticatedUser = Depends(get_current_user)) -> AuthenticatedUser:
        ensure_roles(user, [role])
        return user

    return guard


def require_any_role(*roles: UserRole) -> Callable[[AuthenticatedUser], AuthenticatedUser]:
    def guard(user: AuthenticatedUser = Depends(get_current_user)) -> AuthenticatedUser:
        ensure_roles(user, roles)
        return user

    return guard


def require_roles(*roles: str) -> Callable[[AuthenticatedUser], AuthenticatedUser]:
    parsed = tuple(UserRole(role) for role in roles)
    return require_any_role(*parsed)


def require_owner_or_admin(owner_id: str, user: AuthenticatedUser) -> None:
    ensure_owner_or_admin(user, owner_id)
