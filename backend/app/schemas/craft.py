from datetime import datetime

from pydantic import BaseModel, Field, field_validator

TEMPLATE_LIFECYCLE_DRAFT = "draft"
TEMPLATE_LIFECYCLE_PUBLISHED = "published"
TEMPLATE_LIFECYCLE_ARCHIVED = "archived"
TEMPLATE_LIFECYCLE_OPTIONS = {
    TEMPLATE_LIFECYCLE_DRAFT,
    TEMPLATE_LIFECYCLE_PUBLISHED,
    TEMPLATE_LIFECYCLE_ARCHIVED,
}


class ProcessStageCreate(BaseModel):
    code: str = Field(min_length=2, max_length=64)
    name: str = Field(min_length=1, max_length=128)
    sort_order: int = Field(default=0)
    remark: str = Field(default="", max_length=500)


class ProcessStageUpdate(BaseModel):
    code: str | None = Field(default=None, min_length=2, max_length=64)
    name: str = Field(min_length=1, max_length=128)
    sort_order: int = Field(default=0)
    is_enabled: bool = True
    remark: str | None = Field(default=None, max_length=500)


class ProcessStageItem(BaseModel):
    id: int
    code: str
    name: str
    sort_order: int
    is_enabled: bool
    remark: str = ""
    process_count: int = 0
    created_at: datetime
    updated_at: datetime


class ProcessStageListResult(BaseModel):
    total: int
    items: list[ProcessStageItem]


class ProcessStageLightItem(BaseModel):
    id: int
    code: str
    name: str
    sort_order: int
    is_enabled: bool


class ProcessStageLightListResult(BaseModel):
    total: int
    items: list[ProcessStageLightItem]


class CraftProcessCreate(BaseModel):
    code: str = Field(min_length=2, max_length=64)
    name: str = Field(min_length=1, max_length=128)
    stage_id: int = Field(gt=0)
    remark: str = Field(default="", max_length=500)


class CraftProcessUpdate(BaseModel):
    code: str | None = Field(default=None, min_length=2, max_length=64)
    name: str = Field(min_length=1, max_length=128)
    stage_id: int = Field(gt=0)
    is_enabled: bool = True
    remark: str | None = Field(default=None, max_length=500)


class CraftProcessItem(BaseModel):
    id: int
    code: str
    name: str
    stage_id: int | None = None
    stage_code: str | None = None
    stage_name: str | None = None
    is_enabled: bool
    remark: str = ""
    created_at: datetime
    updated_at: datetime


class CraftProcessListResult(BaseModel):
    total: int
    items: list[CraftProcessItem]


class CraftProcessLightItem(BaseModel):
    id: int
    code: str
    name: str
    stage_id: int | None = None
    stage_code: str | None = None
    stage_name: str | None = None
    is_enabled: bool


class CraftProcessLightListResult(BaseModel):
    total: int
    items: list[CraftProcessLightItem]


class TemplateStepPayload(BaseModel):
    step_order: int = Field(gt=0)
    stage_id: int = Field(gt=0)
    process_id: int = Field(gt=0)
    standard_minutes: int = Field(default=0, ge=0)
    is_key_process: bool = False
    step_remark: str = Field(default="", max_length=500)


class ProductProcessTemplateCreate(BaseModel):
    product_id: int = Field(gt=0)
    template_name: str = Field(min_length=1, max_length=128)
    is_default: bool = False
    remark: str = Field(default="", max_length=500)
    steps: list[TemplateStepPayload] = Field(default_factory=list, min_length=1)

    @field_validator("steps")
    @classmethod
    def validate_steps(
        cls, value: list[TemplateStepPayload]
    ) -> list[TemplateStepPayload]:
        step_orders = [item.step_order for item in value]
        if len(step_orders) != len(set(step_orders)):
            raise ValueError("step_order cannot be duplicated")
        return value

class ProductProcessTemplateUpdate(BaseModel):
    template_name: str = Field(min_length=1, max_length=128)
    is_default: bool = False
    is_enabled: bool = True
    remark: str | None = Field(default=None, max_length=500)
    steps: list[TemplateStepPayload] = Field(default_factory=list, min_length=1)
    sync_orders: bool = True

    @field_validator("steps")
    @classmethod
    def validate_steps(
        cls, value: list[TemplateStepPayload]
    ) -> list[TemplateStepPayload]:
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
    standard_minutes: int = 0
    is_key_process: bool = False
    step_remark: str = ""
    created_at: datetime
    updated_at: datetime


class ProductProcessTemplateItem(BaseModel):
    id: int
    product_id: int
    product_name: str
    product_category: str = ""
    template_name: str
    version: int
    lifecycle_status: str
    published_version: int
    is_default: bool
    is_enabled: bool
    created_by_user_id: int | None = None
    created_by_username: str | None = None
    updated_by_user_id: int | None = None
    updated_by_username: str | None = None
    remark: str = ""
    source_type: str = "manual"
    source_template_id: int | None = None
    source_template_name: str | None = None
    source_template_version: int | None = None
    source_product_id: int | None = None
    source_system_master_version: int | None = None
    created_at: datetime
    updated_at: datetime


class ProductProcessTemplateDetail(BaseModel):
    template: ProductProcessTemplateItem
    steps: list[TemplateStepItem]


class ProductProcessTemplateListResult(BaseModel):
    total: int
    items: list[ProductProcessTemplateItem]


class SystemMasterTemplateUpsertRequest(BaseModel):
    steps: list[TemplateStepPayload] = Field(default_factory=list, min_length=1)

    @field_validator("steps")
    @classmethod
    def validate_steps(
        cls, value: list[TemplateStepPayload]
    ) -> list[TemplateStepPayload]:
        step_orders = [item.step_order for item in value]
        if len(step_orders) != len(set(step_orders)):
            raise ValueError("step_order cannot be duplicated")
        return value


class SystemMasterTemplateStepItem(BaseModel):
    id: int
    step_order: int
    stage_id: int
    stage_code: str
    stage_name: str
    process_id: int
    process_code: str
    process_name: str
    standard_minutes: int = 0
    is_key_process: bool = False
    step_remark: str = ""
    created_at: datetime
    updated_at: datetime


class SystemMasterTemplateItem(BaseModel):
    id: int
    version: int
    created_by_user_id: int | None = None
    created_by_username: str | None = None
    updated_by_user_id: int | None = None
    updated_by_username: str | None = None
    created_at: datetime
    updated_at: datetime
    steps: list[SystemMasterTemplateStepItem]


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


class TemplateImpactOrderItem(BaseModel):
    order_id: int
    order_code: str
    order_status: str
    syncable: bool
    reason: str | None = None


class TemplateImpactReferenceItem(BaseModel):
    ref_type: str
    ref_id: int
    ref_code: str | None = None
    ref_name: str
    detail: str | None = None
    ref_status: str | None = None
    jump_module: str | None = None
    jump_target: str | None = None
    risk_level: str | None = None
    risk_note: str | None = None


class TemplateImpactAnalysisResult(BaseModel):
    target_version: int
    total_orders: int
    pending_orders: int
    in_progress_orders: int
    syncable_orders: int
    blocked_orders: int
    total_references: int = 0
    user_stage_reference_count: int = 0
    template_reuse_reference_count: int = 0
    items: list[TemplateImpactOrderItem]
    reference_items: list[TemplateImpactReferenceItem] = Field(default_factory=list)


class TemplatePublishRequest(BaseModel):
    apply_order_sync: bool = False
    confirmed: bool = False
    expected_version: int | None = Field(default=None, gt=0)
    note: str | None = Field(default=None, max_length=256)


class TemplateVersionItem(BaseModel):
    version: int
    action: str
    record_type: str
    record_title: str
    record_summary: str
    note: str | None = None
    source_version: int | None = None
    created_by_user_id: int | None = None
    created_by_username: str | None = None
    created_at: datetime


class TemplateVersionListResult(BaseModel):
    total: int
    items: list[TemplateVersionItem]


class TemplateVersionDiffItem(BaseModel):
    step_order: int
    diff_type: str
    from_stage_code: str | None = None
    from_process_code: str | None = None
    to_stage_code: str | None = None
    to_process_code: str | None = None


class TemplateVersionCompareResult(BaseModel):
    from_version: int
    to_version: int
    added_steps: int
    removed_steps: int
    changed_steps: int
    items: list[TemplateVersionDiffItem]


class CraftKanbanSampleItem(BaseModel):
    order_process_id: int
    order_id: int
    order_code: str
    start_at: datetime
    end_at: datetime
    work_minutes: int
    production_qty: int
    capacity_per_hour: float


class CraftKanbanProcessItem(BaseModel):
    stage_id: int | None = None
    stage_code: str | None = None
    stage_name: str | None = None
    process_id: int
    process_code: str
    process_name: str
    samples: list[CraftKanbanSampleItem]


class CraftKanbanProcessMetricsResult(BaseModel):
    product_id: int
    product_name: str
    items: list[CraftKanbanProcessItem]


class TemplateRollbackRequest(BaseModel):
    target_version: int = Field(gt=0)
    apply_order_sync: bool = False
    confirmed: bool = False
    note: str | None = Field(default=None, max_length=256)


class TemplateCopyRequest(BaseModel):
    new_name: str = Field(min_length=1, max_length=128)


class TemplateCopyFromMasterRequest(BaseModel):
    product_id: int = Field(ge=1)
    new_name: str = Field(min_length=1, max_length=128)


class TemplateCopyToProductRequest(BaseModel):
    target_product_id: int = Field(ge=1)
    new_name: str = Field(min_length=1, max_length=128)


class TemplateBatchExportItem(BaseModel):
    product_id: int
    product_name: str
    template_name: str
    is_default: bool
    is_enabled: bool
    lifecycle_status: str
    source_type: str = "manual"
    source_template_name: str | None = None
    source_template_version: int | None = None
    source_system_master_version: int | None = None
    steps: list[TemplateStepPayload]


class TemplateBatchExportResult(BaseModel):
    total: int
    exported_at: datetime
    items: list[TemplateBatchExportItem]


class TemplateBatchImportItem(BaseModel):
    product_id: int | None = Field(default=None, gt=0)
    product_name: str | None = Field(default=None, min_length=1, max_length=128)
    template_name: str = Field(min_length=1, max_length=128)
    is_default: bool = False
    is_enabled: bool = True
    lifecycle_status: str = Field(
        default=TEMPLATE_LIFECYCLE_DRAFT, min_length=1, max_length=32
    )
    source_type: str = Field(default="manual", min_length=1, max_length=32)
    source_template_name: str | None = Field(default=None, max_length=128)
    source_template_version: int | None = Field(default=None, ge=1)
    source_system_master_version: int | None = Field(default=None, ge=1)
    steps: list[TemplateStepPayload] = Field(default_factory=list, min_length=1)

    @field_validator("steps")
    @classmethod
    def validate_steps(
        cls, value: list[TemplateStepPayload]
    ) -> list[TemplateStepPayload]:
        step_orders = [item.step_order for item in value]
        if len(step_orders) != len(set(step_orders)):
            raise ValueError("step_order cannot be duplicated")
        return value

    @field_validator("lifecycle_status")
    @classmethod
    def validate_template_lifecycle_status(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized not in TEMPLATE_LIFECYCLE_OPTIONS:
            raise ValueError("Invalid lifecycle_status")
        return normalized


class TemplateBatchImportRequest(BaseModel):
    overwrite_existing: bool = False
    items: list[TemplateBatchImportItem] = Field(default_factory=list, min_length=1)


class TemplateBatchImportResultItem(BaseModel):
    template_id: int
    product_id: int
    product_name: str
    template_name: str
    action: str
    lifecycle_status: str
    published_version: int


class TemplateBatchImportResult(BaseModel):
    total: int
    created: int
    updated: int
    skipped: int
    items: list[TemplateBatchImportResultItem]
    errors: list[str] = Field(default_factory=list)


class TemplateArchiveRequest(BaseModel):
    note: str | None = Field(default=None, max_length=256)


class StageReferenceItem(BaseModel):
    ref_type: str
    ref_id: int
    ref_code: str | None = None
    ref_name: str
    detail: str | None = None
    ref_status: str | None = None
    jump_module: str | None = None
    jump_target: str | None = None
    risk_level: str | None = None
    risk_note: str | None = None


class StageReferenceResult(BaseModel):
    stage_id: int
    stage_code: str
    stage_name: str
    total: int
    items: list[StageReferenceItem]


class ProcessReferenceItem(BaseModel):
    ref_type: str
    ref_id: int
    ref_code: str | None = None
    ref_name: str
    detail: str | None = None
    ref_status: str | None = None
    jump_module: str | None = None
    jump_target: str | None = None
    risk_level: str | None = None
    risk_note: str | None = None


class ProcessReferenceResult(BaseModel):
    process_id: int
    process_code: str
    process_name: str
    total: int
    items: list[ProcessReferenceItem]


class TemplateReferenceItem(BaseModel):
    ref_type: str
    ref_id: int
    ref_code: str | None = None
    ref_name: str
    detail: str | None = None
    ref_status: str | None = None
    jump_module: str | None = None
    jump_target: str | None = None
    risk_level: str | None = None
    risk_note: str | None = None
    is_blocking: bool = False


class TemplateReferenceResult(BaseModel):
    template_id: int
    template_name: str
    product_id: int
    product_name: str
    total: int
    order_reference_count: int = 0
    user_stage_reference_count: int = 0
    template_reuse_reference_count: int = 0
    blocking_reference_count: int = 0
    has_blocking_references: bool = False
    items: list[TemplateReferenceItem]


class ProductTemplateReferenceRow(BaseModel):
    template_id: int
    template_name: str
    lifecycle_status: str
    ref_type: str
    ref_id: int
    ref_code: str | None = None
    ref_name: str
    detail: str | None = None
    ref_status: str | None = None
    jump_module: str | None = None
    jump_target: str | None = None
    risk_level: str | None = None
    risk_note: str | None = None


class ProductTemplateReferenceResult(BaseModel):
    product_id: int
    product_name: str
    total_templates: int
    total_references: int
    items: list[ProductTemplateReferenceRow]


class SystemMasterTemplateVersionStepItem(BaseModel):
    id: int
    step_order: int
    stage_id: int
    stage_code: str
    stage_name: str
    process_id: int
    process_code: str
    process_name: str
    standard_minutes: int = 0
    is_key_process: bool = False
    step_remark: str = ""
    created_at: datetime
    updated_at: datetime


class SystemMasterTemplateVersionItem(BaseModel):
    version: int
    action: str
    note: str | None = None
    created_by_user_id: int | None = None
    created_by_username: str | None = None
    created_at: datetime
    steps: list[SystemMasterTemplateVersionStepItem]


class SystemMasterTemplateVersionListResult(BaseModel):
    total: int
    items: list[SystemMasterTemplateVersionItem]


class CraftExportResult(BaseModel):
    file_name: str
    mime_type: str
    content_base64: str
    exported_count: int = 0
