from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class UserBase(BaseModel):
    username: str = Field(min_length=2, max_length=10)
    full_name: str | None = Field(default=None, max_length=128)
    remark: str | None = Field(default=None, max_length=255)


class UserCreate(UserBase):
    password: str = Field(min_length=6, max_length=128)
    role_code: str = Field(min_length=2, max_length=64)
    stage_id: int | None = Field(default=None, gt=0)
    is_active: bool = True


class UserUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    username: str | None = Field(default=None, min_length=2, max_length=10)
    full_name: str | None = Field(default=None, max_length=128)
    remark: str | None = Field(default=None, max_length=255)
    role_code: str | None = Field(default=None, min_length=2, max_length=64)
    stage_id: int | None = Field(default=None, gt=0)
    is_active: bool | None = None
    must_change_password: bool | None = None


class UserResetPasswordRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    password: str = Field(min_length=6, max_length=128)
    remark: str = Field(min_length=1, max_length=255)


class UserLifecycleRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    remark: str | None = Field(default=None, max_length=255)


class UserDeleteRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    remark: str = Field(min_length=1, max_length=255)


class UserRestoreRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    remark: str = Field(min_length=1, max_length=255)


class UserItem(BaseModel):
    id: int
    username: str
    full_name: str | None
    remark: str | None
    is_online: bool
    is_active: bool
    is_deleted: bool
    must_change_password: bool
    last_seen_at: datetime | None = None
    stage_id: int | None = None
    stage_name: str | None = None
    role_code: str | None = None
    role_name: str | None = None
    last_login_at: datetime | None = None
    last_login_ip: str | None = None
    password_changed_at: datetime | None = None
    created_at: datetime
    updated_at: datetime


class UserListResult(BaseModel):
    total: int
    items: list[UserItem]


class UserExportResult(BaseModel):
    filename: str
    content_type: str
    content_base64: str


class UserExportTaskCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    format: str = Field(pattern="^(csv|excel)$")
    keyword: str | None = Field(default=None, max_length=255)
    role_code: str | None = Field(default=None, max_length=64)
    is_active: bool | None = None
    deleted_scope: str = Field(default="active", pattern="^(active|deleted|all)$")


class UserExportTaskItem(BaseModel):
    id: int
    task_code: str
    status: str
    format: str
    deleted_scope: str
    keyword: str | None = None
    role_code: str | None = None
    is_active: bool | None = None
    record_count: int
    file_name: str | None = None
    mime_type: str | None = None
    failure_reason: str | None = None
    requested_at: datetime
    started_at: datetime | None = None
    finished_at: datetime | None = None
    expires_at: datetime | None = None


class UserExportTaskListResult(BaseModel):
    total: int
    items: list[UserExportTaskItem]


class UserOnlineStatusResult(BaseModel):
    user_ids: list[int]


class UserLifecycleResult(BaseModel):
    user: UserItem
    forced_offline_session_count: int
    cleared_online_status: bool


class UserDeleteResult(BaseModel):
    user: UserItem
    forced_offline_session_count: int
    cleared_online_status: bool
    deleted: bool


class UserPasswordResetResult(BaseModel):
    user: UserItem
    forced_offline_session_count: int
    must_change_password: bool
    cleared_online_status: bool
