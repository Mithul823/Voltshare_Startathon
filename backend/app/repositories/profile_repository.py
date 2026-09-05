from app.core.exceptions import ApiError, ErrorCode
from app.db.supabase import get_supabase_admin_client
from app.schemas.common import UserRole, now_utc
from app.schemas.profile import Profile, ProfileUpdate


class ProfileRepository:
    def __init__(self) -> None:
        self._test_profiles: dict[str, Profile] = {}

    def set_test_profile(self, profile: Profile) -> None:
        self._test_profiles[profile.id] = profile

    def clear_test_profiles(self) -> None:
        self._test_profiles.clear()

    async def get_profile(self, user_id: str, email: str | None = None) -> Profile:
        cached = self._test_profiles.get(user_id)
        if cached is not None:
            return cached
        client = get_supabase_admin_client()
        if client is None:
            return Profile(id=user_id, email=email, role=UserRole.consumer)
        try:
            result = client.table("profiles").select("*").eq("id", user_id).maybe_single().execute()
        except Exception as exc:
            raise ApiError(503, ErrorCode.DATABASE_ERROR, "Unable to load user profile.") from exc
        if result is None or not result.data:
            return Profile(id=user_id, email=email, role=UserRole.consumer)
        return Profile.model_validate(result.data)

    async def update_profile(self, user_id: str, update: ProfileUpdate, email: str | None = None) -> Profile:
        safe_data = update.model_dump(exclude_unset=True, exclude_none=True)
        if not safe_data:
            return await self.get_profile(user_id, email=email)
        # Prevent users from changing their own role via profile update
        if "role" in safe_data:
            raise ApiError(403, ErrorCode.ACCESS_DENIED, "Role cannot be changed through profile update.")
        safe_data["updated_at"] = now_utc().isoformat()
        if user_id in self._test_profiles:
            current = self._test_profiles[user_id]
            updated = current.model_copy(update=safe_data)
            self._test_profiles[user_id] = updated
            return updated
        client = get_supabase_admin_client()
        if client is None:
            current = await self.get_profile(user_id, email=email)
            updated = current.model_copy(update=safe_data)
            self._test_profiles[user_id] = updated
            return updated
        try:
            result = client.table("profiles").update(safe_data).eq("id", user_id).execute()
        except Exception as exc:
            raise ApiError(503, ErrorCode.DATABASE_ERROR, "Unable to update user profile.") from exc
        if result.data:
            return Profile.model_validate(result.data[0])
        return await self.get_profile(user_id, email=email)


profile_repository = ProfileRepository()
