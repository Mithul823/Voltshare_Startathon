from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user
from app.core.exceptions import ApiError, ErrorCode
from app.core.security import AuthenticatedUser
from app.schemas.insights import InsightRequest, InsightResponse
from app.services.gemini_insight_service import gemini_insight_service

router = APIRouter()


@router.post("/generate", response_model=InsightResponse)
async def generate(request: InsightRequest, user: AuthenticatedUser = Depends(get_current_user)) -> InsightResponse:
    return await gemini_insight_service.generate(user.user_id, request)


@router.get("/latest", response_model=InsightResponse)
def latest(user: AuthenticatedUser = Depends(get_current_user)) -> InsightResponse:
    insight = gemini_insight_service.latest(user.user_id)
    if insight is None:
        raise ApiError(404, ErrorCode.RESOURCE_NOT_FOUND, "No insight has been generated yet.")
    return insight
