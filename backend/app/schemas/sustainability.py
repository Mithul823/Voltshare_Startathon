from datetime import datetime
from typing import Any

from pydantic import Field

from app.schemas.common import ApiModel, now_utc


class SustainabilitySummary(ApiModel):
    renewable_energy_consumed_kwh: float
    renewable_energy_generated_kwh: float
    estimated_grid_energy_displaced_kwh: float
    estimated_carbon_avoided_kg_co2e: float
    community_energy_contribution_kwh: float
    battery_efficiency_indicator_percent: float
    trading_sustainability_impact_kwh: float
    monthly_carbon_trend_kg_co2e: list[float]
    yearly_carbon_trend_kg_co2e: list[float]
    sdg_contribution_summary: list[str]
    assumptions: list[str]


class SustainabilityScore(ApiModel):
    total_score: int = Field(ge=0, le=100)
    grade: str
    factor_scores: dict[str, float]
    improvement_actions: list[str]
    calculation_version: str = "phase-6.6-v1"
    calculated_at: datetime = Field(default_factory=now_utc)
    confidence: float = Field(ge=0, le=1)
    assumptions: list[str]


class SustainabilityHistory(ApiModel):
    monthly_carbon_trend_kg_co2e: list[float]
    yearly_carbon_trend_kg_co2e: list[float]
    generated_at: datetime = Field(default_factory=now_utc)


class CommunityImpact(ApiModel):
    community_energy_contribution_kwh: float
    grid_energy_displaced_kwh: float
    carbon_avoided_kg_co2e: float
    assumptions: list[str]
    metadata: dict[str, Any] = {}
