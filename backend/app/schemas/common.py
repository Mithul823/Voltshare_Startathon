from datetime import datetime, timezone
from enum import Enum
from uuid import uuid4

from pydantic import BaseModel, Field


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


class UserRole(str, Enum):
    consumer = "consumer"
    producer = "producer"
    prosumer = "prosumer"
    technician = "technician"
    grid_operator = "grid_operator"
    admin = "admin"


class ApiModel(BaseModel):
    model_config = {"from_attributes": True}


def new_id(prefix: str) -> str:
    return f"{prefix}-{uuid4().hex[:12].upper()}"


class Page(ApiModel):
    limit: int = Field(default=25, ge=1, le=100)
    offset: int = Field(default=0, ge=0)
