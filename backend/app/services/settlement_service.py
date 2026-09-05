from app.core.security import AuthenticatedUser
from app.repositories.financial_store import financial_state as state
from app.schemas.common import UserRole
from app.schemas.escrow import DeliveryVerificationRequest, EscrowSettlementResult
from app.schemas.wallet import Settlement
from app.services.escrow_service import escrow_service


class SettlementService:
    def process(self, user: AuthenticatedUser, escrow_id: str, delivered_energy_kwh: float | None, idempotency_key: str) -> EscrowSettlementResult:
        escrow = escrow_service.get(escrow_id)
        request = DeliveryVerificationRequest(deliveredEnergyKwh=delivered_energy_kwh)
        return escrow_service.verify_and_settle(user, escrow_id, request, idempotency_key)

    def list_for(self, user: AuthenticatedUser) -> list[Settlement]:
        items = list(state.settlements.values())
        if user.role == UserRole.admin:
            return items
        return [item for item in items if item.sellerId == user.user_id]


settlement_service = SettlementService()
