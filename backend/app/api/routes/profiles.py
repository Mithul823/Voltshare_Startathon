from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user
from app.core.security import AuthenticatedUser
from app.schemas.profile import Profile
from app.services.profile_service import profile_service

router = APIRouter()


@router.get("/me", response_model=Profile)
def current_profile(user: AuthenticatedUser = Depends(get_current_user)) -> Profile:
    return profile_service.current(user)
