from datetime import datetime

from pydantic import BaseModel, Field


class ProcessCreate(BaseModel):
    code: str = Field(min_length=2, max_length=64)
    name: str = Field(min_length=1, max_length=128)
    stage_id: int | None = Field(default=None, gt=0)


class ProcessUpdate(BaseModel):
    code: str = Field(min_length=2, max_length=64)
    name: str = Field(min_length=1, max_length=128)
    stage_id: int | None = Field(default=None, gt=0)
    is_enabled: bool | None = None


class ProcessItem(BaseModel):
    id: int
    code: str
    name: str
    stage_id: int | None = None
    stage_code: str | None = None
    stage_name: str | None = None
    is_enabled: bool = True
    created_at: datetime
    updated_at: datetime


class ProcessListResult(BaseModel):
    total: int
    items: list[ProcessItem]
