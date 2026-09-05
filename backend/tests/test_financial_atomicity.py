from copy import deepcopy
import pytest
from app.core.security import AuthenticatedUser
from app.repositories.state import state
from app.schemas.common import UserRole
from app.schemas.purchase import PurchaseCreateRequest
from app.services.purchase_service import purchase_service
from tests.test_marketplace_phase63 import _listing


@pytest.mark.parametrize("stage", ["escrow", "wallet", "purchase"])
def test_failed_purchase_rolls_back_every_financial_record(monkeypatch, stage):
    from tests.conftest import seed_kyc
    seed_kyc("atomic-buyer")
    _listing("atomic-listing", "atomic-seller", quantity=3.0, price=8.0)
    from app.services.wallet_service import wallet_service
    from app.services.escrow_service import escrow_service
    wallet_service.wallet("atomic-buyer")
    before = deepcopy(state.__dict__)
    def fail(*args, **kwargs):
        raise RuntimeError("injected persistence failure")
    target, method = {"escrow": (escrow_service, "create_for_purchase"), "wallet": (wallet_service, "escrow_hold"), "purchase": (purchase_service._purchase_repo, "save")}[stage]
    monkeypatch.setattr(target, method, fail)
    with pytest.raises(RuntimeError):
        purchase_service.create(AuthenticatedUser("atomic-buyer", None, UserRole.consumer, "token"), PurchaseCreateRequest(listingId="atomic-listing", quantityKwh=1), "atomic-key")
    assert state.__dict__ == before


def test_database_transaction_rolls_back(tmp_path, monkeypatch):
    from app.core.config import get_settings
    from app.core.financial_transaction import transaction
    from app.repositories.financial_store import RecordMap
    monkeypatch.setattr(get_settings(), "financial_database_url", "sqlite:///" + str(tmp_path / "rollback.db"))
    records = RecordMap("test", dict)
    with pytest.raises(RuntimeError):
        with transaction():
            records["purchase"] = {"amount": 840}
            raise RuntimeError("failure")
    assert not records
