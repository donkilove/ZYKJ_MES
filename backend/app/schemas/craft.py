from datetime import datetime

from pydantic import BaseModel, Field, field_validator


class ProcessStageCreate(BaseModel):
    code: str = Field(min_length=2, max_length=64)
    name: str = Field(min_length=1, max_length=128)
    sort_order: int = Field(default=0)


class ProcessStageUpdate(BaseModel):
    code: str | None = Field(default=None, min_length=2, max_length=64)
    name: str = Field(min_length=1, max_length=128)
    sort_order: int = Field(default=0)
    is_enabled: bool = True


class ProcessStageItem(BaseModel):
    id: int
    code: str
    name: str
    sort_order: int
    is_enabled: bool
    created_at: datetime
    updated_at: datetime


class ProcessStageListResult(BaseModel):
    total: int
    items: list[ProcessStageItem]


class CraftProcessCreate(BaseModel):
    code: str = Field(min_length=2, max_length=64)
    name: str = Field(min_length=1, max_length=128)
    stage_id: int = Field(gt=0)


class CraftProcessUpdate(BaseModel):
    code: str | None = Field(default=None, min_length=2, max_length=64)
    name: str = Field(min_length=1, max_length=128)
    stage_id: int = Field(gt=0)
    is_enabled: bool = True


class CraftProcessItem(BaseModel):
    id: int
    code: str
    name: str
    stage_id: int | None = None
    stage_code: str | None = None
    stage_name: str | None = None
    is_enabled: bool
    created_at: datetime
    updated_at: datetime


class CraftProcessListResult(BaseModel):
    total: int
    items: list[CraftProcessItem]


class TemplateStepPayload(BaseModel):
    step_order: int = Field(gt=0)
    stage_id: int = Field(gt=0)
    process_id: int = Field(gt=0)


class ProductProcessTemplateCreate(BaseModel):
    product_id: int = Field(gt=0)
    template_name: str = Field(min_length=1, max_length=128)
    is_default: bool = False
    steps: list[TemplateStepPayload] = Field(default_factory=list, min_length=1)

    @field_validator("steps")
    @classmethod
    def validate_steps(cls, value: list[TemplateStepPayload]) -> list[TemplateStepPayload]:
        step_orders = [item.step_order for item in value]
        if len(step_orders) != len(set(step_orders)):
            raise ValueError("step_order cannot be duplicated")
        return value


class ProductProcessTemplateUpdate(BaseModel):
    template_name: str = Field(min_length=1, max_length=128)
    is_default: bool = False
    is_enabled: bool = True
    steps: list[TemplateStepPayload] = Field(default_factory=list, min_length=1)
    sync_orders: bool = True

    @field_validator("steps")
    @classmethod
    def validate_steps(cls, value: list[TemplateStepPayload]) -> list[TemplateStepPayload]:
        step_orders = [item.step_order for item in value]
        if len(step_orders) != len(set(step_orders)):
            raise ValueError("step_order cannot be duplicated")
        return value


class TemplateStepItem(BaseModel):
    id: int
    step_order: int
    stage_id: int
    stage_code: str
    stage_name: str
    process_id: int
    process_code: str
    process_name: str
    created_at: datetime
    updated_at: datetime


class ProductProcessTemplateItem(BaseModel):
    id: int
    product_id: int
    product_name: str
    template_name: str
    version: int
    is_default: bool
    is_enabled: bool
    created_by_user_id: int | None = None
    created_by_username: str | None = None
    updated_by_user_id: int | None = None
    updated_by_username: str | None = None
    created_at: datetime
    updated_at: datetime


class ProductProcessTemplateDetail(BaseModel):
    template: ProductProcessTemplateItem
    steps: list[TemplateStepItem]


class ProductProcessTemplateListResult(BaseModel):
    total: int
    items: list[ProductProcessTemplateItem]


class TemplateSyncOrderConflict(BaseModel):
    order_id: int
    order_code: str
    reason: str


class TemplateSyncResult(BaseModel):
    total: int
    synced: int
    skipped: int
    reasons: list[TemplateSyncOrderConflict]


class ProductProcessTemplateUpdateResult(BaseModel):
    detail: ProductProcessTemplateDetail
    sync_result: TemplateSyncResult
