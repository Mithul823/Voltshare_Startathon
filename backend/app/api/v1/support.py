"""Support ticket API routes — consumer/producer facing."""

from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user
from app.core.security import AuthenticatedUser
from app.schemas.common import UserRole
from app.schemas.support import (
    SupportMessageCreate,
    SupportMessageResponse,
    SupportTicketCreate,
    SupportTicketResponse,
)
from app.services.support_service import support_service

router = APIRouter()


@router.get("/mine", response_model=list[SupportTicketResponse])
def list_my_tickets(
    user: AuthenticatedUser = Depends(get_current_user),
) -> list[SupportTicketResponse]:
    """Get all support tickets for the current user.

    Requires authentication. Users can only view their own tickets.
    """
    return support_service.get_my_tickets(user.user_id)


@router.get("/{ticket_id}", response_model=SupportTicketResponse)
def get_ticket(
    ticket_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
) -> SupportTicketResponse:
    """Get details of a specific support ticket.

    Requires authentication. Users can only view their own tickets;
    admins can view any ticket.
    """
    return support_service.get_ticket(ticket_id)


@router.post("", response_model=SupportTicketResponse, status_code=201)
def create_ticket(
    data: SupportTicketCreate,
    user: AuthenticatedUser = Depends(get_current_user),
) -> SupportTicketResponse:
    """Create a new support ticket.

    Requires authentication. Available for consumers, producers, and all roles.
    """
    user_name = user.email or "User"
    user_role = user.role.value
    return support_service.create_ticket(user.user_id, user_name, user_role, data)


@router.get("/{ticket_id}/messages", response_model=list[SupportMessageResponse])
def get_ticket_messages(
    ticket_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
) -> list[SupportMessageResponse]:
    """Get all messages for a support ticket.

    Requires authentication. Only participants (user or admin) can view messages.
    """
    return support_service.get_messages(ticket_id)


@router.post("/{ticket_id}/reply", response_model=SupportMessageResponse, status_code=201)
def reply_to_ticket(
    ticket_id: str,
    data: SupportMessageCreate,
    user: AuthenticatedUser = Depends(get_current_user),
) -> SupportMessageResponse:
    """Add a reply to a support ticket.

    Requires authentication. Users can reply to their own tickets.
    Admins can reply to any ticket.
    """
    user_name = user.email or "User"
    is_admin = user.role == UserRole.admin
    return support_service.add_message(ticket_id, user.user_id, user_name, data.message, is_admin)
