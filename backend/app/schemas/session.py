from datetime import datetime

from pydantic import BaseModel, Field


class LoginLogItem(BaseModel):
    id: int
    login_time: datetime
    username: str
    success: bool
    ip_address: str | None = None
    terminal_info: str | None = None
    failure_reason: str | None = None
    session_token_id: str | None = None


class LoginLogListResult(BaseModel):
    total: int
    items: list[LoginLogItem]


class OnlineSessionItem(BaseModel):
    id: int
    session_token_id: str
    user_id: int
    username: str
    role_codes: list[str] = Field(default_factory=list)
    role_names: list[str] = Field(default_factory=list)
    stage_name: str | None = None
    login_time: datetime
    last_active_at: datetime
    expires_at: datetime
    ip_address: str | None = None
    terminal_info: str | None = None
    status: str


class OnlineSessionListResult(BaseModel):
    total: int
    items: list[OnlineSessionItem]


class ForceOfflineRequest(BaseModel):
    session_token_id: str


class BatchForceOfflineRequest(BaseModel):
    session_token_ids: list[str] = Field(default_factory=list, min_length=1)


class ForceOfflineResult(BaseModel):
    affected: int
