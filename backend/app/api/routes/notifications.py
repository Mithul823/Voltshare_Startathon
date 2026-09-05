from fastapi import APIRouter, Depends, HTTPException

from app.api.dependencies import get_current_user
from app.core.security import AuthenticatedUser
from app.schemas.realtime import Notification
from app.services.event_publisher import event_publisher
from app.services.notification_service import notification_service
from app.schemas.realtime import RealtimeChannel

router = APIRouter()


@router.get("", response_model=list[Notification])
def notifications(user: AuthenticatedUser = Depends(get_current_user)) -> list[Notification]:
    return notification_service.list_for(user.user_id)


@router.get("/unread-count")
def unread_count(user: AuthenticatedUser = Depends(get_current_user)) -> dict[str, int]:
    return {"count": notification_service.unread_count(user.user_id)}


@router.patch("/{notification_id}/read", response_model=Notification)
def mark_read(notification_id: str, user: AuthenticatedUser = Depends(get_current_user)) -> Notification:
    try:
        notification = notification_service.mark_read(user.user_id, notification_id, role=user.role)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Notification not found.") from exc
    event_publisher.publish(
        "notification.read",
        channels=[RealtimeChannel.notifications],
        user_id=notification.userId,
        actor_user_id=user.user_id,
        payload=notification.model_dump(mode="json"),
    )
    return notification
