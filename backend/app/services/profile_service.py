from app.core.security import AuthenticatedUser
from app.schemas.profile import Profile
from app.services.user_service import user_service


class ProfileService:
    def current(self, user: AuthenticatedUser) -> Profile:
        return Profile(id=user.user_id, email=user.email, role=user.role)


profile_service = ProfileService()

__all__ = ["profile_service", "user_service"]
