from app.api.v1 import mock_listings
from tests.test_marketplace_phase63 import _listing


def test_mock_controls_are_implemented_and_persist(client, monkeypatch):
    saved = []
    monkeypatch.setattr(mock_listings._repo, "_save_to_file", lambda: saved.append(True))
    _listing("controls", "seller", quantity=3, price=8)
    paused = client.post("/api/v1/mock/listings/controls/pause")
    assert paused.status_code == 200
    assert paused.json()["listingStatus"] == "paused"
    updated = client.post("/api/v1/mock/listings/controls/quantity", json={"availableEnergyKwh": 5})
    assert updated.status_code == 200
    assert updated.json()["availableEnergyKwh"] == 5
    assert client.post("/api/v1/mock/listings/controls/quantity", json={"availableEnergyKwh": -1}).status_code == 422
    assert client.post("/api/v1/mock/listings/controls/delete").status_code == 200
    assert client.get("/api/v1/mock/listings/controls").status_code == 404
    assert len(saved) == 3


def test_listing_ids_do_not_reuse_persisted_counter_ids(client, monkeypatch):
    from uuid import UUID
    monkeypatch.setattr(mock_listings._repo, "_save_to_file", lambda: None)
    existing = _listing("mock-listing-1", "original-seller", quantity=3, price=8)
    response = client.post("/api/v1/mock/listings", json={"sellerId": "new-seller", "availableEnergyKwh": 2, "pricePerKwh": 8})
    assert response.status_code == 201
    UUID(response.json()["id"].removeprefix("mock-listing-"))
    assert mock_listings._repo.get("mock-listing-1").sellerId == "original-seller"
    assert len({mock_listings._next_id() for _ in range(100)}) == 100
