from fastapi import APIRouter, Depends, Response

from app.api.dependencies import get_current_user
from app.core.security import AuthenticatedUser
from app.repositories.state import state
from app.schemas.security import RiskEvaluation, RiskEvaluationRequest, SecurityEvent, TrustedDevice
from app.services.security_risk_service import security_risk_service

router = APIRouter()


@router.post("/evaluate-risk", response_model=RiskEvaluation)
def evaluate_risk(request: RiskEvaluationRequest, user: AuthenticatedUser = Depends(get_current_user)) -> RiskEvaluation:
    return security_risk_service.evaluate(user.user_id, request)


@router.get("/events", response_model=list[SecurityEvent])
def events(user: AuthenticatedUser = Depends(get_current_user)) -> list[SecurityEvent]:
    return [event for event in state.security_events if user.role == "admin" or event.userId == user.user_id]


@router.get("/score", response_model=RiskEvaluation)
def score(user: AuthenticatedUser = Depends(get_current_user)) -> RiskEvaluation:
    return security_risk_service.evaluate(user.user_id, RiskEvaluationRequest())


@router.get("/devices", response_model=list[TrustedDevice])
def devices(user: AuthenticatedUser = Depends(get_current_user)) -> list[TrustedDevice]:
    return security_risk_service.devices(user.user_id)


@router.post("/devices/{device_id}/trust", response_model=TrustedDevice)
def trust_device(device_id: str, user: AuthenticatedUser = Depends(get_current_user)) -> TrustedDevice:
    return security_risk_service.trust_device(user.user_id, device_id)


@router.delete("/devices/{device_id}", status_code=204)
def remove_device(device_id: str, response: Response, user: AuthenticatedUser = Depends(get_current_user)) -> Response:
    security_risk_service.remove_device(user.user_id, device_id)
    response.status_code = 204
    return response
