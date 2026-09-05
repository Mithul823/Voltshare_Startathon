from __future__ import annotations

from collections import defaultdict, deque
from contextlib import suppress
from typing import Any

from fastapi import WebSocket

from app.core.security import AuthenticatedUser
from app.schemas.common import UserRole, now_utc
from app.schemas.realtime import PresenceRecord, RealtimeChannel, RealtimeEvent


class ConnectionManager:
    def __init__(self) -> None:
        self._connections: dict[RealtimeChannel, set[WebSocket]] = defaultdict(set)
        self._users: dict[WebSocket, AuthenticatedUser] = {}
        self._channels: dict[WebSocket, set[RealtimeChannel]] = defaultdict(set)
        self._presence: dict[str, PresenceRecord] = {}
        self._recent_event_ids: deque[str] = deque(maxlen=500)

    async def connect(
        self,
        websocket: WebSocket,
        user: AuthenticatedUser,
        channels: set[RealtimeChannel],
    ) -> None:
        await websocket.accept()
        self._users[websocket] = user
        self._channels[websocket] = set(channels)
        for channel in channels:
            self._connections[channel].add(websocket)
        self._presence[user.user_id] = PresenceRecord(
            userId=user.user_id,
            online=True,
            channels=sorted(channels, key=lambda item: item.value),
            lastSeen=now_utc(),
        )

    def disconnect(self, websocket: WebSocket) -> None:
        user = self._users.pop(websocket, None)
        channels = self._channels.pop(websocket, set())
        for channel in channels:
            self._connections[channel].discard(websocket)
        if user:
            self._presence[user.user_id] = PresenceRecord(
                userId=user.user_id,
                online=False,
                channels=[],
                lastSeen=now_utc(),
            )

    async def send_json(self, websocket: WebSocket, payload: dict[str, Any]) -> None:
        await websocket.send_json(payload)

    async def broadcast(self, event: RealtimeEvent) -> int:
        if event.id in self._recent_event_ids:
            return 0
        self._recent_event_ids.append(event.id)
        delivered = 0
        targets: set[WebSocket] = set()
        for channel in event.channels:
            targets.update(self._connections[channel])
        message = {"type": "event", "event": event.model_dump(mode="json")}
        for websocket in list(targets):
            user = self._users.get(websocket)
            if event.userId and user and event.userId != user.user_id and user.role != UserRole.admin:
                continue
            with suppress(Exception):
                await websocket.send_json(message)
                delivered += 1
        return delivered

    def presence(self, user_id: str) -> PresenceRecord | None:
        return self._presence.get(user_id)

    def active_count(self, channel: RealtimeChannel) -> int:
        return len(self._connections[channel])


class RealtimeService:
    def __init__(self) -> None:
        self.manager = ConnectionManager()

    def allowed_channels(self, user: AuthenticatedUser) -> set[RealtimeChannel]:
        common = {
            RealtimeChannel.dashboard,
            RealtimeChannel.marketplace,
            RealtimeChannel.notifications,
        }
        role_channels = {
            UserRole.consumer: {RealtimeChannel.wallet, RealtimeChannel.purchases},
            UserRole.producer: {RealtimeChannel.wallet, RealtimeChannel.listings, RealtimeChannel.sales},
            UserRole.prosumer: {
                RealtimeChannel.wallet,
                RealtimeChannel.listings,
                RealtimeChannel.purchases,
                RealtimeChannel.sales,
            },
            UserRole.technician: set(),
            UserRole.grid_operator: {RealtimeChannel.grid},
            UserRole.admin: set(RealtimeChannel),
        }
        return common | role_channels.get(user.role, set())

    def ensure_authorized(self, user: AuthenticatedUser, requested: set[RealtimeChannel]) -> set[RealtimeChannel]:
        allowed = self.allowed_channels(user)
        denied = requested - allowed
        if denied:
            return set()
        return requested


realtime_service = RealtimeService()
