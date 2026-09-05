from fastapi import APIRouter, Depends

from app.core.config import Settings, get_settings
from app.db.supabase import check_supabase_reachable
from app.api.routes.health import build_health_response

router = APIRouter()


@router.get("/health")
async def api_health(settings: Settings = Depends(get_settings)) -> dict:
    """API v1 health check that delegates to the shared health builder.

    Returns the same structured response as the root /health endpoint.
    """
    supabase_status = await check_supabase_reachable(settings)
    return build_health_response(settings, supabase_status)
