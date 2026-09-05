from typing import cast

from fastapi import APIRouter, Depends, Header, Response

from app.api.dependencies import get_current_user
from app.core.idempotency import idempotency_store
from app.core.security import AuthenticatedUser
from app.schemas.purchase import EnergyPurchase, PurchaseCreateRequest, PurchaseCreateResponse
from app.services.purchase_service import purchase_service

router = APIRouter()


@router.post("", response_model=PurchaseCreateResponse, status_code=201)
def create_purchase(request: PurchaseCreateRequest, response: Response, idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"), user: AuthenticatedUser = Depends(get_current_user)) -> PurchaseCreateResponse:
    status, payload = idempotency_store.run(key=idempotency_key, user_id=user.user_id, operation="create_purchase", payload=request.model_dump(mode="json"), handler=lambda: (201, purchase_service.create(user, request, idempotency_key)))
    response.status_code = status
    return cast(PurchaseCreateResponse, payload)


@router.get("", response_model=list[EnergyPurchase])
def purchases(user: AuthenticatedUser = Depends(get_current_user)) -> list[EnergyPurchase]:
    return purchase_service.list_for(user)


@router.get("/{purchase_id}", response_model=EnergyPurchase)
def purchase(purchase_id: str, user: AuthenticatedUser = Depends(get_current_user)) -> EnergyPurchase:
    return purchase_service.get(user, purchase_id)
