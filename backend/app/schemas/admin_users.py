from datetime import datetime

from app.schemas.common import ApiModel, UserRole, now_utc


class AdminUserSummary(ApiModel):
    id: str
    full_name: str = "VoltShare User"
    email: str | None = None
    role: UserRole = UserRole.consumer
    is_active: bool = True
    email_verified: bool = False
    kyc_status: str | None = None
    city: str | None = None
    district: str | None = None
    created_at: datetime = now_utc()
    last_login_at: datetime | None = None
    listings_count: int = 0
    purchases_count: int = 0
    disputes_count: int = 0


class PaginatedAdminUsers(ApiModel):
    items: list[AdminUserSummary] = []
    page: int = 1
    page_size: int = 20
    total: int = 0
    total_pages: int = 0


class UserStatusUpdate(ApiModel):
    is_active: bool
    reason: str = ""


class UserStatusUpdateResponse(ApiModel):
    id: str
    is_active: bool
    message: str = "User status updated successfully."
