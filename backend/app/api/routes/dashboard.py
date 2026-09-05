from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user, require_roles
from app.core.config import Settings, get_settings
from app.core.exceptions import ApiError, ErrorCode
from app.core.security import AuthenticatedUser
from app.schemas.dashboard import DashboardSnapshot, SimulatedReadingRequest
from app.services.dashboard_service import dashboard_service

router = APIRouter()


@router.get("", response_model=DashboardSnapshot)
def dashboard(user: AuthenticatedUser = Depends(get_current_user)) -> DashboardSnapshot:
    return dashboard_service.snapshot(user.user_id)


@router.get("/history")
def dashboard_history(user: AuthenticatedUser = Depends(get_current_user)) -> dict:
    snapshot = dashboard_service.snapshot(user.user_id)
    return {"solarHistory": snapshot.solarHistory, "consumptionHistory": snapshot.consumptionHistory}


@router.post("/simulate-reading", response_model=DashboardSnapshot)
def simulate_reading(
    request: SimulatedReadingRequest,
    user: AuthenticatedUser = Depends(require_roles("prosumer", "producer", "admin")),
    settings: Settings = Depends(get_settings),
) -> DashboardSnapshot:
    if not settings.is_demo_mode:
        raise ApiError(403, ErrorCode.ACCESS_DENIED, "Simulation is disabled outside demo/development mode.")
    return dashboard_service.simulate(user.user_id, request)
