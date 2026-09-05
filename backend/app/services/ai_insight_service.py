from app.core.security import AuthenticatedUser
from app.repositories.state import state
from app.schemas.ai import AIInsight
from app.schemas.realtime import RealtimeChannel
from app.services.event_publisher import event_publisher
from app.services.recommendation_service import recommendation_service


class AIInsightService:
    def list_for(self, user: AuthenticatedUser, period: str = "daily") -> list[AIInsight]:
        recommendations = recommendation_service.for_user(user)
        insights = [
            AIInsight(
                title=item.title,
                message=item.message,
                category=item.category.value,
                priority=item.priority.value,
                confidence=item.confidence,
                explanation=item.reason,
            )
            for item in recommendations[:4]
        ]
        state.ai_insight_items[user.user_id] = insights
        if insights:
            event_publisher.publish("insight.created", channels=[RealtimeChannel.dashboard, RealtimeChannel.notifications], user_id=user.user_id, payload={"count": len(insights), "period": period})
        return insights


ai_insight_service = AIInsightService()
