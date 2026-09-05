from typing import cast

from fastapi import APIRouter, Depends, Header, Request, Response

from app.api.dependencies import get_current_user
from app.core.idempotency import idempotency_store
from app.core.security import AuthenticatedUser
from app.schemas.wallet import RefundRequest, Wallet, WalletBalance, WalletMutationRequest, WalletTransaction
from app.services.audit_service import audit_service
from app.services.deposit_service import deposit_service
from app.services.wallet_service import wallet_service
from app.services.withdrawal_service import withdrawal_service

router = APIRouter()


@router.get("", response_model=Wallet)
def wallet(user: AuthenticatedUser = Depends(get_current_user)) -> Wallet:
    return wallet_service.wallet(user.user_id)


@router.get("/balance", response_model=WalletBalance)
def balance(user: AuthenticatedUser = Depends(get_current_user)) -> WalletBalance:
    return wallet_service.balance(user.user_id)


@router.get("/transactions", response_model=list[WalletTransaction])
def transactions(user: AuthenticatedUser = Depends(get_current_user)) -> list[WalletTransaction]:
    return wallet_service.transactions(user.user_id)


@router.get("/transactions/{transaction_id}", response_model=WalletTransaction)
def transaction(transaction_id: str, user: AuthenticatedUser = Depends(get_current_user)) -> WalletTransaction:
    return wallet_service.transaction(user.user_id, transaction_id)


@router.post("/demo-top-up", response_model=WalletTransaction)
@router.post("/deposit", response_model=WalletTransaction)
def top_up(request: WalletMutationRequest, response: Response, request_context: Request, idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"), user: AuthenticatedUser = Depends(get_current_user)) -> WalletTransaction:
    status, payload = idempotency_store.run(key=idempotency_key, user_id=user.user_id, operation="wallet_deposit", payload=request.model_dump(mode="json"), handler=lambda: (200, deposit_service.create(user, request)))
    response.status_code = status
    audit_service.append(actor_user_id=user.user_id, action="wallet_deposit", resource_type="wallet", resource_id=user.user_id, idempotency_key=idempotency_key)
    wallet_service.audit(user, endpoint=str(request_context.url.path), transaction_id=payload.id if isinstance(payload, WalletTransaction) else None, wallet_id=wallet_service.wallet(user.user_id).walletId, ip_address=request_context.client.host if request_context.client else None)
    return cast(WalletTransaction, payload)


@router.post("/demo-withdraw", response_model=WalletTransaction)
@router.post("/withdraw", response_model=WalletTransaction)
def withdraw(request: WalletMutationRequest, response: Response, request_context: Request, idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"), user: AuthenticatedUser = Depends(get_current_user)) -> WalletTransaction:
    status, payload = idempotency_store.run(key=idempotency_key, user_id=user.user_id, operation="wallet_withdraw", payload=request.model_dump(mode="json"), handler=lambda: (200, withdrawal_service.create(user, request)))
    response.status_code = status
    wallet_service.audit(user, endpoint=str(request_context.url.path), transaction_id=payload.id if isinstance(payload, WalletTransaction) else None, wallet_id=wallet_service.wallet(user.user_id).walletId, ip_address=request_context.client.host if request_context.client else None)
    return cast(WalletTransaction, payload)


@router.post("/refunds", response_model=WalletTransaction)
def refund(request: RefundRequest, response: Response, idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"), user: AuthenticatedUser = Depends(get_current_user)) -> WalletTransaction:
    status, payload = idempotency_store.run(key=idempotency_key, user_id=user.user_id, operation="wallet_refund", payload=request.model_dump(mode="json"), handler=lambda: (200, wallet_service.refund(user, request)))
    response.status_code = status
    return cast(WalletTransaction, payload)
