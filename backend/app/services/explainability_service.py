class ExplainabilityService:
    def confidence(self, *, data_points: int, issues: list[str], spread: float = 0.0) -> float:
        base = min(0.82, 0.35 + data_points / 120)
        penalty = min(0.4, len(issues) * 0.08 + spread * 0.03)
        return round(max(0.12, base - penalty), 2)

    def grade(self, score: int) -> str:
        if score >= 90:
            return "Exceptional"
        if score >= 75:
            return "Excellent"
        if score >= 60:
            return "Good"
        if score >= 40:
            return "Developing"
        return "Needs Improvement"


explainability_service = ExplainabilityService()
