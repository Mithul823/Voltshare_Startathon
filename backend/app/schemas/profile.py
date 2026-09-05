from datetime import datetime

from app.schemas.common import ApiModel, UserRole, now_utc


class Profile(ApiModel):
    id: str
    email: str | None = None
    full_name: str = "VoltShare User"
    role: UserRole = UserRole.consumer
    phone: str | None = None
    avatar_url: str | None = None
    is_active: bool = True
    email_verified: bool = False
    created_at: datetime = now_utc()
    updated_at: datetime = now_utc()


class ProfileUpdate(ApiModel):
    full_name: str | None = None
    phone: str | None = None
    avatar_url: str | None = None


class AuthenticatedProfile(ApiModel):
    id: str
    email: str | None = None
    full_name: str
    role: UserRole
    email_verified: bool
    is_active: bool
