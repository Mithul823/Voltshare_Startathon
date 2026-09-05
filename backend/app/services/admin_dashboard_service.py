"""Admin dashboard service — delegates aggregate queries to the active repository."""

from app.repositories.admin_dashboard_repository import get_admin_dashboard_repository
from app.schemas.admin_dashboard import AdminDashboardResponse


class AdminDashboardService:
    def __init__(self) -> None:
        self._repo_instance: object | None = None

    @property
    def _repo(self) -> object:
        if self._repo_instance is None:
            self._repo_instance = get_admin_dashboard_repository()
        return self._repo_instance

    async def dashboard(self, range_days: int = 30) -> AdminDashboardResponse:
        """Fetch aggregated admin dashboard data from the active repository.

        In demo mode, returns deterministic mock data.
        In live mode, runs aggregate queries against Supabase tables.
        """
        return await self._repo.fetch(range_days=range_days)


admin_dashboard_service = AdminDashboardService()
