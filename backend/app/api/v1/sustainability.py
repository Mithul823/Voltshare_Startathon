from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user
from app.core.security import AuthenticatedUser
from app.schemas.realtime import RealtimeChannel
from app.schemas.sustainability import CommunityImpact, SustainabilityHistory, SustainabilityScore, SustainabilitySummary
from app.services.event_publisher import event_publisher
from app.services.sustainability_service import sustainability_service

router = APIRouter()


@router.get("/summary", response_model=SustainabilitySummary)
def summary(user: AuthenticatedUser = Depends(get_current_user)) -> SustainabilitySummary:
    result = sustainability_service.summary(user.user_id)
    event_publisher.publish("sustainability.updated", channels=[RealtimeChannel.dashboard], user_id=user.user_id, payload={"carbon": result.estimated_carbon_avoided_kg_co2e})
    return result


@router.get("/score", response_model=SustainabilityScore)
def score(user: AuthenticatedUser = Depends(get_current_user)) -> SustainabilityScore:
    return sustainability_service.score(user.user_id)


@router.get("/history", response_model=SustainabilityHistory)
def history(user: AuthenticatedUser = Depends(get_current_user)) -> SustainabilityHistory:
    return sustainability_service.history(user.user_id)


@router.get("/community-impact", response_model=CommunityImpact)
def community(user: AuthenticatedUser = Depends(get_current_user)) -> CommunityImpact:
    return sustainability_service.community(user.user_id)
