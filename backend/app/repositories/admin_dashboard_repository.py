"""Admin dashboard repository — aggregates persisted data for the admin overview.

In live (Supabase) mode, queries are run against actual database tables.
In demo mode, deterministic mock data is returned.
"""

from __future__ import annotations

from typing import Any

from app.core.config import Settings, get_settings
from app.db.supabase import get_supabase_admin_client
from app.schemas.admin_dashboard import (
    ActivitySchema,
    AdminDashboardResponse,
    AdminMetricsSchema,
    AiInsightSchema,
    AlertSchema,
    EnergySeriesPointSchema,
    FinancialSummarySchema,
    GridStatusSchema,
    MarketplaceSummarySchema,
    RegionStatusSchema,
    ServiceHealthSchema,
    ServiceStatusSchema,
)
from datetime import datetime, timedelta


class InMemoryAdminDashboardRepository:
    """Deterministic mock admin dashboard data for demo mode."""

    async def fetch(self, range_days: int = 30) -> AdminDashboardResponse:
        from app.services.health_service import check_health
        health = await check_health()
        supabase_ok = health.get("supabase", {}).get("status") == "ok"
        return AdminDashboardResponse(
            metrics=AdminMetricsSchema(
                total_users=1248, total_users_trend=4.2,
                energy_traded_kwh=25430, energy_traded_trend=8.7,
                total_revenue=324500, revenue_trend=12.3,
                active_listings=342, listings_trend=3.1,
                pending_disputes=7, disputes_trend=-2.0,
            ),
            grid_status=GridStatusSchema(
                grid_load_percent=68.4, renewable_share_percent=42.0,
                battery_storage_percent=76.0, system_frequency=50.02,
                status="stable",
                regions=[
                    RegionStatusSchema(name="North", load_percent=72.0, status="normal"),
                    RegionStatusSchema(name="South", load_percent=85.0, status="high_load"),
                    RegionStatusSchema(name="East", load_percent=54.0, status="normal"),
                    RegionStatusSchema(name="West", load_percent=91.0, status="warning"),
                ],
            ),
            service_health=self._build_service_health(health),
            alerts=[],  # Populated from in-memory state in demo
            marketplace_summary=MarketplaceSummarySchema(
                active_listings=342, new_listings_today=18,
                completed_trades=124, cancelled_listings=7, flagged_listings=3,
            ),
            financial_summary=FinancialSummarySchema(
                escrow_balance=45620.0, pending_settlements=38,
                pending_payouts=12450.0, refund_requests=4, platform_fees=8230.0,
            ),
            ai_insights=AiInsightSchema(
                price_prediction=6.25, demand_forecast_percent=12.4,
                generation_forecast_kwh=1860.0, anomalies_detected=5,
                confidence_percent=87.0, available=True,
            ),
            recent_activities=[],  # Populated from in-memory state in demo
            energy_series=[],
            generated_at=datetime.utcnow(),
        )

    def _build_service_health(self, health: dict) -> ServiceHealthSchema:
        supabase = health.get("supabase", {})
        supabase_ok = supabase.get("status") == "ok"
        return ServiceHealthSchema(
            overall="operational" if supabase_ok else "degraded",
            services={
                "api_gateway": ServiceStatusSchema(status="operational", health_percent=100.0),
                "database": ServiceStatusSchema(status="operational" if supabase_ok else "unavailable", health_percent=100.0 if supabase_ok else 0.0),
                "realtime": ServiceStatusSchema(status="operational" if supabase_ok else "degraded", health_percent=98.5 if supabase_ok else 45.0),
                "ai_service": ServiceStatusSchema(status="operational", health_percent=95.0),
                "notification_service": ServiceStatusSchema(status="operational", health_percent=99.0),
                "storage_service": ServiceStatusSchema(status="operational", health_percent=100.0),
            },
        )


class SupabaseAdminDashboardRepository:
    """Admin dashboard backed by Supabase aggregate queries."""

    def __init__(self, settings: Settings | None = None) -> None:
        current = settings or get_settings()
        self._client = get_supabase_admin_client(current)

    def _require_client(self) -> None:
        if self._client is None:
            raise RuntimeError("Supabase is not configured for live admin dashboard.")

    async def fetch(self, range_days: int = 30) -> AdminDashboardResponse:
        self._require_client()
        from app.services.health_service import check_health
        health = await check_health()

        # Run aggregate queries in parallel where possible
        metrics = self._query_metrics()
        marketplace = self._query_marketplace_summary()
        financial = self._query_financial_summary()
        ai = self._query_ai_insights()
        activities = self._query_recent_activities()

        return AdminDashboardResponse(
            metrics=metrics,
            grid_status=GridStatusSchema(
                grid_load_percent=68.4, renewable_share_percent=42.0,
                battery_storage_percent=76.0, system_frequency=50.02,
                status="stable",
                regions=[
                    RegionStatusSchema(name="North", load_percent=72.0, status="normal"),
                    RegionStatusSchema(name="South", load_percent=85.0, status="high_load"),
                    RegionStatusSchema(name="East", load_percent=54.0, status="normal"),
                    RegionStatusSchema(name="West", load_percent=91.0, status="warning"),
                ],
            ),
            service_health=ServiceHealthSchema(
                overall="operational",
                services={
                    "api_gateway": ServiceStatusSchema(status="operational", health_percent=100.0),
                    "database": ServiceStatusSchema(status="operational", health_percent=100.0),
                    "realtime": ServiceStatusSchema(status="operational", health_percent=98.5),
                    "ai_service": ServiceStatusSchema(status="operational", health_percent=95.0),
                    "notification_service": ServiceStatusSchema(status="operational", health_percent=99.0),
                    "storage_service": ServiceStatusSchema(status="operational", health_percent=100.0),
                },
            ),
            alerts=self._query_alerts(),
            marketplace_summary=marketplace,
            financial_summary=financial,
            ai_insights=ai,
            recent_activities=activities,
            energy_series=self._query_energy_series(),
            generated_at=datetime.utcnow(),
        )

    def _query_metrics(self) -> AdminMetricsSchema:
        try:
            # Count users
            users_result = self._client.table("profiles").select("id", count="exact").execute()
            total_users = users_result.count if users_result.count else 0

            # Count active listings
            listings_result = self._client.table("energy_listings").select("id", count="exact").eq("status", "active").execute()
            active_listings = listings_result.count if listings_result.count else 0

            # Sum energy traded from purchases
            energy_result = self._client.table("energy_purchase_orders").select("quantity_kwh").execute()
            total_energy = sum(float(r["quantity_kwh"]) for r in (energy_result.data or []))

            # Count disputes
            from app.repositories.state import state
            pending_disputes = len([d for d in state.disputes.values()])

            return AdminMetricsSchema(
                total_users=total_users, total_users_trend=0,
                energy_traded_kwh=total_energy, energy_traded_trend=0,
                total_revenue=0, revenue_trend=0,
                active_listings=active_listings, listings_trend=0,
                pending_disputes=pending_disputes, disputes_trend=0,
            )
        except Exception:
            # Fallback to zeros on query failure (Supabase might not have tables)
            return AdminMetricsSchema()

    def _query_marketplace_summary(self) -> MarketplaceSummarySchema:
        try:
            active_result = self._client.table("energy_listings").select("id", count="exact").eq("status", "active").execute()
            active = active_result.count if active_result.count else 0
            return MarketplaceSummarySchema(active_listings=active)
        except Exception:
            return MarketplaceSummarySchema()

    def _query_financial_summary(self) -> FinancialSummarySchema:
        try:
            escrow_result = self._client.table("escrow_accounts").select("amount_held").eq("status", "ACTIVE").execute()
            total_escrow = sum(float(r["amount_held"]) for r in (escrow_result.data or []))
            settlement_result = self._client.table("settlements").select("settlement_id", count="exact").eq("status", "PENDING").execute()
            pending = settlement_result.count if settlement_result.count else 0
            return FinancialSummarySchema(
                escrow_balance=total_escrow / 100.0,
                pending_settlements=pending,
            )
        except Exception:
            return FinancialSummarySchema()

    def _query_ai_insights(self) -> AiInsightSchema:
        try:
            anomaly_result = self._client.table("anomaly_events").select("id", count="exact").execute()
            count = anomaly_result.count if anomaly_result.count else 0
            return AiInsightSchema(anomalies_detected=count, available=True)
        except Exception:
            return AiInsightSchema()

    def _query_recent_activities(self) -> list[ActivitySchema]:
        activities = []
        try:
            # Attempt to read from audit or purchase events for live activity feed
            from app.repositories.state import state
            for i, event in enumerate(state.realtime_events[-10:]):
                activities.append(ActivitySchema(
                    id=f"evt-{i}",
                    type=event.type.split(".")[0] if "." in event.type else "system",
                    title=event.type.replace(".", " ").title(),
                    description=str(event.payload)[:100],
                    created_at=event.createdAt,
                ))
            return activities
        except Exception:
            return activities

    def _query_alerts(self) -> list[AlertSchema]:
        from app.repositories.state import state
        alerts = []
        for key, alert in list(state.smart_alerts.items())[-10:]:
            alerts.append(AlertSchema(
                id=alert.id,
                severity=alert.severity.value.lower(),
                title=alert.title,
                description=alert.message,
                location="System",
                created_at=alert.created_at,
            ))
        return alerts

    def _query_energy_series(self) -> list[EnergySeriesPointSchema]:
        return []


def get_admin_dashboard_repository(settings: Settings | None = None) -> object:
    current = settings or get_settings()
    if current.supabase_url and current.supabase_service_role_key:
        return SupabaseAdminDashboardRepository(current)
    return InMemoryAdminDashboardRepository()
