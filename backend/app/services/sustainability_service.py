from app.repositories.dashboard_repository import dashboard_repository
from app.schemas.sustainability import CommunityImpact, SustainabilityHistory, SustainabilityScore, SustainabilitySummary
from app.services.explainability_service import explainability_service


class SustainabilityService:
    weights = {
        "renewable_usage_ratio": 25,
        "renewable_generation_ratio": 20,
        "carbon_avoided": 15,
        "grid_dependency_reduction": 15,
        "battery_utilization_efficiency": 10,
        "peer_to_peer_trading": 10,
        "community_contribution": 5,
    }
    carbon_kg_per_kwh = 0.7

    def summary(self, user_id: str) -> SustainabilitySummary:
        readings = dashboard_repository.get_dashboard_summary(user_id)
        generated = sum(item.solar_generation_kwh for item in readings)
        consumed = sum(item.consumption_kwh for item in readings)
        export = sum(item.grid_export_kwh for item in readings)
        import_kwh = sum(item.grid_import_kwh for item in readings)
        renewable_consumed = max(0, min(consumed, generated - export + import_kwh * 0.2))
        carbon = round(generated * self.carbon_kg_per_kwh, 2)
        trend = [round(carbon * factor, 2) for factor in (0.82, 0.88, 0.93, 1.0)]
        return SustainabilitySummary(
            renewable_energy_consumed_kwh=round(renewable_consumed, 2),
            renewable_energy_generated_kwh=round(generated, 2),
            estimated_grid_energy_displaced_kwh=round(max(0, generated - import_kwh), 2),
            estimated_carbon_avoided_kg_co2e=carbon,
            community_energy_contribution_kwh=round(export, 2),
            battery_efficiency_indicator_percent=round(sum(item.battery_percent for item in readings) / max(1, len(readings)), 1),
            trading_sustainability_impact_kwh=round(export, 2),
            monthly_carbon_trend_kg_co2e=trend,
            yearly_carbon_trend_kg_co2e=[round(value * 12, 2) for value in trend],
            sdg_contribution_summary=["SDG 7: Affordable and clean energy", "SDG 13: Climate action"],
            assumptions=["Carbon uses 0.7 kg CO2e avoided per generated renewable kWh.", "Values are estimates, not utility-grade measurements."],
        )

    def score(self, user_id: str) -> SustainabilityScore:
        summary = self.summary(user_id)
        generated = max(0.01, summary.renewable_energy_generated_kwh)
        consumed = max(0.01, summary.renewable_energy_consumed_kwh)
        factors = {
            "renewable_usage_ratio": min(100, consumed / max(0.01, consumed + 3) * 100),
            "renewable_generation_ratio": min(100, generated / max(0.01, generated + 5) * 100),
            "carbon_avoided": min(100, summary.estimated_carbon_avoided_kg_co2e * 2),
            "grid_dependency_reduction": min(100, summary.estimated_grid_energy_displaced_kwh * 4),
            "battery_utilization_efficiency": summary.battery_efficiency_indicator_percent,
            "peer_to_peer_trading": min(100, summary.trading_sustainability_impact_kwh * 12),
            "community_contribution": min(100, summary.community_energy_contribution_kwh * 12),
        }
        total = round(sum(factors[key] * weight / 100 for key, weight in self.weights.items()))
        actions = []
        if factors["peer_to_peer_trading"] < 35:
            actions.append("List surplus energy during high-demand windows when available.")
        if factors["battery_utilization_efficiency"] < 45:
            actions.append("Keep battery reserve above 30% before evening peak.")
        if factors["renewable_usage_ratio"] < 60:
            actions.append("Shift flexible consumption to solar production hours.")
        return SustainabilityScore(
            total_score=max(0, min(100, total)),
            grade=explainability_service.grade(total),
            factor_scores={key: round(value, 1) for key, value in factors.items()},
            improvement_actions=actions or ["Maintain current renewable trading and battery habits."],
            confidence=0.76,
            assumptions=summary.assumptions + [f"Score weights: {self.weights}"],
        )

    def history(self, user_id: str) -> SustainabilityHistory:
        summary = self.summary(user_id)
        return SustainabilityHistory(monthly_carbon_trend_kg_co2e=summary.monthly_carbon_trend_kg_co2e, yearly_carbon_trend_kg_co2e=summary.yearly_carbon_trend_kg_co2e)

    def community(self, user_id: str) -> CommunityImpact:
        summary = self.summary(user_id)
        return CommunityImpact(
            community_energy_contribution_kwh=summary.community_energy_contribution_kwh,
            grid_energy_displaced_kwh=summary.estimated_grid_energy_displaced_kwh,
            carbon_avoided_kg_co2e=summary.estimated_carbon_avoided_kg_co2e,
            assumptions=summary.assumptions,
            metadata={"calculation_version": "phase-6.6-v1"},
        )


sustainability_service = SustainabilityService()
