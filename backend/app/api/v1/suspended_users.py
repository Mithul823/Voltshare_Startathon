from fastapi import APIRouter, Depends, Query

from app.api.dependencies import get_current_user, require_role
from app.core.security import AuthenticatedUser
from app.schemas.common import UserRole
from app.schemas.suspended_users import PaginatedSuspendedUsers, SuspendedUserRecord
from app.services.audit_service import audit_service
from app.services.suspended_users_service import suspended_users_service
from app.services.user_service import user_service

router = APIRouter()


@router.get("", response_model=PaginatedSuspendedUsers)
async def list_suspended_users(
    search: str | None = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> PaginatedSuspendedUsers:
    """List suspended users with search and pagination."""
    return await suspended_users_service.list_suspended(
        search=search,
        page=page,
        page_size=page_size,
    )


@router.get("/history/{target_user_id}", response_model=list[SuspendedUserRecord])
async def get_suspension_history(
    target_user_id: str,
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> list[SuspendedUserRecord]:
    """Get suspension history for a specific user."""
    return await suspended_users_service.get_suspension_history(target_user_id)


@router.post("/{target_user_id}/restore", response_model=SuspendedUserRecord)
async def restore_user(
    target_user_id: str,
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> SuspendedUserRecord:
    """Restore a suspended user to active status."""
    result = await suspended_users_service.restore(target_user_id, user)
    audit_service.append(
        actor_user_id=user.user_id,
        action="user_restored",
        resource_type="user",
        resource_id=target_user_id,
    )
    return result


@router.delete("/{target_user_id}", status_code=204)
async def delete_suspension(
    target_user_id: str,
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> None:
    """Permanently delete a suspension record."""
    await suspended_users_service.delete_suspension(target_user_id, user)
    audit_service.append(
        actor_user_id=user.user_id,
        action="suspension_deleted",
        resource_type="suspension",
        resource_id=target_user_id,
    )
