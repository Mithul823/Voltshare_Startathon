import pytest
from tests.conftest import seed_profile, auth_headers
from app.schemas.common import UserRole
from app.schemas.kyc import KycStatus
from app.repositories.kyc_repository import kyc_repository


@pytest.mark.parametrize("status", [None, KycStatus.pending, KycStatus.rejected, KycStatus.resubmission_requested])
def test_unapproved_kyc_blocks_direct_purchase(client, status):
    seed_profile("kyc-buyer", verified_kyc=status is not None)
    if status:
        record = kyc_repository._records["kyc-buyer"]
        kyc_repository._records["kyc-buyer"] = record.model_copy(update={"status": status})
    response = client.post("/api/v1/purchases", headers={**auth_headers("kyc-buyer"), "Idempotency-Key": "kyc-denied"}, json={"listingId": "any", "quantityKwh": 1})
    assert response.status_code == 403


def test_unapproved_kyc_blocks_listing_service():
    from app.services.marketplace_service import marketplace_service
    from app.core.security import AuthenticatedUser
    from app.core.exceptions import ApiError
    with pytest.raises(ApiError) as error:
        marketplace_service.create(AuthenticatedUser("unverified-seller", None, UserRole.producer, "token"), None)
    assert error.value.status_code == 403


def test_kyc_persists(tmp_path, monkeypatch):
    from app.core.config import get_settings
    from tests.conftest import seed_kyc
    from app.repositories.kyc_repository import KycRepository
    monkeypatch.setattr(get_settings(), "financial_database_url", "sqlite:///" + str(tmp_path / "kyc.db"))
    seed_kyc("persistent-user")
    assert KycRepository()._get_by_user_id("persistent-user").status == KycStatus.verified


def test_latest_submission_wins_over_original_rejection():
    from datetime import datetime, timedelta, timezone
    from tests.conftest import seed_kyc
    seed_kyc("resubmitter")
    original = kyc_repository._records.pop("resubmitter")
    now = datetime.now(timezone.utc)
    kyc_repository._records["old"] = original.model_copy(update={"id": "old", "status": KycStatus.rejected, "submitted_at": now - timedelta(days=1)})
    kyc_repository._records["new"] = original.model_copy(update={"id": "new", "status": KycStatus.verified, "submitted_at": now})
    assert kyc_repository._get_by_user_id("resubmitter").id == "new"
    assert kyc_repository._get_by_user_id("resubmitter").status == KycStatus.verified
