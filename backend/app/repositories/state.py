from datetime import timedelta

from app.schemas.audit import AuditEvent
from app.schemas.ai import AIInsight, AnomalyInsight, AssistantConversation, SmartAlert
from app.schemas.common import now_utc
from app.schemas.emergency import EmergencyRequestData
from app.schemas.escrow import Dispute, EscrowAgreement
from app.schemas.marketplace import EnergyListing, EnergySource, ListingStatus
from app.schemas.realtime import Notification, PresenceRecord, RealtimeEvent
from app.schemas.forecast import ForecastResponse
from app.schemas.recommendation import Recommendation, PricingSuggestion
from app.schemas.support import SupportTicketData
from app.schemas.sustainability import SustainabilityScore, SustainabilitySummary
from app.schemas.purchase import EnergyPurchase
from app.schemas.security import SecurityEvent, TrustedDevice
from app.schemas.wallet import (
    Deposit,
    EscrowAccount,
    LedgerEntry,
    Refund,
    Settlement,
    TransactionAudit,
    Wallet,
    WalletTransaction,
    Withdrawal,
)


class AppState:
    def __init__(self) -> None:
        self.listings: dict[str, EnergyListing] = {}
        self.purchases: dict[str, EnergyPurchase] = {}
        self.wallets: dict[str, Wallet] = {}
        self.transactions: dict[str, list[WalletTransaction]] = {}
        self.ledger_entries: dict[str, LedgerEntry] = {}
        self.ledger_by_transaction: dict[str, list[str]] = {}
        self.escrow_accounts: dict[str, EscrowAccount] = {}
        self.settlements: dict[str, Settlement] = {}
        self.withdrawals: dict[str, Withdrawal] = {}
        self.deposits: dict[str, Deposit] = {}
        self.refunds: dict[str, Refund] = {}
        self.transaction_audit: list[TransactionAudit] = []
        self.escrows: dict[str, EscrowAgreement] = {}
        self.disputes: dict[str, Dispute] = {}
        self.default_cases: dict[str, dict] = {}
        self.audit_events: list[AuditEvent] = []
        self.security_events: list[SecurityEvent] = []
        self.devices: dict[str, TrustedDevice] = {}
        self.insights: dict[str, list] = {}
        self.notifications: dict[str, list[Notification]] = {}
        self.realtime_events: list[RealtimeEvent] = []
        self.presence: dict[str, PresenceRecord] = {}
        self.forecasts: dict[str, ForecastResponse] = {}
        self.recommendations: dict[str, list[Recommendation]] = {}
        self.pricing_suggestions: dict[str, PricingSuggestion] = {}
        self.sustainability_scores: dict[str, SustainabilityScore] = {}
        self.sustainability_summaries: dict[str, SustainabilitySummary] = {}
        self.ai_insight_items: dict[str, list[AIInsight]] = {}
        self.assistant_conversations: dict[str, AssistantConversation] = {}
        self.anomaly_events: list[AnomalyInsight] = []
        self.smart_alerts: dict[str, SmartAlert] = {}
        self.emergency_requests: dict[str, EmergencyRequestData] = {}
        self.support_tickets: dict[str, SupportTicketData] = {}
        self._seed()

    def wallet_for(self, user_id: str) -> Wallet:
        wallet = self.wallets.get(user_id)
        if wallet:
            return wallet
        wallet = Wallet(
            walletId=f"WAL-{user_id}",
            userId=user_id,
            availableBalancePaise=125000,
            heldBalancePaise=0,
            pendingBalancePaise=32000,
            escrowHeldBalancePaise=0,
            totalEarnedPaise=486000,
            totalSpentPaise=293000,
            totalWithdrawnPaise=84000,
            totalAddedPaise=200000,
        )
        self.wallets[user_id] = wallet
        self.transactions[user_id] = []
        return wallet

    def _seed(self) -> None:
        now = now_utc()
        samples = [
            ("ravi", "Ravi Solar Hub", "producer", "RS", EnergySource.solar, 4.5, 8.20, "Kakkanad", True),
            ("green", "GreenNest Energy", "prosumer", "GE", EnergySource.communitySolar, 2.8, 7.85, "Edappally", False),
            ("anjali", "Anjali Rooftop Solar", "producer", "AR", EnergySource.solar, 6.0, 8.60, "Vyttila", True),
            ("eco", "EcoGrid Community", "producer", "EC", EnergySource.hybrid, 10.0, 7.50, "Fort Kochi", True),
        ]
        for sid, name, role, initials, source, energy, price, location, battery in samples:
            listing = EnergyListing(
                id=sid,
                sellerId=f"seller-{sid}",
                sellerName=name,
                sellerRole=role,
                sellerInitials=initials,
                sellerRating=4.8,
                reviewCount=100,
                energySource=source,
                availableEnergyKwh=energy,
                pricePerKwh=price,
                distanceKm=2,
                location=location,
                batteryBacked=battery,
                renewableVerified=True,
                availabilityStart=now - timedelta(hours=1),
                availabilityEnd=now + timedelta(hours=6),
                createdAt=now - timedelta(minutes=40),
                listingStatus=ListingStatus.active,
            )
            self.listings[listing.id] = listing
        self.wallet_for("current-user")


state = AppState()
