"""Notification service — delegates to the active notification repository."""

from app.repositories.notification_repository import get_notification_repository
from app.schemas.common import UserRole
from app.schemas.realtime import Notification, NotificationCategory, NotificationPriority


class NotificationService:
    def __init__(self) -> None:
        self._repo_instance: object | None = None

    @property
    def _repo(self) -> object:
        if self._repo_instance is None:
            self._repo_instance = get_notification_repository()
        return self._repo_instance

    def create(self, *, user_id: str, title: str, message: str, category: NotificationCategory, priority: NotificationPriority = NotificationPriority.medium, action_url: str | None = None) -> Notification:
        return self._repo.create(user_id=user_id, title=title, message=message, category=category, priority=priority, action_url=action_url)

    def list_for(self, user_id: str) -> list[Notification]:
        return self._repo.list_for(user_id)

    def unread_count(self, user_id: str) -> int:
        return self._repo.unread_count(user_id)

    def mark_read(self, user_id: str, notification_id: str, *, role: UserRole) -> Notification:
        return self._repo.mark_read(user_id, notification_id, role=role)


notification_service = NotificationService()
