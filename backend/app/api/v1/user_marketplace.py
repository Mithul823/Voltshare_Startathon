from fastapi import APIRouter, Depends, Query

from app.api.dependencies import get_current_user
from app.core.security import AuthenticatedUser
from app.schemas.marketplace import EnergyListing
from app.schemas.purchase import EnergyPurchase
from app.schemas.producer_sales import ProducerSalesPage, ProducerSaleSummary
from app.services.marketplace_service import marketplace_service
from app.services.purchase_service import purchase_service
from app.core.exceptions import ApiError, ErrorCode

router = APIRouter()


@router.get("/listings", response_model=list[EnergyListing])
def my_listings(user: AuthenticatedUser = Depends(get_current_user)) -> list[EnergyListing]:
    return marketplace_service.list(active_only=False, seller_id=user.user_id, sort="newest")


@router.get("/purchases", response_model=list[EnergyPurchase])
def my_purchases(user: AuthenticatedUser = Depends(get_current_user)) -> list[EnergyPurchase]:
    return purchase_service.list_for(user, "purchases")


@router.get("/sales", response_model=ProducerSalesPage)
def my_sales(
    status: str | None = Query(None, description="Filter by purchase status"),
    search: str | None = Query(None, description="Search by listing title or purchase ID"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user: AuthenticatedUser = Depends(get_current_user),
) -> ProducerSalesPage:
    """Producer sales with pagination, filtering, and summary aggregation.

    Returns sales where the authenticated user is the seller. Supports
    status filtering, text search, and pagination.
    """
    all_sales = purchase_service.list_for(user, "sales")

    # Apply status filter
    if status:
        filtered = [s for s in all_sales if s.status.value.lower() == status.lower()]
    else:
        filtered = all_sales

    # Apply search filter
    if search:
        lower_search = search.lower()
        filtered = [
            s for s in filtered
            if (s.listingTitle and lower_search in s.listingTitle.lower())
            or lower_search in s.id.lower()
        ]

    # Sort by date descending
    filtered.sort(key=lambda s: s.purchasedAt, reverse=True)

    # Calculate pagination
    total = len(filtered)
    total_pages = max(1, (total + page_size - 1) // page_size)
    start = (page - 1) * page_size
    page_items = filtered[start:start + page_size]

    # Calculate summary from all filtered results (not just the page)
    completed = [s for s in filtered if s.status == PurchaseStatus.completed]
    pending = [s for s in filtered if s.status in {PurchaseStatus.pending, PurchaseStatus.initiated, PurchaseStatus.confirmed, PurchaseStatus.awaiting_payment}]
    cancelled_or_failed = [s for s in filtered if s.status in {PurchaseStatus.cancelled, PurchaseStatus.failed, PurchaseStatus.expired}]

    total_kwh = sum(s.quantityKwh for s in filtered)
    gross_paise = sum(round(s.totalAmount * 100) for s in filtered)
    fees_paise = sum(round(s.platformFee * 100) for s in filtered)
    settled_paise = sum(round(s.totalAmount * 100) for s in completed) if completed else 0

    summary = ProducerSaleSummary(
        total_sales=total,
        completed_sales=len(completed),
        pending_sales=len(pending),
        cancelled_or_failed_sales=len(cancelled_or_failed),
        energy_sold_kwh=total_kwh,
        gross_revenue_paise=gross_paise,
        platform_fees_paise=fees_paise,
        net_revenue_paise=gross_paise - fees_paise,
        pending_settlement_paise=max(0, gross_paise - settled_paise),
        settled_amount_paise=settled_paise,
    )

    return ProducerSalesPage(
        items=[purchase_service._enrich_purchase(s) for s in page_items],
        summary=summary,
        page=page,
        page_size=page_size,
        total=total,
        total_pages=total_pages,
    )


@router.get("/sales/{sale_id}", response_model=EnergyPurchase)
def my_sale_detail(
    sale_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
) -> EnergyPurchase:
    """Get detailed information about a specific sale.

    Verifies that the authenticated user is the seller of the related listing.
    """
    purchase = purchase_service.get(user, sale_id)
    if purchase.sellerId != user.user_id and user.role.value != "admin":
        raise ApiError(403, ErrorCode.ACCESS_DENIED, "You do not have permission to view this sale.")
    return purchase_service._enrich_purchase(purchase)
