"""Support ticket repository — in-memory (demo) and Supabase (live) implementations."""

from __future__ import annotations

import logging
from typing import Any, Protocol

from app.core.config import Settings, get_settings
from app.core.exceptions import ApiError, ErrorCode
from app.db.supabase import get_supabase_admin_client
from app.repositories.state import state
from app.schemas.support import (
    SupportTicketData,
    SupportTicketMessageData,
    SupportTicketResponse,
    SupportMessageResponse,
    SupportSummary,
)
from app.schemas.common import now_utc

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Protocol
# ---------------------------------------------------------------------------


class SupportRepository(Protocol):
    def create_ticket(self, user_id: str, user_name: str, user_role: str, data: Any) -> SupportTicketResponse: ...
    def get_my_tickets(self, user_id: str) -> list[SupportTicketResponse]: ...
    def get_all_tickets(self) -> list[SupportTicketResponse]: ...
    def get_ticket(self, ticket_id: str) -> SupportTicketResponse | None: ...
    def update_ticket(self, ticket_id: str, update: Any) -> SupportTicketResponse: ...
    def get_messages(self, ticket_id: str) -> list[SupportMessageResponse]: ...
    def add_message(self, ticket_id: str, sender_id: str, sender_name: str, message: str, is_admin: bool) -> SupportMessageResponse: ...
    def get_summary(self) -> SupportSummary: ...


# ---------------------------------------------------------------------------
# In-memory
# ---------------------------------------------------------------------------


class InMemorySupportRepository:
    """Deterministic in-memory support ticket repository for demo mode."""

    def __init__(self) -> None:
        pass

    def _tickets(self) -> dict[str, SupportTicketData]:
        return state.support_tickets

    def create_ticket(self, user_id: str, user_name: str, user_role: str, data: Any) -> SupportTicketResponse:
        ticket = SupportTicketData(
            user_id=user_id,
            user_name=user_name,
            user_role=user_role,
            category=data.category.value,
            subject=data.subject,
            description=data.description,
            priority=data.priority.value,
            attachment_url=getattr(data, 'screenshot_url', None),
        )
        # Add initial message
        ticket.messages.append(SupportTicketMessageData(
            ticket_id=ticket.id,
            sender_id=user_id,
            sender_name=user_name,
            message=data.description,
            is_admin_reply=False,
        ))
        self._tickets()[ticket.id] = ticket
        return _ticket_to_response(ticket)

    def get_my_tickets(self, user_id: str) -> list[SupportTicketResponse]:
        return [
            _ticket_to_response(t)
            for t in self._tickets().values()
            if t.user_id == user_id
        ]

    def get_all_tickets(self) -> list[SupportTicketResponse]:
        return [_ticket_to_response(t) for t in self._tickets().values()]

    def get_ticket(self, ticket_id: str) -> SupportTicketResponse | None:
        t = self._tickets().get(ticket_id)
        return _ticket_to_response(t) if t else None

    def update_ticket(self, ticket_id: str, update: Any) -> SupportTicketResponse:
        t = self._tickets().get(ticket_id)
        if not t:
            raise ApiError(404, ErrorCode.RESOURCE_NOT_FOUND, f"Support ticket {ticket_id} not found")

        updates = {}
        if update.status:
            updates["status"] = update.status.value
            if update.status.value in ("Resolved", "Closed"):
                updates["resolved_at"] = now_utc()
        if update.assigned_admin is not None:
            updates["assigned_admin"] = update.assigned_admin

        updates["updated_at"] = now_utc()
        updated = t.model_copy(update=updates)
        self._tickets()[ticket_id] = updated
        return _ticket_to_response(updated)

    def get_messages(self, ticket_id: str) -> list[SupportMessageResponse]:
        t = self._tickets().get(ticket_id)
        if not t:
            return []
        return [
            SupportMessageResponse(
                id=msg.id,
                ticket_id=msg.ticket_id,
                sender_id=msg.sender_id,
                sender_name=msg.sender_name,
                message=msg.message,
                is_admin_reply=msg.is_admin_reply,
                created_at=msg.created_at,
            )
            for msg in t.messages
        ]

    def add_message(self, ticket_id: str, sender_id: str, sender_name: str, message: str, is_admin: bool) -> SupportMessageResponse:
        t = self._tickets().get(ticket_id)
        if not t:
            raise ApiError(404, ErrorCode.RESOURCE_NOT_FOUND, f"Support ticket {ticket_id} not found")

        msg = SupportTicketMessageData(
            ticket_id=ticket_id,
            sender_id=sender_id,
            sender_name=sender_name,
            message=message,
            is_admin_reply=is_admin,
        )
        t.messages.append(msg)
        t.updated_at = now_utc()
        self._tickets()[ticket_id] = t

        return SupportMessageResponse(
            id=msg.id,
            ticket_id=msg.ticket_id,
            sender_id=msg.sender_id,
            sender_name=msg.sender_name,
            message=msg.message,
            is_admin_reply=msg.is_admin_reply,
            created_at=msg.created_at,
        )

    def get_summary(self) -> SupportSummary:
        total = 0
        open_t = 0
        in_progress = 0
        resolved = 0
        closed = 0
        for t in self._tickets().values():
            total += 1
            if t.status == "Open":
                open_t += 1
            elif t.status == "In Progress":
                in_progress += 1
            elif t.status == "Resolved":
                resolved += 1
            elif t.status == "Closed":
                closed += 1
        return SupportSummary(
            total=total,
            open=open_t,
            in_progress=in_progress,
            resolved=resolved,
            closed=closed,
        )


# ---------------------------------------------------------------------------
# Supabase-backed
# ---------------------------------------------------------------------------


class SupabaseSupportRepository:
    """Support ticket repository backed by Supabase."""

    def __init__(self, settings: Settings | None = None) -> None:
        current = settings or get_settings()
        self._client = get_supabase_admin_client(current)
        self._in_memory = InMemorySupportRepository()

    def _require_client(self) -> None:
        if self._client is None:
            raise RuntimeError("Supabase is not configured for live mode.")

    def _get_user_name(self, user_id: str) -> str:
        try:
            result = self._client.table("profiles").select("full_name,role").eq("id", user_id).execute()
            if result.data:
                return result.data[0].get("full_name", "") or ""
        except Exception:
            pass
        return ""

    def _get_user_role(self, user_id: str) -> str:
        try:
            result = self._client.table("profiles").select("role").eq("id", user_id).execute()
            if result.data:
                return result.data[0].get("role", "consumer") or "consumer"
        except Exception:
            pass
        return "consumer"

    def create_ticket(self, user_id: str, user_name: str, user_role: str, data: Any) -> SupportTicketResponse:
        self._require_client()
        try:
            payload = {
                "user_id": user_id,
                "category": data.category.value,
                "subject": data.subject,
                "description": data.description,
                "priority": data.priority.value,
            }
            result = self._client.table("support_tickets").insert(payload).execute()
            if result.data:
                row = result.data[0]
                # Add initial message
                try:
                    self._client.table("support_ticket_messages").insert({
                        "ticket_id": row["id"],
                        "sender_id": user_id,
                        "message": data.description,
                        "is_admin_reply": False,
                    }).execute()
                except Exception:
                    pass
                return _row_to_ticket_response(row, user_name, user_role, 1)
        except Exception as exc:
            logger.warning("Supabase support create_ticket failed, using in-memory: %s", exc)
        return self._in_memory.create_ticket(user_id, user_name, user_role, data)

    def get_my_tickets(self, user_id: str) -> list[SupportTicketResponse]:
        self._require_client()
        try:
            result = self._client.table("support_tickets")\
                .select("*")\
                .eq("user_id", user_id)\
                .order("created_at", desc=True)\
                .execute()
            rows = result.data or []
            responses = []
            for row in rows:
                user_name = self._get_user_name(row.get("user_id", ""))
                user_role = self._get_user_role(row.get("user_id", ""))
                msg_count = self._get_message_count(row.get("id", ""))
                responses.append(_row_to_ticket_response(row, user_name, user_role, msg_count))
            return responses
        except Exception as exc:
            logger.warning("Supabase support get_my_tickets failed, using in-memory: %s", exc)
            return self._in_memory.get_my_tickets(user_id)

    def get_all_tickets(self) -> list[SupportTicketResponse]:
        self._require_client()
        try:
            result = self._client.table("support_tickets")\
                .select("*")\
                .order("created_at", desc=True)\
                .execute()
            rows = result.data or []
            responses = []
            for row in rows:
                user_name = self._get_user_name(row.get("user_id", ""))
                user_role = self._get_user_role(row.get("user_id", ""))
                msg_count = self._get_message_count(row.get("id", ""))
                responses.append(_row_to_ticket_response(row, user_name, user_role, msg_count))
            return responses
        except Exception as exc:
            logger.warning("Supabase support get_all_tickets failed, using in-memory: %s", exc)
            return self._in_memory.get_all_tickets()

    def get_ticket(self, ticket_id: str) -> SupportTicketResponse | None:
        self._require_client()
        try:
            result = self._client.table("support_tickets")\
                .select("*")\
                .eq("id", ticket_id)\
                .execute()
            if not result.data:
                return self._in_memory.get_ticket(ticket_id)
            row = result.data[0]
            user_name = self._get_user_name(row.get("user_id", ""))
            user_role = self._get_user_role(row.get("user_id", ""))
            msg_count = self._get_message_count(ticket_id)
            return _row_to_ticket_response(row, user_name, user_role, msg_count)
        except Exception as exc:
            logger.warning("Supabase support get_ticket failed, using in-memory: %s", exc)
            return self._in_memory.get_ticket(ticket_id)

    def update_ticket(self, ticket_id: str, update: Any) -> SupportTicketResponse:
        self._require_client()
        try:
            payload: dict[str, object] = {"updated_at": now_utc().isoformat()}
            if update.status:
                payload["status"] = update.status.value
                if update.status.value in ("Resolved", "Closed"):
                    payload["resolved_at"] = now_utc().isoformat()
            if update.assigned_admin is not None:
                payload["assigned_admin"] = update.assigned_admin
            result = self._client.table("support_tickets")\
                .update(payload)\
                .eq("id", ticket_id)\
                .execute()
            if result.data:
                row = result.data[0]
                user_name = self._get_user_name(row.get("user_id", ""))
                user_role = self._get_user_role(row.get("user_id", ""))
                msg_count = self._get_message_count(ticket_id)
                return _row_to_ticket_response(row, user_name, user_role, msg_count)
        except Exception as exc:
            logger.warning("Supabase support update_ticket failed, using in-memory: %s", exc)
        return self._in_memory.update_ticket(ticket_id, update)

    def get_messages(self, ticket_id: str) -> list[SupportMessageResponse]:
        self._require_client()
        try:
            result = self._client.table("support_ticket_messages")\
                .select("*")\
                .eq("ticket_id", ticket_id)\
                .order("created_at", asc=True)\
                .execute()
            rows = result.data or []
            responses = []
            for row in rows:
                sender_name = self._get_user_name(row.get("sender_id", ""))
                responses.append(SupportMessageResponse(
                    id=row.get("id", ""),
                    ticket_id=row.get("ticket_id", ""),
                    sender_id=row.get("sender_id", ""),
                    sender_name=sender_name,
                    message=row.get("message", ""),
                    is_admin_reply=bool(row.get("is_admin_reply", False)),
                    created_at=_parse_dt(row.get("created_at")),
                ))
            return responses
        except Exception as exc:
            logger.warning("Supabase support get_messages failed, using in-memory: %s", exc)
            return self._in_memory.get_messages(ticket_id)

    def add_message(self, ticket_id: str, sender_id: str, sender_name: str, message: str, is_admin: bool) -> SupportMessageResponse:
        self._require_client()
        try:
            payload = {
                "ticket_id": ticket_id,
                "sender_id": sender_id,
                "message": message,
                "is_admin_reply": is_admin,
            }
            result = self._client.table("support_ticket_messages").insert(payload).execute()
            if result.data:
                row = result.data[0]
                # Update ticket updated_at
                try:
                    self._client.table("support_tickets")\
                        .update({"updated_at": now_utc().isoformat()})\
                        .eq("id", ticket_id)\
                        .execute()
                except Exception:
                    pass
                return SupportMessageResponse(
                    id=row.get("id", ""),
                    ticket_id=row.get("ticket_id", ""),
                    sender_id=row.get("sender_id", ""),
                    sender_name=sender_name,
                    message=row.get("message", ""),
                    is_admin_reply=bool(row.get("is_admin_reply", False)),
                    created_at=_parse_dt(row.get("created_at")),
                )
        except Exception as exc:
            logger.warning("Supabase support add_message failed, using in-memory: %s", exc)
        return self._in_memory.add_message(ticket_id, sender_id, sender_name, message, is_admin)

    def get_summary(self) -> SupportSummary:
        self._require_client()
        try:
            result = self._client.table("support_tickets").select("status").execute()
            rows = result.data or []
            total = len(rows)
            open_t = sum(1 for r in rows if r.get("status") == "Open")
            in_progress = sum(1 for r in rows if r.get("status") == "In Progress")
            resolved = sum(1 for r in rows if r.get("status") == "Resolved")
            closed = sum(1 for r in rows if r.get("status") == "Closed")
            return SupportSummary(
                total=total, open=open_t, in_progress=in_progress,
                resolved=resolved, closed=closed,
            )
        except Exception as exc:
            logger.warning("Supabase support get_summary failed, using in-memory: %s", exc)
            return self._in_memory.get_summary()

    def _get_message_count(self, ticket_id: str) -> int:
        try:
            result = self._client.table("support_ticket_messages")\
                .select("id", count="exact")\
                .eq("ticket_id", ticket_id)\
                .execute()
            return result.count or 0
        except Exception:
            return 0


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _ticket_to_response(t: SupportTicketData) -> SupportTicketResponse:
    return SupportTicketResponse(
        id=t.id,
        user_id=t.user_id,
        user_name=t.user_name,
        user_role=t.user_role,
        category=t.category,
        subject=t.subject,
        description=t.description,
        priority=t.priority,
        status=t.status,
        assigned_admin=t.assigned_admin,
        created_at=t.created_at,
        updated_at=t.updated_at,
        resolved_at=t.resolved_at,
        message_count=len(t.messages),
    )


def _row_to_ticket_response(row: dict, user_name: str = "", user_role: str = "", msg_count: int = 0) -> SupportTicketResponse:
    return SupportTicketResponse(
        id=row.get("id", ""),
        user_id=row.get("user_id", ""),
        user_name=user_name,
        user_role=user_role,
        category=row.get("category", ""),
        subject=row.get("subject", ""),
        description=row.get("description", ""),
        priority=row.get("priority", "Medium"),
        status=row.get("status", "Open"),
        assigned_admin=row.get("assigned_admin"),
        created_at=_parse_dt(row.get("created_at")),
        updated_at=_parse_dt(row.get("updated_at")),
        resolved_at=_parse_dt(row.get("resolved_at")),
        message_count=msg_count,
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


# ---------------------------------------------------------------------------
# Factory
# ---------------------------------------------------------------------------


def get_support_repository(settings: Settings | None = None) -> SupportRepository:
    current = settings or get_settings()
    if current.supabase_url and current.supabase_service_role_key:
        return SupabaseSupportRepository(current)
    return InMemorySupportRepository()
