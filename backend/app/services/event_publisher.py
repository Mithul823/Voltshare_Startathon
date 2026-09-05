from __future__ import annotations

import asyncio
from contextlib import suppress
from typing import Any

from app.repositories.state import state
from app.schemas.realtime import (
    NotificationCategory,
    NotificationPriority,
    RealtimeChannel,
    RealtimeEvent,
)
from app.services.notification_service import notification_service
from app.services.realtime_service import realtime_service


class EventPublisher:
    def publish(
        self,
        event_type: str,
        *,
        channels: list[RealtimeChannel],
        payload: dict[str, Any] | None = None,
        actor_user_id: str | None = None,
        user_id: str | None = None,
        notification_title: str | None = None,
        notification_message: str | None = None,
        notification_category: NotificationCategory | None = None,
        notification_priority: NotificationPriority = NotificationPriority.medium,
        action_url: str | None = None,
    ) -> RealtimeEvent:
        event = RealtimeEvent(
            type=event_type,
            channels=channels,
            userId=user_id,
            actorUserId=actor_user_id,
            payload=payload or {},
        )
        from app.core.financial_transaction import defer
        if defer(lambda: self.publish(event_type, channels=channels, payload=payload,
            actor_user_id=actor_user_id, user_id=user_id, notification_title=notification_title,
            notification_message=notification_message, notification_category=notification_category,
            notification_priority=notification_priority, action_url=action_url)):
            return event
        state.realtime_events.append(event)
        if user_id and notification_title and notification_message and notification_category:
            notification = notification_service.create(
                user_id=user_id,
                title=notification_title,
                message=notification_message,
                category=notification_category,
                priority=notification_priority,
                action_url=action_url,
            )
            notification_event = RealtimeEvent(
                type="notification.created",
                channels=[RealtimeChannel.notifications],
                userId=user_id,
                actorUserId=actor_user_id,
                payload=notification.model_dump(mode="json"),
            )
            state.realtime_events.append(notification_event)
            self._dispatch(notification_event)
        self._dispatch(event)
        return event

    def _dispatch(self, event: RealtimeEvent) -> None:
        with suppress(RuntimeError):
            loop = asyncio.get_running_loop()
            loop.create_task(realtime_service.manager.broadcast(event))


event_publisher = EventPublisher()
