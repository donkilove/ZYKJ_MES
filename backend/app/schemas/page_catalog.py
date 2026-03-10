from pydantic import BaseModel


class PageCatalogItem(BaseModel):
    code: str
    name: str
    page_type: str
    parent_code: str | None = None
    always_visible: bool = False
    sort_order: int


class PageCatalogResult(BaseModel):
    items: list[PageCatalogItem]
