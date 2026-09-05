import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.router import api_router
from app.api.routes.realtime import register_realtime_websockets
from app.api.routes.health import router as root_health_router
from app.core.config import get_settings
from app.core.exceptions import add_exception_handlers
from app.core.logging import request_context_middleware

logger = logging.getLogger(__name__)


def create_app() -> FastAPI:
    settings = get_settings()
    settings.validate_startup()

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        settings.validate_startup()
        yield

    app = FastAPI(
        title=settings.app_name,
        version=settings.version,
        description="VoltShare Phase 6.1 FastAPI backend foundation with Supabase authentication.",
        docs_url=None if settings.is_production else "/docs",
        redoc_url=None if settings.is_production else "/redoc",
        lifespan=lifespan,
    )

    # Log active mode and configuration summary at startup
    supabase_configured = bool(settings.supabase_url and settings.supabase_anon_key)
    runtime_mode = "demo" if settings.is_demo_mode else "production"
    data_persistence = "supabase" if supabase_configured else "in_memory"
    logger.info(
        "VoltShare starting | "
        f"env={settings.app_env} "
        f"mode={runtime_mode} "
        f"persistence={data_persistence} "
        f"ai={'gemini' if settings.gemini_api_key else 'rule_based'} "
        f"version={settings.version}"
    )

    app.middleware("http")(request_context_middleware)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins if settings.cors_origins else [],
        allow_credentials=True,
        allow_methods=["GET", "POST", "PATCH", "PUT", "DELETE"],
        allow_headers=["Authorization", "Content-Type", "Idempotency-Key", "X-Request-ID"],
    )
    add_exception_handlers(app)
    app.include_router(root_health_router)
    app.include_router(api_router, prefix=settings.api_v1_prefix)
    register_realtime_websockets(app)

    return app


app = create_app()
