from datetime import timedelta

from app.core.security import AuthenticatedUser
from app.repositories.state import state
from app.schemas.ai import AnomalySeverity, SmartAlert
from app.schemas.realtime import NotificationCategory, NotificationPriority, RealtimeChannel
from app.services.event_publisher import event_publisher
from app.schemas.common import now_utc


class SmartAlertService:
    window = timedelta(hours=2)

    def create(self, user: AuthenticatedUser, *, alert_type: str, severity: AnomalySeverity, title: str, message: str) -> SmartAlert:
        key = f"{user.user_id}:{alert_type}:{severity.value}"
        existing = state.smart_alerts.get(key)
        if existing and now_utc() - existing.created_at < self.window:
            return existing
        alert = SmartAlert(event_key=alert_type, title=title, message=message, severity=severity, deduplication_key=key)
        state.smart_alerts[key] = alert
        event_publisher.publish(
            "smart_alert.created",
            channels=[RealtimeChannel.notifications],
            user_id=user.user_id,
            payload={"id": alert.id, "title": alert.title, "severity": alert.severity.value},
            notification_title=title,
            notification_message=message,
            notification_category=NotificationCategory.system,
            notification_priority=NotificationPriority.high if severity in {AnomalySeverity.high, AnomalySeverity.critical} else NotificationPriority.medium,
        )
        return alert


smart_alert_service = SmartAlertService()
