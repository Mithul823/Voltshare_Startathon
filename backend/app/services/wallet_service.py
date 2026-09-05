"""Wallet service — delegates data access to the active wallet repository.

Business logic (authorisation, event publishing) lives here.
Data access is delegated to ``get_wallet_repository()`` which returns
either an ``InMemoryWalletRepository`` or a ``SupabaseWalletRepository``.
"""

from app.core.financial_transaction import atomic
from app.core.config import get_settings
from app.core.exceptions import ApiError, ErrorCode
from app.core.security import AuthenticatedUser
from app.repositories.wallet_repository import get_wallet_repository
from app.schemas.common import UserRole, new_id, now_utc
from app.schemas.wallet import (
    Deposit,
    LedgerEntry,
    Refund,
    RefundRequest,
    TransactionAudit,
    Wallet,
    WalletBalance,
    WalletMutationRequest,
    WalletTransaction,
    WalletTransactionStatus,
    WalletTransactionType,
    Withdrawal,
)
from app.schemas.realtime import NotificationCategory, NotificationPriority, RealtimeChannel
from app.services.event_publisher import event_publisher
from app.services.ledger_service import ledger_service


class WalletService:
    maximum_top_up_paise = 500000
    minimum_withdrawal_paise = 10000

    def __init__(self) -> None:
        self._repo_instance: object | None = None

    @property
    def _repo(self) -> object:
        if self._repo_instance is None:
            self._repo_instance = get_wallet_repository()
        return self._repo_instance

    def wallet(self, user_id: str) -> Wallet:
        return self._repo.load_wallet(user_id)

    def balance(self, user_id: str) -> WalletBalance:
        w = self._repo.load_wallet(user_id)
        return WalletBalance(
            walletId=w.walletId or f"WAL-{w.userId}",
            userId=w.userId,
            availableBalancePaise=w.availableBalancePaise,
            heldBalancePaise=w.heldBalancePaise,
            escrowHeldBalancePaise=w.escrowHeldBalancePaise,
            pendingBalancePaise=w.pendingBalancePaise,
            currency=w.currency,
            status=w.status,
        )

    def transactions(self, user_id: str) -> list[WalletTransaction]:
        return self._repo.transactions(user_id)

    def transaction(self, user_id: str, transaction_id: str) -> WalletTransaction:
        for tx in self._repo.transactions(user_id):
            if tx.id == transaction_id:
                return tx
        raise ApiError(404, ErrorCode.RESOURCE_NOT_FOUND, "Transaction not found.")

    def ensure_available(self, user_id: str, amount_paise: int) -> None:
        if amount_paise > self._repo.load_wallet(user_id).availableBalancePaise:
            raise ApiError(409, ErrorCode.INSUFFICIENT_BALANCE, "Insufficient wallet balance.")

    def append(self, user_id: str, transaction: WalletTransaction) -> WalletTransaction:
        return self._repo.add_transaction(user_id, transaction)

    def audit(self, user: AuthenticatedUser, *, endpoint: str, transaction_id: str | None = None, wallet_id: str | None = None, ip_address: str | None = None) -> None:
        self._repo.record_audit(TransactionAudit(
            auditId=new_id("AUD"),
            userId=user.user_id,
            role=user.role.value,
            endpoint=endpoint,
            transactionId=transaction_id,
            walletId=wallet_id,
            ipAddress=ip_address,
        ))

    @staticmethod
    def _ensure_active(wallet: Wallet) -> None:
        if wallet.status != "ACTIVE":
            raise ApiError(409, ErrorCode.ACTION_BLOCKED, f"Wallet is {wallet.status.lower()}.")

    def _record_ledger(self, *, transaction_id: str, user_id: str, amount_paise: int, debit_account: str, credit_account: str, description: str) -> None:
        ledger_service.record(
            transaction_id=transaction_id,
            entries=[
                LedgerEntry(
                    entryId=new_id("LED"),
                    transactionId=transaction_id,
                    userId=user_id,
                    debitPaise=amount_paise,
                    creditPaise=0,
                    accountType=debit_account,
                    description=description,
                ),
                LedgerEntry(
                    entryId=new_id("LED"),
                    transactionId=transaction_id,
                    userId=user_id,
                    debitPaise=0,
                    creditPaise=amount_paise,
                    accountType=credit_account,
                    description=description,
                ),
            ],
        )

    def demo_top_up(self, user: AuthenticatedUser, request: WalletMutationRequest) -> WalletTransaction:
        return self.deposit(user, request)

    def deposit(self, user: AuthenticatedUser, request: WalletMutationRequest) -> WalletTransaction:
        if not get_settings().is_demo_mode:
            raise ApiError(403, ErrorCode.ACTION_BLOCKED, "Unverified deposits are only available in enabled demo mode.")
        return self._demo_deposit(user, request)

    @atomic
    def _demo_deposit(self, user: AuthenticatedUser, request: WalletMutationRequest) -> WalletTransaction:
        if user.role not in {UserRole.consumer, UserRole.prosumer, UserRole.admin}:
            raise ApiError(403, ErrorCode.ACCESS_DENIED, "This role cannot deposit funds.")
        if request.amountPaise > self.maximum_top_up_paise:
            raise ApiError(422, ErrorCode.VALIDATION_FAILED, "Demo top-up limit is Rs 5,000.00.")
        wallet = self._repo.load_wallet(user.user_id)
        self._ensure_active(wallet)
        transaction_id = new_id("DEP")
        new_balance = wallet.availableBalancePaise + request.amountPaise
        self._repo.update_balance(user.user_id, availableBalancePaise=new_balance, totalAddedPaise=wallet.totalAddedPaise + request.amountPaise)
        wallet_id = wallet.walletId or f"WAL-{wallet.userId}"
        self._record_ledger(
            transaction_id=transaction_id, user_id=user.user_id, amount_paise=request.amountPaise,
            debit_account="cash_clearing", credit_account="wallet_available",
            description=f"Deposit via {request.method}",
        )
        self._repo.save_deposit(Deposit(
            depositId=transaction_id, userId=user.user_id, walletId=wallet_id,
            amountPaise=request.amountPaise, method=request.method, status="COMPLETED",
        ))
        transaction = self._repo.add_transaction(user.user_id, WalletTransaction(
            id=transaction_id, userId=user.user_id,
            type=WalletTransactionType.walletTopUp, status=WalletTransactionStatus.completed,
            amountPaise=request.amountPaise, description=f"Deposit via {request.method}",
            reference=new_id("VS"), completedAt=now_utc(),
        ))
        self.audit(user, endpoint="/wallet/deposit", transaction_id=transaction.id, wallet_id=wallet_id)
        event_publisher.publish("deposit.completed", channels=[RealtimeChannel.wallet, RealtimeChannel.dashboard],
            actor_user_id=user.user_id, user_id=user.user_id,
            payload={"transaction": transaction.model_dump(mode="json"), "balance": self.balance(user.user_id).model_dump(mode="json")},
            notification_title="Deposit completed", notification_message="Your wallet top-up is available.",
            notification_category=NotificationCategory.wallet, notification_priority=NotificationPriority.medium,
            action_url="/wallet")
        event_publisher.publish("balance.changed", channels=[RealtimeChannel.wallet, RealtimeChannel.dashboard],
            user_id=user.user_id, payload=self.balance(user.user_id).model_dump(mode="json"))
        event_publisher.publish("wallet.updated", channels=[RealtimeChannel.wallet, RealtimeChannel.dashboard],
            user_id=user.user_id, payload=self._repo.load_wallet(user.user_id).model_dump(mode="json"))
        return transaction

    def demo_withdraw(self, user: AuthenticatedUser, request: WalletMutationRequest) -> WalletTransaction:
        return self.withdraw(user, request)

    @atomic
    def withdraw(self, user: AuthenticatedUser, request: WalletMutationRequest) -> WalletTransaction:
        if user.role not in {UserRole.producer, UserRole.prosumer, UserRole.admin}:
            raise ApiError(403, ErrorCode.ACCESS_DENIED, "Only producers and prosumers can withdraw demo earnings.")
        if request.amountPaise < self.minimum_withdrawal_paise:
            raise ApiError(422, ErrorCode.VALIDATION_FAILED, "Minimum demo withdrawal is Rs 100.00.")
        self.ensure_available(user.user_id, request.amountPaise)
        wallet = self._repo.load_wallet(user.user_id)
        self._ensure_active(wallet)
        if wallet.escrowHeldBalancePaise > 0 and request.amountPaise > wallet.availableBalancePaise:
            raise ApiError(409, ErrorCode.ACTION_BLOCKED, "Pending escrow prevents this withdrawal.")
        transaction_id = new_id("WDR")
        new_balance = wallet.availableBalancePaise - request.amountPaise
        self._repo.update_balance(user.user_id, availableBalancePaise=new_balance, totalWithdrawnPaise=wallet.totalWithdrawnPaise + request.amountPaise)
        wallet_id = wallet.walletId or f"WAL-{wallet.userId}"
        self._record_ledger(
            transaction_id=transaction_id, user_id=user.user_id, amount_paise=request.amountPaise,
            debit_account="wallet_available", credit_account="withdrawal_clearing",
            description="Withdrawal requested",
        )
        self._repo.save_withdrawal(Withdrawal(
            withdrawalId=transaction_id, userId=user.user_id, walletId=wallet_id,
            amountPaise=request.amountPaise, method=request.method, status="PENDING",
        ))
        transaction = self._repo.add_transaction(user.user_id, WalletTransaction(
            id=transaction_id, userId=user.user_id,
            type=WalletTransactionType.withdrawal, status=WalletTransactionStatus.pending,
            amountPaise=request.amountPaise, description="Withdrawal request", reference=new_id("VS"),
        ))
        self.audit(user, endpoint="/wallet/withdraw", transaction_id=transaction.id, wallet_id=wallet_id)
        event_publisher.publish("withdrawal.completed", channels=[RealtimeChannel.wallet, RealtimeChannel.dashboard],
            actor_user_id=user.user_id, user_id=user.user_id,
            payload={"transaction": transaction.model_dump(mode="json"), "balance": self.balance(user.user_id).model_dump(mode="json")},
            notification_title="Withdrawal requested", notification_message="Your withdrawal request was recorded.",
            notification_category=NotificationCategory.wallet, notification_priority=NotificationPriority.medium,
            action_url="/wallet")
        event_publisher.publish("balance.changed", channels=[RealtimeChannel.wallet, RealtimeChannel.dashboard],
            user_id=user.user_id, payload=self.balance(user.user_id).model_dump(mode="json"))
        event_publisher.publish("wallet.updated", channels=[RealtimeChannel.wallet, RealtimeChannel.dashboard],
            user_id=user.user_id, payload=self._repo.load_wallet(user.user_id).model_dump(mode="json"))
        return transaction

    @atomic
    def escrow_hold(self, *, buyer_id: str, seller_id: str, purchase_id: str, escrow_id: str, amount_paise: int, platform_fee_paise: int, quantity_kwh: float, unit_price_paise: int, listing_id: str) -> WalletTransaction:
        wallet = self._repo.load_wallet(buyer_id)
        self._ensure_active(wallet)
        new_available = wallet.availableBalancePaise - amount_paise
        new_held = wallet.heldBalancePaise + amount_paise
        new_escrow_held = wallet.escrowHeldBalancePaise + amount_paise
        new_total_spent = wallet.totalSpentPaise + amount_paise
        self._repo.update_balance(buyer_id,
            availableBalancePaise=new_available, heldBalancePaise=new_held,
            escrowHeldBalancePaise=new_escrow_held, totalSpentPaise=new_total_spent)
        transaction_id = new_id("HLD")
        wallet_id = wallet.walletId or f"WAL-{wallet.userId}"
        self._record_ledger(
            transaction_id=transaction_id, user_id=buyer_id, amount_paise=amount_paise,
            debit_account="escrow_asset", credit_account="wallet_available",
            description="Escrow hold for energy purchase",
        )
        return self._repo.add_transaction(buyer_id, WalletTransaction(
            id=transaction_id, userId=buyer_id,
            type=WalletTransactionType.energyPurchase, status=WalletTransactionStatus.pending,
            amountPaise=amount_paise, description="Energy purchase funds held in escrow",
            reference=new_id("VS"), energyQuantityKwh=quantity_kwh,
            unitPricePaise=unit_price_paise, platformFeePaise=platform_fee_paise,
            counterpartyId=seller_id, marketplaceListingId=listing_id,
            energyPurchaseId=purchase_id, escrowId=escrow_id,
            escrowStatusLabel="Funds held in escrow",
        ))

    @atomic
    def release_escrow(self, *, buyer_id: str, seller_id: str, escrow_id: str, purchase_id: str, seller_release_paise: int, buyer_refund_paise: int, platform_fee_paise: int) -> None:
        buyer_wallet = self._repo.load_wallet(buyer_id)
        held_delta = seller_release_paise + buyer_refund_paise + platform_fee_paise
        self._repo.update_balance(buyer_id,
            heldBalancePaise=max(0, buyer_wallet.heldBalancePaise - held_delta),
            escrowHeldBalancePaise=max(0, buyer_wallet.escrowHeldBalancePaise - held_delta),
            availableBalancePaise=buyer_wallet.availableBalancePaise + buyer_refund_paise,
        )
        # Update buyer transactions with escrow release status
        updated_txs = []
        for item in self._repo.transactions(buyer_id):
            if item.escrowId == escrow_id:
                new_status = WalletTransactionStatus.refunded if buyer_refund_paise and not seller_release_paise else WalletTransactionStatus.completed
                item = item.model_copy(update={
                    "status": new_status, "completedAt": now_utc(),
                    "escrowStatusLabel": "Refunded" if buyer_refund_paise and not seller_release_paise else "Released",
                })
            updated_txs.append(item)
        self._repo.replace_transactions(buyer_id, updated_txs)
        if seller_release_paise:
            seller_wallet = self._repo.load_wallet(seller_id)
            self._repo.update_balance(seller_id,
                availableBalancePaise=seller_wallet.availableBalancePaise + seller_release_paise,
                totalEarnedPaise=seller_wallet.totalEarnedPaise + seller_release_paise,
            )
            self._repo.add_transaction(seller_id, WalletTransaction(
                id=new_id("SET"), userId=seller_id,
                type=WalletTransactionType.settlement, status=WalletTransactionStatus.completed,
                amountPaise=seller_release_paise, description="Escrow settlement credited to seller wallet",
                reference=new_id("VS"), completedAt=now_utc(),
                energyPurchaseId=purchase_id, escrowId=escrow_id, escrowStatusLabel="Released",
            ))
        if buyer_refund_paise:
            self._repo.add_transaction(buyer_id, WalletTransaction(
                id=new_id("RFD"), userId=buyer_id,
                type=WalletTransactionType.refund, status=WalletTransactionStatus.completed,
                amountPaise=buyer_refund_paise, description="Escrow refund returned to buyer wallet",
                reference=new_id("VS"), completedAt=now_utc(),
                energyPurchaseId=purchase_id, escrowId=escrow_id, escrowStatusLabel="Refunded",
            ))
        settlement_tx_id = new_id("LEDSET")
        self._record_ledger(
            transaction_id=settlement_tx_id, user_id=buyer_id, amount_paise=held_delta,
            debit_account="escrow_liability", credit_account="seller_wallet_or_refund",
            description="Escrow release settlement",
        )
        event_publisher.publish("escrow.released", channels=[RealtimeChannel.wallet, RealtimeChannel.dashboard, RealtimeChannel.sales],
            user_id=buyer_id, payload={"escrowId": escrow_id, "purchaseId": purchase_id})
        event_publisher.publish("settlement.completed", channels=[RealtimeChannel.wallet, RealtimeChannel.dashboard, RealtimeChannel.sales],
            user_id=seller_id,
            payload={"escrowId": escrow_id, "purchaseId": purchase_id, "sellerReleasePaise": seller_release_paise},
            notification_title="Settlement completed", notification_message="Escrow settlement has reached your wallet.",
            notification_category=NotificationCategory.settlement, notification_priority=NotificationPriority.high,
            action_url="/wallet")
        event_publisher.publish("wallet.updated", channels=[RealtimeChannel.wallet, RealtimeChannel.dashboard],
            user_id=buyer_id, payload=self._repo.load_wallet(buyer_id).model_dump(mode="json"))
        event_publisher.publish("wallet.updated", channels=[RealtimeChannel.wallet, RealtimeChannel.dashboard],
            user_id=seller_id, payload=self._repo.load_wallet(seller_id).model_dump(mode="json"))

    @atomic
    def refund(self, user: AuthenticatedUser, request: RefundRequest) -> WalletTransaction:
        original = self.transaction(user.user_id, request.transactionId)
        if original.escrowId:
            raise ApiError(409, ErrorCode.ACTION_BLOCKED, "Escrow purchases must be refunded through escrow resolution.")
        if original.type != WalletTransactionType.energyPurchase or original.status != WalletTransactionStatus.completed:
            raise ApiError(409, ErrorCode.VALIDATION_FAILED, "This transaction is not eligible for refund.")
        if any(tx.refundedTransactionId == original.id for tx in self._repo.transactions(user.user_id)):
            raise ApiError(409, ErrorCode.DUPLICATE_OPERATION, "This transaction has already been refunded.")
        wallet = self._repo.load_wallet(user.user_id)
        self._repo.update_balance(user.user_id,
            availableBalancePaise=wallet.availableBalancePaise + original.amountPaise,
            totalSpentPaise=max(0, wallet.totalSpentPaise - original.amountPaise),
        )
        transaction_id = new_id("RFD")
        wallet_id = wallet.walletId or f"WAL-{wallet.userId}"
        self._record_ledger(
            transaction_id=transaction_id, user_id=user.user_id, amount_paise=original.amountPaise,
            debit_account="refund_clearing", credit_account="wallet_available",
            description=f"Refund for {original.reference}",
        )
        self._repo.save_refund(Refund(
            refundId=transaction_id, userId=user.user_id, walletId=wallet_id,
            amountPaise=original.amountPaise, transactionId=original.id, status="COMPLETED",
        ))
        transaction = WalletTransaction(
            id=transaction_id, userId=user.user_id,
            type=WalletTransactionType.refund, status=WalletTransactionStatus.completed,
            amountPaise=original.amountPaise, description=f"Refund for {original.reference}",
            reference=new_id("VS"), completedAt=now_utc(), refundedTransactionId=original.id,
        )
        self._repo.add_transaction(user.user_id, transaction)
        self.audit(user, endpoint="/refunds", transaction_id=transaction.id, wallet_id=wallet_id)
        event_publisher.publish("refund.created", channels=[RealtimeChannel.wallet, RealtimeChannel.dashboard],
            actor_user_id=user.user_id, user_id=user.user_id,
            payload={"transactionId": original.id, "refundId": transaction.id})
        event_publisher.publish("refund.completed", channels=[RealtimeChannel.wallet, RealtimeChannel.dashboard],
            actor_user_id=user.user_id, user_id=user.user_id,
            payload={"transaction": transaction.model_dump(mode="json"), "balance": self.balance(user.user_id).model_dump(mode="json")},
            notification_title="Refund completed", notification_message="Your refund has been returned to your wallet.",
            notification_category=NotificationCategory.wallet, notification_priority=NotificationPriority.high,
            action_url="/wallet")
        event_publisher.publish("wallet.updated", channels=[RealtimeChannel.wallet, RealtimeChannel.dashboard],
            user_id=user.user_id, payload=self._repo.load_wallet(user.user_id).model_dump(mode="json"))
        return transaction


wallet_service = WalletService()
