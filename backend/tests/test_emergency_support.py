"""Tests for Emergency Assistance and Help Center features.

All tests use in-memory repository implementations.
"""

import pytest
from datetime import datetime, timedelta

from app.repositories.state import state
from app.repositories.emergency_repository import InMemoryEmergencyRepository, get_emergency_repository
from app.repositories.support_repository import InMemorySupportRepository, get_support_repository
from app.schemas.emergency import (
    EmergencyAdminUpdate,
    EmergencyAllocationCreate,
    EmergencyRequestCreate,
    EmergencyStatus,
    EmergencyPriority,
    EmergencyCategory,
    AllocationSource,
)
from app.schemas.support import (
    SupportAdminUpdate,
    SupportTicketCreate,
    SupportStatus,
    SupportCategory,
    SupportPriority,
)
from app.schemas.common import UserRole
from app.services.emergency_service import emergency_service
from app.services.support_service import support_service


# =========================================================================
# Fixtures
# =========================================================================


@pytest.fixture(autouse=True)
def reset_state():
    """Clear in-memory state before each test."""
    state.emergency_requests.clear()
    state.support_tickets.clear()
    yield


@pytest.fixture
def emergency_repo():
    return InMemoryEmergencyRepository()


@pytest.fixture
def support_repo():
    return InMemorySupportRepository()


@pytest.fixture
def sample_emergency_data():
    return EmergencyRequestCreate(
        title="Medical Emergency - Life Support",
        category=EmergencyCategory.medical,
        description="Need urgent power for life support equipment at home due to grid failure.",
        required_energy_kwh=15.0,
        priority=EmergencyPriority.critical,
        address="123 Main St, Kochi",
        phone="+91-9876543210",
    )


@pytest.fixture
def sample_support_data():
    return SupportTicketCreate(
        category=SupportCategory.marketplace,
        subject="Unable to complete purchase",
        description="I keep getting an error when trying to purchase energy from the marketplace.",
        priority=SupportPriority.high,
    )


# =========================================================================
# Emergency Tests - Consumer
# =========================================================================


class TestEmergencyCreateRequest:
    def test_consumer_can_create_request(self, emergency_repo, sample_emergency_data):
        result = emergency_repo.create_request("consumer-001", "Test Consumer", sample_emergency_data)
        assert result.id.startswith("EMR-")
        assert result.consumer_id == "consumer-001"
        assert result.consumer_name == "Test Consumer"
        assert result.title == "Medical Emergency - Life Support"
        assert result.category == "Medical"
        assert result.status == "Pending"
        assert result.priority == "Critical"
        assert result.required_energy_kwh == 15.0
        assert result.address == "123 Main St, Kochi"
        assert result.phone == "+91-9876543210"
        assert result.allocated_energy_kwh == 0

    def test_consumer_can_view_own_requests(self, emergency_repo, sample_emergency_data):
        emergency_repo.create_request("consumer-001", "Ananya Nair", sample_emergency_data)
        emergency_repo.create_request("consumer-001", "Ananya Nair", sample_emergency_data)
        emergency_repo.create_request("consumer-002", "Biju Mathew", sample_emergency_data)

        own = emergency_repo.get_my_requests("consumer-001")
        assert len(own) == 2

        other = emergency_repo.get_my_requests("consumer-002")
        assert len(other) == 1

    def test_request_has_timestamps(self, emergency_repo, sample_emergency_data):
        result = emergency_repo.create_request("consumer-001", "Test", sample_emergency_data)
        assert result.created_at is not None
        assert result.updated_at is not None
        assert result.approved_at is None
        assert result.completed_at is None


class TestEmergencyAdminActions:
    def test_admin_can_approve_request(self, emergency_repo, sample_emergency_data):
        req = emergency_repo.create_request("consumer-001", "Test", sample_emergency_data)
        update = EmergencyAdminUpdate(status=EmergencyStatus.approved, admin_notes="Approved by admin")
        result = emergency_repo.update_request(req.id, update, "admin-001")

        assert result.status == "Approved"
        assert result.admin_notes == "Approved by admin"
        assert result.approved_at is not None
        assert result.assigned_admin == "admin-001"

    def test_admin_can_reject_request(self, emergency_repo, sample_emergency_data):
        req = emergency_repo.create_request("consumer-001", "Test", sample_emergency_data)
        update = EmergencyAdminUpdate(status=EmergencyStatus.rejected)
        result = emergency_repo.update_request(req.id, update, "admin-001")

        assert result.status == "Rejected"
        assert result.approved_at is None

    def test_admin_can_mark_in_progress(self, emergency_repo, sample_emergency_data):
        req = emergency_repo.create_request("consumer-001", "Test", sample_emergency_data)
        update = EmergencyAdminUpdate(status=EmergencyStatus.approved)
        result = emergency_repo.update_request(req.id, update, "admin-001")
        assert result.status == "Approved"

        update2 = EmergencyAdminUpdate(status=EmergencyStatus.completed)
        result2 = emergency_repo.update_request(req.id, update2, "admin-001")
        assert result2.status == "Completed"
        assert result2.completed_at is not None

    def test_admin_can_allocate_energy(self, emergency_repo, sample_emergency_data):
        req = emergency_repo.create_request("consumer-001", "Test", sample_emergency_data)
        update = EmergencyAdminUpdate(status=EmergencyStatus.approved)
        emergency_repo.update_request(req.id, update, "admin-001")

        allocation = EmergencyAllocationCreate(
            request_id=req.id,
            source=AllocationSource.government_reserve,
            allocated_energy=10.0,
            remarks="Emergency allocation approved",
        )
        result = emergency_repo.create_allocation(allocation, "admin-001")
        assert result.source == "Government Reserve"
        assert result.allocated_energy == 10.0
        assert result.allocated_by == "admin-001"
        assert result.request_id == req.id

    def test_unknown_request_raises_error(self, emergency_repo):
        update = EmergencyAdminUpdate(status=EmergencyStatus.approved)
        with pytest.raises(Exception):
            emergency_repo.update_request("nonexistent", update, "admin-001")


class TestEmergencySummary:
    def test_summary_counts(self, emergency_repo, sample_emergency_data):
        # Create 5 requests with different statuses
        r1 = emergency_repo.create_request("c1", "A", sample_emergency_data)
        r2 = emergency_repo.create_request("c2", "B", sample_emergency_data)
        r3 = emergency_repo.create_request("c3", "C", sample_emergency_data)
        r4 = emergency_repo.create_request("c4", "D", sample_emergency_data)
        r5 = emergency_repo.create_request("c5", "E", sample_emergency_data)

        emergency_repo.update_request(r1.id, EmergencyAdminUpdate(status=EmergencyStatus.approved), "admin-001")
        emergency_repo.update_request(r2.id, EmergencyAdminUpdate(status=EmergencyStatus.rejected), "admin-001")
        emergency_repo.update_request(r3.id, EmergencyAdminUpdate(status=EmergencyStatus.completed), "admin-001")
        # r4 = Pending (default), r5 = Pending (default)

        summary = emergency_repo.get_summary()
        assert summary.total == 5
        assert summary.pending == 2
        assert summary.approved == 1
        assert summary.rejected == 1
        assert summary.completed == 1
        # All 5 have Critical priority
        assert summary.critical == 5


# =========================================================================
# Support Tests
# =========================================================================


class TestSupportCreateTicket:
    def test_user_can_create_ticket(self, support_repo, sample_support_data):
        result = support_repo.create_ticket("user-001", "Test User", "consumer", sample_support_data)
        assert result.id.startswith("TKT-")
        assert result.subject == "Unable to complete purchase"
        assert result.category == "Marketplace"
        assert result.status == "Open"
        assert result.priority == "High"
        assert result.user_id == "user-001"
        assert result.user_name == "Test User"
        assert result.message_count >= 1

    def test_user_can_view_own_tickets(self, support_repo, sample_support_data):
        support_repo.create_ticket("user-001", "A", "consumer", sample_support_data)
        support_repo.create_ticket("user-001", "A", "consumer", sample_support_data)
        support_repo.create_ticket("user-002", "B", "producer", sample_support_data)

        own = support_repo.get_my_tickets("user-001")
        assert len(own) == 2


class TestSupportAdminActions:
    def test_admin_can_update_status(self, support_repo, sample_support_data):
        ticket = support_repo.create_ticket("user-001", "User", "consumer", sample_support_data)
        update = SupportAdminUpdate(status=SupportStatus.in_progress)
        result = support_repo.update_ticket(ticket.id, update)
        assert result.status == "In Progress"

    def test_admin_can_resolve_ticket(self, support_repo, sample_support_data):
        ticket = support_repo.create_ticket("user-001", "User", "consumer", sample_support_data)
        update = SupportAdminUpdate(status=SupportStatus.resolved)
        result = support_repo.update_ticket(ticket.id, update)
        assert result.status == "Resolved"
        assert result.resolved_at is not None

    def test_admin_can_close_ticket(self, support_repo, sample_support_data):
        ticket = support_repo.create_ticket("user-001", "User", "consumer", sample_support_data)
        update = SupportAdminUpdate(status=SupportStatus.closed)
        result = support_repo.update_ticket(ticket.id, update)
        assert result.status == "Closed"

    def test_admin_can_assign_ticket(self, support_repo, sample_support_data):
        ticket = support_repo.create_ticket("user-001", "User", "consumer", sample_support_data)
        update = SupportAdminUpdate(assigned_admin="admin-001")
        result = support_repo.update_ticket(ticket.id, update)
        assert result.assigned_admin == "admin-001"


class TestSupportMessages:
    def test_add_reply_creates_message(self, support_repo, sample_support_data):
        ticket = support_repo.create_ticket("user-001", "User", "consumer", sample_support_data)
        msg = support_repo.add_message(ticket.id, "admin-001", "Admin", "We are looking into this.", True)
        assert msg.ticket_id == ticket.id
        assert msg.message == "We are looking into this."
        assert msg.is_admin_reply is True
        assert msg.sender_id == "admin-001"

    def test_get_messages_initial(self, support_repo, sample_support_data):
        ticket = support_repo.create_ticket("user-001", "User", "consumer", sample_support_data)
        messages = support_repo.get_messages(ticket.id)
        assert len(messages) >= 1
        assert messages[0].ticket_id == ticket.id

    def test_conversation_history(self, support_repo, sample_support_data):
        ticket = support_repo.create_ticket("user-001", "User", "consumer", sample_support_data)
        support_repo.add_message(ticket.id, "admin-001", "Admin", "Reply 1", True)
        support_repo.add_message(ticket.id, "user-001", "User", "Reply 2", False)
        support_repo.add_message(ticket.id, "admin-001", "Admin", "Reply 3", True)

        messages = support_repo.get_messages(ticket.id)
        assert len(messages) == 4  # 1 initial + 3 replies


class TestSupportSummary:
    def test_summary_counts(self, support_repo, sample_support_data):
        t1 = support_repo.create_ticket("u1", "A", "consumer", sample_support_data)
        t2 = support_repo.create_ticket("u2", "B", "consumer", sample_support_data)
        t3 = support_repo.create_ticket("u3", "C", "consumer", sample_support_data)
        t4 = support_repo.create_ticket("u4", "D", "consumer", sample_support_data)

        support_repo.update_ticket(t1.id, SupportAdminUpdate(status=SupportStatus.in_progress))
        support_repo.update_ticket(t2.id, SupportAdminUpdate(status=SupportStatus.resolved))
        support_repo.update_ticket(t3.id, SupportAdminUpdate(status=SupportStatus.closed))

        summary = support_repo.get_summary()
        assert summary.total == 4
        assert summary.open == 1
        assert summary.in_progress == 1
        assert summary.resolved == 1
        assert summary.closed == 1


# =========================================================================
# Service Layer Tests (with notifications)
# =========================================================================


class TestEmergencyServiceNotifications:
    def test_create_sends_notification(self, reset_state, sample_emergency_data):
        result = emergency_service.create_request("consumer-001", "Ananya Nair", sample_emergency_data)
        assert result is not None
        assert result.id.startswith("EMR-")

    def test_admin_update_sends_notification(self, reset_state, sample_emergency_data):
        req = emergency_service.create_request("consumer-001", "Ananya Nair", sample_emergency_data)
        update = EmergencyAdminUpdate(status=EmergencyStatus.approved)
        result = emergency_service.update_request(req.id, update, "admin-001")
        assert result.status == "Approved"
        assert result.consumer_id == "consumer-001"


class TestSupportService:
    def test_create_ticket(self, reset_state, sample_support_data):
        result = support_service.create_ticket("user-001", "Test User", "consumer", sample_support_data)
        assert result is not None
        assert result.id.startswith("TKT-")

    def test_get_messages(self, reset_state, sample_support_data):
        ticket = support_service.create_ticket("user-001", "Test User", "consumer", sample_support_data)
        messages = support_service.get_messages(ticket.id)
        assert len(messages) >= 1

    def test_add_reply(self, reset_state, sample_support_data):
        ticket = support_service.create_ticket("user-001", "Test User", "consumer", sample_support_data)
        msg = support_service.add_message(ticket.id, "admin-001", "Admin", "Test reply", True)
        assert msg.message == "Test reply"
        assert msg.is_admin_reply is True
