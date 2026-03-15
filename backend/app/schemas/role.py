from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class RoleCreate(BaseModel):
    code: str = Field(min_length=2, max_length=64)
    name: str = Field(min_length=1, max_length=128)
    description: str | None = Field(default=None, max_length=255)
    role_type: Literal["builtin", "custom"] = "custom"
    is_enabled: bool = True


class RoleUpdate(BaseModel):
    code: str | None = Field(default=None, min_length=2, max_length=64)
    name: str | None = Field(default=None, min_length=1, max_length=128)
    description: str | None = Field(default=None, max_length=255)
    is_enabled: bool | None = None


class RoleItem(BaseModel):
    id: int
    code: str
    name: str
    description: str | None
    role_type: str
    is_builtin: bool
    is_enabled: bool
    user_count: int = 0
    created_at: datetime
    updated_at: datetime


class RoleListResult(BaseModel):
    total: int
    items: list[RoleItem]
