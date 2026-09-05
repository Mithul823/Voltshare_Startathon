from fastapi import APIRouter, Depends, Query

from app.api.dependencies import get_current_user, require_role
from app.core.security import AuthenticatedUser
from app.schemas.admin_dashboard import AdminDashboardResponse
from app.schemas.common import UserRole
from app.services.admin_dashboard_service import admin_dashboard_service

router = APIRouter()


@router.get("/dashboard", response_model=AdminDashboardResponse)
async def admin_dashboard(
    range: int = Query(30, ge=1, le=365, description="Days of history to include"),
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> AdminDashboardResponse:
    """Admin dashboard with platform-wide metrics, grid status, health, and activity.

    Requires admin role. Returns aggregated data for the admin overview screen.
    """
    return await admin_dashboard_service.dashboard(range_days=range)
