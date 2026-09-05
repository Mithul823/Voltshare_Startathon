"""Wallet repository — in-memory (demo) and Supabase (live) implementations.

Supports wallet CRUD, balance mutations, deposits, withdrawals, ledger
entries, and escrow holds/releases.  The Supabase implementation uses the
service-role admin client to bypass RLS for backend operations.
"""

from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal
from typing import Any, Protocol

from app.core.config import Settings, get_settings
from app.core.exceptions import ApiError, ErrorCode
from app.db.supabase import get_supabase_admin_client
from app.schemas.common import new_id, now_utc
from app.schemas.wallet import (
    Deposit,
    LedgerEntry,
    Refund,
    Settlement,
    TransactionAudit,
    Wallet,
    WalletBalance,
    WalletTransaction,
    WalletTransactionStatus,
    WalletTransactionType,
    Withdrawal,
)


# ---------------------------------------------------------------------------
# Protocol / interface
# ---------------------------------------------------------------------------

class WalletRepository(Protocol):
    """Interface for wallet data access."""

    def load_wallet(self, user_id: str) -> Wallet: ...
    def create_if_missing(self, user_id: str) -> Wallet: ...
    def update_balance(self, user_id: str, **patch: Any) -> Wallet: ...
    def transactions(self, user_id: str) -> list[WalletTransaction]: ...
    def add_transaction(self, user_id: str, tx: WalletTransaction) -> WalletTransaction: ...
    def replace_transactions(self, user_id: str, transactions: list[WalletTransaction]) -> None: ...
    def get_deposit(self, deposit_id: str) -> Deposit | None: ...
    def save_deposit(self, deposit: Deposit) -> Deposit: ...
    def get_withdrawal(self, withdrawal_id: str) -> Withdrawal | None: ...
    def save_withdrawal(self, withdrawal: Withdrawal) -> Withdrawal: ...
    def get_refund(self, refund_id: str) -> Refund | None: ...
    def save_refund(self, refund: Refund) -> Refund: ...
    def get_settlement(self, settlement_id: str) -> Settlement | None: ...
    def save_settlement(self, settlement: Settlement) -> Settlement: ...
    def save_ledger_entry(self, entry: LedgerEntry) -> LedgerEntry: ...
    def record_audit(self, audit: TransactionAudit) -> None: ...


# ---------------------------------------------------------------------------
# In-memory repository (demo / fallback)
# ---------------------------------------------------------------------------

class InMemoryWalletRepository:
    """Deterministic in-memory wallet repository.

    All data is transient — lost on server restart.
    Operates on the global ``state`` instance.
    """

    def __init__(self) -> None:
        from app.repositories.state import state as app_state
        self._state = app_state

    def _wallet_for(self, user_id: str) -> Wallet:
        """Lazy-init wallet for a user."""
        wallet = self._state.wallets.get(user_id)
        if wallet:
            return wallet
        wallet = Wallet(
            walletId=f"WAL-{user_id}",
            userId=user_id,
            availableBalancePaise=125000,
            heldBalancePaise=0,
            pendingBalancePaise=32000,
            escrowHeldBalancePaise=0,
            totalEarnedPaise=486000,
            totalSpentPaise=293000,
            totalWithdrawnPaise=84000,
            totalAddedPaise=200000,
        )
        self._state.wallets[user_id] = wallet
        self._state.transactions.setdefault(user_id, [])
        return wallet

    def load_wallet(self, user_id: str) -> Wallet:
        return self._wallet_for(user_id)

    def create_if_missing(self, user_id: str) -> Wallet:
        return self._wallet_for(user_id)

    def update_balance(self, user_id: str, **patch: Any) -> Wallet:
        wallet = self._wallet_for(user_id)
        patch["updatedAt"] = now_utc()
        updated = wallet.model_copy(update=patch)
        self._state.wallets[user_id] = updated
        return updated

    def transactions(self, user_id: str) -> list[WalletTransaction]:
        self._wallet_for(user_id)
        return self._state.transactions.get(user_id, [])

    def add_transaction(self, user_id: str, tx: WalletTransaction) -> WalletTransaction:
        self._state.transactions.setdefault(user_id, []).insert(0, tx)
        return tx

    def replace_transactions(self, user_id: str, transactions: list[WalletTransaction]) -> None:
        self._state.transactions[user_id] = transactions

    def get_deposit(self, deposit_id: str) -> Deposit | None:
        return self._state.deposits.get(deposit_id)

    def save_deposit(self, deposit: Deposit) -> Deposit:
        self._state.deposits[deposit.depositId] = deposit
        return deposit

    def get_withdrawal(self, withdrawal_id: str) -> Withdrawal | None:
        return self._state.withdrawals.get(withdrawal_id)

    def save_withdrawal(self, withdrawal: Withdrawal) -> Withdrawal:
        self._state.withdrawals[withdrawal.withdrawalId] = withdrawal
        return withdrawal

    def get_refund(self, refund_id: str) -> Refund | None:
        return self._state.refunds.get(refund_id)

    def save_refund(self, refund: Refund) -> Refund:
        self._state.refunds[refund.refundId] = refund
        return refund

    def get_settlement(self, settlement_id: str) -> Settlement | None:
        return self._state.settlements.get(settlement_id)

    def save_settlement(self, settlement: Settlement) -> Settlement:
        self._state.settlements[settlement.settlementId] = settlement
        return settlement

    def save_ledger_entry(self, entry: LedgerEntry) -> LedgerEntry:
        self._state.ledger_entries[entry.entryId] = entry
        return entry

    def record_audit(self, audit: TransactionAudit) -> None:
        self._state.transaction_audit.append(audit)


# ---------------------------------------------------------------------------
# Supabase-backed repository (live mode)
# ---------------------------------------------------------------------------

_WALLET_COLUMNS = {
    "wallet_id": "walletId",
    "user_id": "userId",
    "available_balance": "availableBalancePaise",
    "held_balance": "heldBalancePaise",
    "currency": "currency",
    "status": "status",
    "created_at": "createdAt",
    "updated_at": "updatedAt",
}


def _row_to_wallet(row: dict[str, Any]) -> Wallet:
    return Wallet(
        walletId=str(row["wallet_id"]),
        userId=str(row["user_id"]),
        availableBalancePaise=int(row.get("available_balance", 0)),
        heldBalancePaise=int(row.get("held_balance", 0)),
        pendingBalancePaise=0,         # TODO: add column if needed
        escrowHeldBalancePaise=int(row.get("held_balance", 0)),
        totalEarnedPaise=0,
        totalSpentPaise=0,
        totalWithdrawnPaise=0,
        totalAddedPaise=0,
        currency=str(row.get("currency", "Rs")),
        updatedAt=_parse_dt(row.get("updated_at")),
        status=str(row.get("status", "ACTIVE")),
    )


def _wallet_to_row(wallet: Wallet) -> dict[str, Any]:
    return {
        "user_id": wallet.userId,
        "available_balance": wallet.availableBalancePaise,
        "held_balance": wallet.heldBalancePaise + wallet.escrowHeldBalancePaise,
        "currency": wallet.currency,
        "status": wallet.status,
        "updated_at": now_utc().isoformat(),
    }


def _parse_dt(value: Any) -> datetime:
    if isinstance(value, datetime):
        return value
    if isinstance(value, str):
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    return now_utc()


class SupabaseWalletRepository(InMemoryWalletRepository):
    """Supabase PostgreSQL-backed wallet repository."""

    def __init__(self, settings: Settings | None = None) -> None:
        from app.repositories.financial_store import financial_state
        self._state = financial_state

    def load_wallet(self, user_id: str) -> Wallet:
        from app.repositories.financial_store import connection
        from psycopg.rows import dict_row
        with connection() as conn:
            row = conn.cursor(row_factory=dict_row).execute("SELECT * FROM wallets WHERE user_id=%s FOR UPDATE", (user_id,)).fetchone()
            return _row_to_wallet(row) if row else self.create_if_missing(user_id)

    def create_if_missing(self, user_id: str) -> Wallet:
        from app.repositories.financial_store import connection
        from psycopg.rows import dict_row
        with connection() as conn:
            conn.execute("INSERT INTO wallets(user_id,available_balance,held_balance,currency,status) VALUES (%s,0,0,'INR','ACTIVE') ON CONFLICT(user_id) DO NOTHING", (user_id,))
            row = conn.cursor(row_factory=dict_row).execute("SELECT * FROM wallets WHERE user_id=%s FOR UPDATE", (user_id,)).fetchone()
            return _row_to_wallet(row)

    def update_balance(self, user_id: str, **patch: Any) -> Wallet:
        from app.repositories.financial_store import connection
        from psycopg import sql
        from psycopg.rows import dict_row
        allowed = {"availableBalancePaise": "available_balance", "heldBalancePaise": "held_balance", "status": "status", "currency": "currency"}
        values = {allowed[k]: v for k, v in patch.items() if k in allowed}
        if any(values.get(k, 0) < 0 for k in ("available_balance", "held_balance")):
            raise ApiError(409, ErrorCode.INSUFFICIENT_BALANCE, "Balance cannot be negative.")
        values["updated_at"] = now_utc()
        with connection() as conn:
            query = sql.SQL("UPDATE wallets SET {} WHERE user_id=%s RETURNING *").format(sql.SQL(",").join(sql.SQL("{}=%s").format(sql.Identifier(k)) for k in values))
            row = conn.cursor(row_factory=dict_row).execute(query, [*values.values(), user_id]).fetchone()
            if not row:
                raise ApiError(404, ErrorCode.RESOURCE_NOT_FOUND, "Wallet not found.")
            return _row_to_wallet(row)

    def transactions(self, user_id: str) -> list[WalletTransaction]:
        return self._state.transactions.get(user_id, [])

    def add_transaction(self, user_id: str, tx: WalletTransaction) -> WalletTransaction:
        items = self.transactions(user_id)
        items.insert(0, tx)
        self._state.transactions[user_id] = items
        return tx


_WALLET_REVERSE = {v: k for k, v in _WALLET_COLUMNS.items() if v is not None}


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

def get_wallet_repository(settings: Settings | None = None) -> WalletRepository:
    """Return the active wallet repository based on configuration."""
    current = settings or get_settings()
    if current.financial_database_url or current.is_production or (current.supabase_url and current.supabase_service_role_key):
        return SupabaseWalletRepository(current)
    return InMemoryWalletRepository()
