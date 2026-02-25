from datetime import datetime

from pydantic import BaseModel, Field


class ProcessCreate(BaseModel):
    code: str = Field(min_length=2, max_length=64)
    name: str = Field(min_length=1, max_length=128)


class ProcessUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=128)


class ProcessItem(BaseModel):
    id: int
    code: str
    name: str
    created_at: datetime
    updated_at: datetime


class ProcessListResult(BaseModel):
    total: int
    items: list[ProcessItem]

