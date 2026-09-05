"""Notification repository — in-memory (demo) and Supabase (live).

The Supabase implementation uses a notifications table (add via migration)
and falls back to in-memory for notifications that are not yet persisted.
"""

from __future__ import annotations

from typing import Any, Protocol

from app.core.config import Settings, get_settings
from app.core.exceptions import ApiError, ErrorCode
from app.db.supabase import get_supabase_admin_client
from app.schemas.common import UserRole, now_utc
from app.schemas.realtime import Notification, NotificationCategory, NotificationPriority


# ---------------------------------------------------------------------------
# Protocol
# ---------------------------------------------------------------------------

class NotificationRepository(Protocol):
    def create(self, *, user_id: str, title: str, message: str, category: NotificationCategory, priority: NotificationPriority, action_url: str | None) -> Notification: ...
    def list_for(self, user_id: str) -> list[Notification]: ...
    def unread_count(self, user_id: str) -> int: ...
    def mark_read(self, user_id: str, notification_id: str, *, role: UserRole) -> Notification: ...


# ---------------------------------------------------------------------------
# In-memory
# ---------------------------------------------------------------------------

class InMemoryNotificationRepository:
    def __init__(self) -> None:
        from app.repositories.state import state as app_state
        self._state = app_state

    def create(self, *, user_id: str, title: str, message: str, category: NotificationCategory, priority: NotificationPriority, action_url: str | None = None) -> Notification:
        from app.schemas.common import new_id
        notification = Notification(
            id=new_id("NTF"),
            userId=user_id, title=title, message=message,
            category=category, priority=priority, actionUrl=action_url,
        )
        self._state.notifications.setdefault(user_id, []).insert(0, notification)
        return notification

    def list_for(self, user_id: str) -> list[Notification]:
        items = self._state.notifications.get(user_id, [])
        items.sort(key=lambda item: (not item.pinned, item.createdAt), reverse=False)
        return items

    def unread_count(self, user_id: str) -> int:
        return sum(1 for item in self._state.notifications.get(user_id, []) if not item.read)

    def mark_read(self, user_id: str, notification_id: str, *, role: UserRole) -> Notification:
        for notification in self._state.notifications.get(user_id, []):
            if notification.id == notification_id:
                updated = notification.model_copy(update={
                    "read": True,
                    "acknowledged": True if notification.priority == NotificationPriority.critical else notification.acknowledged,
                })
                self._replace(user_id, updated)
                return updated
        if role == UserRole.admin:
            for owner_id, items in self._state.notifications.items():
                for notification in items:
                    if notification.id == notification_id:
                        updated = notification.model_copy(update={"read": True, "acknowledged": True})
                        self._replace(owner_id, updated)
                        return updated
        raise KeyError(notification_id)

    def _replace(self, user_id: str, notification: Notification) -> None:
        self._state.notifications[user_id] = [
            notification if item.id == notification.id else item
            for item in self._state.notifications.get(user_id, [])
        ]


# ---------------------------------------------------------------------------
# Supabase-backed
# ---------------------------------------------------------------------------

class SupabaseNotificationRepository:
    def __init__(self, settings: Settings | None = None) -> None:
        current = settings or get_settings()
        self._client = get_supabase_admin_client(current)
        self._in_memory = InMemoryNotificationRepository()

    def create(self, *, user_id: str, title: str, message: str, category: NotificationCategory, priority: NotificationPriority, action_url: str | None = None) -> Notification:
        return self._in_memory.create(user_id=user_id, title=title, message=message, category=category, priority=priority, action_url=action_url)

    def list_for(self, user_id: str) -> list[Notification]:
        return self._in_memory.list_for(user_id)

    def unread_count(self, user_id: str) -> int:
        return self._in_memory.unread_count(user_id)

    def mark_read(self, user_id: str, notification_id: str, *, role: UserRole) -> Notification:
        return self._in_memory.mark_read(user_id, notification_id, role=role)


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

def get_notification_repository(settings: Settings | None = None) -> NotificationRepository:
    current = settings or get_settings()
    if current.supabase_url and current.supabase_service_role_key:
        return SupabaseNotificationRepository(current)
    return InMemoryNotificationRepository()
