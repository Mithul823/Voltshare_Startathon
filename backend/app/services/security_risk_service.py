from app.repositories.state import state
from app.schemas.common import new_id
from app.schemas.security import RiskEvaluation, RiskEvaluationRequest, SecurityEvent, TrustedDevice


class SecurityRiskService:
    def evaluate(self, user_id: str, request: RiskEvaluationRequest) -> RiskEvaluation:
        score = 0
        reasons: list[str] = []
        def add(points: int, reason: str) -> None:
            nonlocal score
            score += points
            reasons.append(reason)
        if request.newDevice:
            add(20, "New device")
        if request.unusualTime:
            add(10, "Unusual time")
        if request.failedAttempts:
            add(min(30, request.failedAttempts * 8), "Failed attempts")
        if request.amountPaise >= 100000:
            add(20, "Large amount")
        if request.repeatedDefaults:
            add(20, "Repeated defaults")
        if request.repeatedDisputes:
            add(10, "Repeated disputes")
        if request.tamperingSignal:
            add(50, "Tampering signal")
        if request.sessionAnomaly:
            add(25, "Session anomaly")
        if request.longInactivity:
            add(10, "Long inactivity")
        score = min(score, 100)
        level = "low" if score < 35 else "medium" if score < 70 else "high"
        result = RiskEvaluation(score=score, level=level, reasons=reasons, requiredAction="block" if score >= 85 else "step_up" if score >= 50 else "allow", stepUpRequired=score >= 50, blocked=score >= 85)
        state.security_events.append(SecurityEvent(id=new_id("SEC"), userId=user_id, eventType="risk_evaluated", riskScore=score))
        return result

    def devices(self, user_id: str) -> list[TrustedDevice]:
        return [item for item in state.devices.values() if item.userId == user_id]

    def trust_device(self, user_id: str, device_id: str) -> TrustedDevice:
        device = TrustedDevice(id=device_id, userId=user_id, label=f"Device {device_id[-4:]}", trusted=True)
        state.devices[device_id] = device
        return device

    def remove_device(self, user_id: str, device_id: str) -> None:
        device = state.devices.get(device_id)
        if device and device.userId == user_id:
            del state.devices[device_id]


security_risk_service = SecurityRiskService()
