from datetime import datetime

from pydantic import BaseModel, Field


class UserBase(BaseModel):
    username: str = Field(min_length=2, max_length=10)
    full_name: str | None = Field(default=None, max_length=128)
    remark: str | None = Field(default=None, max_length=255)


class UserCreate(UserBase):
    password: str = Field(min_length=6, max_length=128)
    role_codes: list[str] = Field(default_factory=list)
    process_codes: list[str] = Field(default_factory=list)
    stage_id: int | None = Field(default=None, gt=0)
    is_active: bool = True


class UserUpdate(BaseModel):
    username: str | None = Field(default=None, min_length=2, max_length=10)
    full_name: str | None = Field(default=None, max_length=128)
    remark: str | None = Field(default=None, max_length=255)
    password: str | None = Field(default=None, min_length=6, max_length=128)
    role_codes: list[str] | None = None
    process_codes: list[str] | None = None
    stage_id: int | None = Field(default=None, gt=0)
    is_active: bool | None = None
    must_change_password: bool | None = None


class UserResetPasswordRequest(BaseModel):
    password: str = Field(min_length=6, max_length=128)


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
    role_codes: list[str]
    role_names: list[str]
    process_codes: list[str]
    process_names: list[str]
    stage_names: list[str]
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
