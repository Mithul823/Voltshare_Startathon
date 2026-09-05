from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class KycStatus(str, Enum):
    not_submitted = "not_submitted"
    pending = "pending"
    verified = "verified"
    rejected = "rejected"
    resubmission_requested = "resubmission_requested"


class IdType(str, Enum):
    aadhar = "aadhar"
    pan = "pan"
    passport = "passport"
    driver_license = "driver_license"
    voter_id = "voter_id"


class KycSubmission(BaseModel):
    full_name: str = Field(..., min_length=1, max_length=200)
    date_of_birth: str = Field(..., description="YYYY-MM-DD")
    address: str = Field(..., min_length=1, max_length=500)
    district: str = Field(..., min_length=1, max_length=100)
    state: str = Field(..., min_length=1, max_length=100)
    pin_code: str = Field(..., min_length=4, max_length=10)
    id_type: IdType
    id_number: str = Field(..., min_length=1, max_length=50)
    phone: str = Field(..., min_length=8, max_length=15)
    # Producer-only fields
    renewable_energy_source: Optional[str] = Field(None, max_length=100)
    installed_capacity_kw: Optional[float] = Field(None, ge=0)
    plant_location: Optional[str] = Field(None, max_length=500)
    utility_license_number: Optional[str] = Field(None, max_length=100)
    bank_account_number: Optional[str] = Field(None, max_length=50)
    bank_ifsc_code: Optional[str] = Field(None, max_length=20)
    bank_account_holder: Optional[str] = Field(None, max_length=200)


class KycRecord(BaseModel):
    id: str
    user_id: str
    user_role: str
    full_name: str
    date_of_birth: str
    address: str
    district: str
    state: str
    pin_code: str
    id_type: str
    id_number: str
    phone: str
    selfie_url: Optional[str] = None
    id_proof_url: Optional[str] = None
    ownership_proof_url: Optional[str] = None
    status: KycStatus = KycStatus.not_submitted
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    remarks: Optional[str] = None
    submitted_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    renewable_energy_source: Optional[str] = None
    installed_capacity_kw: Optional[float] = None
    plant_location: Optional[str] = None
    utility_license_number: Optional[str] = None
    bank_account_number: Optional[str] = None
    bank_ifsc_code: Optional[str] = None
    bank_account_holder: Optional[str] = None

    model_config = {"from_attributes": True}


class KycRecordResponse(BaseModel):
    id: str
    user_id: str
    user_role: str
    full_name: str
    date_of_birth: str
    address: str
    district: str
    state: str
    pin_code: str
    id_type: str
    id_number: str
    phone: str
    selfie_url: Optional[str] = None
    id_proof_url: Optional[str] = None
    ownership_proof_url: Optional[str] = None
    status: KycStatus
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[datetime] = None
    remarks: Optional[str] = None
    submitted_at: Optional[datetime] = None
    renewable_energy_source: Optional[str] = None
    installed_capacity_kw: Optional[float] = None
    plant_location: Optional[str] = None
    utility_license_number: Optional[str] = None

    model_config = {"from_attributes": True}


class KycReviewRequest(BaseModel):
    status: KycStatus = Field(..., description="verified or rejected or resubmission_requested")
    remarks: Optional[str] = Field(None, max_length=500)


class KycAdminSummary(BaseModel):
    total_applications: int = 0
    pending: int = 0
    verified: int = 0
    rejected: int = 0
    resubmission_requested: int = 0


class PaginatedKycRecords(BaseModel):
    items: list[KycRecordResponse] = []
    page: int = 1
    page_size: int = 20
    total: int = 0
    total_pages: int = 0
