"""Mock-mode purchase endpoints — no authentication required.

Stores purchases in ``data/purchases.json`` alongside ``data/listings.json``
so that after a simulated purchase in mock mode, the purchase history screen
shows the transaction.

When a purchase is created, the listing's ``availableEnergyKwh`` is reduced
(and marked ``sold`` if depleted).
"""

from __future__ import annotations

import json
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from threading import RLock
from typing import Any

from fastapi import APIRouter, Query

from app.repositories.json_file_marketplace_repository import JsonFileMarketplaceRepository
from app.schemas.common import ApiModel
from app.schemas.purchase import EnergyPurchase, PurchaseStatus

router = APIRouter()

# ── JSON file persistence for purchases ─────────────────────────────────

_DATA_DIR = Path(os.environ.get("VOLTSHARE_DATA_DIR", "data"))
_PURCHASES_FILE = _DATA_DIR / "purchases.json"
_purchase_lock = RLock()

# Shared marketplace repo — used to update listing quantities
_listing_repo = JsonFileMarketplaceRepository()


def _load_purchases() -> dict[str, dict[str, Any]]:
    """Load all purchases from the JSON file.

    If the file doesn't exist yet, seeds default demo purchases and
    saves them so purchase history is non-empty on first run.
    """
    if not _PURCHASES_FILE.exists():
        purchases = _seed_default_purchases()
        _save_purchases(purchases)
        return purchases
    try:
        raw = _PURCHASES_FILE.read_text(encoding="utf-8")
        return json.loads(raw)
    except (json.JSONDecodeError, OSError):
        return {}


def _save_purchases(purchases: dict[str, dict[str, Any]]) -> None:
    """Write all purchases to the JSON file."""
    with _purchase_lock:
        _DATA_DIR.mkdir(parents=True, exist_ok=True)
        _PURCHASES_FILE.write_text(
            json.dumps(purchases, indent=2, default=str, ensure_ascii=False),
            encoding="utf-8",
        )


def _next_purchase_id(existing: dict[str, Any]) -> str:
    n = len(existing) + 1
    return f"mock-purchase-{n}"


# ── Request / response models ───────────────────────────────────────────


class MockPurchaseCreateBody(ApiModel):
    listingId: str
    buyerId: str
    sellerId: str
    sellerName: str | None = None
    listingTitle: str | None = None
    quantityKwh: float
    unitPrice: float
    platformFee: float
    totalAmount: float
    estimatedSavings: float
    co2ImpactKg: float


# ── Endpoints ───────────────────────────────────────────────────────────


@router.post("", response_model=EnergyPurchase, status_code=201)
def mock_create_purchase(body: MockPurchaseCreateBody) -> EnergyPurchase:
    """Create a new purchase (no auth).

    Stores the record in ``data/purchases.json`` and reduces the listing's
    available energy in ``data/listings.json``.
    """
    purchases = _load_purchases()
    purchase_id = _next_purchase_id(purchases)
    now = datetime.now(timezone.utc)

    purchase_dict: dict[str, Any] = {
        "id": purchase_id,
        "listingId": body.listingId,
        "buyerId": body.buyerId,
        "sellerId": body.sellerId,
        "sellerName": body.sellerName,
        "listingTitle": body.listingTitle,
        "quantityKwh": body.quantityKwh,
        "unitPrice": body.unitPrice,
        "platformFee": body.platformFee,
        "totalAmount": body.totalAmount,
        "estimatedSavings": body.estimatedSavings,
        "co2ImpactKg": body.co2ImpactKg,
        "purchasedAt": now.isoformat(),
        "status": PurchaseStatus.completed.value,
    }

    purchases[purchase_id] = purchase_dict
    _save_purchases(purchases)

    # Update listing quantity via the shared listing repo
    try:
        listing = _listing_repo.get(body.listingId)
        remaining = max(0.0, listing.availableEnergyKwh - body.quantityKwh)
        new_status = "sold" if remaining <= 0 else "active"
        _listing_repo.update(
            body.listingId,
            availableEnergyKwh=remaining,
            listingStatus=new_status,
        )
    except Exception:
        # Silently continue even if listing update fails
        pass

    return _purchase_from_dict(purchase_id, purchase_dict)


@router.get("", response_model=list[EnergyPurchase])
def mock_purchases(
    buyer_id: str | None = Query(default=None, alias="buyerId"),
    seller_id: str | None = Query(default=None, alias="sellerId"),
) -> list[EnergyPurchase]:
    """Return purchases, optionally filtered by buyer or seller (no auth)."""
    all_purchases = _load_purchases()
    result = []

    for pid, data in all_purchases.items():
        if buyer_id and data.get("buyerId") != buyer_id:
            continue
        if seller_id and data.get("sellerId") != seller_id:
            continue
        result.append(_purchase_from_dict(pid, data))

    # Sort newest first
    result.sort(key=lambda p: p.purchasedAt, reverse=True)
    return result


# ── Seed defaults ────────────────────────────────────────────────────────


def _seed_default_purchases() -> dict[str, dict[str, Any]]:
    """Seed demo purchases referencing the demo listings.

    Also reduces the corresponding listing quantities via ``_listing_repo``
    so the marketplace reflects that energy has been consumed.
    """
    now = datetime.now(timezone.utc)
    seeds: list[dict[str, Any]] = [
        {
            "listingId": "ravi",
            "buyerId": "consumer-1",
            "sellerId": "producer-1",
            "sellerName": "Ravi Solar Hub",
            "listingTitle": "Solar Surplus — Kochi",
            "quantityKwh": 2.0,
            "unitPrice": 8.20,
            "platformFee": 0.49,
            "totalAmount": 16.89,
            "estimatedSavings": 3.61,
            "co2ImpactKg": 1.4,
            "purchasedAt": (now - timedelta(hours=5)).isoformat(),
            "status": "completed",
        },
        {
            "listingId": "ravi",
            "buyerId": "consumer-2",
            "sellerId": "producer-1",
            "sellerName": "Ravi Solar Hub",
            "listingTitle": "Solar Surplus — Kochi",
            "quantityKwh": 1.5,
            "unitPrice": 8.20,
            "platformFee": 0.37,
            "totalAmount": 12.67,
            "estimatedSavings": 2.71,
            "co2ImpactKg": 1.05,
            "purchasedAt": (now - timedelta(hours=12)).isoformat(),
            "status": "completed",
        },
        {
            "listingId": "eco",
            "buyerId": "consumer-1",
            "sellerId": "producer-1",
            "sellerName": "Chandra Devi",
            "listingTitle": "Biomass — Alappuzha",
            "quantityKwh": 5.0,
            "unitPrice": 6.20,
            "platformFee": 0.93,
            "totalAmount": 31.93,
            "estimatedSavings": 19.32,
            "co2ImpactKg": 3.5,
            "purchasedAt": (now - timedelta(days=2)).isoformat(),
            "status": "completed",
        },
    ]

    purchases: dict[str, dict[str, Any]] = {}
    for i, item in enumerate(seeds, start=1):
        pid = f"mock-purchase-{i}"
        entry = dict(item)
        entry["id"] = pid
        purchases[pid] = entry

        # Also reduce listing quantity so marketplace reflects the sale
        _reduce_listing_quantity(entry["listingId"], entry["quantityKwh"])

    print(f"[MockPurchases] Seeded {len(seeds)} demo purchases.")
    return purchases


def _reduce_listing_quantity(listing_id: str, qty_kwh: float) -> None:
    """Reduce a listing's available energy (safe to call on non-existent listings)."""
    try:
        listing = _listing_repo.get(listing_id)
        remaining = max(0.0, listing.availableEnergyKwh - qty_kwh)
        new_status = "sold" if remaining <= 0 else "active"
        _listing_repo.update(
            listing_id,
            availableEnergyKwh=remaining,
            listingStatus=new_status,
        )
    except Exception:
        pass


# ── Helpers ─────────────────────────────────────────────────────────────


def _purchase_from_dict(pid: str, data: dict[str, Any]) -> EnergyPurchase:
    status = PurchaseStatus.completed
    raw_status = data.get("status", "completed")
    try:
        status = PurchaseStatus(raw_status)
    except ValueError:
        pass

    return EnergyPurchase(
        id=pid,
        listingId=str(data.get("listingId", "")),
        buyerId=str(data.get("buyerId", "")),
        sellerId=str(data.get("sellerId", "")),
        sellerName=data.get("sellerName"),
        listingTitle=data.get("listingTitle"),
        quantityKwh=float(data.get("quantityKwh", 0)),
        unitPrice=float(data.get("unitPrice", 0)),
        platformFee=float(data.get("platformFee", 0)),
        totalAmount=float(data.get("totalAmount", 0)),
        estimatedSavings=float(data.get("estimatedSavings", 0)),
        co2ImpactKg=float(data.get("co2ImpactKg", 0)),
        purchasedAt=_parse_dt(data.get("purchasedAt")),
        status=status,
    )


def _parse_dt(val: Any) -> datetime:
    if isinstance(val, datetime):
        return val
    if isinstance(val, str):
        try:
            return datetime.fromisoformat(val.replace("Z", "+00:00"))
        except (ValueError, TypeError):
            pass
    return datetime.now(timezone.utc)
