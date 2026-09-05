"""Admin users service — manages user listing, search, filtering, and status updates."""

from app.schemas.admin_users import AdminUserSummary, PaginatedAdminUsers, UserStatusUpdateResponse
from app.schemas.common import UserRole
from app.services.audit_service import audit_service


class AdminUsersService:
    def __init__(self) -> None:
        self._repo_instance: object | None = None

    @property
    def _repo(self) -> object:
        if self._repo_instance is None:
            from app.repositories.admin_users_repository import get_admin_users_repository
            self._repo_instance = get_admin_users_repository()
        return self._repo_instance

    async def list_users(
        self,
        search: str | None = None,
        role: str | None = None,
        status: str | None = None,
        kyc_status: str | None = None,
        page: int = 1,
        page_size: int = 20,
        actor_user_id: str | None = None,
    ) -> PaginatedAdminUsers:
        return await self._repo.list_users(
            search=search,
            role=role,
            status=status,
            kyc_status=kyc_status,
            page=page,
            page_size=page_size,
        )

    async def get_user_detail(
        self,
        user_id: str,
        actor_user_id: str | None = None,
    ) -> AdminUserSummary:
        return await self._repo.get_user_detail(user_id=user_id)

    async def update_user_status(
        self,
        target_user_id: str,
        is_active: bool,
        reason: str = "",
        actor_user_id: str | None = None,
        actor_role: UserRole | None = None,
    ) -> UserStatusUpdateResponse:
        # Prevent self-deactivation
        if actor_user_id and target_user_id == actor_user_id:
            return UserStatusUpdateResponse(
                id=target_user_id,
                is_active=True,
                message="Administrators cannot deactivate their own account.",
            )

        result = await self._repo.update_user_status(
            user_id=target_user_id,
            is_active=is_active,
        )

        # Create audit event
        action = "user_suspended" if not is_active else "user_reactivated"
        status_val = "succeeded"
        audit_service.append(
            actor_user_id=actor_user_id or "system",
            action=action,
            resource_type="user",
            resource_id=target_user_id,
            status=status_val,
            metadata={"reason": reason, "is_active": is_active},
        )

        return result


admin_users_service = AdminUsersService()
