from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.page_catalog import (
    PAGE_BY_CODE,
    PAGE_CATALOG,
    PAGE_TYPE_SIDEBAR,
    PAGE_TYPE_TAB,
    ROLE_CODE_ORDER,
    ROLE_CODE_SET,
    default_page_visible,
    is_always_visible_page,
    is_valid_page_code,
)
from app.core.rbac import ROLE_DEFINITIONS
from app.models.page_visibility import PageVisibility


def list_page_catalog_items() -> list[dict[str, object]]:
    return [dict(item) for item in PAGE_CATALOG]


def _load_all_visibility_rows(db: Session) -> list[PageVisibility]:
    stmt = select(PageVisibility).order_by(PageVisibility.id.asc())
    return db.execute(stmt).scalars().all()


def _build_visibility_lookup(rows: list[PageVisibility]) -> dict[tuple[str, str], bool]:
    lookup: dict[tuple[str, str], bool] = {}
    for row in rows:
        lookup[(row.role_code, row.page_code)] = bool(row.is_visible)
    return lookup


def _is_visible_for_role(
    role_code: str,
    page_code: str,
    lookup: dict[tuple[str, str], bool],
) -> bool:
    if is_always_visible_page(page_code):
        return True
    key = (role_code, page_code)
    if key in lookup:
        return lookup[key]
    return default_page_visible(role_code, page_code)


def get_user_visible_pages(
    db: Session,
    role_codes: list[str],
) -> tuple[list[str], dict[str, list[str]]]:
    rows = _load_all_visibility_rows(db)
    lookup = _build_visibility_lookup(rows)
    effective_roles = [code for code in role_codes if code in ROLE_CODE_SET]

    sidebar_codes: list[str] = []
    tab_codes_by_parent: dict[str, list[str]] = {}

    for page in PAGE_CATALOG:
        page_code = str(page["code"])
        page_type = str(page["page_type"])
        parent_code = page.get("parent_code")
        visible = False
        if is_always_visible_page(page_code):
            visible = True
        else:
            visible = any(
                _is_visible_for_role(role_code, page_code, lookup)
                for role_code in effective_roles
            )

        if not visible:
            continue

        if page_type == PAGE_TYPE_SIDEBAR:
            sidebar_codes.append(page_code)
        elif page_type == PAGE_TYPE_TAB and isinstance(parent_code, str):
            tab_codes_by_parent.setdefault(parent_code, []).append(page_code)

    return sidebar_codes, tab_codes_by_parent


def get_page_visibility_config(db: Session) -> list[dict[str, object]]:
    rows = _load_all_visibility_rows(db)
    lookup = _build_visibility_lookup(rows)
    role_name_by_code = {item["code"]: item["name"] for item in ROLE_DEFINITIONS}
    items: list[dict[str, object]] = []

    for role_code in ROLE_CODE_ORDER:
        role_name = role_name_by_code.get(role_code, role_code)
        for page in PAGE_CATALOG:
            page_code = str(page["code"])
            always_visible = bool(page.get("always_visible", False))
            is_visible = (
                True
                if always_visible
                else _is_visible_for_role(role_code, page_code, lookup)
            )
            items.append(
                {
                    "role_code": role_code,
                    "role_name": role_name,
                    "page_code": page_code,
                    "page_name": str(page["name"]),
                    "page_type": str(page["page_type"]),
                    "parent_code": page.get("parent_code"),
                    "editable": not always_visible,
                    "is_visible": is_visible,
                    "always_visible": always_visible,
                }
            )
    return items


def update_page_visibility_config(
    db: Session,
    updates: list[dict[str, object]],
) -> tuple[int, list[str]]:
    invalid_items: list[str] = []
    update_map: dict[tuple[str, str], bool] = {}

    for update in updates:
        role_code = str(update.get("role_code", "")).strip()
        page_code = str(update.get("page_code", "")).strip()
        is_visible = bool(update.get("is_visible", False))

        if role_code not in ROLE_CODE_SET:
            invalid_items.append(f"invalid role_code: {role_code}")
            continue
        if not is_valid_page_code(page_code):
            invalid_items.append(f"invalid page_code: {page_code}")
            continue
        if is_always_visible_page(page_code):
            continue
        update_map[(role_code, page_code)] = is_visible

    if invalid_items:
        return 0, invalid_items

    if not update_map:
        return 0, []

    rows = _load_all_visibility_rows(db)
    row_map = {(row.role_code, row.page_code): row for row in rows}
    updated_count = 0

    for (role_code, page_code), is_visible in update_map.items():
        key = (role_code, page_code)
        row = row_map.get(key)
        if row:
            if row.is_visible != is_visible:
                row.is_visible = is_visible
                updated_count += 1
            continue

        row = PageVisibility(
            role_code=role_code,
            page_code=page_code,
            is_visible=is_visible,
        )
        db.add(row)
        updated_count += 1

    db.commit()
    return updated_count, []


def ensure_visibility_defaults(db: Session) -> None:
    rows = _load_all_visibility_rows(db)
    row_keys = {(row.role_code, row.page_code) for row in rows}
    created = False
    for role_code in ROLE_CODE_ORDER:
        for page in PAGE_CATALOG:
            page_code = str(page["code"])
            if is_always_visible_page(page_code):
                continue
            key = (role_code, page_code)
            if key in row_keys:
                continue
            row = PageVisibility(
                role_code=role_code,
                page_code=page_code,
                is_visible=default_page_visible(role_code, page_code),
            )
            db.add(row)
            created = True
    if created:
        db.commit()
