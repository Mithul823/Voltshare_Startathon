"""Emergency service — delegates to the active emergency repository."""

from typing import Any

from app.core.config import get_settings
from app.core.exceptions import ApiError, ErrorCode
from app.repositories.emergency_repository import get_emergency_repository
from app.schemas.emergency import (
    EmergencyAllocationResponse,
    EmergencyRequestResponse,
    EmergencySummary,
)
from app.services.notification_service import notification_service
from app.schemas.realtime import NotificationCategory, NotificationPriority


class EmergencyService:
    def __init__(self) -> None:
        self._repo_instance: object | None = None

    @property
    def _repo(self) -> object:
        if self._repo_instance is None:
            self._repo_instance = get_emergency_repository()
        return self._repo_instance

    def create_request(self, consumer_id: str, consumer_name: str, data: Any) -> EmergencyRequestResponse:
        result = self._repo.create_request(consumer_id, consumer_name, data)
        # Notify consumer
        notification_service.create(
            user_id=consumer_id,
            title="Emergency Request Submitted",
            message=f"Your emergency request '{data.title}' has been submitted and is awaiting review.",
            category=NotificationCategory.system,
            priority=NotificationPriority.high,
        )
        return result

    def get_my_requests(self, consumer_id: str) -> list[EmergencyRequestResponse]:
        return self._repo.get_my_requests(consumer_id)

    def get_all_requests(self) -> list[EmergencyRequestResponse]:
        return self._repo.get_all_requests()

    def get_request(self, request_id: str) -> EmergencyRequestResponse | None:
        return self._repo.get_request(request_id)

    def update_request(self, request_id: str, update: Any, admin_id: str) -> EmergencyRequestResponse:
        result = self._repo.update_request(request_id, update, admin_id)
        # Notify consumer about status change
        status_changed = result.status
        title = "Emergency Request Updated"
        message = f"Your emergency request '{result.title}' has been {status_changed.lower()}."
        priority = NotificationPriority.medium

        if status_changed == "Approved":
            title = "Emergency Request Approved"
            message = f"Your emergency request '{result.title}' has been approved. Energy will be allocated shortly."
            priority = NotificationPriority.high
        elif status_changed == "Rejected":
            title = "Emergency Request Rejected"
            message = f"Your emergency request '{result.title}' has been rejected. Please contact support for details."
            priority = NotificationPriority.high
        elif status_changed == "In Progress":
            title = "Emergency In Progress"
            message = f"Your emergency request '{result.title}' is being processed."
        elif status_changed == "Completed":
            title = "Emergency Completed"
            message = f"Your emergency request '{result.title}' has been completed. {result.allocated_energy_kwh} kWh allocated."
            priority = NotificationPriority.medium

        notification_service.create(
            user_id=result.consumer_id,
            title=title,
            message=message,
            category=NotificationCategory.system,
            priority=priority,
        )
        return result

    def create_allocation(self, data: Any, allocated_by: str, consumer_id: str) -> EmergencyAllocationResponse:
        # Enforce energy allocation limit
        settings = get_settings()
        if data.allocated_energy > settings.emergency_max_allocation_kwh:
            raise ApiError(
                400, ErrorCode.VALIDATION_FAILED,
                f"Allocation of {data.allocated_energy} kWh exceeds maximum limit of {settings.emergency_max_allocation_kwh} kWh.",
            )

        result = self._repo.create_allocation(data, allocated_by)
        # Notify consumer about allocation
        notification_service.create(
            user_id=consumer_id,
            title="Energy Allocated",
            message=f"{data.allocated_energy} kWh has been allocated from {data.source.value} for your emergency request.",
            category=NotificationCategory.system,
            priority=NotificationPriority.high,
        )
        return result

    def get_summary(self) -> EmergencySummary:
        return self._repo.get_summary()


emergency_service = EmergencyService()
