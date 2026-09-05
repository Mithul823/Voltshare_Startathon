from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user
from app.core.security import AuthenticatedUser
from app.schemas.profile import AuthenticatedProfile, ProfileUpdate
from app.services.user_service import user_service

router = APIRouter()


@router.get("/me", response_model=AuthenticatedProfile)
async def get_me(user: AuthenticatedUser = Depends(get_current_user)) -> AuthenticatedProfile:
    return await user_service.current_profile(user)


@router.patch("/me", response_model=AuthenticatedProfile)
async def patch_me(update: ProfileUpdate, user: AuthenticatedUser = Depends(get_current_user)) -> AuthenticatedProfile:
    return await user_service.update_current_profile(user, update)
