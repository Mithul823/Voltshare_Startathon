from datetime import datetime

from app.schemas.common import ApiModel, now_utc


class AdminDisputeSummary(ApiModel):
    id: str
    escrow_id: str | None = None
    purchase_id: str | None = None
    buyer_id: str | None = None
    buyer_name: str | None = None
    seller_id: str | None = None
    seller_name: str | None = None
    listing_title: str | None = None
    amount_paise: int = 0
    reason: str = ""
    status: str = "open"
    priority: str = "medium"
    created_at: datetime = now_utc()
    updated_at: datetime = now_utc()


class PaginatedAdminDisputes(ApiModel):
    items: list[AdminDisputeSummary] = []
    page: int = 1
    page_size: int = 20
    total: int = 0
    total_pages: int = 0


class DisputeResolutionRequest(ApiModel):
    resolution: str = "resolved"
    reason: str = ""
    refund_amount_paise: int = 0
    release_to_seller_paise: int = 0


class DisputeActionResponse(ApiModel):
    id: str
    status: str
    message: str = "Dispute action completed successfully."
