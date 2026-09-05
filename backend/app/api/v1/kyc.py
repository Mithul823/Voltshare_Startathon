from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user
from app.core.security import AuthenticatedUser
from app.schemas.kyc import KycRecord, KycSubmission
from app.services.kyc_service import kyc_service

router = APIRouter()


@router.post("", response_model=KycRecord, status_code=201)
async def submit_kyc(
    submission: KycSubmission,
    user: AuthenticatedUser = Depends(get_current_user),
) -> KycRecord:
    """Submit a KYC application.

    Consumers need: full_name, date_of_birth, address, district, state,
    pin_code, id_type, id_number, phone.

    Producers additionally need: renewable_energy_source, installed_capacity_kw,
    plant_location, bank_account_number, bank_ifsc_code, bank_account_holder.
    """
    return await kyc_service.submit(user, submission)


@router.get("/me", response_model=KycRecord | None)
async def get_my_kyc(
    user: AuthenticatedUser = Depends(get_current_user),
) -> KycRecord | None:
    """Get the current user's KYC record."""
    return await kyc_service.get_my_kyc(user)


@router.get("/status", response_model=dict)
async def kyc_status(
    user: AuthenticatedUser = Depends(get_current_user),
) -> dict:
    """Check if user can purchase/can sell based on KYC status."""
    record = await kyc_service.get_my_kyc(user)
    is_verified = record is not None and getattr(record, 'status', None) == "verified"
    can_purchase = await kyc_service.check_can_purchase(user)
    can_sell = await kyc_service.check_can_sell(user)
    return {
        "can_purchase": can_purchase,
        "can_sell": can_sell,
        "needs_kyc": not is_verified,
        "status": record.status.value if record and hasattr(record.status, 'value') else (str(record.status) if record else "unverified"),
    }
