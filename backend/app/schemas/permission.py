from datetime import datetime

from pydantic import BaseModel


class PermissionItem(BaseModel):
    id: int
    code: str
    name: str
    created_at: datetime
    updated_at: datetime


class PermissionListResult(BaseModel):
    total: int
    items: list[PermissionItem]

