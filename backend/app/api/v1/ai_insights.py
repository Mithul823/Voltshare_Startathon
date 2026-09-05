from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user
from app.core.security import AuthenticatedUser
from app.schemas.ai import AIInsight
from app.services.ai_insight_service import ai_insight_service

router = APIRouter()


@router.get("", response_model=list[AIInsight])
def insights(user: AuthenticatedUser = Depends(get_current_user)) -> list[AIInsight]:
    return ai_insight_service.list_for(user)


@router.get("/daily", response_model=list[AIInsight])
def daily(user: AuthenticatedUser = Depends(get_current_user)) -> list[AIInsight]:
    return ai_insight_service.list_for(user, period="daily")


@router.get("/weekly", response_model=list[AIInsight])
def weekly(user: AuthenticatedUser = Depends(get_current_user)) -> list[AIInsight]:
    return ai_insight_service.list_for(user, period="weekly")


@router.get("/monthly", response_model=list[AIInsight])
def monthly(user: AuthenticatedUser = Depends(get_current_user)) -> list[AIInsight]:
    return ai_insight_service.list_for(user, period="monthly")
