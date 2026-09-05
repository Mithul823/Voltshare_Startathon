import httpx
from supabase import Client, create_client

from app.core.config import Settings, get_settings


def get_supabase_public_client(settings: Settings | None = None) -> Client | None:
    current = settings or get_settings()
    if not current.supabase_url or not current.supabase_anon_key:
        return None
    return create_client(current.supabase_url, current.supabase_anon_key)


def get_supabase_admin_client(settings: Settings | None = None) -> Client | None:
    current = settings or get_settings()
    if not current.supabase_url or not current.supabase_service_role_key:
        return None
    return create_client(current.supabase_url, current.supabase_service_role_key)


async def check_supabase_reachable(settings: Settings | None = None) -> dict[str, str | int | None]:
    """Check Supabase connectivity with bounded timeout and diagnostic info.

    Returns a structured status dict. Does not expose secrets.
    """
    current = settings or get_settings()
    if not current.supabase_url:
        return {"status": "missing_config", "reason": "SUPABASE_URL is not configured"}
    if not current.supabase_anon_key:
        return {"status": "missing_config", "reason": "SUPABASE_ANON_KEY is not configured"}
    try:
        host = current.supabase_url.rstrip("/")
        async with httpx.AsyncClient(timeout=4.0) as client:
            health_response = await client.get(f"{host}/auth/v1/health")
            if health_response.status_code >= 500:
                return {"status": "degraded", "reason": f"Supabase returned server error (HTTP {health_response.status_code})"}
            rest_response = await client.get(f"{host}/rest/v1/", headers={"apikey": current.supabase_anon_key, "Accept": "application/json"})
            db_ok = rest_response.status_code < 500
            latency_ms = health_response.elapsed.total_seconds() * 1000 if hasattr(health_response, 'elapsed') else None
            return {
                "status": "ok",
                "reason": None,
                "latency_ms": round(latency_ms) if latency_ms else None,
                "rest_api": "ok" if db_ok else "degraded",
            }
    except httpx.TimeoutException:
        return {"status": "timeout", "reason": "Supabase health check timed out after 4s"}
    except httpx.HTTPError as exc:
        return {"status": "unreachable", "reason": f"Cannot reach Supabase: {type(exc).__name__}"}
