from decimal import Decimal, ROUND_HALF_UP

from app.core.config import get_settings
from app.core.exceptions import ApiError, ErrorCode
from app.schemas.purchase import PurchasePriceBreakdown


MONEY = Decimal("0.01")
KWH = Decimal("0.001")


class PricingService:
    def __init__(self) -> None:
        self.grid_price_per_kwh = Decimal("10.25")

    @property
    def platform_fee_rate(self) -> Decimal:
        return Decimal(str(get_settings().marketplace_platform_fee_percent)) / Decimal("100")

    def validate_price(self, price_per_kwh: Decimal) -> None:
        if price_per_kwh <= 0:
            raise ApiError(422, ErrorCode.MARKETPLACE_INVALID_QUANTITY, "Price must be positive.")

    def breakdown(self, *, quantity_kwh: Decimal, price_per_kwh: Decimal, currency: str = "INR") -> PurchasePriceBreakdown:
        if quantity_kwh <= 0:
            raise ApiError(422, ErrorCode.MARKETPLACE_INVALID_QUANTITY, "Purchase quantity must be positive.")
        self.validate_price(price_per_kwh)
        quantity = quantity_kwh.quantize(KWH, rounding=ROUND_HALF_UP)
        unit_price = price_per_kwh.quantize(MONEY, rounding=ROUND_HALF_UP)
        subtotal = (quantity * unit_price).quantize(MONEY, rounding=ROUND_HALF_UP)
        platform_fee = (subtotal * self.platform_fee_rate).quantize(MONEY, rounding=ROUND_HALF_UP)
        total = (subtotal + platform_fee).quantize(MONEY, rounding=ROUND_HALF_UP)
        return PurchasePriceBreakdown(
            quantityKwh=quantity,
            unitPrice=unit_price,
            subtotal=subtotal,
            platformFee=platform_fee,
            totalAmount=total,
            currency=currency,
        )


pricing_service = PricingService()
