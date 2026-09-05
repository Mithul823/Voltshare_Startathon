import pytest
from app.core.config import get_settings
from app.core.exceptions import ApiError
from app.core.security import AuthenticatedUser
from app.schemas.common import UserRole
from app.schemas.wallet import WalletMutationRequest
from app.services.wallet_service import WalletService


@pytest.mark.parametrize("environment,enabled", [("production", True), ("production", False), ("development", False), ("demo", False)])
@pytest.mark.parametrize("method", ["deposit", "demo_top_up"])
def test_unverified_credits_blocked(monkeypatch, environment, enabled, method):
    monkeypatch.setattr(get_settings(), "app_env", environment)
    monkeypatch.setattr(get_settings(), "enable_demo_endpoints", enabled)
    service = WalletService()
    user = AuthenticatedUser("buyer", None, UserRole.consumer, "token")
    with pytest.raises(ApiError) as error:
        getattr(service, method)(user, WalletMutationRequest(amountPaise=10000))
    assert error.value.status_code == 403
    assert service._repo_instance is None

