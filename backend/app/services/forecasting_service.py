from __future__ import annotations

from datetime import timedelta
from statistics import mean

from app.repositories.dashboard_repository import dashboard_repository
from app.schemas.common import now_utc
from app.schemas.forecast import ForecastHorizon, ForecastMetric, ForecastPoint, ForecastResponse, ForecastSummary
from app.services.explainability_service import explainability_service
from app.services.marketplace_service import marketplace_service


class ForecastingService:
    horizon_steps = {
        ForecastHorizon.next_hour: (2, timedelta(minutes=30)),
        ForecastHorizon.six_hours: (12, timedelta(minutes=30)),
        ForecastHorizon.twenty_four_hours: (24, timedelta(hours=1)),
        ForecastHorizon.seven_days: (7, timedelta(days=1)),
    }

    def forecast(self, user_id: str, metric: ForecastMetric, horizon: ForecastHorizon) -> ForecastResponse:
        readings = dashboard_repository.get_dashboard_summary(user_id)
        values = self._values(metric, readings)
        issues = self._quality_issues(values, metric)
        steps, interval = self.horizon_steps[horizon]
        points_used = len(values)
        fallback = points_used < 8 or bool(issues)
        model = "weighted_moving_average" if points_used >= 8 else "safe_rule_fallback"
        baseline = self._weighted_average(values[-12:]) if values else self._fallback_value(metric)
        trend = self._trend(values[-12:])
        generated = now_utc()
        forecast = [
            ForecastPoint(
                timestamp=generated + interval * (index + 1),
                value=round(max(0, baseline + trend * index), 3),
                unit=self._unit(metric),
            )
            for index in range(steps)
        ]
        confidence = explainability_service.confidence(data_points=points_used, issues=issues)
        if horizon == ForecastHorizon.seven_days and points_used < 96:
            confidence = min(confidence, 0.42)
            issues.append("Seven-day forecasts need more than one day of history for higher confidence.")
            fallback = True
        return ForecastResponse(
            metric=metric,
            horizon=horizon,
            model=model,
            confidence=confidence,
            data_points_used=points_used,
            forecast=forecast,
            explanation=f"{metric.value} uses a transparent weighted moving average over recent VoltShare readings.",
            limitations=issues,
            fallback_used=fallback,
        )

    def summary(self, user_id: str) -> ForecastSummary:
        return ForecastSummary(
            consumption=self.forecast(user_id, ForecastMetric.consumption, ForecastHorizon.twenty_four_hours),
            generation=self.forecast(user_id, ForecastMetric.generation, ForecastHorizon.twenty_four_hours),
            price=self.forecast(user_id, ForecastMetric.price, ForecastHorizon.six_hours),
            battery=self.forecast(user_id, ForecastMetric.battery, ForecastHorizon.six_hours),
        )

    def _values(self, metric: ForecastMetric, readings) -> list[float]:
        if metric == ForecastMetric.consumption:
            return [item.consumption_kwh for item in readings]
        if metric == ForecastMetric.generation:
            return [item.solar_generation_kwh for item in readings]
        if metric == ForecastMetric.battery:
            return [float(item.battery_percent) for item in readings]
        if metric == ForecastMetric.daily_cost:
            return [item.cost for item in readings]
        if metric == ForecastMetric.producer_earnings:
            return [item.earnings for item in readings]
        if metric == ForecastMetric.peak_demand:
            return [item.consumption_kwh for item in readings]
        listings = marketplace_service.list(active_only=True)
        return [item.pricePerKwh for item in listings]

    def _quality_issues(self, values: list[float], metric: ForecastMetric) -> list[str]:
        issues: list[str] = []
        if len(values) < 8:
            issues.append("Insufficient sample size; confidence is intentionally low.")
        if any(value < 0 for value in values):
            issues.append("Negative values were detected and ignored by the fallback.")
        if metric == ForecastMetric.price and any(value <= 0 for value in values):
            issues.append("Invalid marketplace prices detected.")
        if len(values) != len(set(round(value, 6) for value in values)) and len(values) < 4:
            issues.append("Duplicate values reduce forecast quality.")
        if values and max(values) > max(1, mean(values) * 4):
            issues.append("Extreme outliers may affect the estimate.")
        return issues

    def _weighted_average(self, values: list[float]) -> float:
        if not values:
            return 0
        weights = list(range(1, len(values) + 1))
        return sum(value * weight for value, weight in zip(values, weights, strict=False)) / sum(weights)

    def _trend(self, values: list[float]) -> float:
        if len(values) < 2:
            return 0
        return max(-0.25, min(0.25, (values[-1] - values[0]) / len(values)))

    def _fallback_value(self, metric: ForecastMetric) -> float:
        return {
            ForecastMetric.consumption: 1.4,
            ForecastMetric.generation: 1.2,
            ForecastMetric.price: 8.2,
            ForecastMetric.battery: 50,
            ForecastMetric.peak_demand: 2.1,
            ForecastMetric.daily_cost: 12,
            ForecastMetric.producer_earnings: 10,
        }[metric]

    def _unit(self, metric: ForecastMetric) -> str:
        return {
            ForecastMetric.consumption: "kWh",
            ForecastMetric.generation: "kWh",
            ForecastMetric.price: "Rs/kWh",
            ForecastMetric.battery: "%",
            ForecastMetric.peak_demand: "kWh",
            ForecastMetric.daily_cost: "Rs",
            ForecastMetric.producer_earnings: "Rs",
        }[metric]


forecasting_service = ForecastingService()
