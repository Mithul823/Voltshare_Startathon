import hashlib
import hmac
import json

from app.core.config import get_settings
from app.repositories.state import state
from app.schemas.audit import AuditEvent
from app.schemas.common import new_id, now_utc


def canonical_hmac(payload: dict) -> str:
    encoded = json.dumps(payload, sort_keys=True, default=str, separators=(",", ":")).encode("utf-8")
    return hmac.new(get_settings().hmac_secret.encode("utf-8"), encoded, hashlib.sha256).hexdigest()


class AuditService:
    def append(self, *, actor_user_id: str, action: str, resource_type: str, resource_id: str, status: str = "succeeded", risk_score: int | None = None, request_id: str | None = None, idempotency_key: str | None = None, metadata: dict | None = None) -> AuditEvent:
        clean = metadata or {}
        payload = {
            "actorUserId": actor_user_id,
            "action": action,
            "resourceType": resource_type,
            "resourceId": resource_id,
            "status": status,
            "riskScore": risk_score,
            "requestId": request_id,
            "idempotencyKey": idempotency_key,
            "metadata": clean,
        }
        event = AuditEvent(
            id=new_id("AUD"),
            actorUserId=actor_user_id,
            action=action,
            resourceType=resource_type,
            resourceId=resource_id,
            status=status,
            riskScore=risk_score,
            requestId=request_id,
            idempotencyKey=idempotency_key,
            metadata=clean,
            integrityHash=canonical_hmac(payload),
            createdAt=now_utc(),
        )
        state.audit_events.append(event)
        return event

    def list_for_user(self, user_id: str, is_admin: bool = False) -> list[AuditEvent]:
        if is_admin:
            return state.audit_events
        return [event for event in state.audit_events if event.actorUserId == user_id]


audit_service = AuditService()
