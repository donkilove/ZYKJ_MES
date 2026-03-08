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
