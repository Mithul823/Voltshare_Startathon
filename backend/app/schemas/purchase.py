from datetime import datetime
from decimal import Decimal
from enum import Enum

from pydantic import AliasChoices, Field

from app.schemas.common import ApiModel, now_utc


class PurchaseStatus(str, Enum):
    pending = "pending"
    initiated = "initiated"
    pending_reservation = "pending_reservation"
    reserved = "reserved"
    awaiting_payment = "awaiting_payment"
    confirmed = "confirmed"
    completed = "completed"
    cancelled = "cancelled"
    failed = "failed"
    expired = "expired"
    refunded = "refunded"


class PurchaseCreateRequest(ApiModel):
    listingId: str = Field(validation_alias=AliasChoices("listingId", "listing_id"))
    quantityKwh: float = Field(ge=0.5, validation_alias=AliasChoices("quantityKwh", "quantity_kwh"))


class PurchaseQuote(ApiModel):
    quantityKwh: float
    unitPrice: float
    subtotal: float
    platformFee: float
    totalAmount: float
    estimatedSavings: float
    co2ImpactKg: float


class EnergyPurchase(ApiModel):
    id: str
    listingId: str
    buyerId: str
    sellerId: str
    sellerName: str | None = None
    listingTitle: str | None = None
    quantityKwh: float
    unitPrice: float
    platformFee: float
    totalAmount: float
    estimatedSavings: float
    co2ImpactKg: float
    purchasedAt: datetime = now_utc()
    status: PurchaseStatus = PurchaseStatus.completed
    escrowId: str | None = None
    subtotalAmount: float | None = None
    currency: str = "INR"
    idempotencyKey: str | None = None
    expiresAt: datetime | None = None


class PurchaseCreateResponse(ApiModel):
    purchase: EnergyPurchase
    escrowId: str | None = None


class PurchasePageResponse(ApiModel):
    items: list[EnergyPurchase]
    page: int
    pageSize: int
    totalItems: int
    totalPages: int
    hasNext: bool
    hasPrevious: bool


class PurchasePriceBreakdown(ApiModel):
    quantityKwh: Decimal
    unitPrice: Decimal
    subtotal: Decimal
    platformFee: Decimal
    totalAmount: Decimal
    currency: str = "INR"
