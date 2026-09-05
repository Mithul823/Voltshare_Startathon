from app.core.security import AuthenticatedUser
from app.repositories.dashboard_repository import dashboard_repository
from app.repositories.state import state
from app.schemas.ai import AnomalyInsight, AnomalySeverity
from app.schemas.common import UserRole
from app.services.marketplace_service import marketplace_service


class AnomalyDetectionService:
    def for_user(self, user: AuthenticatedUser) -> list[AnomalyInsight]:
        readings = dashboard_repository.get_dashboard_summary(user.user_id)
        anomalies: list[AnomalyInsight] = []
        if any(item.battery_percent < 20 for item in readings[-6:]):
            anomalies.append(AnomalyInsight(title="Low battery pattern", message="Possible anomaly: recent battery reserve dropped below 20%. Inspection recommended if unexpected.", severity=AnomalySeverity.medium, confidence=0.62))
        if user.role == UserRole.technician:
            anomalies.append(AnomalyInsight(title="Sensor consistency check", message="Possible data gap indicators should be reviewed before claiming a device fault.", severity=AnomalySeverity.low, confidence=0.55))
        if user.role == UserRole.admin:
            prices = [item.pricePerKwh for item in marketplace_service.list(active_only=True)]
            if prices and max(prices) > min(prices) * 1.35:
                anomalies.append(AnomalyInsight(title="Unusual listing price spread", message="Marketplace price spread is elevated. This is an indicator only.", severity=AnomalySeverity.medium, confidence=0.64, supporting_metrics={"min_price": min(prices), "max_price": max(prices)}))
        state.anomaly_events.extend(anomalies)
        return anomalies

    def admin(self, user: AuthenticatedUser) -> list[AnomalyInsight]:
        if user.role != UserRole.admin:
            return []
        return self.for_user(user)


anomaly_detection_service = AnomalyDetectionService()
