"""Dashboard repository — wraps the active energy readings repository.

Provides high-level dashboard queries (summary, history, activity) by
delegating to the currently active energy readings repository.
"""

from __future__ import annotations

from datetime import datetime, timedelta

from app.repositories.energy_repository import get_energy_readings_repository
from app.schemas.common import now_utc
from app.schemas.dashboard import EnergyReading


class DashboardRepository:
    """High-level dashboard queries backed by the energy readings repository.

    Uses ``get_energy_readings_repository()`` which returns either an
    ``InMemoryEnergyReadingsRepository`` or a ``SupabaseEnergyReadingsRepository``.
    """

    def __init__(self) -> None:
        self._energy_repo_instance: object | None = None

    @property
    def _energy(self) -> object:
        if self._energy_repo_instance is None:
            self._energy_repo_instance = get_energy_readings_repository()
        return self._energy_repo_instance

    def get_latest_reading(self, user_id: str) -> EnergyReading:
        return self._energy.latest(user_id)

    def get_energy_history(self, user_id: str, start: datetime | None = None, end: datetime | None = None) -> list[EnergyReading]:
        current_end = end or now_utc()
        current_start = start or (current_end - timedelta(hours=24))
        return self._energy.between(user_id, current_start, current_end)

    def get_battery_history(self, user_id: str, start: datetime | None = None, end: datetime | None = None) -> list[EnergyReading]:
        return self.get_energy_history(user_id, start, end)

    def get_recent_activity(self, user_id: str) -> list[EnergyReading]:
        return self.get_energy_history(user_id)[-6:]

    def get_dashboard_summary(self, user_id: str) -> list[EnergyReading]:
        return self.get_energy_history(user_id)


dashboard_repository = DashboardRepository()
