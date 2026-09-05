from typing import Optional

from app.core.exceptions import ApiError, ErrorCode
from app.core.security import AuthenticatedUser
from app.repositories.kyc_repository import kyc_repository
from app.repositories.state import state
from app.schemas.kyc import KycAdminSummary, KycRecord, KycRecordResponse, KycStatus, KycSubmission, PaginatedKycRecords
from app.schemas.realtime import NotificationCategory, NotificationPriority, RealtimeChannel
from app.services.event_publisher import event_publisher


class KycService:
    async def submit(self, user: AuthenticatedUser, submission: KycSubmission) -> KycRecord:
        role_str = user.role.value if hasattr(user.role, 'value') else str(user.role)

        # Producers need additional fields
        if role_str in {"producer", "prosumer"}:
            if not submission.renewable_energy_source:
                raise ApiError(422, ErrorCode.VALIDATION_FAILED, "Producers must specify renewable energy source.")
            if not submission.installed_capacity_kw or submission.installed_capacity_kw <= 0:
                raise ApiError(422, ErrorCode.VALIDATION_FAILED, "Producers must specify installed capacity.")
            if not submission.plant_location:
                raise ApiError(422, ErrorCode.VALIDATION_FAILED, "Producers must provide plant location.")
            if not submission.bank_account_number or not submission.bank_ifsc_code:
                raise ApiError(422, ErrorCode.VALIDATION_FAILED, "Producers must provide bank details for settlement.")

        record = await kyc_repository.submit_kyc(user.user_id, role_str, submission)
        event_publisher.publish(
            "kyc.submitted",
            channels=[RealtimeChannel.admin, RealtimeChannel.notifications],
            actor_user_id=user.user_id,
            user_id=user.user_id,
            payload=record.model_dump(mode="json"),
            notification_title="KYC Submitted",
            notification_message=f"KYC application received for {submission.full_name}.",
            notification_category=NotificationCategory.system,
            notification_priority=NotificationPriority.medium,
        )
        return record

    async def get_my_kyc(self, user: AuthenticatedUser) -> Optional[KycRecord]:
        return await kyc_repository.get_my_kyc(user.user_id)

    async def check_can_purchase(self, user: AuthenticatedUser) -> bool:
        """Consumers and prosumers must have approved KYC before purchasing."""
        role_str = user.role.value if hasattr(user.role, 'value') else str(user.role)
        if role_str == "admin":
            return True
        if role_str not in {"consumer", "prosumer"}:
            return False
        record = await kyc_repository.get_my_kyc(user.user_id)
        if record is None or record.status != KycStatus.verified:
            return False
        return True

    async def check_can_sell(self, user: AuthenticatedUser) -> bool:
        """Producers and prosumers must have approved KYC before creating listings."""
        role_str = user.role.value if hasattr(user.role, 'value') else str(user.role)
        if role_str == "admin":
            return True
        if role_str not in {"producer", "prosumer"}:
            return False
        record = await kyc_repository.get_my_kyc(user.user_id)
        if record is None or record.status != KycStatus.verified:
            return False
        return True

    async def review(self, kyc_id: str, status: KycStatus, remarks: Optional[str], admin_user: AuthenticatedUser) -> KycRecord:
        if status not in {KycStatus.verified, KycStatus.rejected, KycStatus.resubmission_requested}:
            raise ApiError(422, ErrorCode.VALIDATION_FAILED, "Invalid review status.")

        record = await kyc_repository.review_kyc(kyc_id, status, remarks, admin_user.user_id)
        status_label = status.value.replace("_", " ").title()

        event_publisher.publish(
            f"kyc.{status.value}",
            channels=[RealtimeChannel.notifications],
            actor_user_id=admin_user.user_id,
            user_id=record.user_id,
            payload=record.model_dump(mode="json"),
            notification_title=f"KYC {status_label}",
            notification_message=f"Your KYC application has been {status_label}.",
            notification_category=NotificationCategory.system,
            notification_priority=NotificationPriority.high,
        )
        return record

    async def list_all(self, status: Optional[str] = None, search: Optional[str] = None,
                       page: int = 1, page_size: int = 20) -> PaginatedKycRecords:
        return await kyc_repository.list_all(status=status, search=search, page=page, page_size=page_size)

    async def get_summary(self) -> KycAdminSummary:
        return await kyc_repository.get_summary()


kyc_service = KycService()
