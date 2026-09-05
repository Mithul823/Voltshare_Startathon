from fastapi import APIRouter, Depends

from app.core.config import Settings, get_settings
from app.db.supabase import check_supabase_reachable
from app.schemas.realtime import RealtimeChannel
from app.services.realtime_service import realtime_service

router = APIRouter()

_realtime_channels = [
    RealtimeChannel.dashboard,
    RealtimeChannel.marketplace,
    RealtimeChannel.wallet,
    RealtimeChannel.notifications,
    RealtimeChannel.admin,
    RealtimeChannel.grid,
]


def build_health_response(settings: Settings, supabase_status: dict) -> dict:
    """Build a structured health response shared by root and v1 endpoints."""
    public = settings.public_dict()
    all_ok = supabase_status["status"] == "ok"
    runtime_mode = "demo" if settings.is_demo_mode else "production"
    return {
        "status": "ok" if all_ok else "degraded",
        "service": settings.app_name,
        "version": settings.version,
        "environment": settings.app_env,
        "runtime_mode": runtime_mode,
        "persistence_layer": "supabase" if public["supabase_configured"] else "in_memory",
        "services": {
            "api": {"status": "ok"},
            "supabase": supabase_status,
            "database": {
                "status": "ok" if supabase_status["status"] == "ok" else "unavailable",
                "configured": public["supabase_configured"],
            },
            "realtime": {
                "status": "active",
                "active_connections": sum(
                    realtime_service.manager.active_count(ch) for ch in _realtime_channels
                ),
            },
            "ai": {
                "status": "configured" if settings.gemini_api_key else "not_configured",
                "provider": "gemini" if settings.gemini_api_key else "rule_based",
                "enabled": settings.ai_enabled,
            },
        },
        "configuration": {
            "supabase_configured": public["supabase_configured"],
            "supabase_jwks_configured": public["supabase_jwks_configured"],
            "demo_endpoints": settings.enable_demo_endpoints,
            "ai_enabled": settings.ai_enabled,
            "marketplace_platform_fee_percent": settings.marketplace_platform_fee_percent,
        },
    }


@router.get("/health")
async def root_health(settings: Settings = Depends(get_settings)) -> dict:
    """Root health check that also verifies Supabase connectivity.

    Returns a structured health response with service-level details.
    Does not expose secrets.
    """
    supabase_status = await check_supabase_reachable(settings)
    return build_health_response(settings, supabase_status)
