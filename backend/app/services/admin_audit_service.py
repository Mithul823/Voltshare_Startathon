"""Admin audit service — provides a unified audit log combining multiple event sources."""

from app.schemas.admin_audit import AdminAuditLog, PaginatedAuditLogs


class AdminAuditService:
    def __init__(self) -> None:
        self._repo_instance: object | None = None

    @property
    def _repo(self) -> object:
        if self._repo_instance is None:
            from app.repositories.admin_audit_repository import get_admin_audit_repository
            self._repo_instance = get_admin_audit_repository()
        return self._repo_instance

    async def list_audit_logs(
        self,
        search: str | None = None,
        event_type: str | None = None,
        severity: str | None = None,
        actor_id: str | None = None,
        resource_type: str | None = None,
        date_from: str | None = None,
        date_to: str | None = None,
        page: int = 1,
        page_size: int = 20,
        actor_user_id: str | None = None,
    ) -> PaginatedAuditLogs:
        return await self._repo.list_audit_logs(
            search=search,
            event_type=event_type,
            severity=severity,
            actor_id=actor_id,
            resource_type=resource_type,
            date_from=date_from,
            date_to=date_to,
            page=page,
            page_size=page_size,
        )


admin_audit_service = AdminAuditService()
