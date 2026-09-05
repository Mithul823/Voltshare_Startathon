from fastapi import APIRouter, Depends, Query

from app.api.dependencies import get_current_user, require_role
from app.core.security import AuthenticatedUser
from app.schemas.common import UserRole
from app.schemas.kyc import KycAdminSummary, KycRecord, KycRecordResponse, KycReviewRequest, PaginatedKycRecords
from app.services.audit_service import audit_service
from app.services.kyc_service import kyc_service

router = APIRouter()


@router.get("/summary", response_model=KycAdminSummary)
async def admin_kyc_summary(
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> KycAdminSummary:
    """Get KYC summary statistics for the admin dashboard."""
    return await kyc_service.get_summary()


@router.get("", response_model=PaginatedKycRecords)
async def admin_list_kyc(
    status: str | None = Query(None, description="Filter by status"),
    search: str | None = Query(None, description="Search by name or ID number"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> PaginatedKycRecords:
    """List all KYC records with filtering and pagination."""
    return await kyc_service.list_all(
        status=status,
        search=search,
        page=page,
        page_size=page_size,
    )


@router.get("/{kyc_id}", response_model=KycRecordResponse)
async def admin_get_kyc(
    kyc_id: str,
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> KycRecordResponse:
    """Get a specific KYC record by ID."""
    records = await kyc_service.list_all(page=1, page_size=1000)
    for record in records.items:
        if record.id == kyc_id:
            return record
    from fastapi import HTTPException
    raise HTTPException(status_code=404, detail="KYC record not found.")


@router.patch("/{kyc_id}/review", response_model=KycRecord)
async def admin_review_kyc(
    kyc_id: str,
    review: KycReviewRequest,
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> KycRecord:
    """Review and update KYC status (approve/reject/request resubmission)."""
    record = await kyc_service.review(kyc_id, review.status, review.remarks, user)
    audit_service.append(
        actor_user_id=user.user_id,
        action=f"kyc_{review.status.value}",
        resource_type="kyc",
        resource_id=kyc_id,
        metadata={"remarks": review.remarks},
    )
    return record
