from datetime import datetime
from typing import Any

from pydantic import BaseModel


class ServiceStatusSchema(BaseModel):
    status: str = "unknown"
    health_percent: float = 0.0


class ServiceHealthSchema(BaseModel):
    overall: str = "unknown"
    services: dict[str, ServiceStatusSchema] = {}


class RegionStatusSchema(BaseModel):
    name: str
    load_percent: float
    status: str = "normal"


class GridStatusSchema(BaseModel):
    grid_load_percent: float = 0.0
    renewable_share_percent: float = 0.0
    battery_storage_percent: float = 0.0
    system_frequency: float = 50.0
    status: str = "unknown"
    regions: list[RegionStatusSchema] = []


class AlertSchema(BaseModel):
    id: str
    severity: str
    title: str
    description: str
    location: str
    created_at: datetime


class MarketplaceSummarySchema(BaseModel):
    active_listings: int = 0
    new_listings_today: int = 0
    completed_trades: int = 0
    cancelled_listings: int = 0
    flagged_listings: int = 0


class FinancialSummarySchema(BaseModel):
    escrow_balance: float = 0.0
    pending_settlements: int = 0
    pending_payouts: float = 0.0
    refund_requests: int = 0
    platform_fees: float = 0.0


class AiInsightSchema(BaseModel):
    price_prediction: float = 0.0
    demand_forecast_percent: float = 0.0
    generation_forecast_kwh: float = 0.0
    anomalies_detected: int = 0
    confidence_percent: float = 0.0
    available: bool = False


class ActivitySchema(BaseModel):
    id: str
    type: str
    title: str
    description: str
    created_at: datetime
    status: str | None = None


class EnergySeriesPointSchema(BaseModel):
    label: str
    traded_kwh: float = 0.0
    generated_kwh: float = 0.0
    consumed_kwh: float = 0.0


class AdminMetricsSchema(BaseModel):
    total_users: int = 0
    total_users_trend: float = 0.0
    energy_traded_kwh: float = 0.0
    energy_traded_trend: float = 0.0
    total_revenue: float = 0.0
    revenue_trend: float = 0.0
    active_listings: int = 0
    listings_trend: float = 0.0
    pending_disputes: int = 0
    disputes_trend: float = 0.0


class AdminDashboardResponse(BaseModel):
    metrics: AdminMetricsSchema
    grid_status: GridStatusSchema
    service_health: ServiceHealthSchema
    alerts: list[AlertSchema]
    marketplace_summary: MarketplaceSummarySchema
    financial_summary: FinancialSummarySchema
    ai_insights: AiInsightSchema
    recent_activities: list[ActivitySchema]
    energy_series: list[EnergySeriesPointSchema]
    generated_at: datetime = None

    def model_post_init(self, __context: Any) -> None:
        if self.generated_at is None:
            self.generated_at = datetime.utcnow()
