from __future__ import annotations

from app.core.page_catalog import PAGE_CATALOG


def list_page_catalog_items() -> list[dict[str, object]]:
    return [dict(item) for item in PAGE_CATALOG]
