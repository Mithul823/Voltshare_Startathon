from fastapi import APIRouter, Depends, HTTPException, Response

from app.api.dependencies import get_current_user
from app.core.security import AuthenticatedUser
from app.schemas.ai import AssistantChatRequest, AssistantChatResponse, AssistantConversation
from app.schemas.realtime import RealtimeChannel
from app.services.event_publisher import event_publisher
from app.services.gemini_assistant_service import gemini_assistant_service
from app.services.smart_alert_service import smart_alert_service
from app.schemas.ai import AnomalySeverity

router = APIRouter()


@router.post("/chat", response_model=AssistantChatResponse)
async def chat(request: AssistantChatRequest, user: AuthenticatedUser = Depends(get_current_user)) -> AssistantChatResponse:
    response = await gemini_assistant_service.chat(user, request)
    event_publisher.publish("ai_response.completed", channels=[RealtimeChannel.notifications], user_id=user.user_id, payload={"conversation_id": response.conversation_id, "fallback_used": response.fallback_used})
    if response.fallback_used:
        smart_alert_service.create(user, alert_type="ai_fallback", severity=AnomalySeverity.low, title="AI fallback used", message="VoltShare answered using safe rule-based guidance.")
    return response


@router.get("/conversations", response_model=list[AssistantConversation])
def conversations(user: AuthenticatedUser = Depends(get_current_user)) -> list[AssistantConversation]:
    return gemini_assistant_service.conversations(user)


@router.get("/conversations/{conversation_id}", response_model=AssistantConversation)
def conversation(conversation_id: str, user: AuthenticatedUser = Depends(get_current_user)) -> AssistantConversation:
    item = gemini_assistant_service.conversation(user, conversation_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Conversation not found.")
    return item


@router.delete("/conversations/{conversation_id}", status_code=204)
def delete_conversation(conversation_id: str, user: AuthenticatedUser = Depends(get_current_user)) -> Response:
    if not gemini_assistant_service.delete(user, conversation_id):
        raise HTTPException(status_code=404, detail="Conversation not found.")
    return Response(status_code=204)
