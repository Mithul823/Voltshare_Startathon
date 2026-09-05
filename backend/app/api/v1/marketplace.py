from fastapi import APIRouter, Depends

from app.api.dependencies import get_current_user
from app.core.security import AuthenticatedUser
from app.schemas.marketplace import ListingPageResponse, MarketplaceActivity, MarketplaceSummaryResponse
from app.services.marketplace_service import marketplace_service

router = APIRouter()


@router.get("", response_model=ListingPageResponse)
def marketplace(page: int = 1, page_size: int = 20, featured_only: bool = False) -> ListingPageResponse:
    response = marketplace_service.page(page=page, page_size=page_size, active_only=True, sort="newest")
    if featured_only:
        response = response.model_copy(update={"items": [item for item in response.items if item.isFeatured]})
    return response


@router.get("/summary", response_model=MarketplaceSummaryResponse)
def summary() -> MarketplaceSummaryResponse:
    return marketplace_service.summary()


@router.get("/activity", response_model=list[MarketplaceActivity])
def activity(
    seller_scoped: bool = False,
    limit: int = 20,
    user: AuthenticatedUser = Depends(get_current_user),
) -> list[MarketplaceActivity]:
    return marketplace_service.activity(seller_id=user.user_id if seller_scoped else None, limit=limit)
