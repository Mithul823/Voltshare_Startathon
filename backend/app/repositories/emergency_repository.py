"""Emergency repository — in-memory (demo) and Supabase (live) implementations."""

from __future__ import annotations

import logging
from typing import Any, Protocol

from app.core.config import Settings, get_settings
from app.core.exceptions import ApiError, ErrorCode
from app.db.supabase import get_supabase_admin_client
from app.repositories.state import state
from app.schemas.emergency import (
    EmergencyAllocationData,
    EmergencyAllocationResponse,
    EmergencyRequestData,
    EmergencyRequestResponse,
    EmergencySummary,
)
from app.schemas.common import now_utc

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Protocol
# ---------------------------------------------------------------------------


class EmergencyRepository(Protocol):
    def create_request(self, consumer_id: str, consumer_name: str, data: Any) -> EmergencyRequestResponse: ...
    def get_my_requests(self, consumer_id: str) -> list[EmergencyRequestResponse]: ...
    def get_all_requests(self) -> list[EmergencyRequestResponse]: ...
    def get_request(self, request_id: str) -> EmergencyRequestResponse | None: ...
    def update_request(self, request_id: str, update: Any, admin_id: str) -> EmergencyRequestResponse: ...
    def create_allocation(self, data: Any, allocated_by: str) -> EmergencyAllocationResponse: ...
    def get_summary(self) -> EmergencySummary: ...


# ---------------------------------------------------------------------------
# In-memory
# ---------------------------------------------------------------------------


class InMemoryEmergencyRepository:
    """Deterministic in-memory emergency repository for demo mode."""

    def __init__(self) -> None:
        pass

    def _requests(self) -> dict[str, EmergencyRequestData]:
        return state.emergency_requests

    def create_request(self, consumer_id: str, consumer_name: str, data: Any) -> EmergencyRequestResponse:
        req = EmergencyRequestData(
            consumer_id=consumer_id,
            consumer_name=consumer_name,
            title=data.title,
            category=data.category.value,
            description=data.description,
            required_energy_kwh=data.required_energy_kwh,
            priority=data.priority.value,
            latitude=data.latitude,
            longitude=data.longitude,
            address=data.address,
            phone=data.phone,
            image_url=data.image_url,
            admin_notes=getattr(data, 'notes', None),
        )
        self._requests()[req.id] = req
        return _request_to_response(req)

    def get_my_requests(self, consumer_id: str) -> list[EmergencyRequestResponse]:
        return [
            _request_to_response(req)
            for req in self._requests().values()
            if req.consumer_id == consumer_id
        ]

    def get_all_requests(self) -> list[EmergencyRequestResponse]:
        return [_request_to_response(req) for req in self._requests().values()]

    def get_request(self, request_id: str) -> EmergencyRequestResponse | None:
        req = self._requests().get(request_id)
        return _request_to_response(req) if req else None

    def update_request(self, request_id: str, update: Any, admin_id: str) -> EmergencyRequestResponse:
        req = self._requests().get(request_id)
        if not req:
            raise ApiError(404, ErrorCode.RESOURCE_NOT_FOUND, f"Emergency request {request_id} not found")

        updates = {}
        if update.status:
            updates["status"] = update.status.value
            updates["assigned_admin"] = admin_id
            if update.status.value == "Approved":
                updates["approved_at"] = now_utc()
            if update.status.value == "Completed":
                updates["completed_at"] = now_utc()
        if update.admin_notes is not None:
            updates["admin_notes"] = update.admin_notes
        if update.allocated_energy_kwh is not None:
            updates["allocated_energy_kwh"] = update.allocated_energy_kwh

        updates["updated_at"] = now_utc()
        updated = req.model_copy(update=updates)
        self._requests()[request_id] = updated
        return _request_to_response(updated)

    def create_allocation(self, data: Any, allocated_by: str) -> EmergencyAllocationResponse:
        source_val = data.source.value
        alloc = EmergencyAllocationData(
            request_id=data.request_id,
            source=source_val,
            allocated_energy=data.allocated_energy,
            remarks=data.remarks,
            allocated_by=allocated_by,
        )
        req = self._requests().get(data.request_id)
        if req:
            req.allocations.append(alloc)
            current_allocated = req.allocated_energy_kwh
            req.allocated_energy_kwh = current_allocated + data.allocated_energy
            self._requests()[data.request_id] = req
        return EmergencyAllocationResponse(
            id=alloc.id,
            request_id=alloc.request_id,
            source=alloc.source,
            allocated_energy=alloc.allocated_energy,
            remarks=alloc.remarks,
            allocated_by=alloc.allocated_by,
            allocated_at=alloc.allocated_at,
        )

    def get_summary(self) -> EmergencySummary:
        total = 0
        pending = 0
        approved = 0
        rejected = 0
        completed = 0
        critical = 0
        for req in self._requests().values():
            total += 1
            if req.status == "Pending":
                pending += 1
            elif req.status == "Approved":
                approved += 1
            elif req.status == "Rejected":
                rejected += 1
            elif req.status == "Completed":
                completed += 1
            if req.priority == "Critical":
                critical += 1
        return EmergencySummary(
            total=total,
            pending=pending,
            approved=approved,
            rejected=rejected,
            completed=completed,
            critical=critical,
        )


# ---------------------------------------------------------------------------
# Supabase-backed
# ---------------------------------------------------------------------------


class SupabaseEmergencyRepository:
    """Emergency repository backed by Supabase."""

    def __init__(self, settings: Settings | None = None) -> None:
        current = settings or get_settings()
        self._client = get_supabase_admin_client(current)
        self._in_memory = InMemoryEmergencyRepository()

    def _require_client(self) -> None:
        if self._client is None:
            raise RuntimeError("Supabase is not configured for live mode.")

    def create_request(self, consumer_id: str, consumer_name: str, data: Any) -> EmergencyRequestResponse:
        self._require_client()
        try:
            payload = {
                "consumer_id": consumer_id,
                "title": data.title,
                "category": data.category.value,
                "description": data.description,
                "required_energy_kwh": data.required_energy_kwh,
                "priority": data.priority.value,
                "latitude": data.latitude,
                "longitude": data.longitude,
                "address": data.address,
                "phone": data.phone,
                "image_url": data.image_url,
                "admin_notes": getattr(data, 'notes', None),
            }
            result = self._client.table("emergency_requests").insert(payload).execute()
            if not result.data:
                return self._in_memory.create_request(consumer_id, consumer_name, data)
            row = result.data[0]
            return _row_to_response(row, consumer_name)
        except Exception as exc:
            logger.warning("Supabase emergency create failed, using in-memory: %s", exc)
            return self._in_memory.create_request(consumer_id, consumer_name, data)

    def get_my_requests(self, consumer_id: str) -> list[EmergencyRequestResponse]:
        self._require_client()
        try:
            result = self._client.table("emergency_requests")\
                .select("*")\
                .eq("consumer_id", consumer_id)\
                .order("created_at", desc=True)\
                .execute()
            rows = result.data or []
            responses = []
            for row in rows:
                consumer_name = self._get_user_name(row.get("consumer_id", ""))
                responses.append(_row_to_response(row, consumer_name))
            return responses
        except Exception as exc:
            logger.warning("Supabase emergency get_my_requests failed, using in-memory: %s", exc)
            return self._in_memory.get_my_requests(consumer_id)

    def get_all_requests(self) -> list[EmergencyRequestResponse]:
        self._require_client()
        try:
            result = self._client.table("emergency_requests")\
                .select("*")\
                .order("created_at", desc=True)\
                .execute()
            rows = result.data or []
            responses = []
            for row in rows:
                consumer_name = self._get_user_name(row.get("consumer_id", ""))
                responses.append(_row_to_response(row, consumer_name))
            return responses
        except Exception as exc:
            logger.warning("Supabase emergency get_all_requests failed, using in-memory: %s", exc)
            return self._in_memory.get_all_requests()

    def get_request(self, request_id: str) -> EmergencyRequestResponse | None:
        self._require_client()
        try:
            result = self._client.table("emergency_requests")\
                .select("*")\
                .eq("id", request_id)\
                .execute()
            if not result.data:
                return self._in_memory.get_request(request_id)
            row = result.data[0]
            consumer_name = self._get_user_name(row.get("consumer_id", ""))
            return _row_to_response(row, consumer_name)
        except Exception as exc:
            logger.warning("Supabase emergency get_request failed, using in-memory: %s", exc)
            return self._in_memory.get_request(request_id)

    def update_request(self, request_id: str, update: Any, admin_id: str) -> EmergencyRequestResponse:
        self._require_client()
        try:
            payload: dict[str, object] = {"updated_at": now_utc().isoformat()}
            if update.status:
                payload["status"] = update.status.value
                payload["assigned_admin"] = admin_id
                if update.status.value == "Approved":
                    payload["approved_at"] = now_utc().isoformat()
                if update.status.value == "Completed":
                    payload["completed_at"] = now_utc().isoformat()
            if update.admin_notes is not None:
                payload["admin_notes"] = update.admin_notes
            if update.allocated_energy_kwh is not None:
                payload["allocated_energy_kwh"] = update.allocated_energy_kwh

            result = self._client.table("emergency_requests")\
                .update(payload)\
                .eq("id", request_id)\
                .execute()
            if not result.data:
                return self._in_memory.update_request(request_id, update, admin_id)
            row = result.data[0]
            consumer_name = self._get_user_name(row.get("consumer_id", ""))
            return _row_to_response(row, consumer_name)
        except Exception as exc:
            logger.warning("Supabase emergency update_request failed, using in-memory: %s", exc)
            return self._in_memory.update_request(request_id, update, admin_id)

    def create_allocation(self, data: Any, allocated_by: str) -> EmergencyAllocationResponse:
        self._require_client()
        try:
            source_val = data.source.value
            payload = {
                "request_id": data.request_id,
                "source": source_val,
                "allocated_energy": data.allocated_energy,
                "remarks": data.remarks,
                "allocated_by": allocated_by,
            }
            result = self._client.table("emergency_allocations").insert(payload).execute()
            if result.data:
                row = result.data[0]
                return EmergencyAllocationResponse(
                    id=row.get("id", ""),
                    request_id=row.get("request_id", ""),
                    source=row.get("source", ""),
                    allocated_energy=float(row.get("allocated_energy", 0)),
                    remarks=row.get("remarks"),
                    allocated_by=row.get("allocated_by", ""),
                    allocated_at=_parse_dt(row.get("allocated_at")),
                )
        except Exception as exc:
            logger.warning("Supabase emergency create_allocation failed, using in-memory: %s", exc)
        return self._in_memory.create_allocation(data, allocated_by)

    def get_summary(self) -> EmergencySummary:
        self._require_client()
        try:
            all_reqs = self._client.table("emergency_requests").select("status, priority").execute()
            rows = all_reqs.data or []
            total = len(rows)
            pending = sum(1 for r in rows if r.get("status") == "Pending")
            approved = sum(1 for r in rows if r.get("status") == "Approved")
            rejected = sum(1 for r in rows if r.get("status") == "Rejected")
            completed = sum(1 for r in rows if r.get("status") == "Completed")
            critical = sum(1 for r in rows if r.get("priority") == "Critical")
            return EmergencySummary(
                total=total, pending=pending, approved=approved,
                rejected=rejected, completed=completed, critical=critical,
            )
        except Exception as exc:
            logger.warning("Supabase emergency get_summary failed, using in-memory: %s", exc)
            return self._in_memory.get_summary()

    def _get_user_name(self, user_id: str) -> str:
        try:
            result = self._client.table("profiles").select("full_name").eq("id", user_id).execute()
            if result.data:
                return result.data[0].get("full_name", "") or ""
        except Exception:
            pass
        return ""


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _request_to_response(req: EmergencyRequestData) -> EmergencyRequestResponse:
    return EmergencyRequestResponse(
        id=req.id,
        consumer_id=req.consumer_id,
        consumer_name=req.consumer_name,
        title=req.title,
        category=req.category,
        description=req.description,
        required_energy_kwh=req.required_energy_kwh,
        allocated_energy_kwh=req.allocated_energy_kwh,
        priority=req.priority,
        status=req.status,
        latitude=req.latitude,
        longitude=req.longitude,
        address=req.address,
        phone=req.phone,
        image_url=req.image_url,
        admin_notes=req.admin_notes,
        assigned_admin=req.assigned_admin,
        created_at=req.created_at,
        updated_at=req.updated_at,
        approved_at=req.approved_at,
        completed_at=req.completed_at,
    )


def _row_to_response(row: dict, consumer_name: str = "") -> EmergencyRequestResponse:
    return EmergencyRequestResponse(
        id=row.get("id", ""),
        consumer_id=row.get("consumer_id", ""),
        consumer_name=consumer_name,
        title=row.get("title", ""),
        category=row.get("category", ""),
        description=row.get("description", ""),
        required_energy_kwh=float(row.get("required_energy_kwh", 0)),
        allocated_energy_kwh=float(row.get("allocated_energy_kwh", 0)),
        priority=row.get("priority", "Medium"),
        status=row.get("status", "Pending"),
        latitude=_float_or_none(row.get("latitude")),
        longitude=_float_or_none(row.get("longitude")),
        address=row.get("address"),
        phone=row.get("phone"),
        image_url=row.get("image_url"),
        admin_notes=row.get("admin_notes"),
        assigned_admin=row.get("assigned_admin"),
        created_at=_parse_dt(row.get("created_at")),
        updated_at=_parse_dt(row.get("updated_at")),
        approved_at=_parse_dt(row.get("approved_at")),
        completed_at=_parse_dt(row.get("completed_at")),
    )


def _parse_dt(val: object) -> Any:
    from datetime import datetime
    if isinstance(val, str):
        try:
            return datetime.fromisoformat(val.replace("Z", "+00:00"))
        except ValueError:
            return datetime.utcnow()
    if isinstance(val, datetime):
        return val
    return datetime.utcnow()


def _float_or_none(val: object) -> float | None:
    if val is None:
        return None
    try:
        return float(val)
    except (ValueError, TypeError):
        return None


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------


def get_emergency_repository(settings: Settings | None = None) -> EmergencyRepository:
    current = settings or get_settings()
    if current.supabase_url and current.supabase_service_role_key:
        return SupabaseEmergencyRepository(current)
    return InMemoryEmergencyRepository()
