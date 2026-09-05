from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user
from app.core.security import AuthenticatedUser
from app.schemas.audit import AuditEvent
from app.services.audit_service import audit_service

router = APIRouter()


@router.get("", response_model=list[AuditEvent])
def audit_events(user: AuthenticatedUser = Depends(get_current_user)) -> list[AuditEvent]:
    return audit_service.list_for_user(user.user_id, is_admin=user.role == "admin")
