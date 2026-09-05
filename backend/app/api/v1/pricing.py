from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user
from app.core.security import AuthenticatedUser
from app.schemas.recommendation import PricingSuggestion, PricingSuggestionRequest
from app.services.pricing_intelligence_service import pricing_intelligence_service

router = APIRouter()


@router.get("/intelligence", response_model=PricingSuggestion)
def intelligence(user: AuthenticatedUser = Depends(get_current_user)) -> PricingSuggestion:
    return pricing_intelligence_service.suggest(PricingSuggestionRequest())


@router.post("/suggest", response_model=PricingSuggestion)
def suggest(request: PricingSuggestionRequest, user: AuthenticatedUser = Depends(get_current_user)) -> PricingSuggestion:
    return pricing_intelligence_service.suggest(request)
