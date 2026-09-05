from datetime import datetime, timezone
from threading import RLock
from typing import Optional

from app.core.exceptions import ApiError, ErrorCode
from app.core.security import AuthenticatedUser
from app.schemas.common import new_id, now_utc
from app.schemas.suspended_users import PaginatedSuspendedUsers, SuspendedUserRecord, SuspensionRequest
from app.schemas.realtime import NotificationCategory, NotificationPriority, RealtimeChannel
from app.services.event_publisher import event_publisher


class SuspendedUsersService:
    def __init__(self) -> None:
        self._lock = RLock()
        self._suspended: dict[str, SuspendedUserRecord] = {}

    async def suspend(self, target_user_id: str, admin_user: AuthenticatedUser,
                      reason: str, target_name: str, target_email: Optional[str],
                      target_role: str) -> SuspendedUserRecord:
        with self._lock:
            # Check if already suspended
            for record in self._suspended.values():
                if record.user_id == target_user_id and not record.is_restored:
                    raise ApiError(409, ErrorCode.VALIDATION_FAILED, "User is already suspended.")

            record = SuspendedUserRecord(
                id=new_id("SUS"),
                user_id=target_user_id,
                full_name=target_name,
                email=target_email,
                role=target_role,
                suspension_reason=reason,
                suspended_by=admin_user.user_id,
                suspended_at=now_utc(),
                is_restored=False,
            )
            self._suspended[record.id] = record

            event_publisher.publish(
                "user.suspended",
                channels=[RealtimeChannel.admin, RealtimeChannel.notifications],
                actor_user_id=admin_user.user_id,
                user_id=target_user_id,
                payload=record.model_dump(mode="json"),
                notification_title="User Suspended",
                notification_message=f"{target_name} has been suspended.",
                notification_category=NotificationCategory.system,
                notification_priority=NotificationPriority.high,
            )
            return record

    async def restore(self, target_user_id: str, admin_user: AuthenticatedUser) -> SuspendedUserRecord:
        with self._lock:
            for record_id, record in self._suspended.items():
                if record.user_id == target_user_id and not record.is_restored:
                    updated = record.model_copy(update={
                        "is_restored": True,
                        "restored_at": now_utc(),
                        "restored_by": admin_user.user_id,
                    })
                    self._suspended[record_id] = updated

                    event_publisher.publish(
                        "user.restored",
                        channels=[RealtimeChannel.admin, RealtimeChannel.notifications],
                        actor_user_id=admin_user.user_id,
                        user_id=target_user_id,
                        payload=updated.model_dump(mode="json"),
                        notification_title="User Restored",
                        notification_message=f"{record.full_name} has been restored.",
                        notification_category=NotificationCategory.system,
                        notification_priority=NotificationPriority.high,
                    )
                    return updated
            raise ApiError(404, ErrorCode.RESOURCE_NOT_FOUND, "No active suspension found for this user.")

    async def delete_suspension(self, target_user_id: str, admin_user: AuthenticatedUser) -> None:
        with self._lock:
            to_delete = None
            for record_id, record in self._suspended.items():
                if record.user_id == target_user_id:
                    to_delete = record_id
                    break
            if to_delete:
                del self._suspended[to_delete]
            else:
                raise ApiError(404, ErrorCode.RESOURCE_NOT_FOUND, "Suspension record not found.")

    async def list_suspended(self, page: int = 1, page_size: int = 20,
                             search: Optional[str] = None) -> PaginatedSuspendedUsers:
        items = [r for r in self._suspended.values() if not r.is_restored]
        if search:
            search_lower = search.lower()
            items = [i for i in items if search_lower in i.full_name.lower() or (i.email and search_lower in i.email.lower())]
        items.sort(key=lambda x: x.suspended_at, reverse=True)
        total = len(items)
        total_pages = max(1, (total + page_size - 1) // page_size)
        start = (page - 1) * page_size
        end = start + page_size
        return PaginatedSuspendedUsers(
            items=items[start:end],
            page=page,
            page_size=page_size,
            total=total,
            total_pages=total_pages,
        )

    async def get_suspension_history(self, target_user_id: str) -> list[SuspendedUserRecord]:
        return [r for r in self._suspended.values() if r.user_id == target_user_id]

    async def is_user_suspended(self, user_id: str) -> bool:
        for record in self._suspended.values():
            if record.user_id == user_id and not record.is_restored:
                return True
        return False


suspended_users_service = SuspendedUsersService()
