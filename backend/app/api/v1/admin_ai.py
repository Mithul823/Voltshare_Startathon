from fastapi import APIRouter, Depends

from app.api.dependencies import require_any_role
from app.core.security import AuthenticatedUser
from app.schemas.ai import AnomalyInsight
from app.schemas.common import UserRole
from app.services.anomaly_detection_service import anomaly_detection_service
from app.services.marketplace_service import marketplace_service

router = APIRouter()


@router.get("/anomalies", response_model=list[AnomalyInsight])
def anomalies(user: AuthenticatedUser = Depends(require_any_role(UserRole.admin))) -> list[AnomalyInsight]:
    return anomaly_detection_service.admin(user)


@router.get("/trends")
def trends(user: AuthenticatedUser = Depends(require_any_role(UserRole.admin))) -> dict:
    summary = marketplace_service.summary()
    return {"marketplace": summary.model_dump(mode="json"), "indicator_only": True, "message": "Admin trend data is advisory and does not trigger automatic moderation."}
