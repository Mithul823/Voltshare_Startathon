from datetime import timedelta

from app.core.security import AuthenticatedUser
from app.repositories.dashboard_repository import dashboard_repository
from app.repositories.state import state
from app.schemas.common import UserRole, now_utc
from app.schemas.recommendation import Recommendation, RecommendationCategory, RecommendationPriority
from app.services.forecasting_service import forecasting_service
from app.schemas.forecast import ForecastHorizon, ForecastMetric
from app.services.pricing_intelligence_service import pricing_intelligence_service
from app.schemas.recommendation import PricingSuggestionRequest
from app.services.sustainability_service import sustainability_service


class RecommendationService:
    def for_user(self, user: AuthenticatedUser, *, refresh: bool = False) -> list[Recommendation]:
        cached = state.recommendations.get(user.user_id)
        if cached and not refresh:
            return [item for item in cached if not item.dismissed]
        readings = dashboard_repository.get_dashboard_summary(user.user_id)
        latest = readings[-1]
        generation = sum(item.solar_generation_kwh for item in readings)
        consumption = sum(item.consumption_kwh for item in readings)
        surplus = max(0, generation - consumption)
        score = sustainability_service.score(user.user_id)
        recs: list[Recommendation] = []
        if user.role == UserRole.consumer:
            recs.extend(self._consumer(user, latest, score.total_score))
        elif user.role == UserRole.producer:
            recs.extend(self._producer(user, surplus))
        elif user.role == UserRole.prosumer:
            recs.extend(self._consumer(user, latest, score.total_score))
            recs.extend(self._producer(user, surplus))
            recs.append(self._rec("Optimize buy versus sell", "Your net energy forecast should guide whether to buy reserve energy or list surplus.", RecommendationCategory.battery, "Compare forecasted generation and consumption before evening peak.", "/trade"))
        elif user.role == UserRole.technician:
            recs.append(self._rec("Possible sensor gap", "Inspection recommended if readings stop updating or battery values jump suddenly.", RecommendationCategory.anomaly, "Technician insights are indicators only and do not claim hardware failure.", "/diagnostics", priority=RecommendationPriority.medium, confidence=0.58))
        elif user.role == UserRole.grid_operator:
            recs.append(self._rec("Demand spike watch", "Evening consumption forecast indicates a possible grid import period.", RecommendationCategory.grid, "Grid insight is based on aggregate-style local demand readings.", "/alerts", priority=RecommendationPriority.high, confidence=0.64))
        elif user.role == UserRole.admin:
            recs.append(self._rec("Review marketplace concentration", "A small set of sellers currently contributes much of marketplace supply.", RecommendationCategory.system, "Admin insight is an indicator only; no automatic moderation is performed.", "/admin/reports", confidence=0.61))
        state.recommendations[user.user_id] = recs
        return recs

    def get(self, user: AuthenticatedUser, recommendation_id: str) -> Recommendation | None:
        return next((item for item in self.for_user(user) if item.recommendation_id == recommendation_id), None)

    def dismiss(self, user: AuthenticatedUser, recommendation_id: str) -> Recommendation | None:
        recs = state.recommendations.get(user.user_id) or self.for_user(user, refresh=True)
        for index, item in enumerate(recs):
            if item.recommendation_id == recommendation_id:
                updated = item.model_copy(update={"dismissed": True})
                recs[index] = updated
                state.recommendations[user.user_id] = recs
                return updated
        return None

    def _consumer(self, user: AuthenticatedUser, latest, score: int) -> list[Recommendation]:
        price_forecast = forecasting_service.forecast(user.user_id, ForecastMetric.price, ForecastHorizon.six_hours)
        cheapest = min(point.value for point in price_forecast.forecast)
        recs = [
            self._rec("Best buying window", f"Look for listings near Rs {cheapest:.2f}/kWh over the next six hours.", RecommendationCategory.buying, price_forecast.explanation, "/marketplace", confidence=price_forecast.confidence),
            self._rec("Battery reserve suggestion", "Keep battery above 30% before the evening demand period.", RecommendationCategory.battery, "Battery guidance uses current reserve and recent demand shape.", "/dashboard", confidence=0.7),
        ]
        if latest.consumption_kwh > 2:
            recs.append(self._rec("Peak consumption warning", "Consumption is elevated; consider shifting flexible loads.", RecommendationCategory.buying, "Latest consumption exceeds the normal simulated baseline.", "/dashboard", priority=RecommendationPriority.high, confidence=0.66))
        if score < 60:
            recs.append(self._rec("Carbon reduction opportunity", "Buying verified renewable listings can improve your sustainability score.", RecommendationCategory.sustainability, "Sustainability score is below the Good threshold.", "/sustainability", confidence=0.68))
        return recs

    def _producer(self, user: AuthenticatedUser, surplus: float) -> list[Recommendation]:
        price = pricing_intelligence_service.suggest(PricingSuggestionRequest(quantity_kwh=max(1, surplus or 1)))
        return [
            self._rec("Suggested listing price", f"Advisory price: Rs {price.suggested_price:.2f}/kWh.", RecommendationCategory.pricing, price.reason, "/create-listing", confidence=price.confidence),
            self._rec("High-demand selling window", "Create listings before the 6 PM to 8 PM evening demand period.", RecommendationCategory.selling, "Demand is typically higher during evening consumption peaks.", "/create-listing", priority=RecommendationPriority.high, confidence=0.72),
        ]

    def _rec(self, title: str, message: str, category: RecommendationCategory, reason: str, route: str | None, *, priority: RecommendationPriority = RecommendationPriority.medium, confidence: float = 0.65) -> Recommendation:
        return Recommendation(
            title=title,
            message=message,
            category=category,
            priority=priority,
            confidence=confidence,
            reason=reason,
            supporting_metrics={"expires_in_hours": 6},
            action_type="navigate" if route else None,
            action_route=route,
            expires_at=now_utc() + timedelta(hours=6),
        )


recommendation_service = RecommendationService()
