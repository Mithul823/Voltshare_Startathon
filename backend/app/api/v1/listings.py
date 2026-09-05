from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user
from app.core.security import AuthenticatedUser
from app.schemas.marketplace import EnergyListing, ListingCreateRequest, ListingPageResponse, ListingUpdateRequest
from app.services.audit_service import audit_service
from app.services.marketplace_service import marketplace_service

router = APIRouter()


@router.get("", response_model=list[EnergyListing])
def listings(
    search: str = "",
    seller_id: str | None = None,
    energy_source: str | None = None,
    minimum_price: float | None = None,
    maximum_price: float | None = None,
    minimum_quantity: float | None = None,
    location: str | None = None,
    verified_only: bool = False,
    available_now: bool = False,
    status: str | None = None,
    sort: str = "priceLow",
    page: int = 1,
    page_size: int = 20,
) -> list[EnergyListing]:
    page_response = marketplace_service.page(
        page=page,
        page_size=page_size,
        search=search,
        active_only=status is None,
        sort=sort,
        seller_id=seller_id,
        energy_source=energy_source,
        minimum_price=minimum_price,
        maximum_price=maximum_price,
        minimum_quantity=minimum_quantity,
        location=location,
        verified_only=verified_only,
        available_now=available_now,
        status=status,
    )
    return page_response.items


@router.get("/page", response_model=ListingPageResponse)
def listing_page(page: int = 1, page_size: int = 20, search: str = "", sort: str = "newest") -> ListingPageResponse:
    return marketplace_service.page(page=page, page_size=page_size, search=search, active_only=True, sort=sort)


@router.get("/mine/all", response_model=list[EnergyListing])
@router.get("/my-listings", response_model=list[EnergyListing])
def my_listings(user: AuthenticatedUser = Depends(get_current_user)) -> list[EnergyListing]:
    return marketplace_service.list(active_only=False, seller_id=user.user_id, sort="newest")


@router.get("/{listing_id}", response_model=EnergyListing)
def listing(listing_id: str) -> EnergyListing:
    return marketplace_service.get(listing_id)


@router.post("", response_model=EnergyListing, status_code=201)
def create_listing(request: ListingCreateRequest, user: AuthenticatedUser = Depends(get_current_user)) -> EnergyListing:
    listing = marketplace_service.create(user, request)
    audit_service.append(actor_user_id=user.user_id, action="listing_created", resource_type="listing", resource_id=listing.id)
    return listing


@router.patch("/{listing_id}", response_model=EnergyListing)
def update_listing(listing_id: str, request: ListingUpdateRequest, user: AuthenticatedUser = Depends(get_current_user)) -> EnergyListing:
    listing = marketplace_service.update(user, listing_id, request)
    audit_service.append(actor_user_id=user.user_id, action="listing_updated", resource_type="listing", resource_id=listing.id)
    return listing


@router.post("/{listing_id}/publish", response_model=EnergyListing)
def publish_listing(listing_id: str, user: AuthenticatedUser = Depends(get_current_user)) -> EnergyListing:
    return marketplace_service.publish(user, listing_id)


@router.post("/{listing_id}/cancel", response_model=EnergyListing)
def cancel_listing(listing_id: str, user: AuthenticatedUser = Depends(get_current_user)) -> EnergyListing:
    return marketplace_service.cancel(user, listing_id)


@router.post("/{listing_id}/suspend", response_model=EnergyListing)
def suspend_listing(listing_id: str, user: AuthenticatedUser = Depends(get_current_user)) -> EnergyListing:
    return marketplace_service.suspend(user, listing_id)


@router.post("/{listing_id}/reactivate", response_model=EnergyListing)
def reactivate_listing(listing_id: str, user: AuthenticatedUser = Depends(get_current_user)) -> EnergyListing:
    return marketplace_service.reactivate(user, listing_id)


@router.post("/{listing_id}/duplicate", response_model=EnergyListing, status_code=201)
def duplicate_listing(listing_id: str, user: AuthenticatedUser = Depends(get_current_user)) -> EnergyListing:
    return marketplace_service.duplicate(user, listing_id)

