from app.core.security import AuthenticatedUser
from app.schemas.wallet import RefundRequest, WalletTransaction
from app.services.wallet_service import wallet_service


class RefundService:
    def create(self, user: AuthenticatedUser, request: RefundRequest) -> WalletTransaction:
        return wallet_service.refund(user, request)


refund_service = RefundService()
