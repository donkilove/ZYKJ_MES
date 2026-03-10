from pydantic import BaseModel, Field
from datetime import datetime


class PermissionCatalogItem(BaseModel):
    permission_code: str
    permission_name: str
    module_code: str
    resource_type: str
    parent_permission_code: str | None = None
    is_enabled: bool


class PermissionCatalogResult(BaseModel):
    items: list[PermissionCatalogItem]


class MyPermissionsResult(BaseModel):
    permission_codes: list[str]


class AuthzSnapshotModuleItem(BaseModel):
    module_code: str
    module_name: str
    module_revision: int = 0
    module_enabled: bool = False
    effective_permission_codes: list[str] = Field(default_factory=list)
    effective_page_permission_codes: list[str] = Field(default_factory=list)
    effective_capability_codes: list[str] = Field(default_factory=list)
    effective_action_permission_codes: list[str] = Field(default_factory=list)


class AuthzSnapshotResult(BaseModel):
    revision: int = 0
    role_codes: list[str] = Field(default_factory=list)
    visible_sidebar_codes: list[str] = Field(default_factory=list)
    tab_codes_by_parent: dict[str, list[str]] = Field(default_factory=dict)
    module_items: list[AuthzSnapshotModuleItem] = Field(default_factory=list)


class RolePermissionItem(BaseModel):
    role_code: str
    role_name: str
    permission_code: str
    permission_name: str
    module_code: str
    resource_type: str
    parent_permission_code: str | None = None
    granted: bool
    is_enabled: bool


class RolePermissionResult(BaseModel):
    role_code: str
    role_name: str
    module_code: str
    items: list[RolePermissionItem]


class RolePermissionUpdateRequest(BaseModel):
    module_code: str = Field(min_length=2, max_length=64)
    granted_permission_codes: list[str] = Field(default_factory=list)
    remark: str | None = Field(default=None, max_length=255)


class RolePermissionUpdateResult(BaseModel):
    role_code: str
    module_code: str
    updated_count: int
    before_permission_codes: list[str]
    after_permission_codes: list[str]


class RolePermissionMatrixItem(BaseModel):
    role_code: str
    role_name: str
    readonly: bool = False
    is_system_admin: bool = False
    granted_permission_codes: list[str]


class RolePermissionMatrixResult(BaseModel):
    module_code: str
    module_codes: list[str]
    permissions: list[PermissionCatalogItem]
    role_items: list[RolePermissionMatrixItem]


class RolePermissionMatrixRoleUpdateItem(BaseModel):
    role_code: str = Field(min_length=2, max_length=64)
    granted_permission_codes: list[str] = Field(default_factory=list)


class RolePermissionMatrixUpdateRequest(BaseModel):
    module_code: str = Field(min_length=2, max_length=64)
    dry_run: bool = False
    role_items: list[RolePermissionMatrixRoleUpdateItem] = Field(default_factory=list)
    remark: str | None = Field(default=None, max_length=255)


class RolePermissionMatrixRoleResult(BaseModel):
    role_code: str
    role_name: str
    readonly: bool = False
    is_system_admin: bool = False
    ignored_input: bool = False
    before_permission_codes: list[str]
    after_permission_codes: list[str]
    added_permission_codes: list[str]
    removed_permission_codes: list[str]
    auto_granted_permission_codes: list[str]
    auto_revoked_permission_codes: list[str]
    updated_count: int


class RolePermissionMatrixUpdateResult(BaseModel):
    module_code: str
    dry_run: bool
    role_results: list[RolePermissionMatrixRoleResult]


class PermissionHierarchyPageItem(BaseModel):
    page_code: str
    page_name: str
    permission_code: str
    parent_page_code: str | None = None


class PermissionHierarchyFeatureItem(BaseModel):
    feature_code: str
    feature_name: str
    permission_code: str
    page_permission_code: str | None = None
    linked_action_permission_codes: list[str] = Field(default_factory=list)
    dependency_permission_codes: list[str] = Field(default_factory=list)


class PermissionHierarchyCatalogResult(BaseModel):
    module_code: str
    module_codes: list[str]
    module_permission_code: str
    module_name: str
    pages: list[PermissionHierarchyPageItem]
    features: list[PermissionHierarchyFeatureItem]


class PermissionHierarchyRoleConfigResult(BaseModel):
    role_code: str
    role_name: str
    readonly: bool = False
    module_code: str
    module_enabled: bool
    granted_page_permission_codes: list[str]
    granted_feature_permission_codes: list[str]
    effective_page_permission_codes: list[str]
    effective_feature_permission_codes: list[str]


class PermissionHierarchyRoleConfigUpdateRequest(BaseModel):
    module_code: str = Field(min_length=2, max_length=64)
    module_enabled: bool = False
    page_permission_codes: list[str] = Field(default_factory=list)
    feature_permission_codes: list[str] = Field(default_factory=list)
    dry_run: bool = False
    remark: str | None = Field(default=None, max_length=255)


class PermissionHierarchyRoleConfigUpdateResult(BaseModel):
    role_code: str
    role_name: str
    readonly: bool = False
    ignored_input: bool = False
    module_code: str
    before_permission_codes: list[str]
    after_permission_codes: list[str]
    added_permission_codes: list[str]
    removed_permission_codes: list[str]
    auto_linked_dependencies: list[str]
    effective_page_permission_codes: list[str]
    effective_feature_permission_codes: list[str]
    updated_count: int
    dry_run: bool = False


class PermissionHierarchyPreviewRoleItem(BaseModel):
    role_code: str = Field(min_length=2, max_length=64)
    module_enabled: bool = False
    page_permission_codes: list[str] = Field(default_factory=list)
    feature_permission_codes: list[str] = Field(default_factory=list)


class PermissionHierarchyPreviewRequest(BaseModel):
    module_code: str = Field(min_length=2, max_length=64)
    role_items: list[PermissionHierarchyPreviewRoleItem] = Field(default_factory=list)


class PermissionHierarchyPreviewResult(BaseModel):
    module_code: str
    role_results: list[PermissionHierarchyRoleConfigUpdateResult]


class CapabilityPackItem(BaseModel):
    capability_code: str
    capability_name: str
    group_code: str
    group_name: str
    page_code: str
    page_name: str
    description: str | None = None
    dependency_capability_codes: list[str] = Field(default_factory=list)
    linked_action_permission_codes: list[str] = Field(default_factory=list)


class CapabilityPackRoleTemplateItem(BaseModel):
    role_code: str
    role_name: str
    capability_codes: list[str] = Field(default_factory=list)
    description: str | None = None


class CapabilityPackCatalogResult(BaseModel):
    module_code: str
    module_codes: list[str]
    module_name: str
    module_revision: int = 0
    module_permission_code: str
    capability_packs: list[CapabilityPackItem]
    role_templates: list[CapabilityPackRoleTemplateItem] = Field(default_factory=list)


class CapabilityPackRoleConfigResult(BaseModel):
    role_code: str
    role_name: str
    readonly: bool = False
    module_code: str
    module_enabled: bool
    granted_capability_codes: list[str] = Field(default_factory=list)
    effective_capability_codes: list[str] = Field(default_factory=list)
    effective_page_permission_codes: list[str] = Field(default_factory=list)
    auto_linked_dependencies: list[str] = Field(default_factory=list)


class CapabilityPackRoleConfigUpdateRequest(BaseModel):
    module_code: str = Field(min_length=2, max_length=64)
    module_enabled: bool = False
    capability_codes: list[str] = Field(default_factory=list)
    dry_run: bool = False
    remark: str | None = Field(default=None, max_length=255)


class CapabilityPackRoleConfigUpdateResult(BaseModel):
    role_code: str
    role_name: str
    readonly: bool = False
    ignored_input: bool = False
    module_code: str
    before_capability_codes: list[str] = Field(default_factory=list)
    after_capability_codes: list[str] = Field(default_factory=list)
    added_capability_codes: list[str] = Field(default_factory=list)
    removed_capability_codes: list[str] = Field(default_factory=list)
    auto_linked_dependencies: list[str] = Field(default_factory=list)
    effective_capability_codes: list[str] = Field(default_factory=list)
    effective_page_permission_codes: list[str] = Field(default_factory=list)
    updated_count: int = 0
    dry_run: bool = False


class CapabilityPackPreviewRoleItem(BaseModel):
    role_code: str = Field(min_length=2, max_length=64)
    module_enabled: bool = False
    capability_codes: list[str] = Field(default_factory=list)


class CapabilityPackPreviewRequest(BaseModel):
    module_code: str = Field(min_length=2, max_length=64)
    role_items: list[CapabilityPackPreviewRoleItem] = Field(default_factory=list)


class CapabilityPackPreviewResult(BaseModel):
    module_code: str
    module_revision: int = 0
    role_results: list[CapabilityPackRoleConfigUpdateResult]


class CapabilityPackBatchApplyRequest(BaseModel):
    module_code: str = Field(min_length=2, max_length=64)
    role_items: list[CapabilityPackPreviewRoleItem] = Field(default_factory=list)
    expected_revision: int | None = Field(default=None, ge=0)
    remark: str | None = Field(default=None, max_length=255)


class CapabilityPackChangeLogItem(BaseModel):
    change_log_id: int
    module_code: str
    module_revision: int = 0
    change_type: str
    remark: str | None = None
    operator_user_id: int | None = None
    operator_username: str | None = None
    rollback_of_change_log_id: int | None = None
    rollback_of_revision: int | None = None
    changed_role_count: int = 0
    added_capability_count: int = 0
    removed_capability_count: int = 0
    auto_linked_dependency_count: int = 0
    is_current_revision: bool = False
    is_noop: bool = False
    can_rollback: bool = True
    created_at: datetime
    role_results: list[CapabilityPackRoleConfigUpdateResult] = Field(default_factory=list)


class CapabilityPackChangeLogListResult(BaseModel):
    module_code: str
    module_revision: int = 0
    items: list[CapabilityPackChangeLogItem] = Field(default_factory=list)


class CapabilityPackRollbackRequest(BaseModel):
    module_code: str = Field(min_length=2, max_length=64)
    change_log_id: int = Field(ge=1)
    expected_revision: int | None = Field(default=None, ge=0)
    remark: str | None = Field(default=None, max_length=255)


class PermissionExplainCapabilityItem(BaseModel):
    capability_code: str
    capability_name: str
    available: bool
    reason_codes: list[str] = Field(default_factory=list)
    reason_messages: list[str] = Field(default_factory=list)


class PermissionExplainResult(BaseModel):
    role_code: str
    role_name: str
    module_code: str
    module_enabled: bool
    effective_page_permission_codes: list[str] = Field(default_factory=list)
    effective_capability_codes: list[str] = Field(default_factory=list)
    capability_items: list[PermissionExplainCapabilityItem] = Field(default_factory=list)
