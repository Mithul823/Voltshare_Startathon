"""Marketplace service — delegates data access to the active repository.

Business logic (authorisation, validation, event publishing) lives here.
Data access is delegated to ``get_marketplace_repository()`` which returns
either an ``InMemoryMarketplaceRepository`` or a ``SupabaseMarketplaceRepository``
depending on runtime configuration.
"""

from __future__ import annotations

from datetime import datetime, timezone
from math import ceil
from threading import RLock
from typing import Any

from app.core.exceptions import ApiError, ErrorCode
from app.core.security import AuthenticatedUser
from app.repositories.marketplace_repository import get_marketplace_repository
from app.schemas.common import new_id, now_utc
from app.schemas.marketplace import (
    EnergyListing,
    ListingCreateRequest,
    ListingPageResponse,
    ListingStatus,
    ListingUpdateRequest,
    MarketplaceActivity,
    MarketplaceSummaryResponse,
    SellerSummary,
)
from app.schemas.purchase import PurchaseQuote
from app.schemas.realtime import NotificationCategory, NotificationPriority, RealtimeChannel
from app.services.event_publisher import event_publisher


class MarketplaceService:
    """Orchestrates marketplace operations.

    Uses a *repository* for data access.  The repository is resolved lazily
    so that database availability is checked at call time rather than import
    time.
    """

    grid_price_per_kwh = 10.25

    def __init__(self) -> None:
        self._lock = RLock()
        self._repo_fallback: Any = None

    @property
    def _repo(self) -> Any:
        """Lazy-loaded repository instance."""
        if self._repo_fallback is None:
            self._repo_fallback = get_marketplace_repository()
        return self._repo_fallback

    # -- queries -----------------------------------------------------------

    def list(
        self,
        search: str = "",
        active_only: bool = True,
        sort: str = "priceLow",
        seller_id: str | None = None,
        energy_source: str | None = None,
        minimum_price: float | None = None,
        maximum_price: float | None = None,
        minimum_quantity: float | None = None,
        location: str | None = None,
        verified_only: bool = False,
        available_now: bool = False,
        status: str | None = None,
    ) -> list[EnergyListing]:
        return self._repo.list(
            search=search,
            active_only=active_only,
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

    def page(self, *, page: int, page_size: int, **filters: Any) -> ListingPageResponse:
        return self._repo.page(page=page, page_size=page_size, **filters)

    def get(self, listing_id: str) -> EnergyListing:
        return self._repo.get(listing_id)

    def summary(self) -> MarketplaceSummaryResponse:
        return self._repo.summary()

    def activity(self, seller_id: str | None = None, limit: int = 20) -> list[MarketplaceActivity]:
        return self._repo.activity(seller_id=seller_id, limit=limit)

    # -- pricing -----------------------------------------------------------

    def quote(self, listing: EnergyListing, quantity_kwh: float) -> PurchaseQuote:
        if listing.listingStatus != ListingStatus.active:
            raise ApiError(409, ErrorCode.MARKETPLACE_LISTING_NOT_ACTIVE, "Listing is not active.")
        if listing.availabilityEnd <= now_utc():
            raise ApiError(409, ErrorCode.MARKETPLACE_LISTING_EXPIRED, "Listing has expired.")
        if quantity_kwh < listing.minimumPurchaseKwh:
            raise ApiError(422, ErrorCode.MARKETPLACE_INVALID_QUANTITY, "Purchase quantity is below the listing minimum.")
        if listing.maximumPurchaseKwh is not None and quantity_kwh > listing.maximumPurchaseKwh:
            raise ApiError(422, ErrorCode.MARKETPLACE_INVALID_QUANTITY, "Purchase quantity is above the listing maximum.")
        if quantity_kwh > listing.availableEnergyKwh:
            raise ApiError(409, ErrorCode.MARKETPLACE_INSUFFICIENT_QUANTITY, "Listing does not have enough active energy.")
        subtotal = quantity_kwh * listing.pricePerKwh
        platform_fee = subtotal * 0.05
        return PurchaseQuote(
            quantityKwh=quantity_kwh,
            unitPrice=listing.pricePerKwh,
            subtotal=round(subtotal, 2),
            platformFee=round(platform_fee, 2),
            totalAmount=round(subtotal + platform_fee, 2),
            estimatedSavings=max(0, round(quantity_kwh * self.grid_price_per_kwh - subtotal, 2)),
            co2ImpactKg=round(quantity_kwh * 0.7, 3),
        )

    # -- mutations ---------------------------------------------------------

    def create(self, user: AuthenticatedUser, request: ListingCreateRequest) -> EnergyListing:
        if user.role not in {"producer", "prosumer", "admin"}:
            raise ApiError(403, ErrorCode.MARKETPLACE_ROLE_NOT_ALLOWED, "Only producers and prosumers can create listings.")
        listing = EnergyListing(
            id=new_id("LST"),
            sellerId=user.user_id,
            sellerName="My VoltShare Listing",
            sellerRole=user.role if isinstance(user.role, str) else user.role.value,
            sellerInitials="MV",
            sellerRating=4.9,
            reviewCount=0,
            energySource=request.energySource,
            availableEnergyKwh=request.availableEnergyKwh,
            quantityTotalKwh=request.availableEnergyKwh,
            pricePerKwh=request.pricePerKwh,
            location=request.location or "Your neighbourhood",
            batteryBacked=request.batteryReservePercentage >= 25,
            renewableVerified=True,
            availabilityStart=request.availabilityStart,
            availabilityEnd=request.availabilityEnd,
            createdAt=now_utc(),
            updatedAt=now_utc(),
            listingStatus=ListingStatus.active,
            notes=request.notes,
            title=request.title,
            description=request.description,
            minimumPurchaseKwh=request.minimumPurchaseKwh,
            maximumPurchaseKwh=request.maximumPurchaseKwh,
        )
        listing = listing.model_copy(update={"seller": self._seller_for(listing)})
        created = self._repo.create(listing)
        # Event publishing is the service's responsibility
        event_publisher.publish(
            "listing.created",
            channels=[RealtimeChannel.marketplace, RealtimeChannel.listings, RealtimeChannel.admin],
            actor_user_id=user.user_id,
            user_id=user.user_id,
            payload=created.model_dump(mode="json"),
            notification_title="Listing published",
            notification_message="Your energy listing is now visible in the marketplace.",
            notification_category=NotificationCategory.marketplace,
            notification_priority=NotificationPriority.medium,
            action_url=f"/marketplace/{created.id}",
        )
        return created

    def update(self, user: AuthenticatedUser, listing_id: str, request: ListingUpdateRequest) -> EnergyListing:
        listing = self._repo.get(listing_id)
        if user.role != "admin" and listing.sellerId != user.user_id:
            raise ApiError(403, ErrorCode.ACCESS_DENIED, "Only the listing owner can update it.")
        if request.version is not None and request.version != listing.version:
            raise ApiError(409, ErrorCode.MARKETPLACE_LISTING_VERSION_CONFLICT, "Listing version conflict.")
        patch = request.model_dump(exclude_unset=True)
        patch.pop("version", None)
        if request.availableEnergyKwh is not None and request.availableEnergyKwh < listing.quantityReservedKwh:
            raise ApiError(409, ErrorCode.MARKETPLACE_INSUFFICIENT_QUANTITY, "Quantity cannot be below reserved energy.")
        availability_start = request.availabilityStart or listing.availabilityStart
        availability_end = request.availabilityEnd or listing.availabilityEnd
        if availability_end <= availability_start:
            raise ApiError(422, ErrorCode.VALIDATION_FAILED, "Availability end must be after start.")
        patch["updatedAt"] = now_utc()
        patch["version"] = listing.version + 1
        updated = self._repo.update(listing_id, **patch)
        self._repo.append_activity("listing_updated", "Listing price or availability updated", listing_id=listing_id)
        event_publisher.publish(
            "listing.updated",
            channels=[RealtimeChannel.marketplace, RealtimeChannel.listings],
            actor_user_id=user.user_id,
            user_id=updated.sellerId,
            payload=updated.model_dump(mode="json"),
            notification_title="Listing updated",
            notification_message="Your listing changes are live.",
            notification_category=NotificationCategory.marketplace,
            action_url=f"/marketplace/{listing_id}",
        )
        return updated

    def cancel(self, user: AuthenticatedUser, listing_id: str) -> EnergyListing:
        listing = self._repo.get(listing_id)
        if user.role != "admin" and listing.sellerId != user.user_id:
            raise ApiError(403, ErrorCode.ACCESS_DENIED, "Only the listing owner can cancel it.")
        updated = self._repo.update(
            listing_id,
            listingStatus=ListingStatus.cancelled,
            updatedAt=now_utc(),
            version=listing.version + 1,
        )
        self._repo.append_activity("listing_cancelled", "Energy listing cancelled", listing_id=listing_id)
        event_publisher.publish(
            "listing.deleted",
            channels=[RealtimeChannel.marketplace, RealtimeChannel.listings],
            actor_user_id=user.user_id,
            user_id=updated.sellerId,
            payload=updated.model_dump(mode="json"),
            notification_title="Listing removed",
            notification_message="Your energy listing was removed from the marketplace.",
            notification_category=NotificationCategory.marketplace,
            action_url="/my-listings",
        )
        return updated

    def publish(self, user: AuthenticatedUser, listing_id: str) -> EnergyListing:
        return self._moderate(user, listing_id, ListingStatus.active, {"producer", "prosumer", "admin"}, "listing_published")

    def suspend(self, user: AuthenticatedUser, listing_id: str) -> EnergyListing:
        return self._moderate(user, listing_id, ListingStatus.suspended, {"grid_operator", "admin"}, "listing_suspended")

    def reactivate(self, user: AuthenticatedUser, listing_id: str) -> EnergyListing:
        return self._moderate(user, listing_id, ListingStatus.active, {"admin"}, "listing_reactivated")

    def duplicate(self, user: AuthenticatedUser, listing_id: str) -> EnergyListing:
        listing = self._repo.get(listing_id)
        if user.role != "admin" and listing.sellerId != user.user_id:
            raise ApiError(403, ErrorCode.ACCESS_DENIED, "Only the listing owner can duplicate it.")
        copy = listing.model_copy(update={
            "id": new_id("LST"),
            "createdAt": now_utc(),
            "updatedAt": now_utc(),
            "listingStatus": ListingStatus.active,
            "version": 1,
        })
        # create() only persists — events are the service's responsibility
        return self._repo.create(copy)

    def reserve_quantity(self, listing_id: str, quantity_kwh: float) -> EnergyListing:
        return self._repo.reserve_quantity(listing_id, quantity_kwh)

    # -- internals ---------------------------------------------------------

    def _moderate(self, user: AuthenticatedUser, listing_id: str, status: ListingStatus, roles: set[str], action: str) -> EnergyListing:
        listing = self._repo.get(listing_id)
        if user.role not in roles and listing.sellerId != user.user_id:
            raise ApiError(403, ErrorCode.MARKETPLACE_ROLE_NOT_ALLOWED, "Role is not allowed for this listing action.")
        updated = self._repo.update(
            listing_id,
            listingStatus=status,
            updatedAt=now_utc(),
            version=listing.version + 1,
        )
        self._repo.append_activity(action, action.replace("_", " ").title(), listing_id=listing_id)
        return updated

    @staticmethod
    def _seller_for(listing: EnergyListing) -> SellerSummary:
        return SellerSummary(
            id=listing.sellerId,
            displayName=listing.sellerName,
            role=listing.sellerRole,
            rating=listing.sellerRating,
            completedSales=listing.reviewCount,
            verifiedStatus=listing.renewableVerified,
            energySourceSummary=listing.energySource.value,
            locationName=listing.location,
        )


marketplace_service = MarketplaceService()
