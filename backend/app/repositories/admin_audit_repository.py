"""Admin audit repository — provides a unified audit log combining multiple event sources.

In demo mode, uses in-memory state. In live mode, queries from Supabase audit/security tables.
"""

from __future__ import annotations

from typing import Any

from app.core.config import Settings, get_settings
from app.db.supabase import get_supabase_admin_client
from app.schemas.admin_audit import AdminAuditLog, PaginatedAuditLogs
from app.repositories.state import state


class InMemoryAdminAuditRepository:
    """Deterministic mock audit logs for demo mode."""

    async def list_audit_logs(
        self,
        search: str | None = None,
        event_type: str | None = None,
        severity: str | None = None,
        actor_id: str | None = None,
        resource_type: str | None = None,
        date_from: str | None = None,
        date_to: str | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> PaginatedAuditLogs:
        all_logs = self._get_mock_logs()
        filtered = self._apply_filters(all_logs, search, event_type, severity, actor_id, resource_type, date_from, date_to)
        total = len(filtered)
        total_pages = max(1, (total + page_size - 1) // page_size)
        start = (page - 1) * page_size
        items = filtered[start:start + page_size]
        return PaginatedAuditLogs(
            items=items,
            page=page,
            page_size=page_size,
            total=total,
            total_pages=total_pages,
        )

    def _get_mock_logs(self) -> list[AdminAuditLog]:
        from datetime import datetime, timedelta
        now = datetime.utcnow()
        return [
            AdminAuditLog(
                id="aud-001", timestamp=now - timedelta(minutes=2),
                event_type="authentication", severity="info",
                actor_user_id="admin-001", actor_name="Admin VoltShare", actor_role="admin",
                action="admin_login", resource_type="session", resource_id="admin-001",
                summary="Admin logged in successfully from trusted device.",
                status="succeeded",
            ),
            AdminAuditLog(
                id="aud-002", timestamp=now - timedelta(minutes=15),
                event_type="marketplace", severity="info",
                actor_user_id="producer-001", actor_name="Chandra Devi", actor_role="producer",
                action="listing_created", resource_type="listing", resource_id="lst-001",
                summary="New solar energy listing created — 50 kWh at ₹5.80/kWh.",
                status="succeeded",
            ),
            AdminAuditLog(
                id="aud-003", timestamp=now - timedelta(hours=1),
                event_type="financial", severity="info",
                actor_user_id="consumer-001", actor_name="Ananya Nair", actor_role="consumer",
                action="escrow_funded", resource_type="escrow", resource_id="escrow-001",
                summary="Escrow funded successfully — ₹1,250 held for energy purchase.",
                status="succeeded",
            ),
            AdminAuditLog(
                id="aud-004", timestamp=now - timedelta(hours=2),
                event_type="security", severity="warning",
                actor_user_id=None, actor_name="System", actor_role=None,
                action="failed_login", resource_type="session", resource_id="unknown",
                summary="3 failed login attempts detected for consumer1@voltshare-demo.local.",
                status="failed",
            ),
            AdminAuditLog(
                id="aud-005", timestamp=now - timedelta(hours=3),
                event_type="dispute", severity="critical",
                actor_user_id="consumer-001", actor_name="Ananya Nair", actor_role="consumer",
                action="dispute_raised", resource_type="dispute", resource_id="dsp-001",
                summary="Dispute raised: Energy shortfall — 8.5 kWh received instead of 10 kWh.",
                status="open", metadata_summary="Amount: ₹1,250",
            ),
            AdminAuditLog(
                id="aud-006", timestamp=now - timedelta(hours=5),
                event_type="admin_action", severity="info",
                actor_user_id="admin-001", actor_name="Admin VoltShare", actor_role="admin",
                action="user_suspended", resource_type="user", resource_id="consumer-002",
                summary="User Biju Mathew suspended: Payment compliance issue.",
                status="succeeded",
            ),
            AdminAuditLog(
                id="aud-007", timestamp=now - timedelta(hours=8),
                event_type="marketplace", severity="info",
                actor_user_id="producer-002", actor_name="Deepak Menon", actor_role="producer",
                action="purchase_completed", resource_type="purchase", resource_id="purch-003",
                summary="Energy purchase completed — 5 kWh at ₹4.50/kWh.",
                status="succeeded",
            ),
            AdminAuditLog(
                id="aud-008", timestamp=now - timedelta(hours=12),
                event_type="settlement", severity="info",
                actor_user_id="system", actor_name="System", actor_role=None,
                action="settlement_completed", resource_type="settlement", resource_id="stl-001",
                summary="Settlement of ₹820 released to producer Chandra Devi.",
                status="succeeded",
            ),
            AdminAuditLog(
                id="aud-009", timestamp=now - timedelta(days=1),
                event_type="financial", severity="info",
                actor_user_id="consumer-001", actor_name="Ananya Nair", actor_role="consumer",
                action="wallet_deposit", resource_type="wallet", resource_id="wallet-c1",
                summary="Wallet deposit of ₹2,000 via UPI completed.",
                status="succeeded",
            ),
            AdminAuditLog(
                id="aud-010", timestamp=now - timedelta(days=2),
                event_type="security", severity="critical",
                actor_user_id=None, actor_name="System", actor_role=None,
                action="anomaly_detected", resource_type="energy", resource_id="meter-012",
                summary="Unusual consumption pattern detected for consumer #1042.",
                status="investigating",
            ),
            AdminAuditLog(
                id="aud-011", timestamp=now - timedelta(days=3),
                event_type="admin_action", severity="info",
                actor_user_id="admin-001", actor_name="Admin VoltShare", actor_role="admin",
                action="dispute_resolved", resource_type="dispute", resource_id="dsp-003",
                summary="Dispute resolved: Settlement adjustment of ₹350 credited to buyer.",
                status="succeeded",
            ),
            AdminAuditLog(
                id="aud-012", timestamp=now - timedelta(days=5),
                event_type="authentication", severity="warning",
                actor_user_id="system", actor_name="System", actor_role=None,
                action="new_device_login", resource_type="session", resource_id="consumer-002",
                summary="New device login detected for Biju Mathew from Kozhikode.",
                status="succeeded",
            ),
        ]

    def _apply_filters(
        self,
        logs: list[AdminAuditLog],
        search: str | None,
        event_type: str | None,
        severity: str | None,
        actor_id: str | None,
        resource_type: str | None,
        date_from: str | None,
        date_to: str | None,
    ) -> list[AdminAuditLog]:
        result = logs
        if search:
            lower = search.lower()
            result = [
                l for l in result
                if lower in l.summary.lower() or lower in l.action.lower() or (l.actor_name and lower in l.actor_name.lower())
            ]
        if event_type:
            result = [l for l in result if l.event_type == event_type]
        if severity:
            result = [l for l in result if l.severity == severity]
        if actor_id:
            result = [l for l in result if l.actor_user_id == actor_id]
        if resource_type:
            result = [l for l in result if l.resource_type == resource_type]
        return result


class SupabaseAdminAuditRepository:
    """Admin audit logs backed by Supabase security_events and audit tables."""

    def __init__(self, settings: Settings | None = None) -> None:
        current = settings or get_settings()
        self._client = get_supabase_admin_client(current)

    def _require_client(self) -> None:
        if self._client is None:
            raise RuntimeError("Supabase is not configured for live admin audit logs.")

    async def list_audit_logs(
        self,
        search: str | None = None,
        event_type: str | None = None,
        severity: str | None = None,
        actor_id: str | None = None,
        resource_type: str | None = None,
        date_from: str | None = None,
        date_to: str | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> PaginatedAuditLogs:
        self._require_client()
        try:
            results = []
            total = 0

            # Try to get security events
            try:
                query = self._client.table("security_events").select("*", count="exact").order("created_at", desc=True)
                if event_type:
                    query = query.eq("event_type", event_type)
                if severity:
                    query = query.eq("severity", severity)
                if actor_id:
                    query = query.eq("user_id", actor_id)
                if resource_type:
                    query = query.eq("resource_type", resource_type)
                start = (page - 1) * page_size
                query = query.range(start, start + page_size - 1)
                sec_result = query.execute()
                for r in (sec_result.data or []):
                    results.append(AdminAuditLog(
                        id=r.get("id", ""),
                        timestamp=self._parse_dt(r.get("created_at")),
                        event_type=r.get("event_type", "security"),
                        severity=r.get("severity", "info"),
                        actor_user_id=r.get("user_id"),
                        actor_name=None,
                        actor_role=None,
                        action=r.get("action", ""),
                        resource_type=r.get("resource_type", "system"),
                        resource_id=r.get("resource_id"),
                        summary=r.get("description", ""),
                        status=r.get("status"),
                    ))
                total = sec_result.count if sec_result.count else len(results)
            except Exception:
                pass

            # Also try audit_events if the table exists
            try:
                audit_result = self._client.table("audit_events").select("*", count="exact").order("created_at", desc=True).limit(10).execute()
                for r in (audit_result.data or []):
                    results.append(AdminAuditLog(
                        id=r.get("id", ""),
                        timestamp=self._parse_dt(r.get("created_at")),
                        event_type="admin_action",
                        severity="info",
                        actor_user_id=r.get("actor_id"),
                        actor_name=None,
                        actor_role=None,
                        action=r.get("action", ""),
                        resource_type=r.get("resource_type", "system"),
                        resource_id=r.get("resource_id"),
                        summary=r.get("description", ""),
                        status=r.get("status"),
                    ))
            except Exception:
                pass

            # Return empty results if no tables found
            if not results:
                return PaginatedAuditLogs(
                    items=[],
                    page=page,
                    page_size=page_size,
                    total=0,
                    total_pages=0,
                )

            # Apply search filter manually
            if search:
                lower = search.lower()
                results = [
                    l for l in results
                    if lower in l.summary.lower() or lower in l.action.lower()
                ]

            results.sort(key=lambda l: l.timestamp, reverse=True)
            total = len(results)
            start_idx = (page - 1) * page_size
            page_items = results[start_idx:start_idx + page_size]

            return PaginatedAuditLogs(
                items=page_items,
                page=page,
                page_size=page_size,
                total=total,
                total_pages=max(1, (total + page_size - 1) // page_size),
            )
        except Exception:
            return PaginatedAuditLogs(page=page, page_size=page_size)

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


def get_admin_audit_repository(settings: Settings | None = None) -> object:
    current = settings or get_settings()
    if current.supabase_url and current.supabase_service_role_key:
        return SupabaseAdminAuditRepository(current)
    return InMemoryAdminAuditRepository()
