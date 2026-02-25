from datetime import datetime

from pydantic import BaseModel, Field


class RoleCreate(BaseModel):
    code: str = Field(min_length=2, max_length=64)
    name: str = Field(min_length=1, max_length=128)
    permission_codes: list[str] = Field(default_factory=list)


class RoleUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=128)
    permission_codes: list[str] | None = None


class RoleItem(BaseModel):
    id: int
    code: str
    name: str
    permission_codes: list[str]
    created_at: datetime
    updated_at: datetime


class RoleListResult(BaseModel):
    total: int
    items: list[RoleItem]

