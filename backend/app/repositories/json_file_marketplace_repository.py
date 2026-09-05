"""
JSON file-backed marketplace repository — stores listings in a local file.

Used as the default fallback when Supabase is not configured.
Data persists across server restarts, enabling multi-device operation
for the prototype.
"""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from threading import RLock
from typing import Any

from app.repositories.marketplace_repository import InMemoryMarketplaceRepository
from app.schemas.marketplace import (
    EnergyListing,
    EnergySource,
    ListingStatus,
)

_DATA_DIR = Path(os.environ.get("VOLTSHARE_DATA_DIR", "data"))
_LISTINGS_FILE = _DATA_DIR / "listings.json"


class JsonFileMarketplaceRepository(InMemoryMarketplaceRepository):
    """Extends the in-memory repo with JSON file persistence.

    Listings are loaded from ``data/listings.json`` on startup and saved
    after every create / update / reserve_quantity operation.
    """

    def __init__(self) -> None:
        super().__init__()
        self._file_lock = RLock()
        _DATA_DIR.mkdir(parents=True, exist_ok=True)
        self._load_from_file()

    # ── file I/O ──────────────────────────────────────────────────────────

    def _load_from_file(self) -> None:
        """Load listings from the JSON file, populating ``self._state.listings``."""
        if not _LISTINGS_FILE.exists():
            self._seed_defaults()
            self._save_to_file()
            return
        try:
            raw = _LISTINGS_FILE.read_text(encoding="utf-8")
            data = json.loads(raw)
            loaded: dict[str, EnergyListing] = {}
            for listing_id, item in data.items():
                try:
                    listing = self._dict_to_listing(item)
                    loaded[listing_id] = listing
                except Exception as exc:
                    print(f"[JsonFileRepo] Skipping invalid listing {listing_id}: {exc}")
            self._state.listings.clear()
            self._state.listings.update(loaded)
            print(f"[JsonFileRepo] Loaded {len(loaded)} listings from {_LISTINGS_FILE}")
        except (json.JSONDecodeError, OSError) as exc:
            print(f"[JsonFileRepo] Failed to load {_LISTINGS_FILE}: {exc}")
            self._seed_defaults()

    def _save_to_file(self) -> None:
        """Write all current listings to the JSON file."""
        with self._file_lock:
            try:
                serializable = {
                    lid: self._listing_to_dict(lst)
                    for lid, lst in self._state.listings.items()
                }
                _LISTINGS_FILE.parent.mkdir(parents=True, exist_ok=True)
                _LISTINGS_FILE.write_text(
                    json.dumps(serializable, indent=2, default=str, ensure_ascii=False),
                    encoding="utf-8",
                )
            except OSError as exc:
                print(f"[JsonFileRepo] Failed to save listings: {exc}")

    # ── conversions ───────────────────────────────────────────────────────

    @staticmethod
    def _listing_to_dict(lst: EnergyListing) -> dict[str, Any]:
        return {
            "id": lst.id,
            "sellerId": lst.sellerId,
            "sellerName": lst.sellerName,
            "sellerRole": lst.sellerRole,
            "sellerInitials": lst.sellerInitials,
            "sellerRating": lst.sellerRating,
            "reviewCount": lst.reviewCount,
            "energySource": lst.energySource.value,
            "availableEnergyKwh": lst.availableEnergyKwh,
            "quantityTotalKwh": lst.quantityTotalKwh,
            "quantityReservedKwh": lst.quantityReservedKwh,
            "pricePerKwh": lst.pricePerKwh,
            "currency": lst.currency,
            "minimumPurchaseKwh": lst.minimumPurchaseKwh,
            "maximumPurchaseKwh": lst.maximumPurchaseKwh,
            "location": lst.location,
            "distanceKm": lst.distanceKm,
            "batteryBacked": lst.batteryBacked,
            "renewableVerified": lst.renewableVerified,
            "availabilityStart": lst.availabilityStart.isoformat(),
            "availabilityEnd": lst.availabilityEnd.isoformat(),
            "createdAt": lst.createdAt.isoformat(),
            "updatedAt": lst.updatedAt.isoformat(),
            "listingStatus": lst.listingStatus.value,
            "notes": lst.notes,
            "title": lst.title,
            "description": lst.description,
            "isFeatured": lst.isFeatured,
            "version": lst.version,
        }

    @staticmethod
    def _dict_to_listing(data: dict[str, Any]) -> EnergyListing:
        return EnergyListing(
            id=str(data["id"]),
            sellerId=str(data.get("sellerId", "")),
            sellerName=str(data.get("sellerName", "Energy Seller")),
            sellerRole=str(data.get("sellerRole", "producer")),
            sellerInitials=str(data.get("sellerInitials", "ES")),
            sellerRating=float(data.get("sellerRating", 4.8)),
            reviewCount=int(data.get("reviewCount", 0)),
            energySource=EnergySource(data.get("energySource", "solar")),
            availableEnergyKwh=float(data.get("availableEnergyKwh", 0)),
            quantityTotalKwh=float(data.get("quantityTotalKwh", 0) or 0) or None,
            quantityReservedKwh=float(data.get("quantityReservedKwh", 0)),
            pricePerKwh=float(data.get("pricePerKwh", 0)),
            currency=str(data.get("currency", "INR")),
            minimumPurchaseKwh=float(data.get("minimumPurchaseKwh", 0.5)),
            maximumPurchaseKwh=(
                float(data["maximumPurchaseKwh"]) if data.get("maximumPurchaseKwh") is not None else None
            ),
            location=str(data.get("location", "")),
            distanceKm=float(data.get("distanceKm", 0)),
            batteryBacked=bool(data.get("batteryBacked", False)),
            renewableVerified=bool(data.get("renewableVerified", True)),
            availabilityStart=_parse_dt(data.get("availabilityStart")),
            availabilityEnd=_parse_dt(data.get("availabilityEnd")),
            createdAt=_parse_dt(data.get("createdAt")),
            updatedAt=_parse_dt(data.get("updatedAt")),
            listingStatus=ListingStatus(data.get("listingStatus", "active")),
            notes=data.get("notes"),
            title=data.get("title"),
            description=data.get("description"),
            isFeatured=bool(data.get("isFeatured", False)),
            version=int(data.get("version", 1)),
        )

    # ── seed defaults ─────────────────────────────────────────────────────

    def _seed_defaults(self) -> None:
        """Seed demo listings (same data as the frontend MockBackendStore)."""
        from datetime import timedelta
        from app.schemas.common import now_utc

        now = now_utc()
        seeds = [
            {
                "id": "ravi",
                "sellerId": "producer-1",
                "sellerName": "Ravi Solar Hub",
                "sellerRole": "producer",
                "sellerInitials": "RS",
                "sellerRating": 4.9,
                "reviewCount": 120,
                "energySource": EnergySource.solar,
                "availableEnergyKwh": 4.5,
                "quantityTotalKwh": 4.5,
                "pricePerKwh": 8.20,
                "location": "Kochi",
                "distanceKm": 0.5,
                "batteryBacked": True,
                "renewableVerified": True,
                "availabilityStart": now - timedelta(hours=1),
                "availabilityEnd": now + timedelta(hours=24),
                "createdAt": now - timedelta(hours=2),
                "listingStatus": ListingStatus.active,
                "notes": "Solar Surplus — Kochi",
                "title": "Solar Surplus — Kochi",
            },
            {
                "id": "green",
                "sellerId": "producer-1",
                "sellerName": "Chandra Devi",
                "sellerRole": "producer",
                "sellerInitials": "CD",
                "sellerRating": 4.8,
                "reviewCount": 100,
                "energySource": EnergySource.wind,
                "availableEnergyKwh": 30.0,
                "quantityTotalKwh": 30.0,
                "pricePerKwh": 5.20,
                "location": "Idukki",
                "distanceKm": 2.0,
                "batteryBacked": False,
                "renewableVerified": True,
                "availabilityStart": now - timedelta(hours=2),
                "availabilityEnd": now + timedelta(hours=48),
                "createdAt": now - timedelta(days=1),
                "listingStatus": ListingStatus.active,
                "notes": "Wind Energy — Idukki",
                "title": "Wind Energy — Idukki",
            },
            {
                "id": "anjali",
                "sellerId": "producer-2",
                "sellerName": "Deepak Menon",
                "sellerRole": "producer",
                "sellerInitials": "DM",
                "sellerRating": 4.8,
                "reviewCount": 85,
                "energySource": EnergySource.hydro,
                "availableEnergyKwh": 80.0,
                "quantityTotalKwh": 80.0,
                "pricePerKwh": 4.50,
                "location": "Thrissur",
                "distanceKm": 3.0,
                "batteryBacked": False,
                "renewableVerified": True,
                "availabilityStart": now - timedelta(hours=3),
                "availabilityEnd": now + timedelta(hours=72),
                "createdAt": now - timedelta(days=2),
                "listingStatus": ListingStatus.active,
                "notes": "Hydro Power — Thrissur",
                "title": "Hydro Power — Thrissur",
            },
            {
                "id": "eco",
                "sellerId": "producer-1",
                "sellerName": "Chandra Devi",
                "sellerRole": "producer",
                "sellerInitials": "CD",
                "sellerRating": 4.7,
                "reviewCount": 60,
                "energySource": EnergySource.biomass,
                "availableEnergyKwh": 20.0,
                "quantityTotalKwh": 20.0,
                "pricePerKwh": 6.20,
                "location": "Alappuzha",
                "distanceKm": 1.5,
                "batteryBacked": True,
                "renewableVerified": False,
                "availabilityStart": now - timedelta(hours=1),
                "availabilityEnd": now + timedelta(hours=12),
                "createdAt": now - timedelta(days=3),
                "listingStatus": ListingStatus.active,
                "notes": "Biomass — Alappuzha",
                "title": "Biomass — Alappuzha",
            },
        ]
        for item in seeds:
            listing = EnergyListing(**item)
            listing = listing.model_copy(update={
                "seller": self._seller_for_static(listing),
            })
            self._state.listings[listing.id] = listing
        print(f"[JsonFileRepo] Seeded {len(seeds)} demo listings.")

    @staticmethod
    def _seller_for_static(listing: EnergyListing) -> Any:
        """Build a seller summary (avoids needing the full service)."""
        from app.schemas.marketplace import SellerSummary
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

    # ── overrides: persist after writes ───────────────────────────────────

    def create(self, listing: EnergyListing) -> EnergyListing:
        result = super().create(listing)
        self._save_to_file()
        return result

    def update(self, listing_id: str, **patch: Any) -> EnergyListing:
        result = super().update(listing_id, **patch)
        self._save_to_file()
        return result

    def reserve_quantity(self, listing_id: str, quantity_kwh: float) -> EnergyListing:
        result = super().reserve_quantity(listing_id, quantity_kwh)
        self._save_to_file()
        return result

    def append_activity(self, event_type: str, message: str, listing_id: str | None = None, purchase_id: str | None = None) -> None:
        # Activity is ephemeral (not persisted to file)
        super().append_activity(event_type, message, listing_id=listing_id, purchase_id=purchase_id)


def _parse_dt(value: Any) -> datetime:
    if isinstance(value, datetime):
        return value
    if isinstance(value, str):
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    return datetime.now(timezone.utc)
