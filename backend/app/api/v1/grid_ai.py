from fastapi import APIRouter, Depends

from app.api.dependencies import require_any_role
from app.core.security import AuthenticatedUser
from app.schemas.common import UserRole
from app.schemas.forecast import ForecastHorizon, ForecastMetric, ForecastResponse
from app.schemas.ai import AnomalySeverity, SmartAlert
from app.services.forecasting_service import forecasting_service
from app.services.smart_alert_service import smart_alert_service

router = APIRouter()


@router.get("/forecast", response_model=ForecastResponse)
def forecast(user: AuthenticatedUser = Depends(require_any_role(UserRole.grid_operator, UserRole.admin))) -> ForecastResponse:
    return forecasting_service.forecast(user.user_id, ForecastMetric.peak_demand, ForecastHorizon.six_hours)


@router.get("/alerts", response_model=list[SmartAlert])
def alerts(user: AuthenticatedUser = Depends(require_any_role(UserRole.grid_operator, UserRole.admin))) -> list[SmartAlert]:
    alert = smart_alert_service.create(user, alert_type="grid_imbalance", severity=AnomalySeverity.medium, title="Grid imbalance watch", message="Demand may exceed renewable supply during the evening window.")
    return [alert]
