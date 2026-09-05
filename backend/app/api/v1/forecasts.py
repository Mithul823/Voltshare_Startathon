from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user
from app.core.security import AuthenticatedUser
from app.schemas.forecast import ForecastHorizon, ForecastMetric, ForecastResponse, ForecastSummary
from app.schemas.realtime import RealtimeChannel
from app.services.event_publisher import event_publisher
from app.services.forecasting_service import forecasting_service

router = APIRouter()


def _forecast(user: AuthenticatedUser, metric: ForecastMetric, horizon: ForecastHorizon) -> ForecastResponse:
    response = forecasting_service.forecast(user.user_id, metric, horizon)
    event_publisher.publish("forecast.updated", channels=[RealtimeChannel.dashboard], user_id=user.user_id, payload={"metric": metric.value, "horizon": horizon.value})
    return response


@router.get("/consumption", response_model=ForecastResponse)
def consumption(horizon: ForecastHorizon = ForecastHorizon.twenty_four_hours, user: AuthenticatedUser = Depends(get_current_user)) -> ForecastResponse:
    return _forecast(user, ForecastMetric.consumption, horizon)


@router.get("/generation", response_model=ForecastResponse)
def generation(horizon: ForecastHorizon = ForecastHorizon.twenty_four_hours, user: AuthenticatedUser = Depends(get_current_user)) -> ForecastResponse:
    return _forecast(user, ForecastMetric.generation, horizon)


@router.get("/price", response_model=ForecastResponse)
def price(horizon: ForecastHorizon = ForecastHorizon.six_hours, user: AuthenticatedUser = Depends(get_current_user)) -> ForecastResponse:
    return _forecast(user, ForecastMetric.price, horizon)


@router.get("/battery", response_model=ForecastResponse)
def battery(horizon: ForecastHorizon = ForecastHorizon.six_hours, user: AuthenticatedUser = Depends(get_current_user)) -> ForecastResponse:
    return _forecast(user, ForecastMetric.battery, horizon)


@router.get("/summary", response_model=ForecastSummary)
def summary(user: AuthenticatedUser = Depends(get_current_user)) -> ForecastSummary:
    return forecasting_service.summary(user.user_id)
