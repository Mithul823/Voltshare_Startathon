"""Purchase records in demo memory or the shared financial database."""

from __future__ import annotations

from typing import Any, Protocol

from app.core.config import Settings, get_settings
from app.core.exceptions import ApiError, ErrorCode
from app.db.supabase import get_supabase_admin_client
from app.schemas.purchase import EnergyPurchase, PurchaseStatus


# ---------------------------------------------------------------------------
# Protocol / interface
# ---------------------------------------------------------------------------

class PurchaseRepository(Protocol):
    """Interface for purchase data access."""

    def save(self, purchase: EnergyPurchase) -> EnergyPurchase: ...
    def get(self, purchase_id: str) -> EnergyPurchase | None: ...
    def list_for_user(self, user_id: str, relation: str | None = None) -> list[EnergyPurchase]: ...
    def list_all(self) -> list[EnergyPurchase]: ...
    def update(self, purchase_id: str, **patch: Any) -> EnergyPurchase: ...
    def get_by_listing(self, listing_id: str) -> list[EnergyPurchase]: ...


# ---------------------------------------------------------------------------
# In-memory repository (demo / fallback)
# ---------------------------------------------------------------------------

class InMemoryPurchaseRepository:
    """Deterministic in-memory purchase repository.

    Operates on the global ``state.purchases`` dict.
    """

    def __init__(self) -> None:
        from app.repositories.state import state as app_state
        self._state = app_state

    def save(self, purchase: EnergyPurchase) -> EnergyPurchase:
        self._state.purchases[purchase.id] = purchase
        return purchase

    def get(self, purchase_id: str) -> EnergyPurchase | None:
        return self._state.purchases.get(purchase_id)

    def list_for_user(self, user_id: str, relation: str | None = None) -> list[EnergyPurchase]:
        if relation == "sales":
            return [p for p in self._state.purchases.values() if p.sellerId == user_id]
        elif relation == "purchases":
            return [p for p in self._state.purchases.values() if p.buyerId == user_id]
        else:
            return [p for p in self._state.purchases.values() if p.buyerId == user_id or p.sellerId == user_id]

    def list_all(self) -> list[EnergyPurchase]:
        return list(self._state.purchases.values())

    def update(self, purchase_id: str, **patch: Any) -> EnergyPurchase:
        purchase = self.get(purchase_id)
        if not purchase:
            raise ApiError(404, ErrorCode.RESOURCE_NOT_FOUND, "Purchase not found.")
        updated = purchase.model_copy(update=patch)
        self._state.purchases[purchase_id] = updated
        return updated

    def get_by_listing(self, listing_id: str) -> list[EnergyPurchase]:
        return [p for p in self._state.purchases.values() if p.listingId == listing_id]


# ---------------------------------------------------------------------------
# Supabase-backed repository (live mode)
# ---------------------------------------------------------------------------

class SupabasePurchaseRepository(InMemoryPurchaseRepository):
    """Persistent financial records in the shared PostgreSQL database."""
    def __init__(self, settings: Settings | None = None) -> None:
        from app.repositories.financial_store import financial_state
        self._state = financial_state


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------

def get_purchase_repository(settings: Settings | None = None) -> PurchaseRepository:
    """Return the active purchase repository based on configuration."""
    current = settings or get_settings()
    if current.financial_database_url or current.is_production or (current.supabase_url and current.supabase_service_role_key):
        return SupabasePurchaseRepository(current)
    return InMemoryPurchaseRepository()
