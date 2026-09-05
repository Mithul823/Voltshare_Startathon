from __future__ import annotations

import logging

from app.core.security import AuthenticatedUser
from app.repositories.dashboard_repository import dashboard_repository
from app.repositories.energy_repository import get_energy_readings_repository
from app.schemas.common import UserRole
from app.services.marketplace_service import marketplace_service
from app.services.sustainability_service import sustainability_service
from app.services.wallet_service import wallet_service

logger = logging.getLogger(__name__)


class AIContextBuilder:
    """Builds a rich, per-user context payload for the AI assistant.

    Sources:
        - Profile role
        - Current dashboard energy reading
        - 24-hour consumption & generation
        - Battery status
        - Marketplace activity (active listings, purchases)
        - Wallet balance
        - Sustainability score
    """
    sensitive_markers = ("token", "secret", "password", "service_role", "refresh")

    def build(self, user: AuthenticatedUser) -> dict:
        user_id = user.user_id
        role = user.role.value
        context: dict = {"role": role, "user_id": user_id[:8]}

        # ── Live energy reading ───────────────────────────────────
        try:
            repo = get_energy_readings_repository()
            latest = repo.latest(user_id)
            context["current_energy"] = {
                "solar_kw": round(latest.solar_generation_kwh, 2),
                "consumption_kw": round(latest.consumption_kwh, 2),
                "battery_percent": latest.battery_percent,
                "grid_export_kwh": round(latest.grid_export_kwh, 2),
                "grid_import_kwh": round(latest.grid_import_kwh, 2),
            }
            # 24-hour aggregation
            all_readings = repo.readings_for(user_id)
            recent = [r for r in all_readings if (latest.timestamp - r.timestamp).total_seconds() < 86400]
            if recent:
                total_gen = sum(r.solar_generation_kwh for r in recent)
                total_cons = sum(r.consumption_kwh for r in recent)
                total_carbon = sum(r.carbon_saved for r in recent)
                context["last_24_hours"] = {
                    "generation_kwh": round(total_gen, 2),
                    "consumption_kwh": round(total_cons, 2),
                    "carbon_saved": round(total_carbon, 2),
                    "net_export_kwh": round(sum(r.grid_export_kwh for r in recent), 2),
                }
            # Battery trend
            if len(recent) >= 6:
                battery_vals = [r.battery_percent for r in recent[-6:]]
                avg_battery = sum(battery_vals) / len(battery_vals)
                trend = "charging" if battery_vals[-1] > battery_vals[0] + 5 else (
                    "discharging" if battery_vals[-1] < battery_vals[0] - 5 else "stable"
                )
                context["battery_trend"] = {
                    "average_percent": round(avg_battery, 1),
                    "trend": trend,
                }
        except Exception as exc:
            logger.debug("AI context: energy readings unavailable: %s", type(exc).__name__)
            context["current_energy"] = {"note": "No recent energy readings"}

        # ── Wallet balance ────────────────────────────────────────
        try:
            wallet = wallet_service.balance(user_id)
            context["wallet"] = {
                "available_balance_paise": wallet.availableBalancePaise,
                "held_balance_paise": wallet.heldBalancePaise,
                "currency": wallet.currency,
            }
        except Exception as exc:
            logger.debug("AI context: wallet unavailable: %s", type(exc).__name__)

        # ── Marketplace activity ──────────────────────────────────
        user_listings: list = []
        try:
            all_listings = marketplace_service.list(active_only=False)
            user_listings = [l for l in all_listings if l.sellerId == user_id]
            if user_listings:
                active_count = sum(1 for l in user_listings if l.listingStatus.value == "active")
                prices = [l.pricePerKwh for l in user_listings if l.pricePerKwh]
                avg_price = sum(prices) / len(prices) if prices else 0
                context["my_listings"] = {
                    "active_count": active_count,
                    "total_count": len(user_listings),
                    "average_price_per_kwh": round(avg_price, 2),
                }
        except Exception as exc:
            logger.debug("AI context: listings unavailable: %s", type(exc).__name__)

        # ── Recent purchases / sales ──────────────────────────────
        try:
            context["recent_activity"] = {
                "active_listings_count": len(user_listings),
            }
        except Exception:
            pass

        # ── Sustainability score ───────────────────────────────────
        try:
            score = sustainability_service.score(user_id)
            context["sustainability"] = {
                "total_score": score.total_score,
                "grade": score.grade,
            }
        except Exception as exc:
            logger.debug("AI context: sustainability unavailable: %s", type(exc).__name__)

        # ── Marketplace summary (always available) ────────────────
        try:
            summary = marketplace_service.summary()
            context["marketplace"] = {
                "active_listings": summary.active_listings_count,
                "average_price": round(summary.average_price_per_kwh, 2) if hasattr(summary, 'average_price_per_kwh') else None,
            }
        except Exception:
            pass

        return self.sanitize(context)

    def sanitize(self, context: dict) -> dict:
        clean = {}
        for key, value in context.items():
            if any(marker in key.lower() for marker in self.sensitive_markers):
                continue
            if isinstance(value, dict):
                clean[key] = self.sanitize(value)
            else:
                clean[key] = value
        return clean


ai_context_builder = AIContextBuilder()
