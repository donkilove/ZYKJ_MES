from pydantic import BaseModel, Field


class PageCatalogItem(BaseModel):
    code: str
    name: str
    page_type: str
    parent_code: str | None = None
    always_visible: bool = False
    sort_order: int


class PageCatalogResult(BaseModel):
    items: list[PageCatalogItem]


class PageVisibilityMeResult(BaseModel):
    sidebar_codes: list[str]
    tab_codes_by_parent: dict[str, list[str]]


class PageVisibilityConfigItem(BaseModel):
    role_code: str
    role_name: str
    page_code: str
    page_name: str
    page_type: str
    parent_code: str | None = None
    editable: bool
    is_visible: bool
    always_visible: bool = False


class PageVisibilityConfigResult(BaseModel):
    items: list[PageVisibilityConfigItem]


class PageVisibilityConfigUpdateItem(BaseModel):
    role_code: str = Field(min_length=2, max_length=64)
    page_code: str = Field(min_length=2, max_length=64)
    is_visible: bool


class PageVisibilityConfigUpdateRequest(BaseModel):
    items: list[PageVisibilityConfigUpdateItem] = Field(default_factory=list)


class PageVisibilityConfigUpdateResult(BaseModel):
    updated_count: int
