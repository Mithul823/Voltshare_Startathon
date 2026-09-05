"""Marketplace repository — in-memory (demo) and Supabase (live) implementations.

Use `get_marketplace_repository()` to obtain the active repository based on
configuration.  Live mode requires a properly initialised Supabase admin client.
When Supabase is not configured (missing URL or service-role key) the in-memory
repository is returned even in live mode so the server can still start.
"""

from __future__ import annotations

from datetime import datetime, timezone
from math import ceil
from threading import RLock
from typing import Any, Protocol

from app.core.config import Settings, get_settings
from app.core.exceptions import ApiError, ErrorCode
from app.db.supabase import get_supabase_admin_client
from app.schemas.common import now_utc
from app.schemas.marketplace import (
    EnergyListing,
    EnergySource,
    ListingPageResponse,
    ListingStatus,
    MarketplaceActivity,
    MarketplaceSummaryResponse,
)
from app.services.event_publisher import event_publisher
from app.schemas.realtime import NotificationCategory, NotificationPriority, RealtimeChannel


# ---------------------------------------------------------------------------
# Protocol / interface
# ---------------------------------------------------------------------------

class MarketplaceRepository(Protocol):
    """Interface for marketplace data access."""

    def list(
        self,
        *,
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
    ) -> list[EnergyListing]: ...

    def page(
        self,
        page: int = 1,
        page_size: int = 20,
        **filters: Any,
    ) -> ListingPageResponse: ...

    def get(self, listing_id: str) -> EnergyListing: ...

    def get_for_update(self, listing_id: str) -> EnergyListing: ...

    def create(self, listing: EnergyListing) -> EnergyListing: ...

    def update(self, listing_id: str, **patch: Any) -> EnergyListing: ...

    def summary(self) -> MarketplaceSummaryResponse: ...

    def activity(self, seller_id: str | None = None, limit: int = 20) -> list[MarketplaceActivity]: ...

    def reserve_quantity(self, listing_id: str, quantity_kwh: float) -> EnergyListing: ...

    def append_activity(self, event_type: str, message: str, listing_id: str | None = None, purchase_id: str | None = None) -> None: ...


# ---------------------------------------------------------------------------
# In-memory repository (demo / fallback)
# ---------------------------------------------------------------------------

class InMemoryMarketplaceRepository:
    """Deterministic in-memory repository for mock/demo mode.

    All data is transient — lost on server restart.
    Operates on the global ``state.listings`` dict.
    """

    def __init__(self) -> None:
        from app.repositories.state import state as app_state
        self._state = app_state
        self._lock = RLock()
        self._activity: list[MarketplaceActivity] = []

    # -- helpers -----------------------------------------------------------

    @staticmethod
    def _new_id(prefix: str = "LST") -> str:
        from app.schemas.common import new_id
        return new_id(prefix)

    @staticmethod
    def _now() -> datetime:
        return now_utc()

    @staticmethod
    def _sort(result: list[EnergyListing], sort: str) -> None:
        if sort in {"priceHigh", "price_high_to_low"}:
            result.sort(key=lambda item: item.pricePerKwh, reverse=True)
        elif sort == "distance":
            result.sort(key=lambda item: item.distanceKm)
        elif sort in {"rating", "rating_high_to_low"}:
            result.sort(key=lambda item: item.sellerRating, reverse=True)
        elif sort in {"energyAvailable", "quantity_high_to_low"}:
            result.sort(key=lambda item: item.availableEnergyKwh, reverse=True)
        elif sort == "newest":
            result.sort(key=lambda item: item.createdAt, reverse=True)
        elif sort == "ending_soon":
            result.sort(key=lambda item: item.availabilityEnd)
        else:
            result.sort(key=lambda item: item.pricePerKwh)

    # -- queries -----------------------------------------------------------

    def list(
        self,
        *,
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
        result = list(self._state.listings.values())
        if active_only:
            result = [item for item in result if item.listingStatus == ListingStatus.active]
        elif status:
            result = [item for item in result if item.listingStatus.value == status]
        if seller_id:
            result = [item for item in result if item.sellerId == seller_id]
        if energy_source:
            result = [item for item in result if item.energySource.value == energy_source]
        if minimum_price is not None:
            result = [item for item in result if item.pricePerKwh >= minimum_price]
        if maximum_price is not None:
            result = [item for item in result if item.pricePerKwh <= maximum_price]
        if minimum_quantity is not None:
            result = [item for item in result if item.availableEnergyKwh >= minimum_quantity]
        if location:
            lowered = location.lower()
            result = [item for item in result if lowered in item.location.lower()]
        if verified_only:
            result = [item for item in result if item.renewableVerified]
        if available_now:
            now = self._now()
            result = [item for item in result if item.availabilityStart <= now <= item.availabilityEnd]
        if search:
            lowered = search.strip().lower()[:80]
            result = [
                item
                for item in result
                if lowered in item.sellerName.lower()
                or lowered in item.location.lower()
                or lowered in item.energySource.value.lower()
                or lowered in (item.title or "").lower()
                or lowered in (item.notes or "").lower()
            ]
        self._sort(result, sort)
        return result

    def page(
        self,
        page: int = 1,
        page_size: int = 20,
        **filters: Any,
    ) -> ListingPageResponse:
        listings = self.list(**filters)
        page = max(1, page)
        page_size = min(max(1, page_size), 100)
        start = (page - 1) * page_size
        total_items = len(listings)
        total_pages = ceil(total_items / page_size) if total_items else 0
        return ListingPageResponse(
            items=listings[start: start + page_size],
            page=page,
            pageSize=page_size,
            totalItems=total_items,
            totalPages=total_pages,
            hasNext=page < total_pages,
            hasPrevious=page > 1,
        )

    def get(self, listing_id: str) -> EnergyListing:
        listing = self._state.listings.get(listing_id)
        if not listing:
            raise ApiError(404, ErrorCode.MARKETPLACE_LISTING_NOT_FOUND, "Listing not found.")
        return listing

    def get_for_update(self, listing_id: str) -> EnergyListing:
        return self.get(listing_id)

    def create(self, listing: EnergyListing) -> EnergyListing:
        self._state.listings[listing.id] = listing
        self.append_activity("listing_created", "New renewable energy listing created", listing_id=listing.id)
        return listing

    def update(self, listing_id: str, **patch: Any) -> EnergyListing:
        listing = self.get(listing_id)
        patch["updatedAt"] = self._now()
        updated = listing.model_copy(update=patch)
        self._state.listings[listing_id] = updated
        return updated

    def summary(self) -> MarketplaceSummaryResponse:
        active = self.list(active_only=True)
        total_energy = sum(item.availableEnergyKwh for item in active)
        avg_price = sum(item.pricePerKwh for item in active) / len(active) if active else 0
        return MarketplaceSummaryResponse(
            activeListings=len(active),
            totalAvailableKwh=round(total_energy, 3),
            averagePricePerKwh=round(avg_price, 2),
            featuredListings=len([item for item in active if item.isFeatured]),
        )

    def activity(self, seller_id: str | None = None, limit: int = 20) -> list[MarketplaceActivity]:
        events = self._activity
        if seller_id:
            events = [
                ev for ev in events
                if ev.listingId and self._state.listings.get(ev.listingId)
                and self._state.listings[ev.listingId].sellerId == seller_id
            ]
        return events[:limit]

    def reserve_quantity(self, listing_id: str, quantity_kwh: float) -> EnergyListing:
        with self._lock:
            listing = self.get(listing_id)
            remaining = round(listing.availableEnergyKwh - quantity_kwh, 6)
            reserved = round(listing.quantityReservedKwh + quantity_kwh, 6)
            status = ListingStatus.sold if remaining <= 0 else ListingStatus.active
            updated = listing.model_copy(update={
                "availableEnergyKwh": max(remaining, 0),
                "quantityReservedKwh": reserved,
                "listingStatus": status,
                "updatedAt": self._now(),
                "version": listing.version + 1,
            })
            self._state.listings[listing_id] = updated
            if status == ListingStatus.sold:
                self.append_activity("listing_sold_out", "Listing sold out", listing_id=listing_id)
                event_publisher.publish(
                    "listing.sold",
                    channels=[RealtimeChannel.marketplace, RealtimeChannel.listings, RealtimeChannel.sales],
                    user_id=updated.sellerId,
                    payload=updated.model_dump(mode="json"),
                    notification_title="Listing sold out",
                    notification_message="One of your energy listings has sold out.",
                    notification_category=NotificationCategory.sale,
                    notification_priority=NotificationPriority.high,
                    action_url="/sales",
                )
            else:
                event_publisher.publish(
                    "listing.updated",
                    channels=[RealtimeChannel.marketplace, RealtimeChannel.listings],
                    user_id=updated.sellerId,
                    payload=updated.model_dump(mode="json"),
                )
            return updated

    def append_activity(self, event_type: str, message: str, listing_id: str | None = None, purchase_id: str | None = None) -> None:
        from app.schemas.common import new_id
        self._activity.insert(
            0,
            MarketplaceActivity(
                id=new_id("ACT"),
                type=event_type,
                message=message,
                createdAt=datetime.now(timezone.utc),
                listingId=listing_id,
                purchaseId=purchase_id,
            ),
        )


# ---------------------------------------------------------------------------
# Supabase-backed repository (live mode)
# ---------------------------------------------------------------------------

# Column mapping from DB snake_case to Pydantic camelCase
_COLUMN_MAP: dict[str, str] = {
    "id": "id",
    "seller_id": "sellerId",
    "title": "title",
    "description": "description",
    "energy_source": "energySource",
    "quantity_total_kwh": "quantityTotalKwh",
    "quantity_available_kwh": "availableEnergyKwh",
    "quantity_reserved_kwh": "quantityReservedKwh",
    "price_per_kwh": "pricePerKwh",
    "currency": "currency",
    "minimum_purchase_kwh": "minimumPurchaseKwh",
    "maximum_purchase_kwh": "maximumPurchaseKwh",
    "location_name": "location",
    "latitude": None,  # not mapped
    "longitude": None,  # not mapped
    "available_from": "availabilityStart",
    "available_until": "availabilityEnd",
    "status": "listingStatus",
    "is_featured": "isFeatured",
    "is_verified": "renewableVerified",
    "created_at": "createdAt",
    "updated_at": "updatedAt",
    "cancelled_at": None,  # not mapped
    "suspended_at": None,  # not mapped
    "version": "version",
}

_REVERSE_MAP: dict[str, str] = {v: k for k, v in _COLUMN_MAP.items() if v is not None}


def _safe_energy_source(val: Any) -> EnergySource:
    if not val:
        return EnergySource.solar
    val_str = str(val).strip()
    try:
        return EnergySource(val_str)
    except Exception:
        try:
            return EnergySource(val_str.lower())
        except Exception:
            return EnergySource.solar


def _safe_listing_status(val: Any) -> ListingStatus:
    if not val:
        return ListingStatus.active
    val_str = str(val).strip()
    try:
        return ListingStatus(val_str)
    except Exception:
        try:
            return ListingStatus(val_str.lower())
        except Exception:
            return ListingStatus.active


def _row_to_listing(row: dict[str, Any]) -> EnergyListing:
    """Convert a Supabase result row to an EnergyListing Pydantic model."""
    return EnergyListing(
        id=str(row["id"]),
        sellerId=str(row.get("seller_id", "")),
        sellerName=str(row.get("seller_name", "") or row.get("title", "Energy Seller")),
        sellerRole=str(row.get("seller_role", "producer")),
        sellerInitials=str(row.get("seller_initials", "ES")),
        sellerRating=float(row.get("seller_rating", 4.8)),
        reviewCount=int(row.get("review_count", 0)),
        energySource=_safe_energy_source(row.get("energy_source")),
        availableEnergyKwh=float(row.get("quantity_available_kwh", 0)),
        pricePerKwh=float(row.get("price_per_kwh", 0)),
        distanceKm=float(row.get("distance_km", 0)),
        location=str(row.get("location_name", "")),
        batteryBacked=bool(row.get("battery_backed", False)),
        renewableVerified=bool(row.get("is_verified", False)),
        availabilityStart=_parse_dt(row.get("available_from")),
        availabilityEnd=_parse_dt(row.get("available_until")),
        createdAt=_parse_dt(row.get("created_at")),
        updatedAt=_parse_dt(row.get("updated_at")),
        listingStatus=_safe_listing_status(row.get("status")),
        notes=row.get("notes"),
        title=row.get("title"),
        description=row.get("description"),
        quantityTotalKwh=_float_or_none(row.get("quantity_total_kwh")),
        quantityReservedKwh=float(row.get("quantity_reserved_kwh", 0)),
        currency=str(row.get("currency", "INR")),
        minimumPurchaseKwh=float(row.get("minimum_purchase_kwh", 0.5)),
        maximumPurchaseKwh=_float_or_none(row.get("maximum_purchase_kwh")),
        isFeatured=bool(row.get("is_featured", False)),
        version=int(row.get("version", 1)),
    )


def _listing_to_row(listing: EnergyListing) -> dict[str, Any]:
    """Convert an EnergyListing model to a DB row (snake_case keys)."""
    return {
        "seller_id": listing.sellerId,
        "title": listing.title or "Renewable energy listing",
        "description": listing.description,
        "energy_source": listing.energySource.value,
        "quantity_total_kwh": listing.quantityTotalKwh or listing.availableEnergyKwh,
        "quantity_available_kwh": listing.availableEnergyKwh,
        "quantity_reserved_kwh": listing.quantityReservedKwh,
        "price_per_kwh": listing.pricePerKwh,
        "currency": listing.currency,
        "minimum_purchase_kwh": listing.minimumPurchaseKwh,
        "maximum_purchase_kwh": listing.maximumPurchaseKwh,
        "location_name": listing.location,
        "available_from": listing.availabilityStart.isoformat(),
        "available_until": listing.availabilityEnd.isoformat(),
        "status": listing.listingStatus.value,
        "is_featured": listing.isFeatured,
        "is_verified": listing.renewableVerified,
    }


def _parse_dt(value: Any) -> datetime:
    if isinstance(value, datetime):
        return value
    if isinstance(value, str):
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    return now_utc()


def _float_or_none(value: Any) -> float | None:
    if value is None:
        return None
    return float(value)


class SupabaseMarketplaceRepository:
    """Supabase PostgreSQL-backed marketplace repository.

    Uses the service-role (admin) client so RLS is bypassed for backend
    operations.  All timestamps are serialised as ISO-8601 strings.
    """

    def __init__(self, settings: Settings | None = None) -> None:
        current = settings or get_settings()
        self._client = get_supabase_admin_client(current)
        self._table = "energy_listings"
        self._lock = RLock()
        self._activity: list[MarketplaceActivity] = []

    def _require_client(self) -> None:
        if self._client is None:
            raise ApiError(503, ErrorCode.DATABASE_ERROR, "Supabase is not configured for live marketplace.")

    # -- queries -----------------------------------------------------------

    def _build_select(self) -> Any:
        self._require_client()
        return self._client.table(self._table).select("*")

    def list(
        self,
        *,
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
        self._require_client()
        query = self._build_select()
        if active_only:
            query = query.eq("status", "active")
        elif status:
            query = query.eq("status", status)
        if seller_id:
            query = query.eq("seller_id", seller_id)
        if energy_source:
            query = query.eq("energy_source", energy_source)
        if minimum_price is not None:
            query = query.gte("price_per_kwh", minimum_price)
        if maximum_price is not None:
            query = query.lte("price_per_kwh", maximum_price)
        if minimum_quantity is not None:
            query = query.gte("quantity_available_kwh", minimum_quantity)
        if verified_only:
            query = query.eq("is_verified", True)
        if available_now:
            now_str = now_utc().isoformat()
            query = query.lte("available_from", now_str).gte("available_until", now_str)
        if location:
            query = query.ilike("location_name", f"%{location}%")
        if search:
            lowered = search.strip().lower()[:80]
            query = query.or_(
                f"title.ilike.%{lowered}%,"
                f"location_name.ilike.%{lowered}%,"
                f"energy_source.ilike.%{lowered}%"
            )

        # Sort
        sort_col = "price_per_kwh"
        sort_order = "asc"
        if sort in {"priceHigh", "price_high_to_low"}:
            sort_col, sort_order = "price_per_kwh", "desc"
        elif sort == "distance":
            sort_col, sort_order = "distance_km", "asc"
        elif sort in {"rating", "rating_high_to_low"}:
            sort_col, sort_order = "seller_rating", "desc"
        elif sort in {"energyAvailable", "quantity_high_to_low"}:
            sort_col, sort_order = "quantity_available_kwh", "desc"
        elif sort == "newest":
            sort_col, sort_order = "created_at", "desc"
        elif sort == "ending_soon":
            sort_col, sort_order = "available_until", "asc"

        query = query.order(sort_col, desc=(sort_order == "desc"))
        query = query.limit(100)  # bounded
        result = query.execute()
        return [_row_to_listing(row) for row in (result.data or [])]

    def page(
        self,
        page: int = 1,
        page_size: int = 20,
        **filters: Any,
    ) -> ListingPageResponse:
        self._require_client()
        page = max(1, page)
        page_size = min(max(1, page_size), 100)
        offset = (page - 1) * page_size

        # Build a Supabase query with count and pagination in a single call
        query = self._client.table(self._table).select("*", count="exact")
        if filters.get("active_only", True):
            query = query.eq("status", "active")

        # Apply simple server-side filters
        search = filters.get("search", "")
        seller_id = filters.get("seller_id")
        energy_source = filters.get("energy_source")
        maximum_price = filters.get("maximum_price")
        minimum_quantity = filters.get("minimum_quantity")

        if seller_id:
            query = query.eq("seller_id", seller_id)
        if energy_source:
            query = query.eq("energy_source", energy_source)
        if maximum_price is not None:
            query = query.lte("price_per_kwh", maximum_price)
        if minimum_quantity is not None:
            query = query.gte("quantity_available_kwh", minimum_quantity)

        # Sort
        sort = filters.get("sort", "priceLow")
        sort_col = "price_per_kwh"
        sort_desc = False
        if sort in {"priceHigh", "price_high_to_low"}:
            sort_col, sort_desc = "price_per_kwh", True
        elif sort == "distance":
            sort_col = "distance_km"
        elif sort in {"rating", "rating_high_to_low"}:
            sort_col, sort_desc = "seller_rating", True
        elif sort in {"energyAvailable", "quantity_high_to_low"}:
            sort_col, sort_desc = "quantity_available_kwh", True
        elif sort == "newest":
            sort_col, sort_desc = "created_at", True
        elif sort == "ending_soon":
            sort_col = "available_until"

        query = query.order(sort_col, desc=sort_desc)
        query = query.range(offset, offset + page_size - 1)

        result = query.execute()
        items = [_row_to_listing(row) for row in (result.data or [])]
        total_items = result.count if result.count is not None else len(items)
        total_pages = ceil(total_items / page_size) if total_items else 0

        return ListingPageResponse(
            items=items,
            page=page,
            pageSize=page_size,
            totalItems=total_items,
            totalPages=total_pages,
            hasNext=page < total_pages,
            hasPrevious=page > 1,
        )

    def get(self, listing_id: str) -> EnergyListing:
        from app.repositories.financial_store import connection
        from psycopg.rows import dict_row
        with connection() as conn:
            row = conn.cursor(row_factory=dict_row).execute("SELECT * FROM energy_listings WHERE id=%s FOR UPDATE", (listing_id,)).fetchone()
            if row is None:
                raise ApiError(404, ErrorCode.MARKETPLACE_LISTING_NOT_FOUND, "Listing not found.")
            return _row_to_listing(row)

    def get_for_update(self, listing_id: str) -> EnergyListing:
        return self.get(listing_id)

    def create(self, listing: EnergyListing) -> EnergyListing:
        from app.repositories.financial_store import connection
        from psycopg import sql
        from psycopg.rows import dict_row
        row = _listing_to_row(listing)
        from uuid import uuid4
        row["id"] = str(uuid4())
        with connection() as conn:
            query = sql.SQL("INSERT INTO energy_listings ({}) VALUES ({}) RETURNING *").format(sql.SQL(",").join(map(sql.Identifier, row)), sql.SQL(",").join(sql.Placeholder() for _ in row))
            saved = conn.cursor(row_factory=dict_row).execute(query, list(row.values())).fetchone()
            return _row_to_listing(saved)

    def update(self, listing_id: str, **patch: Any) -> EnergyListing:
        from app.repositories.financial_store import connection
        from psycopg import sql
        from psycopg.rows import dict_row
        values = {_REVERSE_MAP[k]: getattr(v, "value", v) for k, v in patch.items() if k in _REVERSE_MAP}
        if values.get("status") == "sold":
            values["status"] = "sold_out"
        values["updated_at"] = now_utc()
        with connection() as conn:
            query = sql.SQL("UPDATE energy_listings SET {} WHERE id=%s RETURNING *").format(sql.SQL(",").join(sql.SQL("{}=%s").format(sql.Identifier(k)) for k in values))
            row = conn.cursor(row_factory=dict_row).execute(query, [*values.values(), listing_id]).fetchone()
            if row is None:
                raise ApiError(404, ErrorCode.MARKETPLACE_LISTING_NOT_FOUND, "Listing not found.")
            return _row_to_listing(row)

    def summary(self) -> MarketplaceSummaryResponse:
        listings = self.list(active_only=True)
        total_energy = sum(item.availableEnergyKwh for item in listings)
        avg_price = sum(item.pricePerKwh for item in listings) / len(listings) if listings else 0
        return MarketplaceSummaryResponse(
            activeListings=len(listings),
            totalAvailableKwh=round(total_energy, 3),
            averagePricePerKwh=round(avg_price, 2),
            featuredListings=len([item for item in listings if item.isFeatured]),
        )

    def activity(self, seller_id: str | None = None, limit: int = 20) -> list[MarketplaceActivity]:
        events = self._activity
        if seller_id:
            events = [ev for ev in events if ev.listingId]
        return events[:limit]

    def reserve_quantity(self, listing_id: str, quantity_kwh: float) -> EnergyListing:
        with self._lock:
            listing = self.get(listing_id)
            remaining = round(listing.availableEnergyKwh - quantity_kwh, 6)
            reserved = round(listing.quantityReservedKwh + quantity_kwh, 6)
            new_status = ListingStatus.sold if remaining <= 0 else ListingStatus.active
            patch = {
                "availableEnergyKwh": max(remaining, 0),
                "quantityReservedKwh": reserved,
                "listingStatus": new_status,
                "version": listing.version + 1,
            }
            updated = self.update(listing_id, **patch)
            if new_status == ListingStatus.sold:
                self.append_activity("listing_sold_out", "Listing sold out", listing_id=listing_id)
                event_publisher.publish(
                    "listing.sold",
                    channels=[RealtimeChannel.marketplace, RealtimeChannel.listings, RealtimeChannel.sales],
                    user_id=updated.sellerId,
                    payload=updated.model_dump(mode="json"),
                    notification_title="Listing sold out",
                    notification_message="One of your energy listings has sold out.",
                    notification_category=NotificationCategory.sale,
                    notification_priority=NotificationPriority.high,
                    action_url="/sales",
                )
            else:
                event_publisher.publish(
                    "listing.updated",
                    channels=[RealtimeChannel.marketplace, RealtimeChannel.listings],
                    user_id=updated.sellerId,
                    payload=updated.model_dump(mode="json"),
                )
            return updated

    def append_activity(self, event_type: str, message: str, listing_id: str | None = None, purchase_id: str | None = None) -> None:
        from app.schemas.common import new_id
        self._activity.insert(
            0,
            MarketplaceActivity(
                id=new_id("ACT"),
                type=event_type,
                message=message,
                createdAt=datetime.now(timezone.utc),
                listingId=listing_id,
                purchaseId=purchase_id,
            ),
        )


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

def get_marketplace_repository(settings: Settings | None = None) -> MarketplaceRepository:
    """Return the active marketplace repository based on configuration.

    *Live mode (Supabase configured) → ``SupabaseMarketplaceRepository``*
    *Otherwise → ``InMemoryMarketplaceRepository``*
    """
    current = settings or get_settings()
    if current.financial_database_url or current.is_production or (current.supabase_url and current.supabase_service_role_key):
        return SupabaseMarketplaceRepository(current)
    return InMemoryMarketplaceRepository()
