"""Purchase service — orchestrates the atomic purchase flow.

The purchase flow involves:
1. Validate listing availability and buyer role
2. Reserve listing quantity (via marketplace repository)
3. Create escrow (via escrow repository)
4. Hold funds in buyer's wallet (via wallet repository)
5. Persist purchase record

In live (Supabase) mode, steps 1–5 use the existing ``create_energy_purchase_order``
RPC for atomicity.  In demo mode, steps are performed sequentially against
in-memory repositories.
"""

from decimal import Decimal

from decimal import Decimal

from app.core.exceptions import ApiError, ErrorCode
from app.core.security import AuthenticatedUser
from app.repositories.marketplace_repository import get_marketplace_repository
from app.repositories.purchase_repository import get_purchase_repository
from app.repositories.wallet_repository import get_wallet_repository
from app.schemas.common import UserRole, new_id, now_utc
from app.schemas.purchase import EnergyPurchase, PurchaseCreateRequest, PurchaseCreateResponse, PurchaseStatus
from app.schemas.realtime import NotificationCategory, NotificationPriority, RealtimeChannel
from app.services.audit_service import audit_service
from app.services.escrow_service import escrow_service
from app.services.marketplace_service import marketplace_service
from app.services.pricing_service import pricing_service
from app.services.wallet_service import wallet_service
from app.services.event_publisher import event_publisher


class PurchaseService:
    def __init__(self) -> None:
        self._wallet_repo_instance: object | None = None
        self._marketplace_repo_instance: object | None = None
        self._purchase_repo_instance: object | None = None

    @property
    def _wallet(self) -> object:
        if self._wallet_repo_instance is None:
            self._wallet_repo_instance = get_wallet_repository()
        return self._wallet_repo_instance

    @property
    def _marketplace(self) -> object:
        if self._marketplace_repo_instance is None:
            self._marketplace_repo_instance = get_marketplace_repository()
        return self._marketplace_repo_instance

    @property
    def _purchase_repo(self) -> object:
        if self._purchase_repo_instance is None:
            self._purchase_repo_instance = get_purchase_repository()
        return self._purchase_repo_instance

    def create(self, user: AuthenticatedUser, request: PurchaseCreateRequest, idempotency_key: str | None = None) -> PurchaseCreateResponse:
        if user.role not in {UserRole.consumer, UserRole.prosumer}:
            raise ApiError(403, ErrorCode.MARKETPLACE_ROLE_NOT_ALLOWED, "Only consumers and prosumers can buy energy.")
        listing = self._marketplace.get(request.listingId)
        if listing.sellerId == user.user_id:
            raise ApiError(409, ErrorCode.MARKETPLACE_SELF_PURCHASE_NOT_ALLOWED, "Users cannot buy their own listing.")

        quote = marketplace_service.quote(listing, request.quantityKwh)
        breakdown = pricing_service.breakdown(
            quantity_kwh=Decimal(str(request.quantityKwh)),
            price_per_kwh=Decimal(str(listing.pricePerKwh)),
            currency=listing.currency,
        )
        total_paise = round(float(breakdown.totalAmount) * 100)
        platform_fee_paise = round(float(breakdown.platformFee) * 100)
        wallet_service.ensure_available(user.user_id, total_paise)

        # Reserve listing quantity (updates available/reserved counts)
        updated_listing = self._marketplace.reserve_quantity(listing.id, request.quantityKwh)

        # Create purchase record
        purchase = EnergyPurchase(
            id=new_id("PUR"),
            listingId=listing.id,
            buyerId=user.user_id,
            sellerId=listing.sellerId,
            sellerName=listing.sellerName,
            listingTitle=listing.title or listing.notes or f"Energy from {listing.sellerName}",
            quantityKwh=float(breakdown.quantityKwh),
            unitPrice=float(breakdown.unitPrice),
            subtotalAmount=float(breakdown.subtotal),
            platformFee=float(breakdown.platformFee),
            totalAmount=float(breakdown.totalAmount),
            estimatedSavings=quote.estimatedSavings,
            co2ImpactKg=quote.co2ImpactKg,
            purchasedAt=now_utc(),
            status=PurchaseStatus.confirmed,
            currency=listing.currency,
            idempotencyKey=idempotency_key,
        )

        # Create escrow for the purchase
        escrow = escrow_service.create_for_purchase(
            purchase_id=purchase.id,
            listing_id=listing.id,
            buyer_id=user.user_id,
            seller_id=listing.sellerId,
            quantity_kwh=float(breakdown.quantityKwh),
            amount_held_paise=total_paise - platform_fee_paise,
            platform_fee_paise=platform_fee_paise,
        )

        # Hold funds in buyer's wallet
        wallet_service.escrow_hold(
            buyer_id=user.user_id,
            seller_id=listing.sellerId,
            purchase_id=purchase.id,
            escrow_id=escrow.id,
            amount_paise=total_paise,
            platform_fee_paise=platform_fee_paise,
            quantity_kwh=float(breakdown.quantityKwh),
            unit_price_paise=round(float(breakdown.unitPrice) * 100),
            listing_id=listing.id,
        )

        purchase = purchase.model_copy(update={"escrowId": escrow.id})

        # Persist purchase via repository
        self._purchase_repo.save(purchase)

        self._marketplace.append_activity("purchase_escrow_funded", "Energy purchase funds moved to escrow",
            listing_id=updated_listing.id, purchase_id=purchase.id)
        audit_service.append(actor_user_id=user.user_id, action="purchase_escrow_funded",
            resource_type="purchase", resource_id=purchase.id, idempotency_key=idempotency_key,
            metadata={"escrow_id": escrow.id})
        wallet_service.audit(user, endpoint="/purchases", transaction_id=purchase.id,
            wallet_id=wallet_service.wallet(user.user_id).walletId)

        # Publish events
        event_publisher.publish("purchase.created",
            channels=[RealtimeChannel.purchases, RealtimeChannel.wallet, RealtimeChannel.dashboard],
            actor_user_id=user.user_id, user_id=user.user_id,
            payload={"purchase": purchase.model_dump(mode="json"), "escrowId": escrow.id},
            notification_title="Purchase created", notification_message="Your energy purchase is funded in escrow.",
            notification_category=NotificationCategory.purchase, notification_priority=NotificationPriority.high,
            action_url="/purchases")
        event_publisher.publish("escrow.created",
            channels=[RealtimeChannel.wallet, RealtimeChannel.sales],
            actor_user_id=user.user_id, user_id=listing.sellerId,
            payload={"purchaseId": purchase.id, "escrowId": escrow.id, "listingId": listing.id},
            notification_title="Energy sold", notification_message="A buyer funded escrow for your energy listing.",
            notification_category=NotificationCategory.sale, notification_priority=NotificationPriority.high,
            action_url="/sales")
        event_publisher.publish("dashboard.updated",
            channels=[RealtimeChannel.dashboard],
            actor_user_id=user.user_id, payload={"reason": "purchase.created", "purchaseId": purchase.id})

        return PurchaseCreateResponse(purchase=purchase, escrowId=escrow.id)

    def get(self, user: AuthenticatedUser, purchase_id: str) -> EnergyPurchase:
        purchase = self._purchase_repo.get(purchase_id)
        if not purchase:
            raise ApiError(404, ErrorCode.RESOURCE_NOT_FOUND, "Purchase not found.")
        if user.role != UserRole.admin and user.user_id not in {purchase.buyerId, purchase.sellerId}:
            raise ApiError(403, ErrorCode.ACCESS_DENIED, "Purchase access denied.")
        return self._enrich_purchase(purchase)

    def list_for(self, user: AuthenticatedUser, relation: str | None = None) -> list[EnergyPurchase]:
        if user.role == UserRole.admin:
            purchases = self._purchase_repo.list_all()
        else:
            purchases = self._purchase_repo.list_for_user(user.user_id, relation)
        purchases = [self._enrich_purchase(p) for p in purchases]
        purchases.sort(key=lambda item: item.purchasedAt, reverse=True)
        return purchases

    def cancel(self, user: AuthenticatedUser, purchase_id: str) -> EnergyPurchase:
        purchase = self.get(user, purchase_id)
        if purchase.status not in {PurchaseStatus.pending, PurchaseStatus.initiated, PurchaseStatus.reserved}:
            raise ApiError(409, ErrorCode.MARKETPLACE_PURCHASE_NOT_CANCELLABLE, "Purchase can no longer be cancelled.")
        cancelled = self._purchase_repo.update(purchase_id, status=PurchaseStatus.cancelled)
        audit_service.append(actor_user_id=user.user_id, action="purchase_cancelled", resource_type="purchase", resource_id=purchase_id)
        event_publisher.publish("purchase.cancelled",
            channels=[RealtimeChannel.purchases, RealtimeChannel.wallet, RealtimeChannel.marketplace],
            actor_user_id=user.user_id, user_id=cancelled.buyerId,
            payload=cancelled.model_dump(mode="json"),
            notification_title="Purchase cancelled", notification_message="Your energy purchase was cancelled.",
            notification_category=NotificationCategory.purchase, action_url="/purchases")
        return cancelled

    @staticmethod
    def _enrich_purchase(purchase: EnergyPurchase) -> EnergyPurchase:
        if purchase.sellerName and purchase.listingTitle:
            return purchase
        from app.repositories.state import state
        listing = state.listings.get(purchase.listingId)
        seller_name = purchase.sellerName
        listing_title = purchase.listingTitle
        if listing:
            if not seller_name:
                seller_name = listing.sellerName
            if not listing_title:
                listing_title = listing.title or listing.notes or f"Energy from {listing.sellerName}"
        return purchase.model_copy(update={"sellerName": seller_name, "listingTitle": listing_title})


purchase_service = PurchaseService()
