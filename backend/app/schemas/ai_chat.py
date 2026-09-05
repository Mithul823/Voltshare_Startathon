from pydantic import Field

from app.schemas.common import ApiModel


class ChatRequest(ApiModel):
    message: str = Field(min_length=1, max_length=2000)


class ChatResponse(ApiModel):
    answer: str
    provider: str = "Gemini"
    confidence: float = Field(ge=0, le=1)
    disclaimer: str = "AI guidance is advisory. Always verify critical decisions."
    model: str | None = None
