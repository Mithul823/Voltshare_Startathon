"""AI repository — in-memory (demo) and Supabase (live).

Persists AI conversations, forecasts, recommendations, and sustainability
scores. The Supabase implementation uses the tables from migration 026.
"""

from __future__ import annotations

from uuid import uuid4
from typing import Any, Protocol

from app.core.config import Settings, get_settings
from app.core.exceptions import ApiError, ErrorCode
from app.db.supabase import get_supabase_admin_client
from app.schemas.ai import AssistantConversation
from app.schemas.common import now_utc
from app.schemas.forecast import ForecastResponse
from app.schemas.recommendation import Recommendation
from app.schemas.sustainability import SustainabilityScore


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _parse_dt(value: object) -> datetime:
    if isinstance(value, datetime):
        return value
    if isinstance(value, str):
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    return now_utc()


# ---------------------------------------------------------------------------
# Protocol
# ---------------------------------------------------------------------------

class AiRepository(Protocol):
    """Interface for AI-related data access."""

    def save_conversation(self, conversation: AssistantConversation) -> AssistantConversation: ...
    def get_conversation(self, conversation_id: str) -> AssistantConversation | None: ...
    def list_conversations(self, user_id: str) -> list[AssistantConversation]: ...
    def delete_conversation(self, conversation_id: str) -> bool: ...
    def save_forecast(self, user_id: str, metric: str, horizon: str, forecast: ForecastResponse) -> None: ...
    def get_forecast(self, user_id: str, metric: str) -> ForecastResponse | None: ...
    def save_recommendation(self, recommendation: Recommendation) -> Recommendation: ...
    def list_recommendations(self, user_id: str) -> list[Recommendation]: ...
    def dismiss_recommendation(self, user_id: str, recommendation_id: str) -> None: ...
    def save_sustainability_score(self, score: SustainabilityScore) -> SustainabilityScore: ...
    def get_latest_sustainability_score(self, user_id: str) -> SustainabilityScore | None: ...


# ---------------------------------------------------------------------------
# In-memory
# ---------------------------------------------------------------------------

class InMemoryAiRepository:
    def __init__(self) -> None:
        from app.repositories.state import state as app_state
        self._state = app_state

    def save_conversation(self, conversation: AssistantConversation) -> AssistantConversation:
        self._state.assistant_conversations[conversation.id] = conversation
        return conversation

    def get_conversation(self, conversation_id: str) -> AssistantConversation | None:
        return self._state.assistant_conversations.get(conversation_id)

    def list_conversations(self, user_id: str) -> list[AssistantConversation]:
        return [c for c in self._state.assistant_conversations.values() if c.user_id == user_id]

    def delete_conversation(self, conversation_id: str) -> bool:
        if conversation_id in self._state.assistant_conversations:
            del self._state.assistant_conversations[conversation_id]
            return True
        return False

    def save_forecast(self, user_id: str, metric: str, horizon: str, forecast: ForecastResponse) -> None:
        from app.schemas.common import new_id
        key = f"{user_id}:{metric}:{horizon}"
        self._state.forecasts[key] = forecast

    def get_forecast(self, user_id: str, metric: str) -> ForecastResponse | None:
        for key, forecast in self._state.forecasts.items():
            if key.startswith(f"{user_id}:{metric}:"):
                return forecast
        return None

    def save_recommendation(self, recommendation: Recommendation) -> Recommendation:
        user_id = recommendation.recommendation_id.split("-")[0] if "-" in recommendation.recommendation_id else "unknown"
        self._state.recommendations.setdefault(user_id, []).append(recommendation)
        return recommendation

    def list_recommendations(self, user_id: str) -> list[Recommendation]:
        return [r for r in self._state.recommendations.get(user_id, []) if not r.dismissed]

    def dismiss_recommendation(self, user_id: str, recommendation_id: str) -> None:
        for r in self._state.recommendations.get(user_id, []):
            if r.recommendation_id == recommendation_id:
                r.dismissed = True

    def save_sustainability_score(self, score: SustainabilityScore) -> SustainabilityScore:
        from app.schemas.common import new_id
        key = f"sustainability:{score.calculated_at.isoformat()}"
        self._state.sustainability_scores[key] = score
        return score

    def get_latest_sustainability_score(self, user_id: str) -> SustainabilityScore | None:
        scores = list(self._state.sustainability_scores.values())
        if not scores:
            return None
        return scores[-1]


# ---------------------------------------------------------------------------
# Supabase-backed
# ---------------------------------------------------------------------------

class SupabaseAiRepository:
    """Supabase-backed AI repository.

    Persists conversations, forecasts, recommendations, and sustainability
    scores to Supabase tables from migration 026.
    Falls back to in-memory when Supabase is unavailable or returns errors.
    """

    def __init__(self, settings: Settings | None = None) -> None:
        current = settings or get_settings()
        self._client = get_supabase_admin_client(current)
        self._in_memory = InMemoryAiRepository()
        self._supabase_available = bool(self._client is not None) and bool(current.supabase_url)

    # ── Conversations ────────────────────────────────────────────────

    def _conversation_to_row(self, conv: AssistantConversation) -> dict[str, Any]:
        return {
            "id": conv.id,
            "user_id": conv.user_id,
            "title": conv.messages[0].content[:80] if conv.messages else "VoltShare chat",
        }

    def _message_to_row(self, conversation_id: str, user_id: str, msg: AssistantMessage) -> dict[str, Any]:
        return {
            "conversation_id": conversation_id,
            "user_id": user_id,
            "role": msg.role,
            "sanitized_content": msg.content,
        }

    def save_conversation(self, conversation: AssistantConversation) -> AssistantConversation:
        self._in_memory.save_conversation(conversation)
        if not self._supabase_available:
            return conversation
        try:
            # Upsert conversation row
            conv_row = self._conversation_to_row(conversation)
            conv_result = self._client.table("assistant_conversations") \
                .upsert(conv_row, on_conflict="id") \
                .execute()
            if conv_result.data:
                persisted_id = conv_result.data[0]["id"]
                # Upsert messages (delete + reinsert for simplicity)
                self._client.table("assistant_messages") \
                    .delete() \
                    .eq("conversation_id", persisted_id) \
                    .execute()
                for msg in conversation.messages:
                    self._client.table("assistant_messages") \
                        .insert(self._message_to_row(persisted_id, conversation.user_id, msg)) \
                        .execute()
        except Exception as exc:
            logger.warning("Failed to persist conversation to Supabase: %s", type(exc).__name__)
        return conversation

    def get_conversation(self, conversation_id: str) -> AssistantConversation | None:
        # Check in-memory first
        cached = self._in_memory.get_conversation(conversation_id)
        if cached is not None:
            return cached
        if not self._supabase_available:
            return None
        try:
            conv_result = self._client.table("assistant_conversations") \
                .select("*") \
                .eq("id", conversation_id) \
                .execute()
            if not conv_result.data:
                return None
            row = conv_result.data[0]
            msg_result = self._client.table("assistant_messages") \
                .select("*") \
                .eq("conversation_id", conversation_id) \
                .order("created_at") \
                .execute()
            messages = []
            for m in msg_result.data if msg_result.data else []:
                messages.append(AssistantMessage(
                    role=m["role"],
                    content=m["sanitized_content"],
                ))
            conv = AssistantConversation(
                id=row["id"],
                user_id=row["user_id"],
                messages=messages,
                created_at=_parse_dt(row.get("created_at")),
                updated_at=_parse_dt(row.get("updated_at")),
            )
            self._in_memory.save_conversation(conv)
            return conv
        except Exception as exc:
            logger.warning("Failed to load conversation from Supabase: %s", type(exc).__name__)
            return None

    def list_conversations(self, user_id: str) -> list[AssistantConversation]:
        if not self._supabase_available:
            return self._in_memory.list_conversations(user_id)
        try:
            result = self._client.table("assistant_conversations") \
                .select("id,user_id,created_at,updated_at") \
                .eq("user_id", user_id) \
                .order("updated_at", desc=True) \
                .limit(50) \
                .execute()
            if not result.data:
                return []
            conversations = []
            for row in result.data:
                conversations.append(AssistantConversation(
                    id=row["id"],
                    user_id=row["user_id"],
                    created_at=_parse_dt(row.get("created_at")),
                    updated_at=_parse_dt(row.get("updated_at")),
                    messages=[],  # Messages loaded lazily by get_conversation
                ))
            return conversations
        except Exception as exc:
            logger.warning("Failed to list conversations from Supabase: %s", type(exc).__name__)
            return self._in_memory.list_conversations(user_id)

    def delete_conversation(self, conversation_id: str) -> bool:
        in_memory_deleted = self._in_memory.delete_conversation(conversation_id)
        if not self._supabase_available:
            return in_memory_deleted
        try:
            self._client.table("assistant_messages") \
                .delete() \
                .eq("conversation_id", conversation_id) \
                .execute()
            self._client.table("assistant_conversations") \
                .delete() \
                .eq("id", conversation_id) \
                .execute()
            return True
        except Exception:
            return in_memory_deleted

    # ── Forecasts ────────────────────────────────────────────────────

    def save_forecast(self, user_id: str, metric: str, horizon: str, forecast: ForecastResponse) -> None:
        self._in_memory.save_forecast(user_id, metric, horizon, forecast)
        if not self._supabase_available:
            return
        try:
            self._client.table("ai_forecasts").insert({
                "id": str(uuid4()),
                "user_id": user_id,
                "metric": metric,
                "horizon": horizon,
                "payload": forecast.model_dump(mode="json"),
            }).execute()
        except Exception as exc:
            logger.warning("Failed to persist forecast: %s", type(exc).__name__)

    def get_forecast(self, user_id: str, metric: str) -> ForecastResponse | None:
        cached = self._in_memory.get_forecast(user_id, metric)
        if cached is not None:
            return cached
        if not self._supabase_available:
            return None
        try:
            result = self._client.table("ai_forecasts") \
                .select("payload") \
                .eq("user_id", user_id) \
                .eq("metric", metric) \
                .order("created_at", desc=True) \
                .limit(1) \
                .execute()
            if result.data:
                return ForecastResponse(**result.data[0]["payload"])
        except Exception:
            pass
        return None

    # ── Recommendations ──────────────────────────────────────────────

    def save_recommendation(self, recommendation: Recommendation) -> Recommendation:
        self._in_memory.save_recommendation(recommendation)
        if not self._supabase_available:
            return recommendation
        try:
            self._client.table("ai_recommendations").insert({
                "id": str(uuid4()),
                "user_id": recommendation.user_id,
                "recommendation_id": recommendation.recommendation_id,
                "role": recommendation.role,
                "payload": recommendation.model_dump(mode="json"),
                "dismissed": recommendation.dismissed,
            }).execute()
        except Exception as exc:
            logger.warning("Failed to persist recommendation: %s", type(exc).__name__)
        return recommendation

    def list_recommendations(self, user_id: str) -> list[Recommendation]:
        if not self._supabase_available:
            return self._in_memory.list_recommendations(user_id)
        try:
            result = self._client.table("ai_recommendations") \
                .select("*") \
                .eq("user_id", user_id) \
                .order("created_at", desc=True) \
                .execute()
            if result.data:
                return [Recommendation(**r["payload"]) for r in result.data if not r["dismissed"]]
        except Exception:
            pass
        return self._in_memory.list_recommendations(user_id)

    def dismiss_recommendation(self, user_id: str, recommendation_id: str) -> None:
        self._in_memory.dismiss_recommendation(user_id, recommendation_id)
        if not self._supabase_available:
            return
        try:
            self._client.table("ai_recommendations") \
                .update({"dismissed": True}) \
                .eq("recommendation_id", recommendation_id) \
                .execute()
        except Exception:
            pass

    # ── Sustainability scores ────────────────────────────────────────

    def save_sustainability_score(self, score: SustainabilityScore) -> SustainabilityScore:
        self._in_memory.save_sustainability_score(score)
        if not self._supabase_available:
            return score
        try:
            self._client.table("sustainability_scores").insert({
                "user_id": score.user_id,
                "total_score": score.total_score,
                "payload": score.model_dump(mode="json"),
            }).execute()
        except Exception as exc:
            logger.warning("Failed to persist sustainability score: %s", type(exc).__name__)
        return score

    def get_latest_sustainability_score(self, user_id: str) -> SustainabilityScore | None:
        cached = self._in_memory.get_latest_sustainability_score(user_id)
        if cached is not None:
            return cached
        if not self._supabase_available:
            return None
        try:
            result = self._client.table("sustainability_scores") \
                .select("payload") \
                .eq("user_id", user_id) \
                .order("created_at", desc=True) \
                .limit(1) \
                .execute()
            if result.data:
                return SustainabilityScore(**result.data[0]["payload"])
        except Exception:
            pass
        return None


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

def get_ai_repository(settings: Settings | None = None) -> AiRepository:
    current = settings or get_settings()
    if current.supabase_url and current.supabase_service_role_key:
        return SupabaseAiRepository(current)
    return InMemoryAiRepository()
