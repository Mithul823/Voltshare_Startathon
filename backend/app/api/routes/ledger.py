from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user
from app.core.security import AuthenticatedUser
from app.schemas.common import UserRole
from app.schemas.wallet import LedgerEntry
from app.services.ledger_service import ledger_service

router = APIRouter()


@router.get("", response_model=list[LedgerEntry])
def ledger(user: AuthenticatedUser = Depends(get_current_user)) -> list[LedgerEntry]:
    return ledger_service.list_for_user(None if user.role == UserRole.admin else user.user_id)


@router.get("/{entry_id}", response_model=LedgerEntry)
def ledger_entry(entry_id: str, user: AuthenticatedUser = Depends(get_current_user)) -> LedgerEntry:
    entry = ledger_service.entry(entry_id)
    if user.role != UserRole.admin and entry.userId != user.user_id:
        from app.core.exceptions import ApiError, ErrorCode

        raise ApiError(403, ErrorCode.ACCESS_DENIED, "Ledger entry access denied.")
    return entry
