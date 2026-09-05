from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user, require_role
from app.core.config import Settings, get_settings
from app.core.exceptions import ApiError, ErrorCode
from app.core.security import AuthenticatedUser
from app.schemas.common import UserRole
from app.schemas.profile import AuthenticatedProfile
from app.services.user_service import user_service

router = APIRouter()


@router.get("/me", response_model=AuthenticatedProfile)
async def me(user: AuthenticatedUser = Depends(get_current_user)) -> AuthenticatedProfile:
    return await user_service.current_profile(user)


@router.get("/protected")
async def protected(user: AuthenticatedUser = Depends(get_current_user)) -> dict[str, str]:
    return {"status": "ok", "user_id": user.user_id, "role": user.role.value}


@router.get("/admin-only")
async def admin_only(
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
    settings: Settings = Depends(get_settings),
) -> dict[str, str]:
    if not settings.is_demo_mode:
        raise ApiError(404, ErrorCode.RESOURCE_NOT_FOUND, "Endpoint not found.")
    return {"status": "ok", "user_id": user.user_id, "role": user.role.value}
