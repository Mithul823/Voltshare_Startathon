"""Emergency assistance schemas for VoltShare."""

from datetime import datetime
from enum import Enum
from typing import Any

from pydantic import Field

from app.schemas.common import ApiModel, new_id, now_utc


class EmergencyCategory(str, Enum):
    medical = "Medical"
    natural_disaster = "Natural Disaster"
    fire = "Fire"
    flood = "Flood"
    hospital = "Hospital"
    government_relief = "Government Relief"
    other = "Other"


class EmergencyPriority(str, Enum):
    low = "Low"
    medium = "Medium"
    high = "High"
    critical = "Critical"


class EmergencyStatus(str, Enum):
    pending = "Pending"
    approved = "Approved"
    rejected = "Rejected"
    in_progress = "In Progress"
    completed = "Completed"


class AllocationSource(str, Enum):
    government_reserve = "Government Reserve"
    partner_producer = "Partner Producer"
    community_storage = "Community Storage"
    battery_backup = "Battery Backup"
    emergency_grid = "Emergency Grid"


# ---------------------------------------------------------------------------
# Request / Response schemas
# ---------------------------------------------------------------------------


class EmergencyRequestCreate(ApiModel):
    title: str = Field(..., min_length=3, max_length=200)
    category: EmergencyCategory
    description: str = Field(..., min_length=10, max_length=2000)
    required_energy_kwh: float = Field(..., gt=0, le=10000)
    priority: EmergencyPriority = EmergencyPriority.medium
    latitude: float | None = None
    longitude: float | None = None
    address: str | None = Field(None, max_length=500)
    phone: str | None = Field(None, max_length=20)
    image_url: str | None = Field(None, max_length=500)
    notes: str | None = Field(None, max_length=1000)


class EmergencyRequestResponse(ApiModel):
    id: str
    consumer_id: str
    consumer_name: str = ""
    title: str
    category: str
    description: str
    required_energy_kwh: float
    allocated_energy_kwh: float = 0
    priority: str
    status: str
    latitude: float | None = None
    longitude: float | None = None
    address: str | None = None
    phone: str | None = None
    image_url: str | None = None
    admin_notes: str | None = None
    assigned_admin: str | None = None
    created_at: datetime
    updated_at: datetime
    approved_at: datetime | None = None
    completed_at: datetime | None = None


class EmergencyAllocationCreate(ApiModel):
    request_id: str
    source: AllocationSource
    allocated_energy: float = Field(..., gt=0)
    remarks: str | None = Field(None, max_length=500)


class EmergencyAllocationResponse(ApiModel):
    id: str
    request_id: str
    source: str
    allocated_energy: float
    remarks: str | None = None
    allocated_by: str
    allocated_at: datetime


class EmergencyAdminUpdate(ApiModel):
    status: EmergencyStatus | None = None
    admin_notes: str | None = Field(None, max_length=1000)
    allocated_energy_kwh: float | None = Field(None, ge=0)
    allocation_source: AllocationSource | None = None
    allocation_remarks: str | None = Field(None, max_length=500)


class EmergencySummary(ApiModel):
    total: int = 0
    pending: int = 0
    approved: int = 0
    rejected: int = 0
    completed: int = 0
    critical: int = 0


# ---------------------------------------------------------------------------
# Internal data model (used by in-memory repository)
# ---------------------------------------------------------------------------


class EmergencyRequestData(ApiModel):
    id: str = Field(default_factory=lambda: new_id("EMR"))
    consumer_id: str
    consumer_name: str = ""
    title: str
    category: str
    description: str
    required_energy_kwh: float
    allocated_energy_kwh: float = 0
    priority: str
    status: str = "Pending"
    latitude: float | None = None
    longitude: float | None = None
    address: str | None = None
    phone: str | None = None
    image_url: str | None = None
    admin_notes: str | None = None
    assigned_admin: str | None = None
    created_at: datetime = Field(default_factory=now_utc)
    updated_at: datetime = Field(default_factory=now_utc)
    approved_at: datetime | None = None
    completed_at: datetime | None = None
    allocations: list["EmergencyAllocationData"] = Field(default_factory=list)


class EmergencyAllocationData(ApiModel):
    id: str = Field(default_factory=lambda: new_id("EMA"))
    request_id: str
    source: str
    allocated_energy: float
    remarks: str | None = None
    allocated_by: str
    allocated_at: datetime = Field(default_factory=now_utc)
