import time
from uuid import uuid4

from fastapi import Request, Response


STRICT_CSP = "default-src 'self'"
DOCUMENTATION_CSP = (
    "default-src 'self'; "
    "script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; "
    "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; "
    "img-src 'self' data: https://fastapi.tiangolo.com; "
    "font-src 'self' data: https://cdn.jsdelivr.net; "
    "connect-src 'self'"
)
DOCUMENTATION_PATHS = {"/docs", "/redoc", "/openapi.json"}


async def request_context_middleware(request: Request, call_next):
    request.state.request_id = request.headers.get("X-Request-ID", str(uuid4()))
    start = time.perf_counter()
    response: Response = await call_next(request)
    response.headers["X-Request-ID"] = request.state.request_id
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Content-Security-Policy"] = DOCUMENTATION_CSP if request.url.path in DOCUMENTATION_PATHS else STRICT_CSP
    if request.url.scheme == "https":
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["X-Response-Time-Ms"] = str(round((time.perf_counter() - start) * 1000, 2))
    return response
