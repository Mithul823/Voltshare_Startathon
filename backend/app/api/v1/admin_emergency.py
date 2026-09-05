"""Admin emergency assistance API routes."""

from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user, require_role
from app.core.security import AuthenticatedUser
from app.schemas.common import UserRole
from app.schemas.emergency import (
    EmergencyAdminUpdate,
    EmergencyAllocationCreate,
    EmergencyAllocationResponse,
    EmergencyRequestResponse,
    EmergencySummary,
)
from app.services.emergency_service import emergency_service

router = APIRouter()


@router.get("/summary", response_model=EmergencySummary)
def get_emergency_summary(
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> EmergencySummary:
    """Get summary statistics for all emergency requests.

    Requires admin role.
    """
    return emergency_service.get_summary()


@router.get("/requests", response_model=list[EmergencyRequestResponse])
def list_all_emergency_requests(
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> list[EmergencyRequestResponse]:
    """List all emergency requests (admin view).

    Requires admin role.
    """
    return emergency_service.get_all_requests()


@router.get("/requests/{request_id}", response_model=EmergencyRequestResponse)
def get_emergency_request_admin(
    request_id: str,
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> EmergencyRequestResponse:
    """Get details of a specific emergency request.

    Requires admin role.
    """
    return emergency_service.get_request(request_id)


@router.patch("/requests/{request_id}", response_model=EmergencyRequestResponse)
def update_emergency_request(
    request_id: str,
    update: EmergencyAdminUpdate,
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> EmergencyRequestResponse:
    """Update an emergency request (approve/reject/complete).

    Requires admin role. Admin can:
    - Change status (Approved, Rejected, In Progress, Completed)
    - Add admin notes
    - Set allocated energy
    """
    return emergency_service.update_request(request_id, update, user.user_id)


@router.post("/allocations", response_model=EmergencyAllocationResponse, status_code=201)
def create_emergency_allocation(
    data: EmergencyAllocationCreate,
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> EmergencyAllocationResponse:
    """Create an energy allocation for an emergency request.

    Requires admin role. Records the allocation source, amount, and remarks.
    """
    req = emergency_service.get_request(data.request_id)
    consumer_id = req.consumer_id if req else ""
    return emergency_service.create_allocation(data, user.user_id, consumer_id)
