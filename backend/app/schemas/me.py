from datetime import datetime

from pydantic import BaseModel, Field


class ProfileResult(BaseModel):
    id: int
    username: str
    full_name: str | None = None
    role_code: str | None = None
    role_name: str | None = None
    stage_id: int | None = None
    stage_name: str | None = None
    is_active: bool
    created_at: datetime
    last_login_at: datetime | None = None
    last_login_ip: str | None = None
    password_changed_at: datetime | None = None


class ChangePasswordRequest(BaseModel):
    old_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=6, max_length=128)
    confirm_password: str = Field(min_length=6, max_length=128)


class CurrentSessionResult(BaseModel):
    session_token_id: str
    login_time: datetime
    last_active_at: datetime
    expires_at: datetime
    status: str
    remaining_seconds: int
