from datetime import datetime

from pydantic import Field

from app.schemas.common import ApiModel, now_utc


class RiskEvaluationRequest(ApiModel):
    newDevice: bool = False
    unusualTime: bool = False
    failedAttempts: int = Field(default=0, ge=0)
    amountPaise: int = Field(default=0, ge=0)
    repeatedDefaults: int = Field(default=0, ge=0)
    repeatedDisputes: int = Field(default=0, ge=0)
    tamperingSignal: bool = False
    sessionAnomaly: bool = False
    longInactivity: bool = False


class RiskEvaluation(ApiModel):
    score: int
    level: str
    reasons: list[str]
    requiredAction: str
    stepUpRequired: bool
    blocked: bool


class SecurityEvent(ApiModel):
    id: str
    userId: str
    eventType: str
    riskScore: int
    createdAt: datetime = now_utc()


class TrustedDevice(ApiModel):
    id: str
    userId: str
    label: str
    trusted: bool
    createdAt: datetime = now_utc()
