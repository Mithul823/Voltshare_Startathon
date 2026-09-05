from app.core.exceptions import ApiError, ErrorCode
from app.core.security import AuthenticatedUser, TokenClaims
from app.repositories.profile_repository import profile_repository
from app.schemas.profile import AuthenticatedProfile, Profile, ProfileUpdate


class UserService:
    async def user_from_claims(self, token: str, claims: TokenClaims) -> AuthenticatedUser:
        profile = await profile_repository.get_profile(claims.subject, email=claims.email)
        if not profile.is_active:
            raise ApiError(403, ErrorCode.ACCESS_DENIED, "This account is suspended.")
        return AuthenticatedUser(user_id=claims.subject, email=claims.email, role=profile.role, token=token)

    async def current_profile(self, user: AuthenticatedUser) -> AuthenticatedProfile:
        profile = await profile_repository.get_profile(user.user_id, email=user.email)
        return self.to_authenticated_profile(profile, user.email)

    async def update_current_profile(self, user: AuthenticatedUser, update: ProfileUpdate) -> AuthenticatedProfile:
        profile = await profile_repository.update_profile(user.user_id, update, email=user.email)
        return self.to_authenticated_profile(profile, user.email)

    def to_authenticated_profile(self, profile: Profile, email: str | None) -> AuthenticatedProfile:
        return AuthenticatedProfile(
            id=profile.id,
            email=profile.email or email,
            full_name=profile.full_name,
            role=profile.role,
            email_verified=profile.email_verified,
            is_active=profile.is_active,
        )


user_service = UserService()
