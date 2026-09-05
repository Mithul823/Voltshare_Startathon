import json

import httpx
from pydantic import ValidationError

from app.core.config import get_settings
from app.repositories.state import state
from app.schemas.insights import InsightCategory, InsightPriority, InsightRequest, InsightResponse


class GeminiInsightService:
    def fallback(self, request: InsightRequest) -> InsightResponse:
        if request.battery_level < 35:
            return InsightResponse(title="Protect battery reserve", message="Keep at least 30% reserve before selling more energy.", category=InsightCategory.battery, priority=InsightPriority.high, confidence=0.74, estimated_savings_paise=0)
        if request.surplus > 2:
            return InsightResponse(title="Best selling window", message="List surplus energy during the evening demand window.", category=InsightCategory.marketplace, priority=InsightPriority.high, action_label="Create listing", confidence=0.78, estimated_savings_paise=round(request.surplus * request.price_per_kwh * 100), best_time_window="6:00 PM-8:00 PM")
        return InsightResponse(title="Consumption is balanced", message="Current usage is aligned with generation. Shift optional loads to sunny hours.", category=InsightCategory.consumption, priority=InsightPriority.medium, confidence=0.68, estimated_savings_paise=250)

    async def generate(self, user_id: str, request: InsightRequest) -> InsightResponse:
        settings = get_settings()
        if not settings.gemini_api_key:
            result = self.fallback(request)
            state.insights.setdefault(user_id, []).insert(0, result)
            return result
        prompt = {
            "instruction": "Return only JSON matching the VoltShare energy insight schema. Recommendations only; do not perform actions.",
            "energy": request.model_dump(mode="json"),
        }
        try:
            async with httpx.AsyncClient(timeout=6.0) as client:
                response = await client.post(
                    f"https://generativelanguage.googleapis.com/v1beta/models/{settings.gemini_model}:generateContent",
                    params={"key": settings.gemini_api_key},
                    json={"contents": [{"parts": [{"text": json.dumps(prompt)}]}]},
                )
                response.raise_for_status()
                text = response.json()["candidates"][0]["content"]["parts"][0]["text"]
                parsed = json.loads(text.strip().removeprefix("```json").removesuffix("```"))
                result = InsightResponse.model_validate({**parsed, "source": "Gemini"})
        except (httpx.HTTPError, KeyError, json.JSONDecodeError, ValidationError):
            result = self.fallback(request)
        state.insights.setdefault(user_id, []).insert(0, result)
        return result

    def latest(self, user_id: str) -> InsightResponse | None:
        items = state.insights.get(user_id, [])
        return items[0] if items else None


gemini_insight_service = GeminiInsightService()
