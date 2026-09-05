from datetime import datetime

from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user
from app.core.security import AuthenticatedUser
from app.schemas.dashboard import (
    BatteryHistoryResponse,
    DashboardHistoryResponse,
    DashboardInterval,
    DashboardResponse,
    DashboardSummary,
)
from app.schemas.dashboard import SimulatedReadingRequest
from app.services.dashboard_service import dashboard_service

router = APIRouter()


@router.get("", response_model=DashboardResponse)
async def dashboard(user: AuthenticatedUser = Depends(get_current_user)) -> DashboardResponse:
    return dashboard_service.dashboard(user.user_id)

@router.post("/simulate", response_model=DashboardResponse)
async def simulate_reading(
    request: SimulatedReadingRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> DashboardResponse:
    """Post a simulated energy reading to the dashboard.

    Used by the energy simulator (scripts/simulate_energy_readings.py) and
    seed scripts to inject realistic energy readings.  The reading is
    persisted via the active energy readings repository and the updated
    dashboard response is returned.

    In live (Supabase) mode the reading is written to the
    ``energy_readings`` table.  In demo mode it is appended to the
    in-memory store.
    """
    return dashboard_service.simulate(user.user_id, request)


@router.get("/summary", response_model=DashboardSummary)
async def dashboard_summary(user: AuthenticatedUser = Depends(get_current_user)) -> DashboardSummary:
    return dashboard_service.summary(user.user_id)


@router.get("/history", response_model=DashboardHistoryResponse)
@router.get("/energy-history", response_model=DashboardHistoryResponse)
async def energy_history(
    start: datetime | None = None,
    end: datetime | None = None,
    interval: DashboardInterval = DashboardInterval.hour,
    user: AuthenticatedUser = Depends(get_current_user),
) -> DashboardHistoryResponse:
    return dashboard_service.history(user.user_id, start, end, interval)


@router.get("/battery-history", response_model=BatteryHistoryResponse)
async def battery_history(
    start: datetime | None = None,
    end: datetime | None = None,
    interval: DashboardInterval = DashboardInterval.hour,
    user: AuthenticatedUser = Depends(get_current_user),
) -> BatteryHistoryResponse:
    return dashboard_service.battery_history(user.user_id, start, end, interval)


@router.get("/activity")
async def dashboard_activity(user: AuthenticatedUser = Depends(get_current_user)) -> dict:
    return {"activity": dashboard_service.activity(user.user_id)}
