"""Mock-mode marketplace endpoints — no authentication required.

Designed for USE_MOCK_BACKEND=true in the Flutter app. Producers POST
listings here; the data is persisted to ``data/listings.json`` via
:class:`JsonFileMarketplaceRepository`. Consumers GET the same endpoint
to browse available energy.
"""

from __future__ import annotations

from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter
from pydantic import Field

from app.repositories.json_file_marketplace_repository import JsonFileMarketplaceRepository
from app.schemas.common import ApiModel
from app.schemas.marketplace import EnergyListing, EnergySource, ListingStatus

router = APIRouter()

# Shared instance — same JSON file as the main app uses when Supabase is off
_repo = JsonFileMarketplaceRepository()


# ═══════════════════════════════════════════════════════════════════════
#  Request body model
# ═══════════════════════════════════════════════════════════════════════


class MockCreateBody(ApiModel):
    """Simplified body for creating a listing via the mock endpoint.

    Fields are a subset of the real ``ListingCreateRequest`` — just enough
    for the Flutter mock flow.
    """

    sellerId: str = ""
    sellerName: str | None = None
    sellerRole: str | None = None
    sellerRating: float | None = None
    reviewCount: int | None = None
    energySource: str | None = None
    availableEnergyKwh: float
    pricePerKwh: float
    location: str | None = None
    distanceKm: float | None = None
    batteryBacked: bool | None = None
    batteryReservePercentage: int = Field(default=0, ge=0, le=100)
    renewableVerified: bool | None = None
    availabilityStart: str | None = None
    availabilityEnd: str | None = None
    notes: str | None = None
    title: str | None = None
    minimumPurchaseKwh: float | None = None


# ═══════════════════════════════════════════════════════════════════════
#  Endpoints
# ═══════════════════════════════════════════════════════════════════════


@router.get("", response_model=list[EnergyListing])
def mock_listings() -> list[EnergyListing]:
    """Return all active listings (no auth)."""
    return _repo.list(active_only=True)


@router.get("/all", response_model=list[EnergyListing])
def mock_all_listings() -> list[EnergyListing]:
    """Return every listing regardless of status (no auth)."""
    return _repo.list(active_only=False)


@router.get("/{listing_id}", response_model=EnergyListing)
def mock_listing(listing_id: str) -> EnergyListing:
    """Return a single listing by ID (no auth)."""
    return _repo.get(listing_id)


@router.post("", response_model=EnergyListing, status_code=201)
def mock_create_listing(body: MockCreateBody) -> EnergyListing:
    """Create a new listing (no auth)."""
    now = datetime.now(timezone.utc)
    listing = EnergyListing(
        id=_next_id(),
        sellerId=body.sellerId,
        sellerName=body.sellerName or "Energy Seller",
        sellerRole=body.sellerRole or "producer",
        sellerInitials=_initials(body.sellerName or "Energy Seller"),
        sellerRating=body.sellerRating or 4.8,
        reviewCount=body.reviewCount or 0,
        energySource=EnergySource(body.energySource or "solar"),
        availableEnergyKwh=body.availableEnergyKwh,
        quantityTotalKwh=body.availableEnergyKwh,
        pricePerKwh=body.pricePerKwh,
        location=body.location or "Your neighbourhood",
        distanceKm=body.distanceKm or 0.0,
        batteryBacked=(
            body.batteryBacked
            if body.batteryBacked is not None
            else body.batteryReservePercentage >= 25
        ),
        renewableVerified=(
            body.renewableVerified if body.renewableVerified is not None else True
        ),
        availabilityStart=_parse_dt(body.availabilityStart) or now,
        availabilityEnd=(
            _parse_dt(body.availabilityEnd) or now.replace(year=now.year + 1)
        ),
        createdAt=now,
        updatedAt=now,
        listingStatus=ListingStatus.active,
        notes=body.notes,
        title=body.title or body.notes,
        minimumPurchaseKwh=body.minimumPurchaseKwh or 0.5,
        version=1,
    )
    return _repo.create(listing)


@router.post("/{listing_id}/cancel", response_model=EnergyListing)
def mock_cancel_listing(listing_id: str) -> EnergyListing:
    """Cancel an existing listing (no auth)."""
    return _repo.update(
        listing_id,
        listingStatus=ListingStatus.cancelled,
        updatedAt=datetime.now(timezone.utc),
    )


# ═══════════════════════════════════════════════════════════════════════
#  Internal helpers
# ═══════════════════════════════════════════════════════════════════════

def _next_id() -> str:
    return f"mock-listing-{uuid4()}"


def _initials(name: str) -> str:
    parts = name.strip().split()
    if len(parts) >= 2:
        return f"{parts[0][0]}{parts[-1][0]}".upper()
    return name[0].upper() if name else "ES"


def _parse_dt(val: str | None) -> datetime | None:
    if val is None:
        return None
    try:
        return datetime.fromisoformat(val.replace("Z", "+00:00"))
    except (ValueError, TypeError):
        return None


class MockQuantityBody(ApiModel):
    availableEnergyKwh: float = Field(ge=0, allow_inf_nan=False)


@router.post("/{listing_id}/pause", response_model=EnergyListing)
def mock_pause_listing(listing_id: str) -> EnergyListing:
    return _repo.update(listing_id, listingStatus=ListingStatus.paused)


@router.post("/{listing_id}/delete")
def mock_delete_listing(listing_id: str) -> dict:
    _repo.delete(listing_id)
    return {"deleted": True}


@router.post("/{listing_id}/quantity", response_model=EnergyListing)
def mock_update_quantity(listing_id: str, body: MockQuantityBody) -> EnergyListing:
    listing = _repo.get(listing_id)
    return _repo.update(listing_id, availableEnergyKwh=body.availableEnergyKwh,
        quantityTotalKwh=body.availableEnergyKwh + listing.quantityReservedKwh)
