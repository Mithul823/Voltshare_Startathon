"""Escrow service — delegates data access to the active escrow and wallet repositories.

Business logic (authorisation, integrity hash verification, settlement
calculation) lives here.  Data access is delegated to repositories.
"""

from app.core.financial_transaction import atomic
from app.core.exceptions import ApiError, ErrorCode
from app.core.security import AuthenticatedUser
from app.repositories.escrow_repository import get_escrow_repository
from app.repositories.wallet_repository import get_wallet_repository
from app.schemas.common import UserRole, new_id, now_utc
from app.schemas.escrow import DeliveryVerificationRequest, Dispute, DisputeRequest, EscrowAgreement, EscrowSettlementResult, EscrowStatus, ReconciliationReport
from app.schemas.wallet import EscrowAccount, Settlement
from app.services.audit_service import audit_service, canonical_hmac


class EscrowService:
    def __init__(self) -> None:
        self._escrow_repo_instance: object | None = None
        self._wallet_repo_instance: object | None = None

    @property
    def _escrow(self) -> object:
        if self._escrow_repo_instance is None:
            self._escrow_repo_instance = get_escrow_repository()
        return self._escrow_repo_instance

    @property
    def _wallet(self) -> object:
        if self._wallet_repo_instance is None:
            self._wallet_repo_instance = get_wallet_repository()
        return self._wallet_repo_instance

    @atomic
    def create_for_purchase(self, *, purchase_id: str, listing_id: str, buyer_id: str, seller_id: str, quantity_kwh: float, amount_held_paise: int, platform_fee_paise: int) -> EscrowAgreement:
        return self._escrow.create_for_purchase(
            purchase_id=purchase_id,
            listing_id=listing_id,
            buyer_id=buyer_id,
            seller_id=seller_id,
            quantity_kwh=quantity_kwh,
            amount_held_paise=amount_held_paise,
            platform_fee_paise=platform_fee_paise,
        )

    def get(self, escrow_id: str) -> EscrowAgreement:
        return self._escrow.get(escrow_id)

    def list_for(self, user: AuthenticatedUser) -> list[EscrowAgreement]:
        if user.role == UserRole.admin:
            from app.repositories.financial_store import financial_state as state
            return list(state.escrows.values())
        return self._escrow.list_for(user.user_id)

    def ensure_participant(self, user: AuthenticatedUser, escrow: EscrowAgreement) -> None:
        if user.role != UserRole.admin and user.user_id not in {escrow.buyerId, escrow.sellerId}:
            raise ApiError(403, ErrorCode.ACCESS_DENIED, "Only escrow participants can access this operation.")

    @atomic
    def verify_and_settle(self, user: AuthenticatedUser, escrow_id: str, request: DeliveryVerificationRequest, idempotency_key: str) -> EscrowSettlementResult:
        escrow = self._escrow.get(escrow_id)
        if user.user_id != escrow.buyerId and user.role != UserRole.admin:
            raise ApiError(403, ErrorCode.ACCESS_DENIED, "Only the buyer or an administrator can confirm delivery and settle escrow.")
        if escrow.completedAt is not None or escrow.status in {EscrowStatus.released, EscrowStatus.refunded, EscrowStatus.frozen, EscrowStatus.disputed}:
            raise ApiError(409, ErrorCode.INVALID_ESCROW_STATE, "Cannot settle a terminal or disputed escrow.")
        # Integrity hash is calculated with integrityHash="" at creation time,
        # so we must zero it out before re-hashing to match.
        dump_for_hash = escrow.model_dump(mode="json")
        dump_for_hash["integrityHash"] = ""
        if escrow.integrityHash != canonical_hmac(dump_for_hash):
            frozen = self._escrow.update(escrow_id, status=EscrowStatus.frozen, failureReason="integrity_failure")
            audit_service.append(actor_user_id=user.user_id, action="integrity_failure", resource_type="escrow", resource_id=escrow.id, status="blocked", idempotency_key=idempotency_key)
            raise ApiError(409, ErrorCode.INTEGRITY_FAILURE, "Escrow integrity validation failed.")
        if escrow.status in {EscrowStatus.released, EscrowStatus.refunded, EscrowStatus.frozen}:
            raise ApiError(409, ErrorCode.INVALID_ESCROW_STATE, "Cannot settle a terminal escrow.")
        blocked = request.tamperingDetected or not request.meterMatched or not request.withinDeliveryWindow
        if blocked:
            updated = self._escrow.update(escrow_id, status=EscrowStatus.frozen, deliveredEnergyKwh=request.deliveredEnergyKwh, failureReason="meter_mismatch_or_tampering")
            result = EscrowSettlementResult(
                escrow=updated, sellerReleasePaise=0, buyerRefundPaise=0,
                platformFeeRetainedPaise=0, frozenPaise=escrow.totalHeldPaise,
                idempotencyKey=idempotency_key, defaultCase={"reason": updated.failureReason},
            )
        else:
            ratio = min(1.0, request.deliveredEnergyKwh / escrow.energyQuantityKwh) if escrow.energyQuantityKwh > 0 else 0
            accepted = 1.0 if ratio >= 0.98 else ratio if ratio >= 0.5 else 0.0
            seller_release = round(escrow.amountHeldPaise * accepted)
            fee = round(escrow.platformFeePaise * accepted)
            buyer_refund = escrow.totalHeldPaise - seller_release - fee
            status = EscrowStatus.released if accepted >= 1 else EscrowStatus.deliveryPartiallyConfirmed if accepted >= 0.5 else EscrowStatus.refunded
            updated = self._escrow.update(escrow_id,
                status=status, deliveredEnergyKwh=request.deliveredEnergyKwh,
                completedAt=now_utc(), releasedAt=now_utc() if seller_release else None,
                refundedAt=now_utc() if buyer_refund else None,
            )
            default_case = None if accepted >= 0.98 else {"reason": "partial_delivery" if accepted >= 0.5 else "seller_default", "financialImpactPaise": buyer_refund}
            result = EscrowSettlementResult(
                escrow=updated, sellerReleasePaise=seller_release, buyerRefundPaise=buyer_refund,
                platformFeeRetainedPaise=fee, frozenPaise=0,
                idempotencyKey=idempotency_key, defaultCase=default_case,
            )
        from app.services.wallet_service import wallet_service
        if not result.frozenPaise:
            wallet_service.release_escrow(
                buyer_id=updated.buyerId, seller_id=updated.sellerId,
                escrow_id=updated.id, purchase_id=updated.purchaseId,
                seller_release_paise=result.sellerReleasePaise,
                buyer_refund_paise=result.buyerRefundPaise,
                platform_fee_paise=result.platformFeeRetainedPaise,
            )
        if result.sellerReleasePaise or result.buyerRefundPaise:
            self._escrow.save_settlement(Settlement(
                settlementId=new_id("STL"), escrowId=updated.id, purchaseId=updated.purchaseId,
                sellerId=updated.sellerId, amountPaise=result.sellerReleasePaise,
                platformFeePaise=result.platformFeeRetainedPaise,
                status="COMPLETED" if result.sellerReleasePaise else "REFUNDED",
            ))
        audit_service.append(actor_user_id=user.user_id, action="escrow_settlement", resource_type="escrow", resource_id=escrow.id, idempotency_key=idempotency_key, metadata=result.model_dump(mode="json", exclude={"escrow"}))
        return result

    @atomic
    def raise_dispute(self, user: AuthenticatedUser, escrow_id: str, request: DisputeRequest) -> Dispute:
        escrow = self._escrow.get(escrow_id)
        self.ensure_participant(user, escrow)
        existing = [d for d in self._escrow.get_disputes() if d.escrowId == escrow_id and d.raisedBy == user.user_id]
        if existing:
            raise ApiError(409, ErrorCode.DUPLICATE_OPERATION, "A dispute already exists for this escrow.")
        dispute = Dispute(id=new_id("DSP"), escrowId=escrow_id, raisedBy=user.user_id, category=request.category, description=request.description)
        self._escrow.save_dispute(dispute)
        self._escrow.update(escrow_id, status=EscrowStatus.disputed, disputedAt=now_utc())
        audit_service.append(actor_user_id=user.user_id, action="dispute_created", resource_type="escrow", resource_id=escrow_id)
        return dispute

    def reconcile(self) -> ReconciliationReport:
        return self._escrow.reconcile()


escrow_service = EscrowService()
