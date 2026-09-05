from datetime import datetime
from enum import Enum

from pydantic import Field

from app.schemas.common import ApiModel, new_id, now_utc


class AssistantChatRequest(ApiModel):
    message: str = Field(min_length=1, max_length=800)
    conversation_id: str | None = None


class AssistantChatResponse(ApiModel):
    conversation_id: str
    answer: str
    provider: str
    model: str
    generated_at: datetime = Field(default_factory=now_utc)
    context_categories_used: list[str]
    confidence: float = Field(ge=0, le=1)
    disclaimer: str
    suggested_actions: list[str]
    fallback_used: bool
    fallback_reason: str | None = None


class AssistantMessage(ApiModel):
    id: str = Field(default_factory=lambda: new_id("MSG"))
    role: str
    content: str
    created_at: datetime = Field(default_factory=now_utc)


class AssistantConversation(ApiModel):
    id: str = Field(default_factory=lambda: new_id("CNV"))
    user_id: str
    created_at: datetime = Field(default_factory=now_utc)
    updated_at: datetime = Field(default_factory=now_utc)
    messages: list[AssistantMessage] = []


class AIInsight(ApiModel):
    id: str = Field(default_factory=lambda: new_id("AIN"))
    title: str
    message: str
    category: str
    priority: str
    confidence: float = Field(ge=0, le=1)
    explanation: str
    created_at: datetime = Field(default_factory=now_utc)


class AnomalySeverity(str, Enum):
    low = "LOW"
    medium = "MEDIUM"
    high = "HIGH"
    critical = "CRITICAL"


class AnomalyInsight(ApiModel):
    id: str = Field(default_factory=lambda: new_id("ANO"))
    title: str
    message: str
    severity: AnomalySeverity
    confidence: float = Field(ge=0, le=1)
    indicator_only: bool = True
    supporting_metrics: dict[str, object] = {}
    created_at: datetime = Field(default_factory=now_utc)


class SmartAlert(ApiModel):
    id: str = Field(default_factory=lambda: new_id("ALT"))
    event_key: str
    title: str
    message: str
    severity: AnomalySeverity
    deduplication_key: str
    created_at: datetime = Field(default_factory=now_utc)
