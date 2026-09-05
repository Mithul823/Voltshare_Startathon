import hashlib
import json
from datetime import datetime, timedelta, timezone
from typing import Callable

from app.core.exceptions import ApiError, ErrorCode


class IdempotencyStore:
    def __init__(self) -> None:
        self._records: dict[tuple[str, str, str], dict] = {}

    @staticmethod
    def request_hash(payload: object) -> str:
        encoded = json.dumps(payload, sort_keys=True, default=str, separators=(",", ":"))
        return hashlib.sha256(encoded.encode("utf-8")).hexdigest()

    def run(self, *, key: str | None, user_id: str, operation: str, payload: object, handler: Callable[[], tuple[int, object]]) -> tuple[int, object]:
        if not key:
            raise ApiError(400, ErrorCode.VALIDATION_FAILED, "Idempotency-Key header is required.")
        record_key = (user_id, operation, key)
        digest = self.request_hash(payload)
        existing = self._records.get(record_key)
        if existing:
            if existing["request_hash"] != digest:
                raise ApiError(409, ErrorCode.MARKETPLACE_IDEMPOTENCY_CONFLICT, "Idempotency key was reused with a different payload.")
            return existing["status_code"], existing["response"]
        status_code, response = handler()
        self._records[record_key] = {
            "request_hash": digest,
            "status_code": status_code,
            "response": response,
            "created_at": datetime.now(timezone.utc),
            "expires_at": datetime.now(timezone.utc) + timedelta(hours=24),
        }
        return status_code, response


idempotency_store = IdempotencyStore()
