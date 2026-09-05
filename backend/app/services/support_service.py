"""Support ticket service — delegates to the active support repository."""

from typing import Any

from app.repositories.support_repository import get_support_repository
from app.schemas.support import SupportMessageResponse, SupportTicketResponse, SupportSummary
from app.services.notification_service import notification_service
from app.schemas.realtime import NotificationCategory, NotificationPriority


class SupportService:
    def __init__(self) -> None:
        self._repo_instance: object | None = None

    @property
    def _repo(self) -> object:
        if self._repo_instance is None:
            self._repo_instance = get_support_repository()
        return self._repo_instance

    def create_ticket(self, user_id: str, user_name: str, user_role: str, data: Any) -> SupportTicketResponse:
        result = self._repo.create_ticket(user_id, user_name, user_role, data)
        # Notify user
        notification_service.create(
            user_id=user_id,
            title="Support Ticket Created",
            message=f"Your support ticket '{data.subject}' has been submitted. We will get back to you shortly.",
            category=NotificationCategory.system,
            priority=NotificationPriority.low,
        )
        return result

    def get_my_tickets(self, user_id: str) -> list[SupportTicketResponse]:
        return self._repo.get_my_tickets(user_id)

    def get_all_tickets(self) -> list[SupportTicketResponse]:
        return self._repo.get_all_tickets()

    def get_ticket(self, ticket_id: str) -> SupportTicketResponse | None:
        return self._repo.get_ticket(ticket_id)

    def update_ticket(self, ticket_id: str, update: Any) -> SupportTicketResponse:
        result = self._repo.update_ticket(ticket_id, update)
        # Notify user about status change
        if result.status in ("Resolved", "Closed"):
            notification_service.create(
                user_id=result.user_id,
                title=f"Ticket {result.status}",
                message=f"Your support ticket '{result.subject}' has been {result.status.lower()}.",
                category=NotificationCategory.system,
                priority=NotificationPriority.medium,
            )
        return result

    def get_messages(self, ticket_id: str) -> list[SupportMessageResponse]:
        return self._repo.get_messages(ticket_id)

    def add_message(self, ticket_id: str, sender_id: str, sender_name: str, message: str, is_admin: bool) -> SupportMessageResponse:
        result = self._repo.add_message(ticket_id, sender_id, sender_name, message, is_admin)
        # Get ticket to find the other party
        ticket = self._repo.get_ticket(ticket_id)
        if ticket:
            if is_admin:
                # Notify the user
                notification_service.create(
                    user_id=ticket.user_id,
                    title="New Reply on Your Ticket",
                    message=f"An admin has replied to your support ticket '{ticket.subject}'.",
                    category=NotificationCategory.system,
                    priority=NotificationPriority.low,
                )
            else:
                # Notify assigned admin or all admins
                if ticket.assigned_admin:
                    notification_service.create(
                        user_id=ticket.assigned_admin,
                        title="New Reply on Support Ticket",
                        message=f"User replied to ticket '{ticket.subject}'.",
                        category=NotificationCategory.system,
                        priority=NotificationPriority.medium,
                    )
        return result

    def get_summary(self) -> SupportSummary:
        return self._repo.get_summary()


support_service = SupportService()
