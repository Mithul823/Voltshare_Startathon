from statistics import mean

from app.schemas.recommendation import PricingSuggestion, PricingSuggestionRequest
from app.services.marketplace_service import marketplace_service


class PricingIntelligenceService:
    def suggest(self, request: PricingSuggestionRequest) -> PricingSuggestion:
        listings = marketplace_service.list(active_only=True)
        prices = [listing.pricePerKwh for listing in listings if listing.pricePerKwh > 0]
        market_average = round(mean(prices), 2) if prices else 8.2
        supply_kwh = sum(listing.availableEnergyKwh for listing in listings)
        demand_level = "high" if supply_kwh < 12 else "medium" if supply_kwh < 25 else "low"
        supply_level = "low" if supply_kwh < 12 else "balanced" if supply_kwh < 25 else "high"
        demand_factor = {"high": 1.08, "medium": 1.0, "low": 0.96}[demand_level]
        quantity_factor = 0.98 if request.quantity_kwh > 5 else 1.0
        suggested = round(market_average * demand_factor * quantity_factor, 2)
        return PricingSuggestion(
            suggested_price=suggested,
            minimum_recommended_price=round(max(1, suggested * 0.9), 2),
            maximum_recommended_price=round(suggested * 1.12, 2),
            current_market_average=market_average,
            demand_level=demand_level,
            supply_level=supply_level,
            confidence=0.72 if prices else 0.42,
            reason="Suggested price is advisory and based on current marketplace supply, average listing prices and listing quantity.",
            factors={"supply_kwh": round(supply_kwh, 2), "energy_source": request.energy_source, "quantity_kwh": request.quantity_kwh},
        )


pricing_intelligence_service = PricingIntelligenceService()
