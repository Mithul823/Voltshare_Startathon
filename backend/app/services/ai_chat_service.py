import json

import httpx
from pydantic import ValidationError

from app.core.config import get_settings
from app.core.exceptions import ApiError, ErrorCode
from app.schemas.ai_chat import ChatRequest, ChatResponse


SYSTEM_PROMPT = (
    "You are VoltShare AI, an energy assistant for a peer-to-peer solar energy marketplace. "
    "Answer the user's question concisely and helpfully. "
    "Return only valid JSON with these exact keys: "
    '"answer" (string, your response), '
    '"confidence" (float 0-1), '
    '"provider" (string, "Gemini"), '
    '"disclaimer" (string, a brief advisory note), '
    '"model" (the model name as a string). '
    "Keep answers under 200 characters. Be practical and focused on energy management."
)


class AIChatService:
    async def chat(self, request: ChatRequest) -> ChatResponse:
        settings = get_settings()
        prompt = {
            "system": SYSTEM_PROMPT,
            "user_message": request.message,
        }
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.post(
                    f"https://generativelanguage.googleapis.com/v1beta/models/{settings.gemini_model}:generateContent",
                    params={"key": settings.gemini_api_key},
                    json={
                        "contents": [
                            {
                                "role": "user",
                                "parts": [{"text": json.dumps(prompt)}],
                            }
                        ]
                    },
                )
                response.raise_for_status()
                text = response.json()["candidates"][0]["content"]["parts"][0]["text"]
                parsed = json.loads(text.strip().removeprefix("```json").removesuffix("```"))
                result = ChatResponse.model_validate({
                    **parsed,
                    "provider": "Gemini",
                    "model": settings.gemini_model,
                })
        except (httpx.HTTPError, KeyError, json.JSONDecodeError, ValidationError):
            raise ApiError(
                503,
                ErrorCode.AI_SERVICE_UNAVAILABLE,
                "Gemini AI service is unavailable. Please try again later.",
            )
        return result


ai_chat_service = AIChatService()
