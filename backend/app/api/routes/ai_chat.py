from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user
from app.core.security import AuthenticatedUser
from app.schemas.ai_chat import ChatRequest, ChatResponse
from app.services.ai_chat_service import ai_chat_service

router = APIRouter()


@router.post("/chat", response_model=ChatResponse)
async def chat(
    request: ChatRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> ChatResponse:
    return await ai_chat_service.chat(request)
