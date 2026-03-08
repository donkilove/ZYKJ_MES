from pydantic import BaseModel, Field


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
