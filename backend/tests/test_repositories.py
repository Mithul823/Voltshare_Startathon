"""Tests for all repository implementations (in-memory mode).

All tests use the in-memory repository implementations which are the default
when Supabase is not configured.  This validates repository behaviour without
external dependencies.
"""

# ---------------------------------------------------------------------------
# Marketplace repository tests
# ---------------------------------------------------------------------------

from datetime import timedelta

from app.repositories.marketplace_repository import (
    InMemoryMarketplaceRepository, get_marketplace_repository,
)
from app.repositories.wallet_repository import (
    InMemoryWalletRepository, get_wallet_repository,
)
from app.repositories.escrow_repository import (
    InMemoryEscrowRepository, get_escrow_repository,
)
from app.repositories.purchase_repository import (
    InMemoryPurchaseRepository, get_purchase_repository,
)
from app.repositories.energy_repository import (
    InMemoryEnergyReadingsRepository, get_energy_readings_repository,
)
from app.repositories.notification_repository import (
    InMemoryNotificationRepository, get_notification_repository,
)
from app.repositories.ai_repository import (
    InMemoryAiRepository, get_ai_repository,
)
from app.schemas.common import new_id, now_utc, UserRole
from app.schemas.marketplace import EnergyListing, EnergySource, ListingStatus
from app.schemas.realtime import NotificationCategory, NotificationPriority


# ---------------------------------------------------------------------------
# Repository factory tests — verify correct implementation is selected
# ---------------------------------------------------------------------------

class TestRepositoryFactories:
    """Verify factory functions return a repository conforming to the
    expected protocol.  Factories are called with explicit empty settings
    so they always return in-memory implementations regardless of the
    test environment."""

    @staticmethod
    def _no_supabase_settings() -> object:
        from app.core.config import Settings
        return Settings(supabase_url="", supabase_service_role_key="")

    def test_marketplace_factory_returns_repo(self) -> None:
        repo = get_marketplace_repository(self._no_supabase_settings())
        assert hasattr(repo, 'list') and hasattr(repo, 'get') and hasattr(repo, 'create')

    def test_wallet_factory_returns_repo(self) -> None:
        repo = get_wallet_repository(self._no_supabase_settings())
        assert hasattr(repo, 'load_wallet') and hasattr(repo, 'update_balance')

    def test_escrow_factory_returns_repo(self) -> None:
        repo = get_escrow_repository(self._no_supabase_settings())
        assert hasattr(repo, 'get') and hasattr(repo, 'create_for_purchase')

    def test_purchase_factory_returns_repo(self) -> None:
        repo = get_purchase_repository(self._no_supabase_settings())
        assert hasattr(repo, 'save') and hasattr(repo, 'get')

    def test_energy_factory_returns_repo(self) -> None:
        repo = get_energy_readings_repository(self._no_supabase_settings())
        assert hasattr(repo, 'latest') and hasattr(repo, 'append')

    def test_notification_factory_returns_repo(self) -> None:
        repo = get_notification_repository(self._no_supabase_settings())
        assert hasattr(repo, 'create') and hasattr(repo, 'list_for')

    def test_ai_factory_returns_repo(self) -> None:
        repo = get_ai_repository(self._no_supabase_settings())
        assert hasattr(repo, 'save_conversation') and hasattr(repo, 'list_conversations')


class TestMarketplaceRepository:
    def setup_method(self) -> None:
        self.repo = InMemoryMarketplaceRepository()
        self.listing = EnergyListing(
            id=new_id("LST"), sellerId="seller-1", sellerName="Tester",
            sellerRole="producer", sellerInitials="TS", energySource=EnergySource.solar,
            availableEnergyKwh=10.0, pricePerKwh=8.0, location="Test City",
            batteryBacked=True, renewableVerified=True,
            availabilityStart=now_utc() - timedelta(hours=1),
            availabilityEnd=now_utc() + timedelta(hours=5),
            listingStatus=ListingStatus.active,
        )

    def test_create_and_get(self) -> None:
        created = self.repo.create(self.listing)
        assert created.id == self.listing.id
        fetched = self.repo.get(self.listing.id)
        assert fetched.id == self.listing.id
        assert fetched.availableEnergyKwh == 10.0

    def test_get_not_found(self) -> None:
        from app.core.exceptions import ApiError
        try:
            self.repo.get("nonexistent")
            assert False, "Expected ApiError"
        except ApiError as e:
            assert e.status_code == 404

    def test_list_active_only(self) -> None:
        self.repo.create(self.listing)
        inactive = self.listing.model_copy(update={"id": new_id("LST"), "listingStatus": ListingStatus.draft})
        self.repo.create(inactive)
        results = self.repo.list(active_only=True)
        assert len(results) == 1
        assert results[0].id == self.listing.id

    def test_list_by_seller(self) -> None:
        self.repo.create(self.listing)
        results = self.repo.list(seller_id="seller-1")
        assert len(results) == 1
        results = self.repo.list(seller_id="other")
        assert len(results) == 0

    def test_reserve_quantity(self) -> None:
        self.repo.create(self.listing)
        updated = self.repo.reserve_quantity(self.listing.id, 3.0)
        assert updated.availableEnergyKwh == 7.0
        assert updated.quantityReservedKwh == 3.0

    def test_summary(self) -> None:
        self.repo.create(self.listing)
        summary = self.repo.summary()
        assert summary.activeListings == 1
        assert summary.totalAvailableKwh == 10.0
        assert summary.averagePricePerKwh == 8.0


class TestWalletRepository:
    def setup_method(self) -> None:
        self.repo = InMemoryWalletRepository()

    def test_create_and_load_wallet(self) -> None:
        wallet = self.repo.load_wallet("user-1")
        assert wallet.userId == "user-1"
        assert wallet.availableBalancePaise >= 0

    def test_update_balance(self) -> None:
        self.repo.load_wallet("user-1")
        updated = self.repo.update_balance("user-1", availableBalancePaise=50000)
        assert updated.availableBalancePaise == 50000

    def test_transactions(self) -> None:
        from app.schemas.wallet import WalletTransaction, WalletTransactionType, WalletTransactionStatus
        tx = WalletTransaction(id="tx-1", userId="user-1", type=WalletTransactionType.walletTopUp,
                               status=WalletTransactionStatus.completed, amountPaise=10000,
                               description="Test", reference="REF-1")
        self.repo.add_transaction("user-1", tx)
        txs = self.repo.transactions("user-1")
        assert len(txs) == 1
        assert txs[0].id == "tx-1"

    def test_deposit_roundtrip(self) -> None:
        from app.schemas.wallet import Deposit
        dep = Deposit(depositId="dep-1", userId="user-1", walletId="wal-1",
                       amountPaise=5000, method="demo", status="COMPLETED")
        self.repo.save_deposit(dep)
        fetched = self.repo.get_deposit("dep-1")
        assert fetched is not None
        assert fetched.amountPaise == 5000


class TestEscrowRepository:
    def setup_method(self) -> None:
        self.repo = InMemoryEscrowRepository()

    def test_create_for_purchase(self) -> None:
        escrow = self.repo.create_for_purchase(
            purchase_id="pur-1", listing_id="lst-1",
            buyer_id="buyer-1", seller_id="seller-1",
            quantity_kwh=5.0, amount_held_paise=40000, platform_fee_paise=2000,
        )
        assert escrow.purchaseId == "pur-1"
        assert escrow.amountHeldPaise == 40000
        assert escrow.totalHeldPaise == 42000
        assert escrow.integrityHash != ""

    def test_get_escrow(self) -> None:
        escrow = self.repo.create_for_purchase(
            purchase_id="pur-2", listing_id="lst-2",
            buyer_id="buyer-2", seller_id="seller-2",
            quantity_kwh=2.0, amount_held_paise=16000, platform_fee_paise=800,
        )
        fetched = self.repo.get(escrow.id)
        assert fetched.id == escrow.id

    def test_list_for_user(self) -> None:
        self.repo.create_for_purchase(
            purchase_id="pur-3", listing_id="lst-3",
            buyer_id="buyer-x", seller_id="seller-y",
            quantity_kwh=1.0, amount_held_paise=8000, platform_fee_paise=400,
        )
        results = self.repo.list_for("buyer-x")
        assert len(results) == 1
        results = self.repo.list_for("other")
        assert len(results) == 0


class TestPurchaseRepository:
    def setup_method(self) -> None:
        self.repo = InMemoryPurchaseRepository()

    def test_save_and_get(self) -> None:
        from app.schemas.purchase import EnergyPurchase, PurchaseStatus
        purchase = EnergyPurchase(
            id="pur-test", listingId="lst-1", buyerId="buyer-1", sellerId="seller-1",
            quantityKwh=2.0, unitPrice=8.0, totalAmount=16.80, platformFee=0.80,
            estimatedSavings=3.50, co2ImpactKg=1.4, status=PurchaseStatus.confirmed,
        )
        self.repo.save(purchase)
        fetched = self.repo.get("pur-test")
        assert fetched is not None
        assert fetched.quantityKwh == 2.0

    def test_list_for_user(self) -> None:
        from app.schemas.purchase import EnergyPurchase, PurchaseStatus
        self.repo.save(EnergyPurchase(id="p1", listingId="l1", buyerId="b1", sellerId="s1",
            quantityKwh=1, unitPrice=8, totalAmount=8.4, platformFee=0.4,
            estimatedSavings=0, co2ImpactKg=0.7, status=PurchaseStatus.confirmed))
        self.repo.save(EnergyPurchase(id="p2", listingId="l2", buyerId="b2", sellerId="b1",
            quantityKwh=1, unitPrice=8, totalAmount=8.4, platformFee=0.4,
            estimatedSavings=0, co2ImpactKg=0.7, status=PurchaseStatus.confirmed))
        as_buyer = self.repo.list_for_user("b1", "purchases")
        assert len(as_buyer) == 1
        all_user = self.repo.list_for_user("b1")
        assert len(all_user) == 2  # one as buyer, one as seller


class TestEnergyReadingsRepository:
    def setup_method(self) -> None:
        self.repo = InMemoryEnergyReadingsRepository()

    def test_seed_and_read(self) -> None:
        readings = self.repo.seed_user("user-1")
        assert len(readings) == 48
        latest = self.repo.latest("user-1")
        assert latest.user_id == "user-1"

    def test_append_reading(self) -> None:
        from app.schemas.dashboard import EnergyReading
        reading = EnergyReading(
            id="rdg-sim-1", user_id="user-1", timestamp=now_utc(),
            solar_generation_kwh=3.5, consumption_kwh=2.1, battery_percent=80,
            battery_charge_kw=1.4, grid_import_kwh=0, grid_export_kwh=1.4,
            carbon_saved=2.45, earnings=11.20, cost=0,
        )
        self.repo.append("user-1", reading)
        readings = self.repo.readings_for("user-1")
        assert len(readings) == 49  # 48 seed + 1 appended
        assert readings[-1].solar_generation_kwh == 3.5

    def test_between(self) -> None:
        readings = self.repo.seed_user("user-1", reference_time=now_utc())
        mid_point = readings[len(readings) // 2]
        window = self.repo.between("user-1", mid_point.timestamp, now_utc())
        assert len(window) <= 48


class TestNotificationRepository:
    def setup_method(self) -> None:
        self.repo = InMemoryNotificationRepository()

    def test_create_and_list(self) -> None:
        self.repo.create(user_id="user-1", title="Test", message="Hello",
                         category=NotificationCategory.system, priority=NotificationPriority.medium)
        items = self.repo.list_for("user-1")
        assert len(items) == 1
        assert items[0].title == "Test"

    def test_unread_count(self) -> None:
        self.repo.create(user_id="user-1", title="N1", message="M1",
                         category=NotificationCategory.wallet, priority=NotificationPriority.high)
        self.repo.create(user_id="user-1", title="N2", message="M2",
                         category=NotificationCategory.system, priority=NotificationPriority.medium)
        assert self.repo.unread_count("user-1") == 2

    def test_mark_read(self) -> None:
        n = self.repo.create(user_id="user-1", title="ReadMe", message="Msg",
                             category=NotificationCategory.system, priority=NotificationPriority.low)
        self.repo.mark_read("user-1", n.id, role=UserRole.consumer)
        assert self.repo.unread_count("user-1") == 0


class TestAiRepository:
    def setup_method(self) -> None:
        self.repo = InMemoryAiRepository()

    def test_conversation_save_and_list(self) -> None:
        from app.schemas.ai import AssistantConversation
        conv = AssistantConversation(id="cnv-1", user_id="user-1")
        self.repo.save_conversation(conv)
        listed = self.repo.list_conversations("user-1")
        assert len(listed) == 1
        fetched = self.repo.get_conversation("cnv-1")
        assert fetched is not None

    def test_delete_conversation(self) -> None:
        from app.schemas.ai import AssistantConversation
        conv = AssistantConversation(id="cnv-2", user_id="user-1")
        self.repo.save_conversation(conv)
        assert self.repo.delete_conversation("cnv-2") is True
        assert self.repo.get_conversation("cnv-2") is None

    def test_save_forecast(self) -> None:
        from app.schemas.forecast import ForecastResponse, ForecastMetric, ForecastHorizon
        forecast = ForecastResponse(metric=ForecastMetric.generation, horizon=ForecastHorizon.twenty_four_hours,
                                     model="test", confidence=0.8, data_points_used=48, forecast=[],
                                     explanation="Test")
        self.repo.save_forecast("user-1", "generation", "24h", forecast)
        fetched = self.repo.get_forecast("user-1", "generation")
        assert fetched is not None
        assert fetched.metric == ForecastMetric.generation

    def test_sustainability_score(self) -> None:
        from app.schemas.sustainability import SustainabilityScore
        score = SustainabilityScore(total_score=75, grade="Good", factor_scores={"a": 1.0},
                                     improvement_actions=[], confidence=0.8, assumptions=[])
        self.repo.save_sustainability_score(score)
        fetched = self.repo.get_latest_sustainability_score("user-1")
        assert fetched is not None
        assert fetched.total_score == 75
