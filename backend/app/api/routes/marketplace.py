from typing import cast

from fastapi import APIRouter, Depends, Header, Response

from app.api.dependencies import get_current_user
from app.core.idempotency import idempotency_store
from app.core.security import AuthenticatedUser
from app.schemas.marketplace import EnergyListing, ListingCreateRequest
from app.services.audit_service import audit_service
from app.services.marketplace_service import marketplace_service

router = APIRouter()


@router.get("", response_model=list[EnergyListing])
def listings(search: str = "", sort: str = "priceLow", active: bool = True) -> list[EnergyListing]:
    return marketplace_service.list(search=search, sort=sort, active_only=active)


@router.get("/my-listings", response_model=list[EnergyListing])
@router.get("/mine/all", response_model=list[EnergyListing])
def my_listings(user: AuthenticatedUser = Depends(get_current_user)) -> list[EnergyListing]:
    return [item for item in marketplace_service.list(active_only=False) if item.sellerId == user.user_id]


@router.get("/{listing_id}", response_model=EnergyListing)
def listing(listing_id: str) -> EnergyListing:
    return marketplace_service.get(listing_id)


@router.post("", response_model=EnergyListing, status_code=201)
def create_listing(request: ListingCreateRequest, response: Response, idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"), user: AuthenticatedUser = Depends(get_current_user)) -> EnergyListing:
    status, payload = idempotency_store.run(key=idempotency_key, user_id=user.user_id, operation="create_listing", payload=request.model_dump(mode="json"), handler=lambda: (201, marketplace_service.create(user, request)))
    listing = cast(EnergyListing, payload)
    response.status_code = status
    audit_service.append(actor_user_id=user.user_id, action="listing_created", resource_type="listing", resource_id=listing.id, idempotency_key=idempotency_key)
    return listing


@router.post("/{listing_id}/cancel", response_model=EnergyListing)
def cancel_listing(listing_id: str, user: AuthenticatedUser = Depends(get_current_user)) -> EnergyListing:
    listing = marketplace_service.cancel(user, listing_id)
    audit_service.append(actor_user_id=user.user_id, action="listing_cancelled", resource_type="listing", resource_id=listing_id)
    return listing


@router.post("/{listing_id}/duplicate", response_model=EnergyListing, status_code=201)
def duplicate_listing(listing_id: str, user: AuthenticatedUser = Depends(get_current_user)) -> EnergyListing:
    return marketplace_service.duplicate(user, listing_id)
