from datetime import datetime

from app.schemas.common import ApiModel, now_utc
from app.schemas.purchase import EnergyPurchase, PurchaseStatus


class ProducerSaleSummary(ApiModel):
    total_sales: int = 0
    completed_sales: int = 0
    pending_sales: int = 0
    cancelled_or_failed_sales: int = 0
    energy_sold_kwh: float = 0.0
    gross_revenue_paise: int = 0
    platform_fees_paise: int = 0
    net_revenue_paise: int = 0
    pending_settlement_paise: int = 0
    settled_amount_paise: int = 0


class ProducerSalesPage(ApiModel):
    items: list[EnergyPurchase] = []
    summary: ProducerSaleSummary = ProducerSaleSummary()
    page: int = 1
    page_size: int = 20
    total: int = 0
    total_pages: int = 0
