from datetime import datetime, timezone
from threading import RLock
from typing import Optional

from app.core.config import get_settings
from app.core.exceptions import ApiError, ErrorCode
from app.repositories.state import state
from app.schemas.common import new_id, now_utc
from app.schemas.kyc import KycRecord, KycRecordResponse, KycStatus, KycSubmission, PaginatedKycRecords, KycAdminSummary

_settings = get_settings()


class KycRepository:
    """In-memory KYC repository for demo/mock mode."""

    def __init__(self) -> None:
        self._lock = RLock()
        self._records: dict[str, KycRecord] = {}

    async def submit_kyc(self, user_id: str, user_role: str, submission: KycSubmission) -> KycRecord:
        with self._lock:
            existing = self._get_by_user_id(user_id)
            if existing and existing.status in {KycStatus.pending, KycStatus.verified}:
                raise ApiError(409, ErrorCode.VALIDATION_FAILED, "KYC is already submitted or verified.")
            record = KycRecord(
                id=new_id("KYC"),
                user_id=user_id,
                user_role=user_role,
                full_name=submission.full_name,
                date_of_birth=submission.date_of_birth,
                address=submission.address,
                district=submission.district,
                state=submission.state,
                pin_code=submission.pin_code,
                id_type=submission.id_type.value,
                id_number=submission.id_number,
                phone=submission.phone,
                status=KycStatus.pending,
                submitted_at=now_utc(),
                updated_at=now_utc(),
                renewable_energy_source=submission.renewable_energy_source,
                installed_capacity_kw=submission.installed_capacity_kw,
                plant_location=submission.plant_location,
                utility_license_number=submission.utility_license_number,
                bank_account_number=submission.bank_account_number,
                bank_ifsc_code=submission.bank_ifsc_code,
                bank_account_holder=submission.bank_account_holder,
            )
            self._records[record.id] = record
            return record

    async def get_my_kyc(self, user_id: str) -> Optional[KycRecord]:
        return self._get_by_user_id(user_id)

    async def review_kyc(self, kyc_id: str, status: KycStatus, remarks: Optional[str], reviewed_by: str) -> KycRecord:
        with self._lock:
            record = self._records.get(kyc_id)
            if not record:
                raise ApiError(404, ErrorCode.RESOURCE_NOT_FOUND, "KYC record not found.")
            if record.status != KycStatus.pending and status != KycStatus.resubmission_requested:
                if status in {KycStatus.verified, KycStatus.rejected}:
                    pass  # Allow override
            updated = record.model_copy(update={
                "status": status,
                "reviewed_by": reviewed_by,
                "reviewed_at": now_utc(),
                "remarks": remarks,
                "updated_at": now_utc(),
            })
            self._records[kyc_id] = updated
            return updated

    async def list_all(self, status: Optional[str] = None, search: Optional[str] = None,
                       page: int = 1, page_size: int = 20) -> PaginatedKycRecords:
        items = list(self._records.values())
        if status:
            items = [i for i in items if i.status.value == status]
        if search:
            search_lower = search.lower()
            items = [i for i in items if search_lower in i.full_name.lower() or search_lower in i.id_number.lower()]
        items.sort(key=lambda x: x.submitted_at or datetime.min.replace(tzinfo=timezone.utc), reverse=True)
        total = len(items)
        total_pages = max(1, (total + page_size - 1) // page_size)
        start = (page - 1) * page_size
        end = start + page_size
        page_items = items[start:end]
        return PaginatedKycRecords(
            items=[self._to_response(r) for r in page_items],
            page=page,
            page_size=page_size,
            total=total,
            total_pages=total_pages,
        )

    async def get_summary(self) -> KycAdminSummary:
        items = list(self._records.values())
        return KycAdminSummary(
            total_applications=len(items),
            pending=sum(1 for i in items if i.status == KycStatus.pending),
            verified=sum(1 for i in items if i.status == KycStatus.verified),
            rejected=sum(1 for i in items if i.status == KycStatus.rejected),
            resubmission_requested=sum(1 for i in items if i.status == KycStatus.resubmission_requested),
        )

    def _get_by_user_id(self, user_id: str) -> Optional[KycRecord]:
        for record in self._records.values():
            if record.user_id == user_id:
                return record
        return None

    def _to_response(self, record: KycRecord) -> KycRecordResponse:
        return KycRecordResponse(
            id=record.id,
            user_id=record.user_id,
            user_role=record.user_role,
            full_name=record.full_name,
            date_of_birth=record.date_of_birth,
            address=record.address,
            district=record.district,
            state=record.state,
            pin_code=record.pin_code,
            id_type=record.id_type,
            id_number=record.id_number,
            phone=record.phone,
            selfie_url=record.selfie_url,
            id_proof_url=record.id_proof_url,
            ownership_proof_url=record.ownership_proof_url,
            status=record.status,
            reviewed_by=record.reviewed_by,
            reviewed_at=record.reviewed_at,
            remarks=record.remarks,
            submitted_at=record.submitted_at,
            renewable_energy_source=record.renewable_energy_source,
            installed_capacity_kw=record.installed_capacity_kw,
            plant_location=record.plant_location,
            utility_license_number=record.utility_license_number,
        )


kyc_repository = KycRepository()
