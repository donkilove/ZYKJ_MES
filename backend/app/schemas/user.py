from datetime import datetime

from pydantic import BaseModel, Field


class UserBase(BaseModel):
    username: str = Field(min_length=3, max_length=64)
    full_name: str | None = Field(default=None, max_length=128)


class UserCreate(UserBase):
    password: str = Field(min_length=6, max_length=128)
    role_codes: list[str] = Field(default_factory=list)
    process_codes: list[str] = Field(default_factory=list)


class UserUpdate(BaseModel):
    username: str | None = Field(default=None, min_length=3, max_length=64)
    full_name: str | None = Field(default=None, max_length=128)
    password: str | None = Field(default=None, min_length=6, max_length=128)
    role_codes: list[str] | None = None
    process_codes: list[str] | None = None


class UserItem(BaseModel):
    id: int
    username: str
    full_name: str | None
    role_codes: list[str]
    role_names: list[str]
    process_codes: list[str]
    process_names: list[str]
    created_at: datetime
    updated_at: datetime


class UserListResult(BaseModel):
    total: int
    items: list[UserItem]
