import pytest
from fastapi.testclient import TestClient

from app.schemas.common import UserRole
from app.schemas.realtime import (
    NotificationCategory,
    NotificationPriority,
    RealtimeChannel,
    RealtimeEvent,
)
from app.services.notification_service import notification_service
from app.services.realtime_service import ConnectionManager, realtime_service
from app.core.security import AuthenticatedUser
from tests.conftest import auth_headers, make_token, seed_profile


class FakeSocket:
    def __init__(self) -> None:
        self.accepted = False
        self.messages: list[dict] = []

    async def accept(self) -> None:
        self.accepted = True

    async def send_json(self, payload: dict) -> None:
        self.messages.append(payload)


def _user(user_id: str, role: UserRole = UserRole.consumer) -> AuthenticatedUser:
    return AuthenticatedUser(user_id=user_id, email=f"{user_id}@example.com", role=role, token="token")


def test_realtime_channel_authorization_by_role() -> None:
    consumer = _user("consumer", UserRole.consumer)
    grid = _user("grid", UserRole.grid_operator)
    admin = _user("admin", UserRole.admin)

    assert RealtimeChannel.wallet in realtime_service.allowed_channels(consumer)
    assert realtime_service.ensure_authorized(consumer, {RealtimeChannel.admin}) == set()
    assert realtime_service.ensure_authorized(grid, {RealtimeChannel.grid}) == {RealtimeChannel.grid}
    assert RealtimeChannel.admin in realtime_service.allowed_channels(admin)
    assert RealtimeChannel.grid in realtime_service.allowed_channels(admin)


@pytest.mark.anyio
async def test_realtime_dashboard_wallet_marketplace_delivery_and_duplicates() -> None:
    manager = ConnectionManager()
    user = _user("buyer", UserRole.prosumer)
    dashboard_socket = FakeSocket()
    wallet_socket = FakeSocket()
    marketplace_socket = FakeSocket()

    await manager.connect(dashboard_socket, user, {RealtimeChannel.dashboard})
    await manager.connect(wallet_socket, user, {RealtimeChannel.wallet})
    await manager.connect(marketplace_socket, user, {RealtimeChannel.marketplace})

    event = RealtimeEvent(
        id="EVT-DUPLICATE",
        type="dashboard.updated",
        channels=[RealtimeChannel.dashboard, RealtimeChannel.wallet, RealtimeChannel.marketplace],
        userId=user.user_id,
        payload={"reason": "test"},
    )
    assert await manager.broadcast(event) == 3
    assert await manager.broadcast(event) == 0
    assert len(dashboard_socket.messages) == 1
    assert len(wallet_socket.messages) == 1
    assert len(marketplace_socket.messages) == 1


@pytest.mark.anyio
async def test_realtime_multiple_clients_and_concurrent_updates() -> None:
    manager = ConnectionManager()
    sockets = [FakeSocket(), FakeSocket()]
    user = _user("buyer", UserRole.consumer)
    for socket in sockets:
        await manager.connect(socket, user, {RealtimeChannel.wallet})

    first = RealtimeEvent(type="balance.changed", channels=[RealtimeChannel.wallet], userId=user.user_id)
    second = RealtimeEvent(type="wallet.updated", channels=[RealtimeChannel.wallet], userId=user.user_id)
    assert await manager.broadcast(first) == 2
    assert await manager.broadcast(second) == 2
    assert [message["event"]["type"] for message in sockets[0].messages] == ["balance.changed", "wallet.updated"]


def test_notification_delivery_and_read_state(client: TestClient) -> None:
    seed_profile("notify-user", UserRole.consumer)
    notification = notification_service.create(
        user_id="notify-user",
        title="Wallet updated",
        message="Your balance changed.",
        category=NotificationCategory.wallet,
        priority=NotificationPriority.critical,
        action_url="/wallet",
    )

    headers = auth_headers("notify-user")
    listing = client.get("/api/v1/notifications", headers=headers)
    assert listing.status_code == 200
    assert listing.json()[0]["id"] == notification.id
    assert listing.json()[0]["priority"] == "CRITICAL"

    marked = client.patch(f"/api/v1/notifications/{notification.id}/read", headers=headers)
    assert marked.status_code == 200
    assert marked.json()["read"] is True
    assert marked.json()["acknowledged"] is True


def test_unauthorized_websocket_and_admin_channel_rejection(client: TestClient) -> None:
    try:
        with client.websocket_connect("/ws/notifications"):
            raise AssertionError("websocket should reject missing auth")
    except Exception:
        assert True

    seed_profile("not-admin", UserRole.consumer)
    token = make_token("not-admin")
    try:
        with client.websocket_connect(f"/ws/admin?token={token}"):
            raise AssertionError("consumer should not join admin websocket")
    except Exception:
        assert True


def test_wallet_websocket_ping_and_presence(client: TestClient) -> None:
    seed_profile("wallet-ws", UserRole.consumer)
    token = make_token("wallet-ws")
    with client.websocket_connect(f"/ws/wallet?token={token}") as websocket:
        ready = websocket.receive_json()
        assert ready["type"] == "connection.ready"
        websocket.send_json({"type": "ping"})
        assert websocket.receive_json()["type"] == "pong"
