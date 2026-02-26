from datetime import datetime

from pydantic import BaseModel, Field


class RoleCreate(BaseModel):
    code: str = Field(min_length=2, max_length=64)
    name: str = Field(min_length=1, max_length=128)


class RoleUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=128)


class RoleItem(BaseModel):
    id: int
    code: str
    name: str
    created_at: datetime
    updated_at: datetime


class RoleListResult(BaseModel):
    total: int
    items: list[RoleItem]
