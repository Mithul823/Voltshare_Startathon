from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class SuspendedUserRecord(BaseModel):
    id: str
    user_id: str
    full_name: str
    email: Optional[str] = None
    role: str
    suspension_reason: str
    suspended_by: str
    suspended_by_name: Optional[str] = None
    suspended_at: datetime
    restored_at: Optional[datetime] = None
    restored_by: Optional[str] = None
    is_restored: bool = False


class PaginatedSuspendedUsers(BaseModel):
    items: list[SuspendedUserRecord] = []
    page: int = 1
    page_size: int = 20
    total: int = 0
    total_pages: int = 0


class SuspensionRequest(BaseModel):
    reason: str
