from datetime import datetime, timedelta
from uuid import uuid4

from app.repositories.dashboard_repository import dashboard_repository
from app.repositories.energy_repository import get_energy_readings_repository
from app.repositories.state import state
from app.schemas.common import now_utc
from app.schemas.dashboard import (
    BatteryHistoryResponse,
    CarbonStats,
    DashboardActivity,
    DashboardHistoryResponse,
    DashboardInterval,
    DashboardMetrics,
    DashboardResponse,
    DashboardSummary,
    EnergyDataPoint,
    EnergyReading,
    SimulatedReadingRequest,
)
from app.schemas.insights import InsightCategory, InsightPriority, InsightResponse
from app.services.energy_monitoring_service import energy_monitoring_service


class DashboardService:
    carbon_kg_per_kwh = 0.7
    export_price_per_kwh = 8.0
    grid_price_per_kwh = 10.25

    def dashboard(self, user_id: str) -> DashboardResponse:
        readings = dashboard_repository.get_dashboard_summary(user_id)
        latest = dashboard_repository.get_latest_reading(user_id)
        summary = self.summary(user_id)
        metrics = self.metrics(readings, latest)
        carbon = CarbonStats(
            carbon_saved_kg=round(sum(reading.carbon_saved for reading in readings), 2),
            trees_equivalent=round(sum(reading.carbon_saved for reading in readings) / 21.0),
        )
        energy = energy_monitoring_service.energy_points(readings)
        consumption = energy_monitoring_service.consumption_points(readings)
        battery = energy_monitoring_service.battery_points(readings)
        wallet = state.wallet_for(user_id)
        return DashboardResponse(
            summary=summary,
            metrics=metrics,
            carbon=carbon,
            ai_insights=self.rule_insights(summary, metrics, latest),
            activity=self.activity(user_id),
            energy_timeline=energy,
            consumption_timeline=consumption,
            battery_timeline=battery,
            distribution=self.distribution(readings),
            latest_reading=latest,
            last_updated=latest.timestamp,
            solarGenerationTodayKwh=summary.daily_production_kwh,
            currentSolarPowerKw=latest.solar_generation_kwh,
            consumptionTodayKwh=summary.daily_consumption_kwh,
            currentConsumptionKw=latest.consumption_kwh,
            availableToSellKwh=max(0, summary.daily_production_kwh - summary.daily_consumption_kwh),
            batteryPercentage=latest.battery_percent,
            batteryHealthPercentage=94,
            batteryStatus=metrics.battery_status,
            walletBalancePaise=wallet.availableBalancePaise,
            gridSavingsPaise=summary.monthly_savings_paise,
            co2AvoidedKg=carbon.carbon_saved_kg,
            sustainabilityScore=metrics.sustainability_score,
            lastUpdated=latest.timestamp,
            solarHistory=[EnergyDataPoint(time=point.time, value=point.value) for point in energy[-12:]],
            consumptionHistory=[EnergyDataPoint(time=point.time, value=point.value) for point in consumption[-12:]],
            aiInsights=self.rule_insights(summary, metrics, latest),
        )

    def summary(self, user_id: str) -> DashboardSummary:
        readings = dashboard_repository.get_dashboard_summary(user_id)
        production = sum(reading.solar_generation_kwh for reading in readings)
        consumption = sum(reading.consumption_kwh for reading in readings)
        export = sum(reading.grid_export_kwh for reading in readings)
        grid_import = sum(reading.grid_import_kwh for reading in readings)
        earnings = sum(reading.earnings for reading in readings)
        purchases = sum(reading.cost for reading in readings)
        avg_battery = sum(reading.battery_percent for reading in readings) / max(1, len(readings))
        return DashboardSummary(
            daily_production_kwh=round(production, 2),
            daily_consumption_kwh=round(consumption, 2),
            daily_earnings_paise=round(earnings * 100),
            daily_purchases_paise=round(purchases * 100),
            monthly_earnings_paise=round(earnings * 30 * 100),
            monthly_savings_paise=round((production * self.grid_price_per_kwh - purchases) * 100),
            grid_import_kwh=round(grid_import, 2),
            grid_export_kwh=round(export, 2),
            average_battery_percent=round(avg_battery, 1),
            latest_battery_percent=readings[-1].battery_percent if readings else 0,
        )

    def metrics(self, readings: list[EnergyReading], latest: EnergyReading) -> DashboardMetrics:
        production = sum(reading.solar_generation_kwh for reading in readings)
        consumption = sum(reading.consumption_kwh for reading in readings)
        grid_import = sum(reading.grid_import_kwh for reading in readings)
        grid_export = sum(reading.grid_export_kwh for reading in readings)
        self_consumption = max(0, production - grid_export)
        renewable_percentage = self_consumption / max(0.01, consumption)
        grid_dependency = grid_import / max(0.01, consumption)
        efficiency = min(1.0, (self_consumption + grid_export) / max(0.01, production))
        score = self.sustainability_score(
            renewable_percentage=renewable_percentage,
            grid_dependency=grid_dependency,
            grid_export=grid_export,
            battery_percent=latest.battery_percent,
            efficiency=efficiency,
        )
        return DashboardMetrics(
            current_power_kw=round(latest.solar_generation_kwh - latest.consumption_kwh, 3),
            current_solar_generation_kw=latest.solar_generation_kwh,
            current_consumption_kw=latest.consumption_kwh,
            battery_status=self.battery_status(latest),
            energy_balance_kwh=round(production - consumption, 2),
            self_consumption_ratio=round(self_consumption / max(0.01, production), 3),
            grid_dependency_ratio=round(grid_dependency, 3),
            renewable_percentage=round(min(1.0, renewable_percentage), 3),
            efficiency_percentage=round(efficiency * 100, 1),
            sustainability_score=score,
        )

    def sustainability_score(
        self,
        *,
        renewable_percentage: float,
        grid_dependency: float,
        grid_export: float,
        battery_percent: int,
        efficiency: float,
    ) -> int:
        """Transparent 0-100 score: renewable use 35, low grid import 25,
        useful export 15, healthy battery utilization 10, efficiency 15."""
        renewable_points = min(35, max(0, renewable_percentage) * 35)
        grid_points = max(0, (1 - grid_dependency)) * 25
        export_points = min(15, grid_export * 2)
        battery_points = min(10, max(0, battery_percent - 20) / 80 * 10)
        efficiency_points = min(15, efficiency * 15)
        return round(min(100, renewable_points + grid_points + export_points + battery_points + efficiency_points))

    def rule_insights(self, summary: DashboardSummary, metrics: DashboardMetrics, latest: EnergyReading) -> list[InsightResponse]:
        insights: list[InsightResponse] = []
        if latest.battery_percent >= 88:
            insights.append(self.insight("Battery nearly full", "Battery is close to full. Consider selling excess energy.", InsightCategory.battery, InsightPriority.high, "Create listing"))
        if summary.grid_export_kwh > 2:
            insights.append(self.insight("Sell excess energy", "You have exportable surplus today.", InsightCategory.marketplace, InsightPriority.high, "View market"))
        if latest.battery_percent < 35:
            insights.append(self.insight("Charge battery before evening", "Battery reserve is low for the evening peak.", InsightCategory.battery, InsightPriority.high))
        if summary.grid_import_kwh > summary.grid_export_kwh + 3:
            insights.append(self.insight("High grid import today", "Shift flexible loads to solar hours to reduce grid dependency.", InsightCategory.consumption, InsightPriority.medium))
        if summary.daily_consumption_kwh > 24:
            insights.append(self.insight("Consumption above weekly average", "Today usage is elevated compared with a typical solar day.", InsightCategory.consumption, InsightPriority.medium))
        if summary.daily_production_kwh > 30:
            insights.append(self.insight("Great solar production today", "Solar output is strong and improving your sustainability score.", InsightCategory.generation, InsightPriority.medium))
        return insights[:4]

    def insight(self, title: str, message: str, category: InsightCategory, priority: InsightPriority, action: str | None = None) -> InsightResponse:
        return InsightResponse(
            title=title,
            message=message,
            category=category,
            priority=priority,
            action_label=action,
            confidence=0.82,
            estimated_savings_paise=0,
            source="fallback rule engine",
        )

    def history(self, user_id: str, start: datetime | None, end: datetime | None, interval: DashboardInterval) -> DashboardHistoryResponse:
        current_end = end or now_utc()
        current_start = start or (current_end - self.default_window(interval))
        readings = dashboard_repository.get_energy_history(user_id, current_start, current_end)
        return DashboardHistoryResponse(
            interval=interval,
            start=current_start,
            end=current_end,
            energy=energy_monitoring_service.energy_points(readings),
            consumption=energy_monitoring_service.consumption_points(readings),
        )

    def battery_history(self, user_id: str, start: datetime | None, end: datetime | None, interval: DashboardInterval) -> BatteryHistoryResponse:
        current_end = end or now_utc()
        current_start = start or (current_end - self.default_window(interval))
        readings = dashboard_repository.get_battery_history(user_id, current_start, current_end)
        return BatteryHistoryResponse(
            interval=interval,
            start=current_start,
            end=current_end,
            battery=energy_monitoring_service.battery_points(readings),
        )

    def activity(self, user_id: str) -> list[DashboardActivity]:
        latest = dashboard_repository.get_recent_activity(user_id)
        items: list[DashboardActivity] = []
        for index, reading in enumerate(reversed(latest)):
            if reading.grid_export_kwh > 0.2:
                message = "Exported clean energy to the grid"
                value = f"{reading.grid_export_kwh:.1f} kWh"
                kind = "grid_export"
            elif reading.grid_import_kwh > 0.2:
                message = "Imported energy from the grid"
                value = f"{reading.grid_import_kwh:.1f} kWh"
                kind = "grid_import"
            else:
                message = "Balanced solar and home consumption"
                value = f"{reading.battery_percent}% battery"
                kind = "balanced"
            items.append(DashboardActivity(id=f"act-{reading.id}-{index}", timestamp=reading.timestamp, type=kind, message=message, value=value))
        return items

    def distribution(self, readings: list[EnergyReading]) -> dict[str, float]:
        production = sum(reading.solar_generation_kwh for reading in readings)
        consumption = sum(reading.consumption_kwh for reading in readings)
        export = sum(reading.grid_export_kwh for reading in readings)
        grid_import = sum(reading.grid_import_kwh for reading in readings)
        return {
            "solar_used": round(max(0, production - export), 2),
            "grid_import": round(grid_import, 2),
            "grid_export": round(export, 2),
            "home_consumption": round(consumption, 2),
        }

    def simulate(self, user_id: str, request: SimulatedReadingRequest) -> DashboardResponse:
        reading = EnergyReading(
            id=str(uuid4()),
            user_id=user_id,
            timestamp=request.timestamp,
            solar_generation_kwh=request.solar_power_kw,
            consumption_kwh=request.consumption_kw,
            battery_percent=request.battery_percentage,
            battery_charge_kw=round(request.solar_power_kw - request.consumption_kw, 3),
            grid_import_kwh=max(0, request.consumption_kw - request.solar_power_kw),
            grid_export_kwh=max(0, request.solar_power_kw - request.consumption_kw),
            carbon_saved=round(request.solar_power_kw * self.carbon_kg_per_kwh, 3),
            earnings=round(max(0, request.solar_power_kw - request.consumption_kw) * self.export_price_per_kwh, 2),
            cost=round(max(0, request.consumption_kw - request.solar_power_kw) * self.grid_price_per_kwh, 2),
        )
        get_energy_readings_repository().append(user_id, reading)
        # Publish realtime event so frontend dashboard refreshes automatically
        from app.services.event_publisher import event_publisher
        from app.schemas.realtime import RealtimeChannel
        event_publisher.publish(
            "energy_reading.created",
            channels=[RealtimeChannel.dashboard],
            user_id=user_id,
            payload=reading.model_dump(mode="json"),
        )
        return self.dashboard(user_id)

    def battery_status(self, latest: EnergyReading) -> str:
        if latest.battery_percent <= 30:
            return "reserve"
        if latest.battery_charge_kw > 0.2:
            return "charging"
        if latest.battery_charge_kw < -0.2:
            return "discharging"
        return "idle"

    def default_window(self, interval: DashboardInterval) -> timedelta:
        return {
            DashboardInterval.hour: timedelta(hours=24),
            DashboardInterval.day: timedelta(days=7),
            DashboardInterval.week: timedelta(days=30),
            DashboardInterval.month: timedelta(days=120),
        }[interval]

    # Backward-compatible method used by older modules.
    def snapshot(self, user_id: str) -> DashboardResponse:
        return self.dashboard(user_id)


dashboard_service = DashboardService()
