"""Support ticket schemas for VoltShare Help Center."""

from datetime import datetime
from enum import Enum
from typing import Any

from pydantic import Field

from app.schemas.common import ApiModel, new_id, now_utc


class SupportCategory(str, Enum):
    marketplace = "Marketplace"
    wallet = "Wallet"
    payment = "Payment"
    login = "Login"
    account = "Account"
    ai_assistant = "AI Assistant"
    energy_trading = "Energy Trading"
    bug = "Bug"
    other = "Other"


class SupportPriority(str, Enum):
    low = "Low"
    medium = "Medium"
    high = "High"
    critical = "Critical"


class SupportStatus(str, Enum):
    open = "Open"
    in_progress = "In Progress"
    resolved = "Resolved"
    closed = "Closed"


# ---------------------------------------------------------------------------
# Request / Response schemas
# ---------------------------------------------------------------------------


class SupportTicketCreate(ApiModel):
    category: SupportCategory
    subject: str = Field(..., min_length=3, max_length=200)
    description: str = Field(..., min_length=10, max_length=5000)
    priority: SupportPriority = SupportPriority.medium
    screenshot_url: str | None = Field(None, max_length=500)


class SupportTicketResponse(ApiModel):
    id: str
    user_id: str
    user_name: str = ""
    user_role: str = ""
    category: str
    subject: str
    description: str
    priority: str
    status: str
    assigned_admin: str | None = None
    created_at: datetime
    updated_at: datetime
    resolved_at: datetime | None = None
    message_count: int = 0


class SupportMessageCreate(ApiModel):
    message: str = Field(..., min_length=1, max_length=5000)


class SupportMessageResponse(ApiModel):
    id: str
    ticket_id: str
    sender_id: str
    sender_name: str = ""
    message: str
    is_admin_reply: bool = False
    created_at: datetime


class SupportAdminUpdate(ApiModel):
    status: SupportStatus | None = None
    assigned_admin: str | None = None
    admin_note: str | None = Field(None, max_length=1000)


class SupportSummary(ApiModel):
    total: int = 0
    open: int = 0
    in_progress: int = 0
    resolved: int = 0
    closed: int = 0


# ---------------------------------------------------------------------------
# Internal data model (used by in-memory repository)
# ---------------------------------------------------------------------------


class SupportTicketData(ApiModel):
    id: str = Field(default_factory=lambda: new_id("TKT"))
    user_id: str
    user_name: str = ""
    user_role: str = ""
    category: str
    subject: str
    description: str
    priority: str
    status: str = "Open"
    assigned_admin: str | None = None
    created_at: datetime = Field(default_factory=now_utc)
    updated_at: datetime = Field(default_factory=now_utc)
    resolved_at: datetime | None = None
    messages: list["SupportTicketMessageData"] = Field(default_factory=list)
    attachment_url: str | None = None


class SupportTicketMessageData(ApiModel):
    id: str = Field(default_factory=lambda: new_id("MSG"))
    ticket_id: str
    sender_id: str
    sender_name: str = ""
    message: str
    is_admin_reply: bool = False
    created_at: datetime = Field(default_factory=now_utc)
