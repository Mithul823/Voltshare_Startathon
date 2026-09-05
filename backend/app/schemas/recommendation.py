from datetime import datetime, timedelta
from enum import Enum
from typing import Any

from pydantic import Field

from app.schemas.common import ApiModel, new_id, now_utc


class RecommendationCategory(str, Enum):
    buying = "buying"
    selling = "selling"
    battery = "battery"
    sustainability = "sustainability"
    anomaly = "anomaly"
    grid = "grid"
    pricing = "pricing"
    system = "system"


class RecommendationPriority(str, Enum):
    low = "LOW"
    medium = "MEDIUM"
    high = "HIGH"
    critical = "CRITICAL"


class Recommendation(ApiModel):
    recommendation_id: str = Field(default_factory=lambda: new_id("REC"))
    title: str
    message: str
    category: RecommendationCategory
    priority: RecommendationPriority
    confidence: float = Field(ge=0, le=1)
    reason: str
    supporting_metrics: dict[str, Any] = {}
    action_type: str | None = None
    action_route: str | None = None
    created_at: datetime = Field(default_factory=now_utc)
    expires_at: datetime = Field(default_factory=lambda: now_utc() + timedelta(hours=6))
    model: str = "rule_based"
    dismissed: bool = False


class PricingSuggestionRequest(ApiModel):
    energy_source: str = "solar"
    quantity_kwh: float = Field(default=1, gt=0)
    duration_hours: int = Field(default=4, ge=1, le=72)
    current_price: float | None = Field(default=None, ge=0)


class PricingSuggestion(ApiModel):
    suggested_price: float
    minimum_recommended_price: float
    maximum_recommended_price: float
    current_market_average: float
    demand_level: str
    supply_level: str
    confidence: float = Field(ge=0, le=1)
    reason: str
    factors: dict[str, float | str]
