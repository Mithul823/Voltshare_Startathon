from typing import cast

from fastapi import APIRouter, Depends, Header, Response

from app.api.dependencies import get_current_user
from app.core.idempotency import idempotency_store
from app.core.security import AuthenticatedUser
from app.repositories.financial_store import financial_state as state
from app.schemas.common import UserRole
from app.schemas.wallet import Refund, RefundRequest, WalletTransaction
from app.services.refund_service import refund_service

router = APIRouter()


@router.post("", response_model=WalletTransaction)
def create_refund(
    request: RefundRequest,
    response: Response,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    user: AuthenticatedUser = Depends(get_current_user),
) -> WalletTransaction:
    status, payload = idempotency_store.run(
        key=idempotency_key,
        user_id=user.user_id,
        operation="refund",
        payload=request.model_dump(mode="json"),
        handler=lambda: (200, refund_service.create(user, request)),
    )
    response.status_code = status
    return cast(WalletTransaction, payload)


@router.get("", response_model=list[Refund])
def refunds(user: AuthenticatedUser = Depends(get_current_user)) -> list[Refund]:
    items = list(state.refunds.values())
    if user.role == UserRole.admin:
        return items
    return [item for item in items if item.userId == user.user_id]
