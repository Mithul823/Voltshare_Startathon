from app.core.config import get_settings
from app.db.supabase import check_supabase_reachable


async def check_health() -> dict:
    """Returns the same health data as the /api/v1/health endpoint."""
    settings = get_settings()
    supabase = await check_supabase_reachable(settings)
    return {
        "status": "ok" if supabase.get("status") == "ok" else "degraded",
        "supabase": supabase,
    }
