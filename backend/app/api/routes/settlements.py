from typing import cast

from fastapi import APIRouter, Depends, Header, Response

from app.api.dependencies import get_current_user
from app.core.idempotency import idempotency_store
from app.core.security import AuthenticatedUser
from app.schemas.escrow import EscrowSettlementResult
from app.schemas.wallet import Settlement
from app.services.settlement_service import settlement_service

router = APIRouter()


@router.post("/process", response_model=EscrowSettlementResult)
def process_settlement(
    escrowId: str,
    response: Response,
    deliveredEnergyKwh: float = 0,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    user: AuthenticatedUser = Depends(get_current_user),
) -> EscrowSettlementResult:
    status, payload = idempotency_store.run(
        key=idempotency_key,
        user_id=user.user_id,
        operation=f"settlement:{escrowId}",
        payload={"escrowId": escrowId, "deliveredEnergyKwh": deliveredEnergyKwh},
        handler=lambda: (200, settlement_service.process(user, escrowId, deliveredEnergyKwh, idempotency_key or "")),
    )
    response.status_code = status
    return cast(EscrowSettlementResult, payload)


@router.get("", response_model=list[Settlement])
def settlements(user: AuthenticatedUser = Depends(get_current_user)) -> list[Settlement]:
    return settlement_service.list_for(user)
