"""Admin disputes repository — manages dispute listing, filtering, and resolution.

In demo mode, uses in-memory state. In live mode, queries from Supabase.
"""

from __future__ import annotations

from typing import Any

from app.core.config import Settings, get_settings
from app.db.supabase import get_supabase_admin_client
from app.schemas.admin_disputes import AdminDisputeSummary, DisputeActionResponse, PaginatedAdminDisputes
from app.repositories.state import state


class InMemoryAdminDisputesRepository:
    """Deterministic mock admin disputes data for demo mode."""

    async def list_disputes(
        self,
        status: str | None = None,
        priority: str | None = None,
        buyer_id: str | None = None,
        seller_id: str | None = None,
        date_from: str | None = None,
        date_to: str | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> PaginatedAdminDisputes:
        all_disputes = self._get_mock_disputes()
        filtered = self._apply_filters(all_disputes, status, priority, buyer_id, seller_id, date_from, date_to)
        total = len(filtered)
        total_pages = max(1, (total + page_size - 1) // page_size)
        start = (page - 1) * page_size
        items = filtered[start:start + page_size]
        return PaginatedAdminDisputes(
            items=items,
            page=page,
            page_size=page_size,
            total=total,
            total_pages=total_pages,
        )

    async def get_dispute_detail(self, dispute_id: str) -> AdminDisputeSummary:
        for d in self._get_mock_disputes():
            if d.id == dispute_id:
                return d
        raise ValueError(f"Dispute {dispute_id} not found")

    async def update_dispute_status(
        self,
        dispute_id: str,
        status: str,
        reason: str = "",
        refund_amount_paise: int = 0,
        release_to_seller_paise: int = 0,
    ) -> DisputeActionResponse:
        return DisputeActionResponse(
            id=dispute_id,
            status=status,
            message=f"Dispute {status} successfully.",
        )

    async def assign_dispute(self, dispute_id: str, admin_id: str) -> DisputeActionResponse:
        return DisputeActionResponse(
            id=dispute_id,
            status="assigned",
            message="Dispute assigned successfully.",
        )

    def _get_mock_disputes(self) -> list[AdminDisputeSummary]:
        from datetime import datetime, timedelta
        now = datetime.utcnow()
        return [
            AdminDisputeSummary(
                id="dsp-001", escrow_id="escrow-001", purchase_id="purch-001",
                buyer_id="consumer-001", buyer_name="Ananya Nair",
                seller_id="producer-001", seller_name="Chandra Devi",
                listing_title="Solar Surplus — Kochi",
                amount_paise=125000, reason="Energy shortfall — received 8.5 kWh instead of 10 kWh",
                status="open", priority="high", created_at=now - timedelta(hours=6), updated_at=now - timedelta(hours=6),
            ),
            AdminDisputeSummary(
                id="dsp-002", escrow_id="escrow-002", purchase_id="purch-002",
                buyer_id="extra-001", buyer_name="Priya Sharma",
                seller_id="producer-002", seller_name="Deepak Menon",
                listing_title="Wind Energy — Thrissur",
                amount_paise=85000, reason="Delayed delivery — energy not delivered within agreed window",
                status="under_review", priority="high", created_at=now - timedelta(hours=12), updated_at=now - timedelta(hours=3),
            ),
            AdminDisputeSummary(
                id="dsp-003", escrow_id="escrow-003", purchase_id="purch-003",
                buyer_id="consumer-001", buyer_name="Ananya Nair",
                seller_id="producer-001", seller_name="Chandra Devi",
                listing_title="Solar Surplus — Kochi",
                amount_paise=42000, reason="Settlement mismatch — expected refund of ₹350 not processed",
                status="resolved", priority="medium", created_at=now - timedelta(days=2), updated_at=now - timedelta(days=1),
            ),
            AdminDisputeSummary(
                id="dsp-004", escrow_id="escrow-004", purchase_id="purch-004",
                buyer_id="producer-002", buyer_name="Deepak Menon",
                seller_id="consumer-002", seller_name="Biju Mathew (Suspended)",
                listing_title="Backup Energy — Kozhikode",
                amount_paise=95000, reason="Buyer claims energy quality below agreed standards",
                status="open", priority="critical", created_at=now - timedelta(hours=1), updated_at=now - timedelta(hours=1),
            ),
            AdminDisputeSummary(
                id="dsp-005", escrow_id="escrow-005", purchase_id="purch-005",
                buyer_id="consumer-002", buyer_name="Biju Mathew",
                seller_id="producer-001", seller_name="Chandra Devi",
                listing_title="Solar Surplus — Idukki",
                amount_paise=34000, reason="Buyer unable to verify delivery — meter data mismatch",
                status="under_review", priority="medium", created_at=now - timedelta(days=1), updated_at=now - timedelta(hours=12),
            ),
        ]

    def _apply_filters(
        self,
        disputes: list[AdminDisputeSummary],
        status: str | None,
        priority: str | None,
        buyer_id: str | None,
        seller_id: str | None,
        date_from: str | None,
        date_to: str | None,
    ) -> list[AdminDisputeSummary]:
        result = disputes
        if status:
            result = [d for d in result if d.status == status]
        if priority:
            result = [d for d in result if d.priority == priority]
        if buyer_id:
            result = [d for d in result if d.buyer_id == buyer_id]
        if seller_id:
            result = [d for d in result if d.seller_id == seller_id]
        return result


class SupabaseAdminDisputesRepository:
    """Admin disputes backed by Supabase disputes table."""

    def __init__(self, settings: Settings | None = None) -> None:
        current = settings or get_settings()
        self._client = get_supabase_admin_client(current)

    def _require_client(self) -> None:
        if self._client is None:
            raise RuntimeError("Supabase is not configured for live admin disputes.")

    async def list_disputes(
        self,
        status: str | None = None,
        priority: str | None = None,
        buyer_id: str | None = None,
        seller_id: str | None = None,
        date_from: str | None = None,
        date_to: str | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> PaginatedAdminDisputes:
        self._require_client()
        try:
            query = self._client.table("disputes").select("*", count="exact")
            if status:
                query = query.eq("status", status)
            if priority:
                query = query.eq("priority", priority)
            if buyer_id:
                query = query.eq("raised_by", buyer_id)
            query = query.order("created_at", desc=True)
            start = (page - 1) * page_size
            query = query.range(start, start + page_size - 1)
            result = query.execute()

            items = [
                AdminDisputeSummary(
                    id=r.get("id", ""),
                    escrow_id=r.get("escrow_id"),
                    purchase_id=r.get("purchase_id"),
                    buyer_id=r.get("raised_by"),
                    buyer_name=None,
                    seller_id=r.get("defaulting_party"),
                    seller_name=None,
                    amount_paise=int(r.get("financial_impact_paise", 0)),
                    reason=r.get("reason", ""),
                    status=r.get("status", "open"),
                    priority=r.get("priority", "medium"),
                    created_at=self._parse_dt(r.get("created_at")),
                    updated_at=self._parse_dt(r.get("updated_at")),
                )
                for r in (result.data or [])
            ]
            total = result.count if result.count else len(items)
            return PaginatedAdminDisputes(
                items=items,
                page=page,
                page_size=page_size,
                total=total,
                total_pages=max(1, (total + page_size - 1) // page_size),
            )
        except Exception:
            return PaginatedAdminDisputes(page=page, page_size=page_size)

    async def get_dispute_detail(self, dispute_id: str) -> AdminDisputeSummary:
        self._require_client()
        try:
            result = self._client.table("disputes").select("*").eq("id", dispute_id).execute()
            if not result.data:
                raise ValueError(f"Dispute {dispute_id} not found")
            r = result.data[0]
            return AdminDisputeSummary(
                id=r.get("id", ""),
                escrow_id=r.get("escrow_id"),
                purchase_id=r.get("purchase_id"),
                buyer_id=r.get("raised_by"),
                buyer_name=None,
                seller_id=r.get("defaulting_party"),
                seller_name=None,
                amount_paise=int(r.get("financial_impact_paise", 0)),
                reason=r.get("reason", ""),
                status=r.get("status", "open"),
                priority=r.get("priority", "medium"),
                created_at=self._parse_dt(r.get("created_at")),
                updated_at=self._parse_dt(r.get("updated_at")),
            )
        except Exception as exc:
            raise exc

    async def update_dispute_status(
        self,
        dispute_id: str,
        status: str,
        reason: str = "",
        refund_amount_paise: int = 0,
        release_to_seller_paise: int = 0,
    ) -> DisputeActionResponse:
        self._require_client()
        try:
            self._client.table("disputes").update({
                "status": status,
                "metadata": {"resolution_reason": reason, "resolved_at": "now"},
            }).eq("id", dispute_id).execute()
            return DisputeActionResponse(
                id=dispute_id,
                status=status,
                message=f"Dispute {status} successfully.",
            )
        except Exception as exc:
            raise RuntimeError(f"Failed to update dispute: {exc}") from exc

    async def assign_dispute(self, dispute_id: str, admin_id: str) -> DisputeActionResponse:
        self._require_client()
        try:
            self._client.table("disputes").update({
                "metadata": {"assigned_to": admin_id, "assigned_at": "now"},
            }).eq("id", dispute_id).execute()
            return DisputeActionResponse(
                id=dispute_id,
                status="assigned",
                message="Dispute assigned successfully.",
            )
        except Exception as exc:
            raise RuntimeError(f"Failed to assign dispute: {exc}") from exc

    def _parse_dt(self, val: object) -> Any:
        from datetime import datetime
        if isinstance(val, str):
            try:
                return datetime.fromisoformat(val.replace("Z", "+00:00"))
            except ValueError:
                return datetime.utcnow()
        if isinstance(val, datetime):
            return val
        return datetime.utcnow()


def get_admin_disputes_repository(settings: Settings | None = None) -> object:
    current = settings or get_settings()
    if current.supabase_url and current.supabase_service_role_key:
        return SupabaseAdminDisputesRepository(current)
    return InMemoryAdminDisputesRepository()
