from fastapi import APIRouter, Depends, Query

from app.api.dependencies import get_current_user, require_role
from app.core.security import AuthenticatedUser
from app.schemas.admin_audit import AdminAuditLog, PaginatedAuditLogs
from app.schemas.common import UserRole
from app.services.admin_audit_service import admin_audit_service

router = APIRouter()


@router.get("/audit-logs", response_model=PaginatedAuditLogs)
async def admin_list_audit_logs(
    search: str | None = Query(None, description="Search by action, summary, or actor"),
    event_type: str | None = Query(None, description="Filter by event type"),
    severity: str | None = Query(None, description="Filter by severity (info, warning, critical)"),
    actor_id: str | None = Query(None, description="Filter by actor user ID"),
    resource_type: str | None = Query(None, description="Filter by resource type"),
    date_from: str | None = Query(None),
    date_to: str | None = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> PaginatedAuditLogs:
    """List audit logs with search, filtering, and pagination.

    Requires admin role. Combines audit events, security events,
    and login events into a unified timeline.
    Never returns secrets or sensitive data.
    """
    return await admin_audit_service.list_audit_logs(
        search=search,
        event_type=event_type,
        severity=severity,
        actor_id=actor_id,
        resource_type=resource_type,
        date_from=date_from,
        date_to=date_to,
        page=page,
        page_size=page_size,
        actor_user_id=user.user_id,
    )
