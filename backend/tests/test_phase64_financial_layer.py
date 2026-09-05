from fastapi.testclient import TestClient

from app.repositories.state import state
from app.schemas.common import UserRole
from tests.conftest import auth_headers, seed_profile
from tests.test_marketplace_phase63 import _listing


def _balanced(transaction_id: str) -> bool:
    entries = [
        state.ledger_entries[entry_id]
        for entry_id in state.ledger_by_transaction.get(transaction_id, [])
    ]
    return bool(entries) and sum(item.debitPaise for item in entries) == sum(item.creditPaise for item in entries)


def test_wallet_creation_and_deposit_create_balanced_ledger(client: TestClient) -> None:
    seed_profile("phase64-consumer", UserRole.consumer)
    headers = {**auth_headers("phase64-consumer"), "Idempotency-Key": "phase64-deposit-1"}

    wallet = client.get("/api/v1/wallet", headers=headers)
    deposit = client.post("/api/v1/wallet/deposit", headers=headers, json={"amountPaise": 25000, "method": "UPI", "label": "dev"})
    balance = client.get("/api/v1/wallet/balance", headers=headers)

    assert wallet.status_code == 200
    assert wallet.json()["status"] == "ACTIVE"
    assert deposit.status_code == 200
    assert deposit.json()["type"] == "walletTopUp"
    assert balance.json()["availableBalancePaise"] >= 150000
    assert _balanced(deposit.json()["id"])


def test_withdrawal_permissions_and_ledger(client: TestClient) -> None:
    seed_profile("phase64-consumer-wd", UserRole.consumer)
    seed_profile("phase64-producer-wd", UserRole.producer)

    denied = client.post(
        "/api/v1/wallet/withdraw",
        headers={**auth_headers("phase64-consumer-wd"), "Idempotency-Key": "phase64-wd-denied"},
        json={"amountPaise": 10000, "method": "Bank", "label": "bank"},
    )
    allowed = client.post(
        "/api/v1/wallet/withdraw",
        headers={**auth_headers("phase64-producer-wd"), "Idempotency-Key": "phase64-wd-ok"},
        json={"amountPaise": 10000, "method": "Bank", "label": "bank"},
    )

    assert denied.status_code == 403
    assert allowed.status_code == 200
    assert allowed.json()["status"] == "pending"
    assert _balanced(allowed.json()["id"])


def test_purchase_moves_buyer_funds_to_escrow_then_settlement_credits_seller(client: TestClient) -> None:
    seed_profile("phase64-buyer", UserRole.consumer)
    seed_profile("phase64-seller", UserRole.producer)
    _listing("phase64-listing", "phase64-seller", quantity=3.0, price=8.0)
    headers = {**auth_headers("phase64-buyer"), "Idempotency-Key": "phase64-buy-1"}
    before = client.get("/api/v1/wallet/balance", headers=headers).json()

    purchase = client.post(
        "/api/v1/purchases",
        headers=headers,
        json={"listingId": "phase64-listing", "quantityKwh": 1.0},
    )

    assert purchase.status_code == 201
    payload = purchase.json()
    escrow_id = payload["escrowId"]
    assert payload["purchase"]["status"] == "confirmed"
    after_hold = client.get("/api/v1/wallet/balance", headers=headers).json()
    assert after_hold["availableBalancePaise"] < before["availableBalancePaise"]
    assert after_hold["escrowHeldBalancePaise"] > before["escrowHeldBalancePaise"]
    buyer_tx = client.get("/api/v1/wallet/transactions", headers=headers).json()[0]
    assert buyer_tx["escrowId"] == escrow_id
    assert _balanced(buyer_tx["id"])

    settlement = client.post(
        "/api/v1/settlements/process",
        headers={**auth_headers("phase64-buyer"), "Idempotency-Key": "phase64-settle-1"},
        params={"escrowId": escrow_id, "deliveredEnergyKwh": 1.0},
    )

    assert settlement.status_code == 200
    assert settlement.json()["sellerReleasePaise"] > 0
    history = client.get("/api/v1/wallet/transactions", headers=headers).json()
    assert next(tx for tx in history if tx["escrowId"] == escrow_id)["status"] == "completed"
    seller_wallet = client.get("/api/v1/wallet", headers=auth_headers("phase64-seller")).json()
    assert seller_wallet["availableBalancePaise"] > 125000
    assert client.get("/api/v1/settlements", headers=auth_headers("phase64-seller")).json()


def test_duplicate_purchase_idempotency_prevents_second_financial_move(client: TestClient) -> None:
    seed_profile("phase64-idem-buyer", UserRole.consumer)
    _listing("phase64-idem-listing", "phase64-idem-seller", quantity=3.0, price=8.0)
    headers = {**auth_headers("phase64-idem-buyer"), "Idempotency-Key": "phase64-idem-key"}
    payload = {"listingId": "phase64-idem-listing", "quantityKwh": 1.0}

    first = client.post("/api/v1/purchases", headers=headers, json=payload)
    second = client.post("/api/v1/purchases", headers=headers, json=payload)
    transactions = client.get("/api/v1/wallet/transactions", headers=headers).json()

    assert first.status_code == 201
    assert second.status_code == 201
    assert first.json()["purchase"]["id"] == second.json()["purchase"]["id"]
    assert len([item for item in transactions if item["escrowId"] == first.json()["escrowId"]]) == 1


def test_ledger_and_refund_endpoints_are_permissioned(client: TestClient) -> None:
    seed_profile("phase64-refund-buyer", UserRole.consumer)
    _listing("phase64-refund-listing", "phase64-refund-seller", quantity=3.0, price=8.0)
    headers = {**auth_headers("phase64-refund-buyer"), "Idempotency-Key": "phase64-refund-buy"}
    purchase = client.post("/api/v1/purchases", headers=headers, json={"listingId": "phase64-refund-listing", "quantityKwh": 1.0})
    escrow_id = purchase.json()["escrowId"]
    client.post("/api/v1/escrow/cancel", headers={**auth_headers("phase64-refund-buyer"), "Idempotency-Key": "phase64-refund-cancel"}, params={"escrowId": escrow_id})

    ledger = client.get("/api/v1/ledger", headers=auth_headers("phase64-refund-buyer"))
    refunds = client.get("/api/v1/refunds", headers=auth_headers("phase64-refund-buyer"))

    assert ledger.status_code == 200
    assert ledger.json()
    assert refunds.status_code == 200


def test_seller_cannot_release_own_escrow(client):
    seed_profile("release-buyer", UserRole.consumer)
    seed_profile("release-seller", UserRole.producer)
    _listing("release-listing", "release-seller", quantity=3.0, price=8.0)
    purchase = client.post("/api/v1/purchases", headers={**auth_headers("release-buyer"), "Idempotency-Key": "release-buy"}, json={"listingId": "release-listing", "quantityKwh": 1.0}).json()
    escrow_id = purchase["escrowId"]
    for index, path in enumerate(("/api/v1/escrow/release", f"/api/v1/escrows/{escrow_id}/verify-delivery", "/api/v1/settlements/process")):
        response = client.post(path, headers={**auth_headers("release-seller"), "Idempotency-Key": f"seller-release-{index}"}, params={"escrowId": escrow_id, "deliveredEnergyKwh": 1.0}, json={"deliveredEnergyKwh": 1.0})
        assert response.status_code == 403
    assert state.escrows[escrow_id].completedAt is None


def test_cancel_returns_entire_hold_including_fee(client):
    seed_profile("fee-buyer", UserRole.consumer)
    _listing("fee-listing", "fee-seller", quantity=3.0, price=8.0)
    headers = auth_headers("fee-buyer")
    before = client.get("/api/v1/wallet/balance", headers=headers).json()
    purchase = client.post("/api/v1/purchases", headers={**headers, "Idempotency-Key": "fee-buy"}, json={"listingId": "fee-listing", "quantityKwh": 1}).json()
    response = client.post("/api/v1/escrow/cancel", params={"escrowId": purchase["escrowId"]}, headers={**headers, "Idempotency-Key": "fee-cancel"})
    assert response.status_code == 200
    assert response.json()["buyerRefundPaise"] == 840
    after = client.get("/api/v1/wallet/balance", headers=headers).json()
    assert after == before
    history = client.get("/api/v1/wallet/transactions", headers=headers).json()
    original = next(tx for tx in history if tx["type"] == "energyPurchase")
    assert original["status"] == "refunded"


def test_partial_settlement_conserves_money_and_cannot_repeat(client):
    seed_profile("partial-buyer")
    _listing("partial-listing", "partial-seller", quantity=3, price=8)
    headers = auth_headers("partial-buyer")
    purchase = client.post("/api/v1/purchases", headers={**headers, "Idempotency-Key": "partial-buy"}, json={"listingId": "partial-listing", "quantityKwh": 1}).json()
    endpoint = f"/api/v1/escrows/{purchase['escrowId']}/verify-delivery"
    response = client.post(endpoint, headers={**headers, "Idempotency-Key": "partial-settle"}, json={"deliveredEnergyKwh": 0.5})
    assert response.status_code == 200
    result = response.json()
    assert result["sellerReleasePaise"] + result["buyerRefundPaise"] + result["platformFeeRetainedPaise"] == 840
    assert client.get("/api/v1/wallet/balance", headers=headers).json()["heldBalancePaise"] == 0
    assert client.post(endpoint, headers={**headers, "Idempotency-Key": "partial-repeat"}, json={"deliveredEnergyKwh": 0.5}).status_code == 409


def test_failed_meter_verification_freezes_without_releasing(client):
    seed_profile("meter-buyer")
    _listing("meter-listing", "meter-seller", quantity=3, price=8)
    headers = auth_headers("meter-buyer")
    purchase = client.post("/api/v1/purchases", headers={**headers, "Idempotency-Key": "meter-buy"}, json={"listingId": "meter-listing", "quantityKwh": 1}).json()
    response = client.post(f"/api/v1/escrows/{purchase['escrowId']}/verify-delivery", headers={**headers, "Idempotency-Key": "meter-settle"}, json={"deliveredEnergyKwh": 1, "meterMatched": False})
    assert response.status_code == 200
    assert response.json()["frozenPaise"] == 840
    assert client.get("/api/v1/wallet/balance", headers=headers).json()["heldBalancePaise"] == 840
