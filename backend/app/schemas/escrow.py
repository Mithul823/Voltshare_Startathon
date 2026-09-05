from datetime import datetime
from enum import Enum

from pydantic import Field

from app.schemas.common import ApiModel, now_utc


class EscrowStatus(str, Enum):
    energyDeliveryPending = "energyDeliveryPending"
    deliveryConfirmed = "deliveryConfirmed"
    deliveryPartiallyConfirmed = "deliveryPartiallyConfirmed"
    released = "released"
    refunded = "refunded"
    disputed = "disputed"
    frozen = "frozen"
    cancelled = "cancelled"


class EscrowAgreement(ApiModel):
    id: str
    purchaseId: str
    listingId: str
    buyerId: str
    sellerId: str
    energyQuantityKwh: float
    amountHeldPaise: int
    platformFeePaise: int
    totalHeldPaise: int
    deliveredEnergyKwh: float = 0
    status: EscrowStatus = EscrowStatus.energyDeliveryPending
    createdAt: datetime = now_utc()
    fundedAt: datetime | None = None
    deliveryDeadline: datetime
    completedAt: datetime | None = None
    releasedAt: datetime | None = None
    refundedAt: datetime | None = None
    disputedAt: datetime | None = None
    failureReason: str | None = None
    integrityHash: str
    version: int = 1


class DeliveryVerificationRequest(ApiModel):
    deliveredEnergyKwh: float = Field(ge=0)
    meterMatched: bool = True
    tamperingDetected: bool = False
    withinDeliveryWindow: bool = True


class EscrowSettlementResult(ApiModel):
    escrow: EscrowAgreement
    sellerReleasePaise: int
    buyerRefundPaise: int
    platformFeeRetainedPaise: int
    frozenPaise: int
    idempotencyKey: str
    defaultCase: dict | None = None


class DisputeRequest(ApiModel):
    category: str
    description: str


class Dispute(ApiModel):
    id: str
    escrowId: str
    raisedBy: str
    category: str
    description: str
    status: str = "underReview"
    createdAt: datetime = now_utc()


class ReconciliationReport(ApiModel):
    checked: int
    repaired: int
    notes: list[str]
