from datetime import datetime
from enum import Enum

from pydantic import Field

from app.schemas.common import ApiModel, now_utc


class Wallet(ApiModel):
    walletId: str | None = None
    userId: str
    availableBalancePaise: int
    heldBalancePaise: int = 0
    pendingBalancePaise: int
    escrowHeldBalancePaise: int
    totalEarnedPaise: int
    totalSpentPaise: int
    totalWithdrawnPaise: int
    totalAddedPaise: int
    currency: str = "Rs"
    updatedAt: datetime = now_utc()
    status: str = "ACTIVE"


class WalletTransactionType(str, Enum):
    walletTopUp = "walletTopUp"
    withdrawal = "withdrawal"
    energyPurchase = "energyPurchase"
    energySale = "energySale"
    refund = "refund"
    reward = "reward"
    platformFee = "platformFee"
    escrowHold = "escrowHold"
    escrowRelease = "escrowRelease"
    settlement = "settlement"
    adjustment = "adjustment"
    transfer = "transfer"


class WalletTransactionStatus(str, Enum):
    pending = "pending"
    completed = "completed"
    failed = "failed"
    refunded = "refunded"


class WalletTransaction(ApiModel):
    id: str
    userId: str
    type: WalletTransactionType
    status: WalletTransactionStatus
    amountPaise: int
    description: str
    reference: str
    createdAt: datetime = now_utc()
    completedAt: datetime | None = None
    energyQuantityKwh: float | None = None
    unitPricePaise: int | None = None
    platformFeePaise: int = 0
    counterpartyId: str | None = None
    counterpartyName: str | None = None
    marketplaceListingId: str | None = None
    energyPurchaseId: str | None = None
    escrowId: str | None = None
    escrowStatusLabel: str | None = None
    refundedTransactionId: str | None = None


class WalletMutationRequest(ApiModel):
    amountPaise: int = Field(gt=0)
    method: str = "demo"
    label: str = ""


class RefundRequest(ApiModel):
    transactionId: str


class WalletBalance(ApiModel):
    walletId: str
    userId: str
    availableBalancePaise: int
    heldBalancePaise: int
    escrowHeldBalancePaise: int
    pendingBalancePaise: int
    currency: str = "Rs"
    status: str = "ACTIVE"


class LedgerEntry(ApiModel):
    entryId: str
    transactionId: str
    userId: str | None = None
    walletId: str | None = None
    accountType: str
    debitPaise: int = 0
    creditPaise: int = 0
    description: str
    createdAt: datetime = now_utc()


class LedgerTransaction(ApiModel):
    transactionId: str
    entries: list[LedgerEntry]
    createdAt: datetime = now_utc()


class EscrowAccount(ApiModel):
    escrowAccountId: str
    escrowId: str
    purchaseId: str
    buyerId: str
    sellerId: str
    amountHeldPaise: int
    platformFeePaise: int
    status: str = "ACTIVE"
    createdAt: datetime = now_utc()


class Settlement(ApiModel):
    settlementId: str
    escrowId: str
    purchaseId: str
    sellerId: str
    amountPaise: int
    platformFeePaise: int
    status: str
    createdAt: datetime = now_utc()


class Withdrawal(ApiModel):
    withdrawalId: str
    userId: str
    walletId: str
    amountPaise: int
    method: str
    status: str
    createdAt: datetime = now_utc()


class Deposit(ApiModel):
    depositId: str
    userId: str
    walletId: str
    amountPaise: int
    method: str
    status: str
    createdAt: datetime = now_utc()


class Refund(ApiModel):
    refundId: str
    userId: str
    walletId: str
    amountPaise: int
    transactionId: str
    status: str
    createdAt: datetime = now_utc()


class TransactionAudit(ApiModel):
    auditId: str
    userId: str
    role: str
    endpoint: str
    transactionId: str | None = None
    walletId: str | None = None
    ipAddress: str | None = None
    createdAt: datetime = now_utc()
