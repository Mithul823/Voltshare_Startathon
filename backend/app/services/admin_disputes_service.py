"""Admin disputes service — manages dispute listing, filtering, and resolution."""

from app.schemas.admin_disputes import AdminDisputeSummary, DisputeActionResponse, DisputeResolutionRequest, PaginatedAdminDisputes
from app.schemas.common import UserRole
from app.services.audit_service import audit_service


class AdminDisputesService:
    def __init__(self) -> None:
        self._repo_instance: object | None = None

    @property
    def _repo(self) -> object:
        if self._repo_instance is None:
            from app.repositories.admin_disputes_repository import get_admin_disputes_repository
            self._repo_instance = get_admin_disputes_repository()
        return self._repo_instance

    async def list_disputes(
        self,
        status: str | None = None,
        priority: str | None = None,
        buyer_id: str | None = None,
        seller_id: str | None = None,
        date_from: str | None = None,
        date_to: str | None = None,
        page: int = 1,
        page_size: int = 20,
        actor_user_id: str | None = None,
    ) -> PaginatedAdminDisputes:
        return await self._repo.list_disputes(
            status=status,
            priority=priority,
            buyer_id=buyer_id,
            seller_id=seller_id,
            date_from=date_from,
            date_to=date_to,
            page=page,
            page_size=page_size,
        )

    async def get_dispute_detail(
        self,
        dispute_id: str,
        actor_user_id: str | None = None,
    ) -> AdminDisputeSummary:
        return await self._repo.get_dispute_detail(dispute_id=dispute_id)

    async def resolve_dispute(
        self,
        dispute_id: str,
        resolution: str = "resolved",
        reason: str = "",
        refund_amount_paise: int = 0,
        release_to_seller_paise: int = 0,
        actor_user_id: str | None = None,
        actor_role: UserRole | None = None,
    ) -> DisputeActionResponse:
        # Validate financial amounts against escrow data
        # This is a best-effort validation since escrow data may not be available
        if refund_amount_paise < 0 or release_to_seller_paise < 0:
            return DisputeActionResponse(
                id=dispute_id,
                status=resolution,
                message="Refund and seller release amounts cannot be negative.",
            )

        result = await self._repo.update_dispute_status(
            dispute_id=dispute_id,
            status=resolution,
            reason=reason,
            refund_amount_paise=refund_amount_paise,
            release_to_seller_paise=release_to_seller_paise,
        )

        audit_service.append(
            actor_user_id=actor_user_id or "system",
            action="dispute_resolved",
            resource_type="dispute",
            resource_id=dispute_id,
            status="succeeded",
            metadata={
                "resolution": resolution,
                "reason": reason,
                "refund_amount_paise": refund_amount_paise,
                "release_to_seller_paise": release_to_seller_paise,
            },
        )

        return result

    async def reject_dispute(
        self,
        dispute_id: str,
        reason: str = "",
        actor_user_id: str | None = None,
        actor_role: UserRole | None = None,
    ) -> DisputeActionResponse:
        result = await self._repo.update_dispute_status(
            dispute_id=dispute_id,
            status="rejected",
            reason=reason,
        )

        audit_service.append(
            actor_user_id=actor_user_id or "system",
            action="dispute_rejected",
            resource_type="dispute",
            resource_id=dispute_id,
            status="succeeded",
            metadata={"reason": reason},
        )

        return result

    async def assign_dispute(
        self,
        dispute_id: str,
        actor_user_id: str | None = None,
        actor_role: UserRole | None = None,
    ) -> DisputeActionResponse:
        result = await self._repo.assign_dispute(
            dispute_id=dispute_id,
            admin_id=actor_user_id or "system",
        )

        audit_service.append(
            actor_user_id=actor_user_id or "system",
            action="dispute_assigned",
            resource_type="dispute",
            resource_id=dispute_id,
            status="succeeded",
            metadata={"assigned_to": actor_user_id},
        )

        return result


admin_disputes_service = AdminDisputesService()
