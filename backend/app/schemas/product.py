from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class ProductCreate(BaseModel):
    name: str = Field(min_length=1, max_length=128)


class ProductDeleteRequest(BaseModel):
    password: str = Field(min_length=1, max_length=128)


class ProductItem(BaseModel):
    id: int
    name: str
    last_parameter_summary: str | None = None
    created_at: datetime
    updated_at: datetime


class ProductListResult(BaseModel):
    total: int
    items: list[ProductItem]


class ProductParameterInputItem(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    category: str = Field(min_length=1, max_length=128)
    type: Literal["Text", "Link"]
    value: str = Field(min_length=0, max_length=1024)


class ProductParameterItem(BaseModel):
    name: str
    category: str
    type: Literal["Text", "Link"]
    value: str
    sort_order: int
    is_preset: bool


class ProductParameterListResult(BaseModel):
    product_id: int
    product_name: str
    total: int
    items: list[ProductParameterItem]


class ProductParameterUpdateRequest(BaseModel):
    remark: str = Field(min_length=1, max_length=512)
    items: list[ProductParameterInputItem] = Field(default_factory=list)


class ProductParameterUpdateResult(BaseModel):
    updated_count: int
    changed_keys: list[str]


class ProductParameterHistoryItem(BaseModel):
    id: int
    remark: str
    changed_keys: list[str]
    operator_username: str
    created_at: datetime


class ProductParameterHistoryListResult(BaseModel):
    total: int
    items: list[ProductParameterHistoryItem]
