from datetime import datetime
from decimal import Decimal
from enum import Enum

from pydantic import AliasChoices, Field, model_validator

from app.schemas.common import ApiModel, now_utc


class EnergySource(str, Enum):
    solar = "solar"
    wind = "wind"
    hydro = "hydro"
    biomass = "biomass"
    mixed_renewable = "mixed_renewable"
    other = "other"
    communitySolar = "communitySolar"
    hybrid = "hybrid"


class ListingStatus(str, Enum):
    draft = "draft"
    active = "active"
    partially_reserved = "partially_reserved"
    sold_out = "sold_out"
    sold = "sold"
    expired = "expired"
    cancelled = "cancelled"
    suspended = "suspended"


class SellerSummary(ApiModel):
    id: str
    displayName: str
    role: str
    rating: float = 4.8
    completedSales: int = 0
    verifiedStatus: bool = False
    energySourceSummary: str = "Renewable"
    locationName: str
    avatarUrl: str | None = None


class EnergyListing(ApiModel):
    id: str
    sellerId: str
    sellerName: str
    sellerRole: str
    sellerInitials: str
    sellerRating: float = 4.8
    reviewCount: int = 0
    energySource: EnergySource
    availableEnergyKwh: float
    pricePerKwh: float
    distanceKm: float = 0
    location: str
    batteryBacked: bool
    renewableVerified: bool
    availabilityStart: datetime
    availabilityEnd: datetime
    createdAt: datetime = now_utc()
    updatedAt: datetime = now_utc()
    listingStatus: ListingStatus = ListingStatus.active
    notes: str | None = None
    title: str | None = None
    description: str | None = None
    quantityTotalKwh: float | None = None
    quantityReservedKwh: float = 0
    currency: str = "INR"
    minimumPurchaseKwh: float = 0.5
    maximumPurchaseKwh: float | None = None
    isFeatured: bool = False
    version: int = 1
    seller: SellerSummary | None = None


class ListingCreateRequest(ApiModel):
    title: str | None = None
    description: str | None = None
    energySource: EnergySource = Field(validation_alias=AliasChoices("energySource", "energy_source"))
    availableEnergyKwh: float = Field(gt=0, validation_alias=AliasChoices("availableEnergyKwh", "quantity_kwh", "quantity_total_kwh"))
    pricePerKwh: float = Field(gt=0, validation_alias=AliasChoices("pricePerKwh", "price_per_kwh"))
    batteryReservePercentage: int = Field(default=0, ge=0, le=100)
    availabilityStart: datetime = Field(validation_alias=AliasChoices("availabilityStart", "available_from"))
    availabilityEnd: datetime = Field(validation_alias=AliasChoices("availabilityEnd", "available_until"))
    location: str | None = None
    minimumPurchaseKwh: float = Field(default=0.5, gt=0, validation_alias=AliasChoices("minimumPurchaseKwh", "minimum_purchase_kwh"))
    maximumPurchaseKwh: float | None = Field(default=None, validation_alias=AliasChoices("maximumPurchaseKwh", "maximum_purchase_kwh"))
    notes: str | None = None

    @model_validator(mode="after")
    def validate_window(self) -> "ListingCreateRequest":
        if not self.availabilityEnd > self.availabilityStart:
            raise ValueError("availabilityEnd must be after availabilityStart")
        if self.maximumPurchaseKwh is not None and self.maximumPurchaseKwh < self.minimumPurchaseKwh:
            raise ValueError("maximumPurchaseKwh must be greater than or equal to minimumPurchaseKwh")
        return self


class ListingUpdateRequest(ApiModel):
    title: str | None = None
    description: str | None = None
    availableEnergyKwh: float | None = Field(default=None, gt=0, validation_alias=AliasChoices("availableEnergyKwh", "quantity_total_kwh"))
    pricePerKwh: float | None = Field(default=None, gt=0, validation_alias=AliasChoices("pricePerKwh", "price_per_kwh"))
    availabilityStart: datetime | None = Field(default=None, validation_alias=AliasChoices("availabilityStart", "available_from"))
    availabilityEnd: datetime | None = Field(default=None, validation_alias=AliasChoices("availabilityEnd", "available_until"))
    notes: str | None = None
    version: int | None = Field(default=None, ge=1)


class ListingPageResponse(ApiModel):
    items: list[EnergyListing]
    page: int
    pageSize: int
    totalItems: int
    totalPages: int
    hasNext: bool
    hasPrevious: bool


class MarketplaceSummaryResponse(ApiModel):
    activeListings: int
    totalAvailableKwh: float
    averagePricePerKwh: float
    featuredListings: int
    simulatedRatings: bool = True


class MarketplaceActivity(ApiModel):
    id: str
    type: str
    message: str
    createdAt: datetime
    listingId: str | None = None
    purchaseId: str | None = None


class PurchasePriceBreakdown(ApiModel):
    quantity_kwh: Decimal
    price_per_kwh: Decimal
    subtotal: Decimal
    platform_fee: Decimal
    total: Decimal
    currency: str = "INR"
