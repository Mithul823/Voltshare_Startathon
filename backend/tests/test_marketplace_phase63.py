from datetime import timedelta

from fastapi.testclient import TestClient

from app.repositories.state import state
from app.schemas.common import UserRole, now_utc
from app.schemas.marketplace import EnergyListing, EnergySource, ListingStatus
from tests.conftest import auth_headers, seed_profile


def _listing(listing_id: str, seller_id: str, *, quantity: float = 5.0, price: float = 8.0, status: ListingStatus = ListingStatus.active) -> EnergyListing:
    now = now_utc()
    listing = EnergyListing(
        id=listing_id,
        sellerId=seller_id,
        sellerName=f"Seller {seller_id}",
        sellerRole="producer",
        sellerInitials="SS",
        energySource=EnergySource.solar,
        availableEnergyKwh=quantity,
        quantityTotalKwh=quantity,
        pricePerKwh=price,
        distanceKm=1,
        location="Testville",
        batteryBacked=True,
        renewableVerified=True,
        availabilityStart=now - timedelta(hours=1),
        availabilityEnd=now + timedelta(hours=5),
        createdAt=now,
        updatedAt=now,
        listingStatus=status,
        minimumPurchaseKwh=0.5,
    )
    state.listings[listing_id] = listing
    return listing


def test_consumer_can_browse_active_listings(client: TestClient) -> None:
    _listing("phase63-active", "seller-phase63")
    state.listings["phase63-draft"] = _listing("phase63-draft", "seller-phase63", status=ListingStatus.draft)

    response = client.get("/api/v1/listings?search=Testville&sort=price_low_to_high")

    assert response.status_code == 200
    ids = {item["id"] for item in response.json()}
    assert "phase63-active" in ids
    assert "phase63-draft" not in ids


def test_roles_gate_listing_creation(client: TestClient) -> None:
    seed_profile("phase63-consumer", UserRole.consumer)
    seed_profile("phase63-producer", UserRole.producer)
    now = now_utc()
    payload = {
        "energySource": "solar",
        "availableEnergyKwh": 3,
        "pricePerKwh": 8.5,
        "batteryReservePercentage": 25,
        "availabilityStart": now.isoformat(),
        "availabilityEnd": (now + timedelta(hours=3)).isoformat(),
    }

    denied = client.post("/api/v1/listings", headers=auth_headers("phase63-consumer"), json=payload)
    created = client.post("/api/v1/listings", headers=auth_headers("phase63-producer"), json=payload)

    assert denied.status_code == 403
    assert denied.json()["error"]["code"] == "MARKETPLACE_ROLE_NOT_ALLOWED"
    assert created.status_code == 201
    assert created.json()["sellerId"] == "phase63-producer"


def test_purchase_reserves_quantity_and_is_idempotent(client: TestClient) -> None:
    seed_profile("phase63-buyer", UserRole.consumer)
    _listing("phase63-buyable", "phase63-seller", quantity=2.0, price=7.75)
    headers = {**auth_headers("phase63-buyer"), "Idempotency-Key": "phase63-key-1"}
    payload = {"listingId": "phase63-buyable", "quantityKwh": 1.25}

    first = client.post("/api/v1/purchases", headers=headers, json=payload)
    second = client.post("/api/v1/purchases", headers=headers, json=payload)

    assert first.status_code == 201
    assert second.status_code == 201
    assert first.json()["purchase"]["id"] == second.json()["purchase"]["id"]
    assert state.listings["phase63-buyable"].availableEnergyKwh == 0.75


def test_idempotency_reuse_with_different_payload_returns_409(client: TestClient) -> None:
    seed_profile("phase63-buyer-conflict", UserRole.consumer)
    _listing("phase63-conflict", "phase63-seller", quantity=5.0)
    headers = {**auth_headers("phase63-buyer-conflict"), "Idempotency-Key": "phase63-key-2"}

    first = client.post("/api/v1/purchases", headers=headers, json={"listingId": "phase63-conflict", "quantityKwh": 1.0})
    conflict = client.post("/api/v1/purchases", headers=headers, json={"listingId": "phase63-conflict", "quantityKwh": 2.0})

    assert first.status_code == 201
    assert conflict.status_code == 409
    assert conflict.json()["error"]["code"] == "MARKETPLACE_IDEMPOTENCY_CONFLICT"


def test_self_purchase_and_insufficient_quantity_are_rejected(client: TestClient) -> None:
    seed_profile("phase63-self", UserRole.prosumer)
    seed_profile("phase63-small-buyer", UserRole.consumer)
    _listing("phase63-small", "phase63-self", quantity=1.0)

    self_purchase = client.post(
        "/api/v1/purchases",
        headers={**auth_headers("phase63-self"), "Idempotency-Key": "phase63-key-3"},
        json={"listingId": "phase63-small", "quantityKwh": 0.5},
    )
    too_large = client.post(
        "/api/v1/purchases",
        headers={**auth_headers("phase63-small-buyer"), "Idempotency-Key": "phase63-key-4"},
        json={"listingId": "phase63-small", "quantityKwh": 2.0},
    )

    assert self_purchase.status_code == 409
    assert self_purchase.json()["error"]["code"] == "MARKETPLACE_SELF_PURCHASE_NOT_ALLOWED"
    assert too_large.status_code == 409
    assert too_large.json()["error"]["code"] == "MARKETPLACE_INSUFFICIENT_QUANTITY"
