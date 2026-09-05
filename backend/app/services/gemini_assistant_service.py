from __future__ import annotations

import json
import logging
from contextlib import suppress

import httpx

from app.core.config import get_settings
from app.core.security import AuthenticatedUser
from app.repositories.ai_repository import get_ai_repository
from app.schemas.ai import AssistantChatRequest, AssistantChatResponse, AssistantConversation, AssistantMessage
from app.schemas.common import new_id, now_utc
from app.services.ai_context_builder import ai_context_builder

logger = logging.getLogger(__name__)


SYSTEM_INSTRUCTION = (
    "You are the VoltShare AI assistant for a peer-to-peer renewable energy marketplace. "
    "Users are from Kerala, India, and use VoltShare to monitor solar generation, "
    "trade energy, manage batteries, track sustainability, and administer the platform.\n\n"
    "RULES:\n"
    "- Answer concisely in plain English (you may use simple Malayalam words for clarity).\n"
    "- Use the user's context (role, energy data, wallet, listings) when available.\n"
    "- Recommend actions but NEVER execute transactions, change roles, modify listings, or transfer money.\n"
    "- Distinguish measured data from estimates when making suggestions.\n"
    "- Do not invent readings or transactions that don't exist in the provided context.\n"
    "- Mention when data is unavailable rather than guessing.\n"
    "- Use INR for money and kWh for energy consistently.\n"
    "- Do not give financial guarantees or unsafe electrical instructions.\n"
    "- Keep answers under 3-4 short paragraphs.\n\n"
    "CONSUMER recommendations: shift appliance usage to solar hours, reduce peak consumption, interpret cost.\n"
    "PRODUCER recommendations: list surplus energy, price competitively, optimize battery.\n"
    "ADMIN recommendations: grid trends, marketplace activity, dispute patterns, system health.\n"
)


class GeminiAssistantService:
    max_context_length = 6000
    max_response_length = 1500
    max_history_messages = 10

    def __init__(self) -> None:
        self._ai_repo_instance: object | None = None

    @property
    def _ai(self) -> object:
        if self._ai_repo_instance is None:
            self._ai_repo_instance = get_ai_repository()
        return self._ai_repo_instance

    def _default_model(self) -> str:
        return "gemini-2.5-flash"

    # ── Public API ───────────────────────────────────────────────────

    async def chat(self, user: AuthenticatedUser, request: AssistantChatRequest) -> AssistantChatResponse:
        message = request.message.strip()
        if not message:
            return self._fallback(user, request, "empty_message", "Please enter a question for VoltShare AI.")
        if self._looks_transactional(request.message):
            return self._fallback(user, request, "transaction_boundary",
                                  "I can explain options, but I cannot execute purchases, withdrawals, settlements, role changes, or listing updates.")

        settings = get_settings()
        model = settings.gemini_model.strip() or self._default_model()

        if not settings.ai_enabled:
            logger.info("AI fallback: ai_enabled=false")
            return self._fallback(user, request, "ai_disabled",
                                  "VoltShare AI is disabled. Here's rule-based guidance instead.")
        if not settings.gemini_api_key.strip():
            logger.info("AI fallback: no Gemini API key")
            return self._fallback(user, request, "missing_gemini_key",
                                  "Gemini is not configured. Here's rule-based guidance instead.")

        # Build user context
        context: dict = {"role": user.role.value}
        try:
            context = ai_context_builder.build(user)
        except Exception as exc:
            logger.warning("AI context builder failed: %s", type(exc).__name__)

        # Retrieve conversation history for context
        conversation_id = request.conversation_id or new_id("CNV")
        existing = self._ai.get_conversation(conversation_id)
        history_messages = list(existing.messages) if existing else []

        # Build prompt with system instruction + user message + structured context
        prompt = self._build_prompt(message, context, history_messages)

        # Attempt Gemini call
        try:
            text = await self._generate_with_gemini(model=model, api_key=settings.gemini_api_key.strip(), prompt=prompt)
        except httpx.TimeoutException:
            logger.warning("Gemini timeout model=%s", model)
            return self._fallback(user, request, "gemini_timeout",
                                  "Gemini took too long. Here's rule-based guidance instead.")
        except httpx.HTTPStatusError as exc:
            reason = self._http_fallback_reason(exc.response.status_code)
            logger.warning("Gemini HTTP %s reason=%s", exc.response.status_code, reason)
            return self._fallback(user, request, reason,
                                  "Gemini was unavailable. Here's rule-based guidance instead.")
        except (KeyError, IndexError, TypeError, ValueError, json.JSONDecodeError) as exc:
            logger.warning("Gemini malformed response: %s", type(exc).__name__)
            return self._fallback(user, request, "malformed_gemini_response",
                                  "Gemini returned an unreadable response. Here's rule-based guidance instead.")
        except httpx.HTTPError as exc:
            logger.warning("Gemini network error: %s", type(exc).__name__)
            return self._fallback(user, request, "gemini_network_error",
                                  "Gemini could not be reached. Here's rule-based guidance instead.")

        if not text:
            logger.warning("Gemini empty response model=%s", model)
            return self._fallback(user, request, "empty_gemini_response",
                                  "Gemini returned an empty response. Here's rule-based guidance instead.")

        return self._record(user, request, conversation_id, text,
                            provider="gemini", model=model, fallback=False,
                            confidence=0.82, fallback_reason=None)

    def conversations(self, user: AuthenticatedUser) -> list[AssistantConversation]:
        return self._ai.list_conversations(user.user_id)

    def conversation(self, user: AuthenticatedUser, conversation_id: str) -> AssistantConversation | None:
        item = self._ai.get_conversation(conversation_id)
        return item if item and item.user_id == user.user_id else None

    def delete(self, user: AuthenticatedUser, conversation_id: str) -> bool:
        return self._ai.delete_conversation(conversation_id)

    # ── Gemini API call ───────────────────────────────────────────────

    async def _generate_with_gemini(self, *, model: str, api_key: str, prompt: str) -> str:
        """Call Gemini generateContent with system instruction and user message."""
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(
                f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
                params={"key": api_key},
                json={
                    "system_instruction": {"parts": [{"text": SYSTEM_INSTRUCTION}]},
                    "contents": [{"parts": [{"text": prompt}]}],
                    "generationConfig": {
                        "temperature": 0.7,
                        "maxOutputTokens": self.max_response_length,
                        "topP": 0.9,
                        "topK": 40,
                    },
                },
            )
            response.raise_for_status()
            data = response.json()
            finish_reason = data.get("candidates", [{}])[0].get("finishReason")
            if finish_reason in {"SAFETY", "RECITATION", "BLOCKLIST", "PROHIBITED_CONTENT"}:
                return ""
            parts = data["candidates"][0]["content"]["parts"]
            return "".join(p.get("text", "") for p in parts).strip()[:self.max_response_length]

    # ── Prompt builder ────────────────────────────────────────────────

    def _build_prompt(self, message: str, context: dict, history: list[AssistantMessage]) -> str:
        """Build a structured prompt with user context."""
        parts = ["The user has this VoltShare context:"]
        parts.append(json.dumps(context, default=str, indent=2))
        if history:
            recent = history[-self.max_history_messages:]
            parts.append("\nRecent conversation history:")
            for msg in recent:
                parts.append(f"  {msg.role}: {msg.content[:200]}")
        parts.append(f"\nUser question: {message}")
        full = "\n".join(parts)
        return full[:self.max_context_length]

    # ── Fallback engine (context-aware) ──────────────────────────────

    def _fallback(self, user: AuthenticatedUser, request: AssistantChatRequest,
                  reason_code: str, preface: str) -> AssistantChatResponse:
        """Generate a role-aware, context-driven fallback response.

        The fallback uses actual user data (energy, wallet, listings) when
        available, rather than generic text.  The frontend can display the
        source field to indicate whether Gemini or rules generated the answer.
        """
        # Build minimal context for fallback
        context_data: dict = {}
        try:
            context_data = ai_context_builder.build(user)
        except Exception:
            pass

        role = user.role.value
        lower = request.message.lower()
        answer = self._compose_fallback(role, lower, preface, context_data)

        conversation_id = request.conversation_id or new_id("CNV")
        return self._record(user, request, conversation_id, answer,
                            provider="rule_based", model="rule_based_assistant",
                            fallback=True, confidence=0.58, fallback_reason=reason_code)

    def _compose_fallback(self, role: str, question_lower: str, preface: str,
                          context: dict) -> str:
        """Compose a fallback answer using actual user context when possible."""
        # Extract data points
        energy = context.get("current_energy", {})
        wallet = context.get("wallet", {})
        daily = context.get("last_24_hours", {})
        listings = context.get("my_listings", {})
        sustain = context.get("sustainability", {})
        battery_trend = context.get("battery_trend", {})
        marketplace = context.get("marketplace", {})

        solar_kw = energy.get("solar_kw", 0)
        cons_kw = energy.get("consumption_kw", 0)
        battery_pct = energy.get("battery_percent", 0)
        balance = wallet.get("available_balance_paise", 0)
        gen_kwh = daily.get("generation_kwh", 0)
        cons_kwh = daily.get("consumption_kwh", 0)
        carbon = daily.get("carbon_saved", 0)
        active_listings = listings.get("active_count", 0)
        score = sustain.get("total_score", 0)

        # Build context-aware responses based on question intent
        lines = [preface]

        # Energy monitoring / dashboard questions
        if any(w in question_lower for w in ("energy", "dashboard", "power", "solar", "generation")):
            if gen_kwh:
                lines.append(f"In the last 24 hours your system generated {gen_kwh} kWh and consumed {cons_kwh} kWh.")
            if solar_kw:
                lines.append(f"Current solar output is {solar_kw} kW with consumption at {cons_kw} kW.")
            if carbon:
                lines.append(f"This has saved approximately {carbon} kg CO2.")
            if not gen_kwh and not solar_kw:
                lines.append("Energy readings are not yet available for your profile.")

        # Battery questions
        if any(w in question_lower for w in ("battery", "storage")):
            if battery_pct:
                trend = battery_trend.get("trend", "stable")
                lines.append(f"Your battery is at {battery_pct}% and {trend}.")
                if battery_pct < 25:
                    lines.append("Consider reducing consumption until solar generation increases.")
                elif battery_pct > 85:
                    lines.append("Battery is nearly full - good opportunity to export surplus.")
            else:
                lines.append("Battery status is not available.")

        # Wallet / cost questions
        if any(w in question_lower for w in ("wallet", "cost", "balance", "money", "spend", "earn")):
            if balance:
                inr = balance / 100
                lines.append(f"Your wallet has ₹{inr:,.2f} available.")
                lines.append("You can deposit more via UPI or Bank in the Wallet screen.")
            else:
                lines.append("Wallet balance information is not currently available.")

        # Marketplace / trading / selling
        if any(w in question_lower for w in ("sell", "list", "marketplace", "trade", "price")):
            if active_listings:
                lines.append(f"You have {active_listings} active listing(s) in the marketplace.")
            elif role == "producer":
                lines.append("You don't have any active listings. Consider listing surplus energy during peak solar hours.")
            if marketplace.get("active_listings"):
                lines.append(f"There are {marketplace['active_listings']} active listings on the marketplace.")

        # Carbon / sustainability
        if any(w in question_lower for w in ("carbon", "sustain", "green", "environment", "co2")):
            if score:
                lines.append(f"Your sustainability score is {score}/100.")
            if carbon:
                lines.append(f"You've saved {carbon} kg CO2 in the last 24 hours.")
            lines.append("Improve your score by shifting loads to solar hours and trading surplus with peers.")

        # Recommendations (generic)
        if any(w in question_lower for w in ("recommend", "advice", "tip", "suggest", "should")):
            if role == "consumer":
                lines.append("Try running high-consumption appliances between 10:00 and 15:00 when solar is strongest.")
            elif role == "producer":
                if solar_kw > cons_kw:
                    lines.append("You are generating more than you consume — list your surplus in the marketplace.")
                else:
                    lines.append("Check your panel health and consider shifting loads to daytime.")
            elif role == "admin":
                lines.append("Review marketplace activity, dispute trends, and system health from the admin dashboard.")

        # Default catch-all
        if len(lines) == 1:
            if role == "consumer":
                lines.append("I can help with your energy dashboard, consumption, wallet, marketplace options, and sustainability. What would you like to know?")
            elif role == "producer":
                lines.append("I can help with your solar generation, battery, listings, earnings, and marketplace activity. What would you like to know?")
            elif role == "admin":
                lines.append("I can help with platform-wide metrics, user activity, disputes, and system health. What would you like to know?")
            else:
                lines.append("I can summarize forecasts, recommendations, wallet context, and estimates without taking actions for you.")

        return "\n\n".join(lines)

    # ── Record & persist conversation ─────────────────────────────

    def _record(self, user: AuthenticatedUser, request: AssistantChatRequest,
                conversation_id: str, answer: str, *, provider: str, model: str,
                fallback: bool, confidence: float, fallback_reason: str | None) -> AssistantChatResponse:
        existing = self._ai.get_conversation(conversation_id)
        conversation = existing or AssistantConversation(id=conversation_id, user_id=user.user_id)
        messages = list(conversation.messages)
        messages.append(AssistantMessage(role="user", content=self._sanitize_text(request.message)))
        messages.append(AssistantMessage(role="assistant", content=self._sanitize_text(answer)))
        # Trim to last N messages to avoid unbounded growth
        if len(messages) > self.max_history_messages * 2:
            messages = messages[-(self.max_history_messages * 2):]
        self._ai.save_conversation(conversation.model_copy(update={
            "messages": messages,
            "updated_at": now_utc(),
        }))
        return AssistantChatResponse(
            conversation_id=conversation_id,
            answer=answer,
            provider=provider,
            model=model,
            context_categories_used=["role", "current_energy", "wallet", "marketplace", "sustainability"],
            confidence=confidence,
            disclaimer="AI guidance is advisory. Forecasts are estimates and actions require your confirmation.",
            suggested_actions=["View dashboard", "Browse marketplace", "Check wallet", "Review sustainability"],
            fallback_used=fallback,
            fallback_reason=fallback_reason,
        )

    # ── Helpers ──────────────────────────────────────────────────────

    def _looks_transactional(self, message: str) -> bool:
        lower = message.lower()
        return any(phrase in lower for phrase in (
            "buy it for me", "withdraw", "release escrow", "transfer money",
            "change my role", "update listing", "cancel listing",
        ))

    def _sanitize_text(self, value: str) -> str:
        clean = value[:1000]
        for marker in ("token", "secret", "password", "service_role", "refresh"):
            with suppress(ValueError):
                clean = clean.replace(marker, "[redacted]")
        return clean

    def _http_fallback_reason(self, status_code: int) -> str:
        if status_code in {401, 403}:
            return "gemini_permission_denied"
        if status_code == 404:
            return "gemini_model_not_found"
        if status_code == 429:
            return "gemini_quota_exceeded"
        return "gemini_http_error"


gemini_assistant_service = GeminiAssistantService()
