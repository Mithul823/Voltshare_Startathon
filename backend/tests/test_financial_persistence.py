from app.core.config import get_settings
from app.repositories.financial_store import RecordMap
from app.repositories.purchase_repository import SupabasePurchaseRepository
from app.repositories.escrow_repository import SupabaseEscrowRepository
from app.repositories.wallet_repository import SupabaseWalletRepository
from app.schemas.wallet import WalletTransaction, WalletTransactionType, WalletTransactionStatus, LedgerEntry
from app.services.ledger_service import LedgerService


def test_financial_records_survive_repository_restart(tmp_path, monkeypatch):
    monkeypatch.setattr(get_settings(), "financial_database_url", "sqlite:///" + str(tmp_path / "finance.db"))
    first = SupabaseEscrowRepository()
    escrow = first.create_for_purchase(purchase_id="purchase", listing_id="listing", buyer_id="buyer", seller_id="seller", quantity_kwh=1, amount_held_paise=800, platform_fee_paise=40)
    assert SupabaseEscrowRepository().get(escrow.id) == escrow
    tx = WalletTransaction(id="tx", userId="buyer", type=WalletTransactionType.energyPurchase, status=WalletTransactionStatus.pending, amountPaise=840, description="purchase", reference="ref")
    # Avoid needing an HTTP client: history accesses only the shared database.
    wallet = object.__new__(SupabaseWalletRepository)
    from app.repositories.financial_store import financial_state
    wallet._state = financial_state
    wallet.add_transaction("buyer", tx)
    again = object.__new__(SupabaseWalletRepository)
    again._state = financial_state
    assert again.transactions("buyer") == [tx]
    ledger = LedgerService()
    ledger.record(transaction_id="tx", entries=[LedgerEntry(entryId="debit", transactionId="tx", userId="buyer", debitPaise=840, creditPaise=0, accountType="escrow", description="hold"), LedgerEntry(entryId="credit", transactionId="tx", userId="buyer", debitPaise=0, creditPaise=840, accountType="wallet", description="hold")])
    assert len(LedgerService().transaction("tx").entries) == 2

