from typing import cast

from fastapi import APIRouter, Depends, Header, Response

from app.api.dependencies import get_current_user
from app.core.idempotency import idempotency_store
from app.core.security import AuthenticatedUser
from app.repositories.state import state
from app.schemas.escrow import DeliveryVerificationRequest, EscrowAgreement, EscrowSettlementResult
from app.services.escrow_service import escrow_service

router = APIRouter()


@router.get("", response_model=list[EscrowAgreement])
def escrows(user: AuthenticatedUser = Depends(get_current_user)) -> list[EscrowAgreement]:
    return escrow_service.list_for(user)


@router.post("/create", response_model=EscrowAgreement, status_code=201)
def create_existing_purchase_escrow(purchaseId: str, user: AuthenticatedUser = Depends(get_current_user)) -> EscrowAgreement:
    purchase = state.purchases.get(purchaseId)
    if not purchase or not purchase.escrowId:
        from app.core.exceptions import ApiError, ErrorCode

        raise ApiError(404, ErrorCode.RESOURCE_NOT_FOUND, "Purchase escrow not found.")
    escrow = escrow_service.get(purchase.escrowId)
    escrow_service.ensure_participant(user, escrow)
    return escrow


@router.post("/release", response_model=EscrowSettlementResult)
def release(
    escrowId: str,
    response: Response,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    user: AuthenticatedUser = Depends(get_current_user),
) -> EscrowSettlementResult:
    escrow = escrow_service.get(escrowId)
    request = DeliveryVerificationRequest(deliveredEnergyKwh=escrow.energyQuantityKwh)
    status, payload = idempotency_store.run(
        key=idempotency_key,
        user_id=user.user_id,
        operation=f"escrow_release:{escrowId}",
        payload={"escrowId": escrowId},
        handler=lambda: (200, escrow_service.verify_and_settle(user, escrowId, request, idempotency_key or "")),
    )
    response.status_code = status
    return cast(EscrowSettlementResult, payload)


@router.post("/cancel", response_model=EscrowSettlementResult)
def cancel(
    escrowId: str,
    response: Response,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    user: AuthenticatedUser = Depends(get_current_user),
) -> EscrowSettlementResult:
    request = DeliveryVerificationRequest(deliveredEnergyKwh=0)
    status, payload = idempotency_store.run(
        key=idempotency_key,
        user_id=user.user_id,
        operation=f"escrow_cancel:{escrowId}",
        payload={"escrowId": escrowId},
        handler=lambda: (200, escrow_service.verify_and_settle(user, escrowId, request, idempotency_key or "")),
    )
    response.status_code = status
    return cast(EscrowSettlementResult, payload)
