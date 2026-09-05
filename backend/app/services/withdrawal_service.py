from app.core.security import AuthenticatedUser
from app.schemas.wallet import WalletMutationRequest, WalletTransaction
from app.services.wallet_service import wallet_service


class WithdrawalService:
    def create(self, user: AuthenticatedUser, request: WalletMutationRequest) -> WalletTransaction:
        return wallet_service.withdraw(user, request)


withdrawal_service = WithdrawalService()
