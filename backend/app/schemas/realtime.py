from datetime import datetime
from enum import Enum
from typing import Any

from pydantic import Field

from app.schemas.common import ApiModel, new_id, now_utc


class RealtimeChannel(str, Enum):
    dashboard = "dashboard"
    marketplace = "marketplace"
    wallet = "wallet"
    listings = "listings"
    purchases = "purchases"
    sales = "sales"
    notifications = "notifications"
    admin = "admin"
    grid = "grid"


class NotificationCategory(str, Enum):
    wallet = "Wallet"
    marketplace = "Marketplace"
    purchase = "Purchase"
    sale = "Sale"
    settlement = "Settlement"
    grid = "Grid"
    security = "Security"
    system = "System"


class NotificationPriority(str, Enum):
    low = "LOW"
    medium = "MEDIUM"
    high = "HIGH"
    critical = "CRITICAL"


class RealtimeEvent(ApiModel):
    id: str = Field(default_factory=lambda: new_id("EVT"))
    type: str
    channels: list[RealtimeChannel]
    userId: str | None = None
    actorUserId: str | None = None
    payload: dict[str, Any] = Field(default_factory=dict)
    createdAt: datetime = Field(default_factory=now_utc)


class Notification(ApiModel):
    id: str = Field(default_factory=lambda: new_id("NTF"))
    userId: str
    title: str
    message: str
    category: NotificationCategory
    priority: NotificationPriority = NotificationPriority.medium
    createdAt: datetime = Field(default_factory=now_utc)
    read: bool = False
    actionUrl: str | None = None
    acknowledged: bool = False

    @property
    def pinned(self) -> bool:
        return self.priority == NotificationPriority.critical and not self.acknowledged


class PresenceRecord(ApiModel):
    userId: str
    online: bool
    channels: list[RealtimeChannel] = Field(default_factory=list)
    lastSeen: datetime = Field(default_factory=now_utc)


class RealtimeDiagnostics(ApiModel):
    apiReachable: bool
    jwtValid: bool
    userAuthenticated: bool
    dashboardLoaded: bool
    marketplaceAvailable: bool
    walletAvailable: bool


# Complete set of supported realtime event types organised by domain.
# Add new event types here as the platform grows.

SUPPORTED_EVENT_TYPES = {
    # Dashboard / energy
    "dashboard.updated",
    "energy_reading.created",
    "energy_reading.batch_seeded",

    # Marketplace listings
    "listing.created",
    "listing.updated",
    "listing.deleted",
    "listing.sold",
    "listing.expired",
    "listing.status_changed",

    # Wallet & balance
    "wallet.updated",
    "deposit.completed",
    "withdrawal.completed",
    "withdrawal.requested",
    "balance.changed",

    # Escrow
    "escrow.created",
    "escrow.funded",
    "escrow.released",
    "escrow.cancelled",
    "escrow.disputed",
    "escrow.frozen",
    "escrow.settled",

    # Settlement & refund
    "settlement.completed",
    "settlement.failed",
    "refund.created",
    "refund.completed",

    # Purchases
    "purchase.created",
    "purchase.completed",
    "purchase.cancelled",
    "purchase.refunded",

    # Notifications
    "notification.created",
    "notification.read",
    "notification.all_read",

    # AI
    "ai_response.completed",
    "forecast.updated",
    "recommendation.created",
    "recommendation.updated",
    "recommendation.dismissed",
    "sustainability.updated",
    "pricing.suggested",

    # Admin / platform
    "user.registered",
    "user.role_changed",
    "alert.created",
    "anomaly.detected",
    "service_health.changed",
    "grid.alert",
    "grid.status_changed",

    # System
    "connection.ready",
    "connection.unauthorized",
}
