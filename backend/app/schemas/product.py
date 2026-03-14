from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field
from pydantic import field_validator

from app.core.product_lifecycle import (
    PRODUCT_LIFECYCLE_ACTIVE,
    PRODUCT_LIFECYCLE_INACTIVE,
    PRODUCT_LIFECYCLE_OPTIONS,
)


VALID_PRODUCT_CATEGORIES = {"贴片", "DTU", "套件"}


class ProductCreate(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    category: str = Field(default="", max_length=32)
    remark: str = Field(default="", max_length=500)

    @field_validator("category")
    @classmethod
    def validate_category(cls, value: str) -> str:
        if value and value not in VALID_PRODUCT_CATEGORIES:
            raise ValueError(f"产品分类必须为以下之一：{', '.join(sorted(VALID_PRODUCT_CATEGORIES))}")
        return value


class ProductUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    category: str = Field(default="", max_length=32)
    remark: str = Field(default="", max_length=500)

    @field_validator("category")
    @classmethod
    def validate_category(cls, value: str) -> str:
        if value and value not in VALID_PRODUCT_CATEGORIES:
            raise ValueError(f"产品分类必须为以下之一：{', '.join(sorted(VALID_PRODUCT_CATEGORIES))}")
        return value


class ProductDeleteRequest(BaseModel):
    password: str = Field(min_length=1, max_length=128)


class ProductItem(BaseModel):
    id: int
    name: str
    category: str = ""
    remark: str = ""
    lifecycle_status: str = PRODUCT_LIFECYCLE_ACTIVE
    current_version: int = 1
    effective_version: int = 0
    effective_at: datetime | None = None
    inactive_reason: str | None = None
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
    description: str = Field(default="", max_length=500)


class ProductParameterItem(BaseModel):
    name: str
    category: str
    type: Literal["Text", "Link"]
    value: str
    description: str = ""
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
    confirmed: bool = False


class ProductParameterUpdateResult(BaseModel):
    updated_count: int
    changed_keys: list[str]


class ProductParameterHistoryItem(BaseModel):
    id: int
    remark: str
    change_type: str = "edit"
    changed_keys: list[str]
    operator_username: str
    before_snapshot: str = "{}"
    after_snapshot: str = "{}"
    created_at: datetime


class ProductParameterHistoryListResult(BaseModel):
    total: int
    items: list[ProductParameterHistoryItem]


class ProductLifecycleUpdateRequest(BaseModel):
    target_status: str = Field(min_length=1, max_length=32)
    confirmed: bool = False
    note: str | None = Field(default=None, max_length=256)
    inactive_reason: str | None = Field(default=None, max_length=512)

    @field_validator("target_status")
    @classmethod
    def validate_target_status(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized not in PRODUCT_LIFECYCLE_OPTIONS:
            raise ValueError("Invalid target_status")
        return normalized


class ProductVersionItem(BaseModel):
    version: int
    version_label: str = "V1.0"
    lifecycle_status: str
    action: str
    note: str | None = None
    source_version: int | None = None
    source_version_label: str | None = None
    created_by_user_id: int | None = None
    created_by_username: str | None = None
    created_at: datetime
    updated_at: datetime | None = None


class ProductVersionListResult(BaseModel):
    total: int
    items: list[ProductVersionItem]


class ProductVersionCreateRequest(BaseModel):
    pass  # no body needed


class ProductVersionNoteUpdateRequest(BaseModel):
    note: str = Field(default="", max_length=256)


class ProductVersionCopyRequest(BaseModel):
    source_version: int = Field(gt=0)


class ProductVersionActivateRequest(BaseModel):
    confirmed: bool = False


class ProductVersionDisableRequest(BaseModel):
    pass  # no body needed


class ProductVersionDiffItem(BaseModel):
    key: str
    diff_type: str
    from_value: str | None = None
    to_value: str | None = None


class ProductVersionCompareResult(BaseModel):
    from_version: int
    to_version: int
    added_items: int
    removed_items: int
    changed_items: int
    items: list[ProductVersionDiffItem]


class ProductRollbackRequest(BaseModel):
    target_version: int = Field(gt=0)
    confirmed: bool = False
    note: str | None = Field(default=None, max_length=256)


class ProductImpactOrderItem(BaseModel):
    order_id: int
    order_code: str
    order_status: str
    reason: str | None = None


class ProductImpactAnalysisResult(BaseModel):
    operation: str
    target_status: str | None = None
    target_version: int | None = None
    total_orders: int
    pending_orders: int
    in_progress_orders: int
    requires_confirmation: bool
    items: list[ProductImpactOrderItem]


class ProductRollbackResult(BaseModel):
    product: ProductItem
    changed_keys: list[str]


class ProductImpactAnalysisQuery(BaseModel):
    operation: Literal["update_parameters", "lifecycle", "rollback"] = "lifecycle"
    target_status: str | None = None
    target_version: int | None = None

    @field_validator("target_status")
    @classmethod
    def validate_query_target_status(cls, value: str | None) -> str | None:
        if value is None:
            return value
        normalized = value.strip().lower()
        if normalized not in PRODUCT_LIFECYCLE_OPTIONS:
            raise ValueError("Invalid target_status")
        return normalized


# Keep constants exported for client-side / docs reuse.
PRODUCT_LIFECYCLE_STATUS_ACTIVE = PRODUCT_LIFECYCLE_ACTIVE
PRODUCT_LIFECYCLE_STATUS_INACTIVE = PRODUCT_LIFECYCLE_INACTIVE
