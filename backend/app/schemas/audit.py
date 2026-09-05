from datetime import datetime

from app.schemas.common import ApiModel, now_utc


class AuditEvent(ApiModel):
    id: str
    actorUserId: str
    action: str
    resourceType: str
    resourceId: str
    status: str
    riskScore: int | None = None
    requestId: str | None = None
    idempotencyKey: str | None = None
    metadata: dict = {}
    integrityHash: str
    createdAt: datetime = now_utc()
