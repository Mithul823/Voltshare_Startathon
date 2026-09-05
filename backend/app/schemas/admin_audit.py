from datetime import datetime

from app.schemas.common import ApiModel, now_utc


class AdminAuditLog(ApiModel):
    id: str
    timestamp: datetime = now_utc()
    event_type: str = "system"
    severity: str = "info"
    actor_user_id: str | None = None
    actor_name: str | None = None
    actor_role: str | None = None
    action: str = ""
    resource_type: str | None = None
    resource_id: str | None = None
    summary: str = ""
    status: str | None = None
    metadata_summary: str | None = None
    source_ip: str | None = None


class PaginatedAuditLogs(ApiModel):
    items: list[AdminAuditLog] = []
    page: int = 1
    page_size: int = 20
    total: int = 0
    total_pages: int = 0
