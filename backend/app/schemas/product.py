from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field
from pydantic import field_validator

from app.core.product_lifecycle import (
    PRODUCT_LIFECYCLE_ACTIVE,
    PRODUCT_LIFECYCLE_DRAFT,
    PRODUCT_LIFECYCLE_INACTIVE,
    PRODUCT_LIFECYCLE_OPTIONS,
)
from app.core.product_parameter_template import VALID_PRODUCT_PARAMETER_CATEGORY_SET


VALID_PRODUCT_CATEGORIES = {"贴片", "DTU", "套件"}


class ProductCreate(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    category: str = Field(min_length=1, max_length=32)
    remark: str = Field(default="", max_length=500)

    @field_validator("category")
    @classmethod
    def validate_category(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("产品分类不能为空")
        if normalized not in VALID_PRODUCT_CATEGORIES:
            raise ValueError(
                f"产品分类必须为以下之一：{', '.join(sorted(VALID_PRODUCT_CATEGORIES))}"
            )
        return normalized


class ProductUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    category: str = Field(min_length=1, max_length=32)
    remark: str = Field(default="", max_length=500)

    @field_validator("category")
    @classmethod
    def validate_category(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("产品分类不能为空")
        if normalized not in VALID_PRODUCT_CATEGORIES:
            raise ValueError(
                f"产品分类必须为以下之一：{', '.join(sorted(VALID_PRODUCT_CATEGORIES))}"
            )
        return normalized


class ProductDeleteRequest(BaseModel):
    password: str = Field(min_length=1, max_length=128)


class ProductItem(BaseModel):
    id: int
    name: str
    category: str = ""
    remark: str = ""
    lifecycle_status: str = PRODUCT_LIFECYCLE_ACTIVE
    current_version: int = 1
    current_version_label: str = "V1.0"
    effective_version: int = 0
    effective_version_label: str | None = None
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

    @field_validator("category")
    @classmethod
    def validate_parameter_category(cls, value: str) -> str:
        normalized = value.strip()
        if normalized not in VALID_PRODUCT_PARAMETER_CATEGORY_SET:
            raise ValueError("参数分类不在允许范围内")
        return normalized


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
    parameter_scope: Literal["version", "effective"] = "version"
    version: int
    version_label: str = "V1.0"
    lifecycle_status: str = PRODUCT_LIFECYCLE_DRAFT
    total: int
    items: list[ProductParameterItem]


class ProductParameterUpdateRequest(BaseModel):
    remark: str = Field(min_length=1, max_length=512)
    items: list[ProductParameterInputItem] = Field(default_factory=list)


class ProductParameterUpdateResult(BaseModel):
    parameter_scope: Literal["version"] = "version"
    version: int
    updated_count: int
    changed_keys: list[str]


class ProductParameterVersionListItem(BaseModel):
    product_id: int
    product_name: str
    product_category: str = ""
    version: int
    version_label: str = "V1.0"
    lifecycle_status: str = PRODUCT_LIFECYCLE_DRAFT
    is_current_version: bool = False
    is_effective_version: bool = False
    created_at: datetime
    parameter_summary: str | None = None
    parameter_count: int = 0
    matched_parameter_name: str | None = None
    matched_parameter_category: str | None = None
    last_modified_parameter: str | None = None
    last_modified_parameter_category: str | None = None
    updated_at: datetime


class ProductParameterVersionListResult(BaseModel):
    total: int
    items: list[ProductParameterVersionListItem]


class ProductParameterHistoryItem(BaseModel):
    id: int
    product_name: str = ""
    product_category: str = ""
    version: int | None = None
    version_label: str | None = None
    remark: str
    change_reason: str = ""
    change_type: str = "edit"
    parameter_name: str | None = None
    changed_keys: list[str]
    operator_username: str
    before_summary: str | None = None
    after_summary: str | None = None
    before_snapshot: str = "{}"
    after_snapshot: str = "{}"
    created_at: datetime


class ProductParameterHistoryListResult(BaseModel):
    version: int | None = None
    version_label: str | None = None
    lifecycle_status: str | None = None
    total: int
    items: list[ProductParameterHistoryItem]


class ProductRelatedInfoItem(BaseModel):
    label: str
    value: str | None = None


class ProductRelatedInfoSection(BaseModel):
    code: str
    title: str
    total: int = 0
    items: list[ProductRelatedInfoItem] = Field(default_factory=list)
    empty_message: str | None = None


class ProductDetailResult(BaseModel):
    product: ProductItem
    detail_parameters: ProductParameterListResult
    detail_parameter_message: str | None = None
    latest_version_changed_at: datetime | None = None
    version_total: int
    versions: list["ProductVersionItem"]
    history_total: int
    history_items: list[ProductParameterHistoryItem]
    related_info_sections: list[ProductRelatedInfoSection] = Field(default_factory=list)


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
    effective_at: datetime | None = None
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
    expected_effective_version: int | None = Field(default=None, ge=0)


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
