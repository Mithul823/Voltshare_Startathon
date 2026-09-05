from enum import Enum

from pydantic import Field

from app.schemas.common import ApiModel


class InsightCategory(str, Enum):
    generation = "generation"
    consumption = "consumption"
    battery = "battery"
    marketplace = "marketplace"
    sustainability = "sustainability"


class InsightPriority(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"


class InsightRequest(ApiModel):
    solar_generation: float = Field(ge=0)
    consumption: float = Field(ge=0)
    battery_level: int = Field(ge=0, le=100)
    surplus: float = Field(ge=0)
    price_per_kwh: float = Field(ge=0)
    historical_trend: list[float] = []
    user_role: str
    marketplace_conditions: str | None = None


class InsightResponse(ApiModel):
    title: str
    message: str
    category: InsightCategory
    priority: InsightPriority
    action_label: str | None = None
    confidence: float = Field(ge=0, le=1)
    estimated_savings_paise: int = Field(ge=0)
    best_time_window: str | None = None
    source: str = "fallback rule engine"
