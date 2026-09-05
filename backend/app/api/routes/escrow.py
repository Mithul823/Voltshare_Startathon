from typing import cast

from fastapi import APIRouter, Depends, Header, Response

from app.api.dependencies import get_current_user, require_roles
from app.core.idempotency import idempotency_store
from app.core.security import AuthenticatedUser
from app.repositories.state import state
from app.schemas.escrow import DeliveryVerificationRequest, Dispute, DisputeRequest, EscrowAgreement, EscrowSettlementResult, ReconciliationReport
from app.services.escrow_service import escrow_service

router = APIRouter()


@router.get("/escrows", response_model=list[EscrowAgreement])
def escrows(user: AuthenticatedUser = Depends(get_current_user)) -> list[EscrowAgreement]:
    return escrow_service.list_for(user)


@router.get("/escrows/{escrow_id}", response_model=EscrowAgreement)
def escrow(escrow_id: str, user: AuthenticatedUser = Depends(get_current_user)) -> EscrowAgreement:
    item = escrow_service.get(escrow_id)
    escrow_service.ensure_participant(user, item)
    return item


@router.post("/escrows/{escrow_id}/verify-delivery", response_model=EscrowSettlementResult)
@router.post("/escrows/{escrow_id}/settle", response_model=EscrowSettlementResult)
def settle(escrow_id: str, request: DeliveryVerificationRequest, response: Response, idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"), user: AuthenticatedUser = Depends(get_current_user)) -> EscrowSettlementResult:
    status, payload = idempotency_store.run(key=idempotency_key, user_id=user.user_id, operation=f"settle:{escrow_id}", payload=request.model_dump(mode="json"), handler=lambda: (200, escrow_service.verify_and_settle(user, escrow_id, request, idempotency_key or "")))
    response.status_code = status
    return cast(EscrowSettlementResult, payload)


@router.post("/escrows/{escrow_id}/cancel", response_model=EscrowSettlementResult)
def cancel(escrow_id: str, response: Response, idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"), user: AuthenticatedUser = Depends(get_current_user)) -> EscrowSettlementResult:
    request = DeliveryVerificationRequest(deliveredEnergyKwh=0)
    status, payload = idempotency_store.run(key=idempotency_key, user_id=user.user_id, operation=f"cancel:{escrow_id}", payload={"cancel": True}, handler=lambda: (200, escrow_service.verify_and_settle(user, escrow_id, request, idempotency_key or "")))
    response.status_code = status
    return cast(EscrowSettlementResult, payload)


@router.post("/escrows/{escrow_id}/disputes", response_model=Dispute, status_code=201)
def dispute_for_escrow(escrow_id: str, request: DisputeRequest, user: AuthenticatedUser = Depends(get_current_user)) -> Dispute:
    return escrow_service.raise_dispute(user, escrow_id, request)


@router.get("/default-cases")
def default_cases() -> list[dict]:
    return list(state.default_cases.values())


@router.get("/default-cases/{case_id}")
def default_case(case_id: str) -> dict:
    return state.default_cases.get(case_id, {})


@router.get("/disputes", response_model=list[Dispute])
def disputes(user: AuthenticatedUser = Depends(get_current_user)) -> list[Dispute]:
    items = list(state.disputes.values())
    if user.role == "admin":
        return items
    return [item for item in items if item.raisedBy == user.user_id]


@router.post("/disputes", response_model=Dispute, status_code=201)
def create_dispute(request: DisputeRequest, escrow_id: str, user: AuthenticatedUser = Depends(get_current_user)) -> Dispute:
    return escrow_service.raise_dispute(user, escrow_id, request)


@router.get("/disputes/{dispute_id}", response_model=Dispute)
def dispute(dispute_id: str) -> Dispute:
    return state.disputes[dispute_id]


@router.post("/escrows/reconcile", response_model=ReconciliationReport)
def reconcile(user: AuthenticatedUser = Depends(require_roles("admin"))) -> ReconciliationReport:
    return escrow_service.reconcile()
