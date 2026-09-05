from fastapi import APIRouter, Depends, HTTPException

from app.api.dependencies import get_current_user
from app.core.security import AuthenticatedUser
from app.schemas.recommendation import Recommendation
from app.schemas.realtime import RealtimeChannel
from app.services.event_publisher import event_publisher
from app.services.recommendation_service import recommendation_service

router = APIRouter()


@router.get("", response_model=list[Recommendation])
def recommendations(user: AuthenticatedUser = Depends(get_current_user)) -> list[Recommendation]:
    return recommendation_service.for_user(user)


@router.get("/{recommendation_id}", response_model=Recommendation)
def recommendation(recommendation_id: str, user: AuthenticatedUser = Depends(get_current_user)) -> Recommendation:
    item = recommendation_service.get(user, recommendation_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Recommendation not found.")
    return item


@router.post("/{recommendation_id}/dismiss", response_model=Recommendation)
def dismiss(recommendation_id: str, user: AuthenticatedUser = Depends(get_current_user)) -> Recommendation:
    item = recommendation_service.dismiss(user, recommendation_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Recommendation not found.")
    event_publisher.publish("recommendation.updated", channels=[RealtimeChannel.dashboard], user_id=user.user_id, payload={"recommendation_id": recommendation_id, "dismissed": True})
    return item


@router.post("/refresh", response_model=list[Recommendation])
def refresh(user: AuthenticatedUser = Depends(get_current_user)) -> list[Recommendation]:
    items = recommendation_service.for_user(user, refresh=True)
    if items:
        event_publisher.publish("recommendation.created", channels=[RealtimeChannel.dashboard, RealtimeChannel.notifications], user_id=user.user_id, payload={"count": len(items)})
    return items
