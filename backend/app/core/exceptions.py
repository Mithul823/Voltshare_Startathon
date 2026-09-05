from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


class ErrorCode:
    AUTH_REQUIRED = "AUTH_REQUIRED"
    AUTH_INVALID_TOKEN = "AUTH_INVALID_TOKEN"
    ACCESS_DENIED = "ACCESS_DENIED"
    VALIDATION_FAILED = "VALIDATION_FAILED"
    DATABASE_ERROR = "DATABASE_ERROR"
    CONFIGURATION_ERROR = "CONFIGURATION_ERROR"
    RESOURCE_NOT_FOUND = "RESOURCE_NOT_FOUND"
    INTERNAL_ERROR = "INTERNAL_ERROR"
    LISTING_NOT_AVAILABLE = "LISTING_NOT_AVAILABLE"
    INSUFFICIENT_BALANCE = "INSUFFICIENT_BALANCE"
    INVALID_ESCROW_STATE = "INVALID_ESCROW_STATE"
    DUPLICATE_OPERATION = "DUPLICATE_OPERATION"
    INTEGRITY_FAILURE = "INTEGRITY_FAILURE"
    RISK_VERIFICATION_REQUIRED = "RISK_VERIFICATION_REQUIRED"
    ACTION_BLOCKED = "ACTION_BLOCKED"
    RATE_LIMITED = "RATE_LIMITED"
    AI_SERVICE_UNAVAILABLE = "AI_SERVICE_UNAVAILABLE"
    MARKETPLACE_LISTING_NOT_FOUND = "MARKETPLACE_LISTING_NOT_FOUND"
    MARKETPLACE_LISTING_NOT_ACTIVE = "MARKETPLACE_LISTING_NOT_ACTIVE"
    MARKETPLACE_LISTING_EXPIRED = "MARKETPLACE_LISTING_EXPIRED"
    MARKETPLACE_INSUFFICIENT_QUANTITY = "MARKETPLACE_INSUFFICIENT_QUANTITY"
    MARKETPLACE_SELF_PURCHASE_NOT_ALLOWED = "MARKETPLACE_SELF_PURCHASE_NOT_ALLOWED"
    MARKETPLACE_ROLE_NOT_ALLOWED = "MARKETPLACE_ROLE_NOT_ALLOWED"
    MARKETPLACE_INVALID_QUANTITY = "MARKETPLACE_INVALID_QUANTITY"
    MARKETPLACE_IDEMPOTENCY_CONFLICT = "MARKETPLACE_IDEMPOTENCY_CONFLICT"
    MARKETPLACE_LISTING_VERSION_CONFLICT = "MARKETPLACE_LISTING_VERSION_CONFLICT"
    MARKETPLACE_PURCHASE_NOT_CANCELLABLE = "MARKETPLACE_PURCHASE_NOT_CANCELLABLE"


class ApiError(Exception):
    def __init__(self, status_code: int, code: str, message: str, details: dict | None = None) -> None:
        self.status_code = status_code
        self.code = code
        self.message = message
        self.details = details


def error_payload(code: str, message: str, details: dict | None) -> dict:
    return {"error": {"code": code, "message": message, "details": details}}


def add_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    async def api_error_handler(request: Request, exc: ApiError) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content=error_payload(exc.code, exc.message, exc.details),
            headers={"X-Request-ID": getattr(request.state, "request_id", str(uuid4()))},
        )

    @app.exception_handler(RequestValidationError)
    async def validation_error_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
        return JSONResponse(
            status_code=422,
            content=error_payload(ErrorCode.VALIDATION_FAILED, "Request validation failed.", {"errors": exc.errors()}),
        )

    @app.exception_handler(Exception)
    async def unhandled_error_handler(request: Request, exc: Exception) -> JSONResponse:
        return JSONResponse(
            status_code=500,
            content=error_payload(ErrorCode.INTERNAL_ERROR, "Unexpected server error.", None),
        )
