from datetime import datetime, timedelta, timezone

import jwt
import pytest
from fastapi.testclient import TestClient

from app.core.config import Settings, get_settings
from app.main import app
from app.repositories.profile_repository import profile_repository
from app.schemas.common import UserRole
from app.schemas.profile import Profile


@pytest.fixture(autouse=True)
def auto_force_inmemory_repositories(monkeypatch) -> None:
    """Force all repository factories to return in-memory implementations.

    This prevents Supabase-backed repos from being instantiated when the
    test environment has SUPABASE_URL / SERVICE_ROLE_KEY set.  In-memory
    repos work with any test ID (string or UUID) and don't require network.

    Each service module holds its own import reference to the factory
    function, so we must patch every import path individually.
    """
    from app.repositories.marketplace_repository import InMemoryMarketplaceRepository
    from app.repositories.wallet_repository import InMemoryWalletRepository
    from app.repositories.escrow_repository import InMemoryEscrowRepository
    from app.repositories.purchase_repository import InMemoryPurchaseRepository
    from app.repositories.energy_repository import InMemoryEnergyReadingsRepository
    from app.repositories.notification_repository import InMemoryNotificationRepository
    from app.repositories.ai_repository import InMemoryAiRepository

    _inmem_marketplace = InMemoryMarketplaceRepository()
    _inmem_wallet = InMemoryWalletRepository()
    _inmem_escrow = InMemoryEscrowRepository()
    _inmem_purchase = InMemoryPurchaseRepository()
    _inmem_energy = InMemoryEnergyReadingsRepository()
    _inmem_notification = InMemoryNotificationRepository()
    _inmem_ai = InMemoryAiRepository()

    # Marketplace — used by both marketplace_service and purchase_service
    for module in ["marketplace_service", "purchase_service"]:
        monkeypatch.setattr(
            f"app.services.{module}.get_marketplace_repository",
            lambda _settings=None: _inmem_marketplace,
        )

    # Wallet — used by wallet_service, purchase_service, escrow_service
    for module in ["wallet_service", "purchase_service", "escrow_service"]:
        monkeypatch.setattr(
            f"app.services.{module}.get_wallet_repository",
            lambda _settings=None: _inmem_wallet,
        )

    # Escrow
    monkeypatch.setattr(
        "app.services.escrow_service.get_escrow_repository",
        lambda _settings=None: _inmem_escrow,
    )

    # Purchase
    monkeypatch.setattr(
        "app.services.purchase_service.get_purchase_repository",
        lambda _settings=None: _inmem_purchase,
    )

    # Energy readings — only patch modules that actually import get_energy_readings_repository
    for module in ["dashboard_service"]:
        monkeypatch.setattr(
            f"app.services.{module}.get_energy_readings_repository",
            lambda _settings=None: _inmem_energy,
        )
    monkeypatch.setattr(
        "app.repositories.dashboard_repository.get_energy_readings_repository",
        lambda _settings=None: _inmem_energy,
    )

    # Notifications
    monkeypatch.setattr(
        "app.services.notification_service.get_notification_repository",
        lambda _settings=None: _inmem_notification,
    )

    # AI
    monkeypatch.setattr(
        "app.services.gemini_assistant_service.get_ai_repository",
        lambda _settings=None: _inmem_ai,
    )


@pytest.fixture(autouse=True)
def auto_clear_profiles_and_state() -> None:
    profile_repository.clear_test_profiles()
    # Clear the global in-memory state between tests
    from app.repositories.state import state
    state.listings.clear()
    state.purchases.clear()
    state.wallets.clear()
    state.notifications.clear()
    state.assistant_conversations.clear()


@pytest.fixture()
def client() -> TestClient:
    return TestClient(app)


@pytest.fixture()
def settings() -> Settings:
    return get_settings()


def make_token(user_id: str, *, expired: bool = False) -> str:
    current = get_settings()
    secret = current.supabase_jwt_secret or "test-secret"
    now = datetime.now(timezone.utc)
    return jwt.encode(
        {
            "sub": user_id,
            "email": f"{user_id}@example.com",
            "iss": current.expected_issuer or "https://example.supabase.co/auth/v1",
            "aud": "authenticated",
            "exp": now - timedelta(minutes=1) if expired else now + timedelta(minutes=15),
        },
        secret,
        algorithm="HS256",
    )


def auth_headers(user_id: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {make_token(user_id)}"}


def seed_profile(user_id: str, role: UserRole = UserRole.consumer) -> None:
    profile_repository.set_test_profile(
        Profile(
            id=user_id,
            email=f"{user_id}@example.com",
            full_name="Test User",
            role=role,
            email_verified=True,
            is_active=True,
        )
    )
