"""Escrow repository — in-memory (demo) and Supabase (live) implementations.

Supports escrow creation, settlement, dispute handling, and reconciliation.
The Supabase implementation uses the service-role admin client.
"""

from __future__ import annotations

from datetime import timedelta
from typing import Any, Protocol

from app.core.config import Settings, get_settings
from app.core.exceptions import ApiError, ErrorCode
from app.db.supabase import get_supabase_admin_client
from app.schemas.common import new_id, now_utc
from app.schemas.escrow import (
    Dispute,
    EscrowAgreement,
    EscrowSettlementResult,
    EscrowStatus,
    ReconciliationReport,
)
from app.schemas.wallet import EscrowAccount, Settlement


# ---------------------------------------------------------------------------
# Protocol / interface
# ---------------------------------------------------------------------------

class EscrowRepository(Protocol):
    """Interface for escrow data access."""

    def create_for_purchase(self, *, purchase_id: str, listing_id: str, buyer_id: str, seller_id: str, quantity_kwh: float, amount_held_paise: int, platform_fee_paise: int) -> EscrowAgreement: ...
    def get(self, escrow_id: str) -> EscrowAgreement: ...
    def update(self, escrow_id: str, **patch: Any) -> EscrowAgreement: ...
    def list_for(self, user_id: str) -> list[EscrowAgreement]: ...
    def save_escrow_account(self, account: EscrowAccount) -> EscrowAccount: ...
    def save_settlement(self, settlement: Settlement) -> Settlement: ...
    def save_dispute(self, dispute: Dispute) -> Dispute: ...
    def get_disputes(self) -> list[Dispute]: ...
    def reconcile(self) -> ReconciliationReport: ...


# ---------------------------------------------------------------------------
# In-memory repository (demo / fallback)
# ---------------------------------------------------------------------------

class InMemoryEscrowRepository:
    """Deterministic in-memory escrow repository."""

    def __init__(self) -> None:
        from app.repositories.state import state as app_state
        self._state = app_state

    def create_for_purchase(self, *, purchase_id: str, listing_id: str, buyer_id: str, seller_id: str, quantity_kwh: float, amount_held_paise: int, platform_fee_paise: int) -> EscrowAgreement:
        from app.services.audit_service import canonical_hmac
        escrow = EscrowAgreement(
            id=new_id("ESC"),
            purchaseId=purchase_id,
            listingId=listing_id,
            buyerId=buyer_id,
            sellerId=seller_id,
            energyQuantityKwh=quantity_kwh,
            amountHeldPaise=amount_held_paise,
            platformFeePaise=platform_fee_paise,
            totalHeldPaise=amount_held_paise + platform_fee_paise,
            fundedAt=now_utc(),
            deliveryDeadline=now_utc() + timedelta(hours=4),
            integrityHash="",
        )
        escrow = escrow.model_copy(update={"integrityHash": canonical_hmac(escrow.model_dump(mode="json"))})
        self._state.escrows[escrow.id] = escrow
        self._state.escrow_accounts[escrow.id] = EscrowAccount(
            escrowAccountId=new_id("EAC"),
            escrowId=escrow.id,
            purchaseId=purchase_id,
            buyerId=buyer_id,
            sellerId=seller_id,
            amountHeldPaise=amount_held_paise,
            platformFeePaise=platform_fee_paise,
            status="ACTIVE",
        )
        return escrow

    def get(self, escrow_id: str) -> EscrowAgreement:
        escrow = self._state.escrows.get(escrow_id)
        if not escrow:
            raise ApiError(404, ErrorCode.RESOURCE_NOT_FOUND, "Escrow not found.")
        return escrow

    def update(self, escrow_id: str, **patch: Any) -> EscrowAgreement:
        escrow = self.get(escrow_id)
        patch["version"] = escrow.version + 1
        updated = escrow.model_copy(update=patch)
        from app.services.audit_service import canonical_hmac
        unsigned = updated.model_copy(update={"integrityHash": ""})
        updated = unsigned.model_copy(update={"integrityHash": canonical_hmac(unsigned.model_dump(mode="json"))})
        self._state.escrows[escrow_id] = updated
        return updated

    def list_for(self, user_id: str) -> list[EscrowAgreement]:
        return [item for item in self._state.escrows.values() if user_id in {item.buyerId, item.sellerId}]

    def save_escrow_account(self, account: EscrowAccount) -> EscrowAccount:
        self._state.escrow_accounts[account.escrowId] = account
        return account

    def save_settlement(self, settlement: Settlement) -> Settlement:
        self._state.settlements[settlement.settlementId] = settlement
        return settlement

    def save_dispute(self, dispute: Dispute) -> Dispute:
        self._state.disputes[dispute.id] = dispute
        return dispute

    def get_disputes(self) -> list[Dispute]:
        return list(self._state.disputes.values())

    def reconcile(self) -> ReconciliationReport:
        notes = []
        for escrow in self._state.escrows.values():
            if escrow.status == EscrowStatus.energyDeliveryPending and escrow.deliveryDeadline < now_utc():
                notes.append(f"{escrow.id}: stale pending delivery requires review")
        return ReconciliationReport(checked=len(self._state.escrows), repaired=0, notes=notes)


# ---------------------------------------------------------------------------
# Supabase-backed repository (live mode)
# ---------------------------------------------------------------------------

class SupabaseEscrowRepository(InMemoryEscrowRepository):
    """Persistent financial records in the shared PostgreSQL database."""
    def __init__(self, settings: Settings | None = None) -> None:
        from app.repositories.financial_store import financial_state
        self._state = financial_state


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

def get_escrow_repository(settings: Settings | None = None) -> EscrowRepository:
    """Return the active escrow repository based on configuration."""
    current = settings or get_settings()
    if current.financial_database_url or current.is_production or (current.supabase_url and current.supabase_service_role_key):
        return SupabaseEscrowRepository(current)
    return InMemoryEscrowRepository()
