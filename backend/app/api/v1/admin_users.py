from fastapi import APIRouter, Depends, Query

from app.api.dependencies import get_current_user, require_role
from app.core.security import AuthenticatedUser
from app.schemas.admin_users import AdminUserSummary, PaginatedAdminUsers, UserStatusUpdate, UserStatusUpdateResponse
from app.schemas.common import UserRole
from app.services.audit_service import audit_service
from app.services.admin_users_service import admin_users_service

router = APIRouter()


@router.get("/users", response_model=PaginatedAdminUsers)
async def admin_list_users(
    search: str | None = Query(None, description="Search by name or email"),
    role: str | None = Query(None, description="Filter by role"),
    status: str | None = Query(None, description="Filter by status (active, suspended)"),
    kyc_status: str | None = Query(None, description="Filter by KYC status"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> PaginatedAdminUsers:
    """List all users with search, filtering, and pagination.

    Requires admin role. Returns paginated user summaries with
    listing/purchase/dispute counts.
    """
    return await admin_users_service.list_users(
        search=search,
        role=role,
        status=status,
        kyc_status=kyc_status,
        page=page,
        page_size=page_size,
        actor_user_id=user.user_id,
    )


@router.get("/users/{user_id}", response_model=AdminUserSummary)
async def admin_get_user(
    user_id: str,
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> AdminUserSummary:
    """Get detailed information about a specific user.

    Requires admin role.
    """
    return await admin_users_service.get_user_detail(
        user_id=user_id,
        actor_user_id=user.user_id,
    )


@router.patch("/users/{user_id}/status", response_model=UserStatusUpdateResponse)
async def admin_update_user_status(
    user_id: str,
    update: UserStatusUpdate,
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> UserStatusUpdateResponse:
    """Suspend or reactivate a user account.

    Requires admin role. Prevents self-deactivation.
    Generates an audit event for every status change.
    """
    return await admin_users_service.update_user_status(
        target_user_id=user_id,
        is_active=update.is_active,
        reason=update.reason,
        actor_user_id=user.user_id,
        actor_role=UserRole.admin,
    )
