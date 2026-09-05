"""Admin support ticket API routes."""

from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user, require_role
from app.core.security import AuthenticatedUser
from app.schemas.common import UserRole
from app.schemas.support import (
    SupportAdminUpdate,
    SupportMessageCreate,
    SupportMessageResponse,
    SupportTicketResponse,
    SupportSummary,
)
from app.services.support_service import support_service

router = APIRouter()


@router.get("/support/summary", response_model=SupportSummary)
def get_support_summary(
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> SupportSummary:
    """Get summary statistics for all support tickets.

    Requires admin role.
    """
    return support_service.get_summary()


@router.get("/support/tickets", response_model=list[SupportTicketResponse])
def list_all_tickets(
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> list[SupportTicketResponse]:
    """List all support tickets (admin view).

    Requires admin role.
    """
    return support_service.get_all_tickets()


@router.get("/support/tickets/{ticket_id}", response_model=SupportTicketResponse)
def get_ticket_admin(
    ticket_id: str,
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> SupportTicketResponse:
    """Get details of a specific support ticket.

    Requires admin role.
    """
    return support_service.get_ticket(ticket_id)


@router.patch("/support/tickets/{ticket_id}", response_model=SupportTicketResponse)
def update_ticket(
    ticket_id: str,
    update: SupportAdminUpdate,
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> SupportTicketResponse:
    """Update a support ticket (assign, change status).

    Requires admin role. Admin can assign to themselves or change status.
    """
    return support_service.update_ticket(ticket_id, update)


@router.get("/support/tickets/{ticket_id}/messages", response_model=list[SupportMessageResponse])
def get_ticket_messages_admin(
    ticket_id: str,
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> list[SupportMessageResponse]:
    """Get all messages for a support ticket.

    Requires admin role.
    """
    return support_service.get_messages(ticket_id)


@router.post("/support/tickets/{ticket_id}/reply", response_model=SupportMessageResponse, status_code=201)
def reply_to_ticket_admin(
    ticket_id: str,
    data: SupportMessageCreate,
    user: AuthenticatedUser = Depends(require_role(UserRole.admin)),
) -> SupportMessageResponse:
    """Add an admin reply to a support ticket.

    Requires admin role.
    """
    user_name = user.email or "Admin"
    return support_service.add_message(ticket_id, user.user_id, user_name, data.message, True)
