from datetime import datetime
from enum import Enum

from pydantic import Field

from app.schemas.common import ApiModel, now_utc
from app.schemas.insights import InsightResponse


class DashboardInterval(str, Enum):
    hour = "hour"
    day = "day"
    week = "week"
    month = "month"


class EnergyPoint(ApiModel):
    time: datetime
    value: float


class EnergyDataPoint(EnergyPoint):
    pass


class BatteryPoint(ApiModel):
    time: datetime
    battery_percent: int = Field(ge=0, le=100)
    battery_charge_kw: float


class EnergyReading(ApiModel):
    id: str
    user_id: str
    timestamp: datetime
    solar_generation_kwh: float
    consumption_kwh: float
    battery_percent: int = Field(ge=0, le=100)
    battery_charge_kw: float
    grid_import_kwh: float
    grid_export_kwh: float
    carbon_saved: float
    earnings: float
    cost: float


class DashboardSummary(ApiModel):
    daily_production_kwh: float
    daily_consumption_kwh: float
    daily_earnings_paise: int
    daily_purchases_paise: int
    monthly_earnings_paise: int
    monthly_savings_paise: int
    grid_import_kwh: float
    grid_export_kwh: float
    average_battery_percent: float
    latest_battery_percent: int


class CarbonStats(ApiModel):
    carbon_saved_kg: float
    trees_equivalent: int


class DashboardMetrics(ApiModel):
    current_power_kw: float
    current_solar_generation_kw: float
    current_consumption_kw: float
    battery_status: str
    energy_balance_kwh: float
    self_consumption_ratio: float
    grid_dependency_ratio: float
    renewable_percentage: float
    efficiency_percentage: float
    sustainability_score: int = Field(ge=0, le=100)


class DashboardActivity(ApiModel):
    id: str
    timestamp: datetime
    type: str
    message: str
    value: str | None = None


class DashboardResponse(ApiModel):
    summary: DashboardSummary
    metrics: DashboardMetrics
    carbon: CarbonStats
    ai_insights: list[InsightResponse]
    activity: list[DashboardActivity]
    energy_timeline: list[EnergyPoint]
    consumption_timeline: list[EnergyPoint]
    battery_timeline: list[BatteryPoint]
    distribution: dict[str, float]
    latest_reading: EnergyReading
    last_updated: datetime

    # Existing Flutter dashboard contract. Keep these fields until the UI is
    # deliberately migrated to the richer Phase 6.2 response.
    solarGenerationTodayKwh: float
    currentSolarPowerKw: float
    consumptionTodayKwh: float
    currentConsumptionKw: float
    availableToSellKwh: float
    batteryPercentage: int = Field(ge=0, le=100)
    batteryHealthPercentage: int = Field(ge=0, le=100)
    batteryStatus: str
    walletBalancePaise: int
    gridSavingsPaise: int
    co2AvoidedKg: float
    sustainabilityScore: int = Field(ge=0, le=100)
    lastUpdated: datetime
    solarHistory: list[EnergyDataPoint]
    consumptionHistory: list[EnergyDataPoint]
    aiInsights: list[InsightResponse]


DashboardSnapshot = DashboardResponse


class DashboardHistoryResponse(ApiModel):
    interval: DashboardInterval
    start: datetime
    end: datetime
    energy: list[EnergyPoint]
    consumption: list[EnergyPoint]


class BatteryHistoryResponse(ApiModel):
    interval: DashboardInterval
    start: datetime
    end: datetime
    battery: list[BatteryPoint]


class SimulatedReadingRequest(ApiModel):
    solar_power_kw: float = Field(ge=0, le=20)
    consumption_kw: float = Field(ge=0, le=20)
    battery_percentage: int = Field(ge=0, le=100)
    timestamp: datetime = Field(default_factory=now_utc)
