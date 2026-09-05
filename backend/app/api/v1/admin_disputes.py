from fastapi import APIRouter, Depends, Query

from app.api.dependencies import get_current_user, require_role
from app.core.security import AuthenticatedUser
from app.schemas.admin_disputes import AdminDisputeSummary, PaginatedAdminDisputes, DisputeResolutionRequest, DisputeActionResponse
from app.schemas.common import UserRole
from app.services.admin_disputes_service import admin_disputes_service

router = APIRouter()


@router.get("/disputes", response_model=PaginatedAdminDisputes)
async def admin_list_disputes(
    status: str | None = Query(None, description="Filter by status (open, under_review, resolved, rejected)"),
    priority: str | None = Query(None, description="Filter by priority (low, medium, high, critical)"),
    buyer_id: str | None = Query(None),
    seller_id: str | None = Query(None),
    date_from: str | None = Query(None),
    date_to: str | None = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> PaginatedAdminDisputes:
    """List disputes with filtering and pagination.

    Requires admin role.
    """
    return await admin_disputes_service.list_disputes(
        status=status,
        priority=priority,
        buyer_id=buyer_id,
        seller_id=seller_id,
        date_from=date_from,
        date_to=date_to,
        page=page,
        page_size=page_size,
        actor_user_id=user.user_id,
    )


@router.get("/disputes/{dispute_id}", response_model=AdminDisputeSummary)
async def admin_get_dispute(
    dispute_id: str,
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> AdminDisputeSummary:
    """Get detailed dispute information."""
    return await admin_disputes_service.get_dispute_detail(
        dispute_id=dispute_id,
        actor_user_id=user.user_id,
    )


@router.post("/disputes/{dispute_id}/resolve", response_model=DisputeActionResponse)
async def admin_resolve_dispute(
    dispute_id: str,
    request: DisputeResolutionRequest,
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> DisputeActionResponse:
    """Resolve a dispute with validated financial amounts.

    Requires admin role. Validates that refund + seller release
    does not exceed the escrow amount when escrow data is available.
    Generates an audit event.
    """
    return await admin_disputes_service.resolve_dispute(
        dispute_id=dispute_id,
        resolution=request.resolution,
        reason=request.reason,
        refund_amount_paise=request.refund_amount_paise,
        release_to_seller_paise=request.release_to_seller_paise,
        actor_user_id=user.user_id,
        actor_role=UserRole.admin,
    )


@router.post("/disputes/{dispute_id}/reject", response_model=DisputeActionResponse)
async def admin_reject_dispute(
    dispute_id: str,
    request: DisputeResolutionRequest,
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> DisputeActionResponse:
    """Reject a dispute with a reason.

    Requires admin role. Generates an audit event.
    """
    return await admin_disputes_service.reject_dispute(
        dispute_id=dispute_id,
        reason=request.reason,
        actor_user_id=user.user_id,
        actor_role=UserRole.admin,
    )


@router.post("/disputes/{dispute_id}/assign", response_model=DisputeActionResponse)
async def admin_assign_dispute(
    dispute_id: str,
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> DisputeActionResponse:
    """Assign a dispute to the requesting admin.

    Requires admin role. Generates an audit event.
    """
    return await admin_disputes_service.assign_dispute(
        dispute_id=dispute_id,
        actor_user_id=user.user_id,
        actor_role=UserRole.admin,
    )
