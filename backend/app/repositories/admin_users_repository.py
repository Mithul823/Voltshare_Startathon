"""Admin users repository — manages user listing, search, filtering, and status updates.

In demo mode, uses in-memory state. In live mode, queries profiles from Supabase.
"""

from __future__ import annotations

from typing import Any

from app.core.config import Settings, get_settings
from app.db.supabase import get_supabase_admin_client
from app.schemas.admin_users import AdminUserSummary, PaginatedAdminUsers, UserStatusUpdateResponse
from app.schemas.common import UserRole
from app.repositories.state import state


class InMemoryAdminUsersRepository:
    """Deterministic mock admin users data for demo mode."""

    async def list_users(
        self,
        search: str | None = None,
        role: str | None = None,
        status: str | None = None,
        kyc_status: str | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> PaginatedAdminUsers:
        all_users = self._get_mock_users()
        filtered = self._apply_filters(all_users, search, role, status, kyc_status)
        total = len(filtered)
        total_pages = max(1, (total + page_size - 1) // page_size)
        start = (page - 1) * page_size
        items = filtered[start:start + page_size]
        return PaginatedAdminUsers(
            items=items,
            page=page,
            page_size=page_size,
            total=total,
            total_pages=total_pages,
        )

    async def get_user_detail(self, user_id: str) -> AdminUserSummary:
        for user in self._get_mock_users():
            if user.id == user_id:
                return user
        raise ValueError(f"User {user_id} not found")

    async def update_user_status(self, user_id: str, is_active: bool) -> UserStatusUpdateResponse:
        return UserStatusUpdateResponse(
            id=user_id,
            is_active=is_active,
            message="User status updated successfully.",
        )

    def _get_mock_users(self) -> list[AdminUserSummary]:
        from datetime import datetime, timedelta
        now = datetime.utcnow()
        return [
            AdminUserSummary(
                id="admin-001", full_name="Admin VoltShare", email="admin@voltshare-demo.local",
                role=UserRole.admin, is_active=True, email_verified=True, kyc_status="verified",
                city="Kochi", district="Ernakulam", created_at=now - timedelta(days=90),
                listings_count=0, purchases_count=0, disputes_count=0,
            ),
            AdminUserSummary(
                id="consumer-001", full_name="Ananya Nair", email="consumer1@voltshare-demo.local",
                role=UserRole.consumer, is_active=True, email_verified=True, kyc_status="verified",
                city="Thiruvananthapuram", district="Thiruvananthapuram", created_at=now - timedelta(days=30),
                listings_count=0, purchases_count=3, disputes_count=1,
            ),
            AdminUserSummary(
                id="consumer-002", full_name="Biju Mathew", email="consumer2@voltshare-demo.local",
                role=UserRole.consumer, is_active=False, email_verified=True, kyc_status="pending",
                city="Kozhikode", district="Kozhikode", created_at=now - timedelta(days=15),
                listings_count=0, purchases_count=1, disputes_count=0,
            ),
            AdminUserSummary(
                id="producer-001", full_name="Chandra Devi", email="producer1@voltshare-demo.local",
                role=UserRole.producer, is_active=True, email_verified=True, kyc_status="verified",
                city="Thodupuzha", district="Idukki", created_at=now - timedelta(days=60),
                listings_count=5, purchases_count=0, disputes_count=0,
            ),
            AdminUserSummary(
                id="producer-002", full_name="Deepak Menon", email="producer2@voltshare-demo.local",
                role=UserRole.producer, is_active=True, email_verified=False, kyc_status="submitted",
                city="Thrissur", district="Thrissur", created_at=now - timedelta(days=7),
                listings_count=2, purchases_count=0, disputes_count=1,
            ),
            AdminUserSummary(
                id="extra-001", full_name="Priya Sharma", email="priya@example.com",
                role=UserRole.consumer, is_active=True, email_verified=True, kyc_status="verified",
                city="Kochi", district="Ernakulam", created_at=now - timedelta(days=45),
                listings_count=0, purchases_count=7, disputes_count=0,
            ),
            AdminUserSummary(
                id="extra-002", full_name="Ravi Krishnan", email="ravi@example.com",
                role=UserRole.producer, is_active=True, email_verified=True, kyc_status="verified",
                city="Alappuzha", district="Alappuzha", created_at=now - timedelta(days=20),
                listings_count=3, purchases_count=0, disputes_count=2,
            ),
        ]

    def _apply_filters(
        self,
        users: list[AdminUserSummary],
        search: str | None,
        role: str | None,
        status: str | None,
        kyc_status: str | None,
    ) -> list[AdminUserSummary]:
        result = users
        if search:
            lower = search.lower()
            result = [
                u for u in result
                if lower in u.full_name.lower() or (u.email and lower in u.email.lower())
            ]
        if role:
            result = [u for u in result if u.role.value == role]
        if status == "active":
            result = [u for u in result if u.is_active]
        elif status == "suspended":
            result = [u for u in result if not u.is_active]
        if kyc_status:
            result = [u for u in result if u.kyc_status == kyc_status]
        return result


class SupabaseAdminUsersRepository:
    """Admin users backed by Supabase profiles table."""

    def __init__(self, settings: Settings | None = None) -> None:
        current = settings or get_settings()
        self._client = get_supabase_admin_client(current)

    def _require_client(self) -> None:
        if self._client is None:
            raise RuntimeError("Supabase is not configured for live admin users.")

    async def list_users(
        self,
        search: str | None = None,
        role: str | None = None,
        status: str | None = None,
        kyc_status: str | None = None,
        page: int = 1,
        page_size: int = 20,
    ) -> PaginatedAdminUsers:
        self._require_client()
        try:
            query = self._client.table("profiles").select(
                "id, full_name, email, role, is_active, email_verified, kyc_status, city, district, created_at",
                count="exact",
            )

            if search:
                query = query.or_(f"full_name.ilike.%{search}%,email.ilike.%{search}%")
            if role:
                query = query.eq("role", role)
            if status == "active":
                query = query.eq("is_active", True)
            elif status == "suspended":
                query = query.eq("is_active", False)
            if kyc_status:
                query = query.eq("kyc_status", kyc_status)

            query = query.order("created_at", desc=True)
            start = (page - 1) * page_size
            query = query.range(start, start + page_size - 1)

            result = query.execute()
            items = [
                AdminUserSummary(
                    id=r.get("id", ""),
                    full_name=r.get("full_name", "VoltShare User"),
                    email=r.get("email"),
                    role=UserRole(r["role"]) if r.get("role") else UserRole.consumer,
                    is_active=r.get("is_active", True),
                    email_verified=r.get("email_verified", False),
                    kyc_status=r.get("kyc_status"),
                    city=r.get("city"),
                    district=r.get("district"),
                    created_at=self._parse_dt(r.get("created_at")),
                )
                for r in (result.data or [])
            ]
            total = result.count if result.count else len(items)

            return PaginatedAdminUsers(
                items=items,
                page=page,
                page_size=page_size,
                total=total,
                total_pages=max(1, (total + page_size - 1) // page_size),
            )
        except Exception:
            return PaginatedAdminUsers(page=page, page_size=page_size)

    async def get_user_detail(self, user_id: str) -> AdminUserSummary:
        self._require_client()
        try:
            result = self._client.table("profiles").select("*").eq("id", user_id).execute()
            if not result.data:
                raise ValueError(f"User {user_id} not found")
            r = result.data[0]
            return AdminUserSummary(
                id=r.get("id", ""),
                full_name=r.get("full_name", "VoltShare User"),
                email=r.get("email"),
                role=UserRole(r["role"]) if r.get("role") else UserRole.consumer,
                is_active=r.get("is_active", True),
                email_verified=r.get("email_verified", False),
                kyc_status=r.get("kyc_status"),
                city=r.get("city"),
                district=r.get("district"),
                created_at=self._parse_dt(r.get("created_at")),
            )
        except Exception as exc:
            raise exc

    async def update_user_status(self, user_id: str, is_active: bool) -> UserStatusUpdateResponse:
        self._require_client()
        try:
            self._client.table("profiles").update({"is_active": is_active}).eq("id", user_id).execute()
            return UserStatusUpdateResponse(
                id=user_id,
                is_active=is_active,
                message="User status updated successfully.",
            )
        except Exception as exc:
            raise RuntimeError(f"Failed to update user status: {exc}") from exc

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


def get_admin_users_repository(settings: Settings | None = None) -> object:
    current = settings or get_settings()
    if current.supabase_url and current.supabase_service_role_key:
        return SupabaseAdminUsersRepository(current)
    return InMemoryAdminUsersRepository()
