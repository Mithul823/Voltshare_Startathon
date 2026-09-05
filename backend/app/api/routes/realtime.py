from __future__ import annotations

from fastapi import FastAPI
from fastapi.security import HTTPAuthorizationCredentials
from fastapi.websockets import WebSocket, WebSocketDisconnect

from app.core.config import get_settings
from app.core.security import token_from_credentials
from app.schemas.realtime import RealtimeChannel
from app.services.dashboard_service import dashboard_service
from app.services.realtime_service import realtime_service
from app.services.user_service import user_service


def register_realtime_websockets(app: FastAPI) -> None:
    @app.websocket("/ws/dashboard")
    async def dashboard_socket(websocket: WebSocket) -> None:
        await _serve(websocket, {RealtimeChannel.dashboard}, send_dashboard_snapshot=True)

    @app.websocket("/ws/marketplace")
    async def marketplace_socket(websocket: WebSocket) -> None:
        await _serve(websocket, {RealtimeChannel.marketplace, RealtimeChannel.listings})

    @app.websocket("/ws/wallet")
    async def wallet_socket(websocket: WebSocket) -> None:
        await _serve(websocket, {RealtimeChannel.wallet})

    @app.websocket("/ws/notifications")
    async def notifications_socket(websocket: WebSocket) -> None:
        await _serve(websocket, {RealtimeChannel.notifications})

    @app.websocket("/ws/admin")
    async def admin_socket(websocket: WebSocket) -> None:
        await _serve(websocket, {RealtimeChannel.admin})

    @app.websocket("/ws/grid")
    async def grid_socket(websocket: WebSocket) -> None:
        await _serve(websocket, {RealtimeChannel.grid})


async def _serve(
    websocket: WebSocket,
    requested_channels: set[RealtimeChannel],
    *,
    send_dashboard_snapshot: bool = False,
) -> None:
    try:
        user = await _authenticate(websocket)
        channels = realtime_service.ensure_authorized(user, requested_channels)
        if not channels:
            await websocket.close(code=1008)
            return
        await realtime_service.manager.connect(websocket, user, channels)
        if send_dashboard_snapshot:
            await websocket.send_json(dashboard_service.dashboard(user.user_id).model_dump(mode="json"))
        else:
            await websocket.send_json(
                {
                    "type": "connection.ready",
                    "channels": [channel.value for channel in sorted(channels, key=lambda item: item.value)],
                    "userId": user.user_id,
                }
            )
        while True:
            message = await websocket.receive_json()
            message_type = message.get("type") if isinstance(message, dict) else None
            if message_type == "ping":
                await websocket.send_json({"type": "pong"})
    except WebSocketDisconnect:
        realtime_service.manager.disconnect(websocket)
    except Exception:
        realtime_service.manager.disconnect(websocket)
        try:
            await websocket.close(code=1008)
        except RuntimeError:
            return


async def _authenticate(websocket: WebSocket):
    settings = get_settings()
    token = websocket.query_params.get("token")
    auth_header = websocket.headers.get("authorization")
    credentials = None
    if auth_header and auth_header.lower().startswith("bearer "):
        credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials=auth_header.split(" ", 1)[1])
    elif token:
        credentials = HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)
    raw_token, claims = token_from_credentials(credentials, settings)
    return await user_service.user_from_claims(raw_token, claims)
