from app.core.security import AuthenticatedUser
from app.schemas.wallet import WalletMutationRequest, WalletTransaction
from app.services.wallet_service import wallet_service


class DepositService:
    def create(self, user: AuthenticatedUser, request: WalletMutationRequest) -> WalletTransaction:
        return wallet_service.deposit(user, request)


deposit_service = DepositService()
