from __future__ import annotations

from collections import defaultdict
import hashlib
import json
from threading import Event, RLock
import time

from sqlalchemy.orm import Session

from app.core.authz_catalog import (
    AUTHZ_RESOURCE_ACTION,
    AUTHZ_RESOURCE_FEATURE,
    AUTHZ_RESOURCE_PAGE,
    MODULE_PERMISSION_BY_MODULE_CODE,
    PAGE_PERMISSION_BY_PAGE_CODE,
)
from app.core.authz_hierarchy_catalog import MODULE_NAME_BY_CODE, module_permission_code
from app.core.page_catalog import PAGE_CATALOG, PAGE_TYPE_SIDEBAR, PAGE_TYPE_TAB
from app.models.user import User
from app.services.authz_service import (
    PermissionCatalogRow,
    get_authz_module_revision_map,
    get_user_permission_codes,
    list_permission_catalog_rows,
)

_AUTHZ_SNAPSHOT_LOCAL_CACHE: dict[str, tuple[float, object]] = {}
_AUTHZ_SNAPSHOT_LOCAL_CACHE_LOCK = RLock()
_AUTHZ_SNAPSHOT_INFLIGHT: dict[str, Event] = {}
_AUTHZ_SNAPSHOT_INFLIGHT_LOCK = RLock()
_AUTHZ_SNAPSHOT_CACHE_TTL_SECONDS = 30


def _authz_snapshot_cache_ttl_seconds() -> int:
    return max(5, min(60, _AUTHZ_SNAPSHOT_CACHE_TTL_SECONDS))


def _authz_snapshot_revision_token(revision_by_module: dict[str, int]) -> str:
    return json.dumps(
        sorted((str(module), int(revision)) for module, revision in revision_by_module.items()),
        ensure_ascii=True,
        separators=(",", ":"),
    )


def _authz_snapshot_cache_key(
    *,
    role_codes: list[str],
    revision_token: str,
) -> str:
    role_token = ",".join(sorted(role_codes))
    digest = hashlib.sha1(f"{role_token}|{revision_token}".encode("utf-8")).hexdigest()
    return f"authz_snapshot:{digest}"


def _authz_snapshot_catalog_cache_key(revision_token: str) -> str:
    digest = hashlib.sha1(revision_token.encode("utf-8")).hexdigest()
    return f"authz_snapshot_catalog:{digest}"


def _get_authz_snapshot_from_cache(cache_key: str):
    with _AUTHZ_SNAPSHOT_LOCAL_CACHE_LOCK:
        cached = _AUTHZ_SNAPSHOT_LOCAL_CACHE.get(cache_key)
        if cached is None:
            return None
        expire_at, payload = cached
        if expire_at <= time.monotonic():
            _AUTHZ_SNAPSHOT_LOCAL_CACHE.pop(cache_key, None)
            return None
        return payload


def _set_authz_snapshot_cache(cache_key: str, payload: object) -> None:
    with _AUTHZ_SNAPSHOT_LOCAL_CACHE_LOCK:
        _AUTHZ_SNAPSHOT_LOCAL_CACHE[cache_key] = (
            time.monotonic() + _authz_snapshot_cache_ttl_seconds(),
            payload,
        )


def _get_or_build_authz_snapshot_cache(cache_key: str, builder) -> object:
    cached = _get_authz_snapshot_from_cache(cache_key)
    if cached is not None:
        return cached

    event: Event | None = None
    while True:
        with _AUTHZ_SNAPSHOT_INFLIGHT_LOCK:
            cached = _get_authz_snapshot_from_cache(cache_key)
            if cached is not None:
                return cached
            event = _AUTHZ_SNAPSHOT_INFLIGHT.get(cache_key)
            if event is None:
                event = Event()
                _AUTHZ_SNAPSHOT_INFLIGHT[cache_key] = event
                break
        event.wait(timeout=max(0.05, float(_authz_snapshot_cache_ttl_seconds())))
        cached = _get_authz_snapshot_from_cache(cache_key)
        if cached is not None:
            return cached

    try:
        payload = builder()
        _set_authz_snapshot_cache(cache_key, payload)
        return payload
    finally:
        with _AUTHZ_SNAPSHOT_INFLIGHT_LOCK:
            current = _AUTHZ_SNAPSHOT_INFLIGHT.get(cache_key)
            if current is event:
                _AUTHZ_SNAPSHOT_INFLIGHT.pop(cache_key, None)
                event.set()


def _load_catalog_meta(
    db: Session,
    *,
    revision_by_module: dict[str, int],
    revision_token: str,
) -> tuple[list[str], dict[str, PermissionCatalogRow]]:
    cache_key = _authz_snapshot_catalog_cache_key(revision_token)
    cached = _get_authz_snapshot_from_cache(cache_key)
    if cached is not None:
        cached_modules, cached_row_by_code = cached
        return list(cached_modules), dict(cached_row_by_code)

    catalog_rows = list_permission_catalog_rows(db)
    row_by_code: dict[str, PermissionCatalogRow] = {
        row.permission_code: row for row in catalog_rows
    }
    module_codes = sorted(
        {
            *revision_by_module.keys(),
            *(str(row.module_code).strip() for row in catalog_rows if str(row.module_code).strip()),
        }
    )
    _set_authz_snapshot_cache(cache_key, (tuple(module_codes), row_by_code))
    return module_codes, row_by_code


def _visible_pages_from_permission_codes(
    permission_codes: set[str],
) -> tuple[list[str], dict[str, list[str]]]:
    sidebar_codes: list[str] = []
    tab_codes_by_parent: dict[str, list[str]] = {}
    visible_sidebar_set: set[str] = set()

    for page in PAGE_CATALOG:
        page_code = str(page["code"])
        page_type = str(page["page_type"])
        parent_code = page.get("parent_code")
        always_visible = bool(page.get("always_visible", False))
        permission_code = PAGE_PERMISSION_BY_PAGE_CODE.get(page_code)
        visible = always_visible or bool(permission_code and permission_code in permission_codes)
        if not visible:
            continue

        if page_type == PAGE_TYPE_SIDEBAR:
            sidebar_codes.append(page_code)
            visible_sidebar_set.add(page_code)
            continue
        if page_type == PAGE_TYPE_TAB and isinstance(parent_code, str):
            if parent_code not in visible_sidebar_set:
                continue
            tab_codes_by_parent.setdefault(parent_code, []).append(page_code)

    return sidebar_codes, tab_codes_by_parent


def get_authz_snapshot(
    db: Session,
    *,
    user: User,
) -> dict[str, object]:
    role_codes = sorted({role.code for role in user.roles})
    revision_by_module = get_authz_module_revision_map(db)
    revision_token = _authz_snapshot_revision_token(revision_by_module)
    cache_key = _authz_snapshot_cache_key(
        role_codes=role_codes,
        revision_token=revision_token,
    )
    result = _get_or_build_authz_snapshot_cache(
        cache_key,
        lambda: _build_authz_snapshot(
            db,
            user=user,
            role_codes=role_codes,
            revision_by_module=revision_by_module,
            revision_token=revision_token,
        ),
    )
    return dict(result)


def _build_authz_snapshot(
    db: Session,
    *,
    user: User,
    role_codes: list[str],
    revision_by_module: dict[str, int],
    revision_token: str,
) -> dict[str, object]:
    module_codes, row_by_code = _load_catalog_meta(
        db,
        revision_by_module=revision_by_module,
        revision_token=revision_token,
    )
    effective_codes = get_user_permission_codes(db, user=user)
    sidebar_codes, tab_codes_by_parent = _visible_pages_from_permission_codes(
        effective_codes,
    )

    permissions_by_module: dict[str, list[str]] = defaultdict(list)
    page_permissions_by_module: dict[str, list[str]] = defaultdict(list)
    capability_codes_by_module: dict[str, list[str]] = defaultdict(list)
    action_codes_by_module: dict[str, list[str]] = defaultdict(list)

    for code in sorted(effective_codes):
        row = row_by_code.get(code)
        if row is None:
            continue
        module_code = str(row.module_code).strip()
        if not module_code:
            continue
        permissions_by_module[module_code].append(code)
        if row.resource_type == AUTHZ_RESOURCE_PAGE:
            page_permissions_by_module[module_code].append(code)
        elif row.resource_type == AUTHZ_RESOURCE_FEATURE:
            capability_codes_by_module[module_code].append(code)
        elif row.resource_type == AUTHZ_RESOURCE_ACTION:
            action_codes_by_module[module_code].append(code)

    module_items: list[dict[str, object]] = []
    for module_code in module_codes:
        module_permission = MODULE_PERMISSION_BY_MODULE_CODE.get(
            module_code,
            module_permission_code(module_code),
        )
        module_items.append(
            {
                "module_code": module_code,
                "module_name": MODULE_NAME_BY_CODE.get(module_code, module_code),
                "module_revision": revision_by_module.get(module_code, 0),
                "module_enabled": module_permission in effective_codes,
                "effective_permission_codes": permissions_by_module.get(module_code, []),
                "effective_page_permission_codes": page_permissions_by_module.get(module_code, []),
                "effective_capability_codes": capability_codes_by_module.get(module_code, []),
                "effective_action_permission_codes": action_codes_by_module.get(module_code, []),
            }
        )

    return {
        "revision": max(revision_by_module.values(), default=0),
        "role_codes": role_codes,
        "visible_sidebar_codes": sidebar_codes,
        "tab_codes_by_parent": tab_codes_by_parent,
        "module_items": module_items,
    }
