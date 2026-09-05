from datetime import datetime
from enum import Enum

from pydantic import Field

from app.schemas.common import ApiModel, now_utc


class ForecastMetric(str, Enum):
    consumption = "energy_consumption"
    generation = "energy_generation"
    price = "marketplace_price"
    battery = "battery_level"
    peak_demand = "peak_demand_period"
    daily_cost = "expected_daily_cost"
    producer_earnings = "expected_producer_earnings"


class ForecastHorizon(str, Enum):
    next_hour = "1h"
    six_hours = "6h"
    twenty_four_hours = "24h"
    seven_days = "7d"


class ForecastPoint(ApiModel):
    timestamp: datetime
    value: float
    unit: str


class ForecastResponse(ApiModel):
    metric: ForecastMetric
    horizon: ForecastHorizon
    model: str
    confidence: float = Field(ge=0, le=1)
    data_points_used: int
    forecast: list[ForecastPoint]
    generated_at: datetime = Field(default_factory=now_utc)
    explanation: str
    limitations: list[str] = []
    fallback_used: bool = False


class ForecastSummary(ApiModel):
    consumption: ForecastResponse
    generation: ForecastResponse
    price: ForecastResponse
    battery: ForecastResponse
