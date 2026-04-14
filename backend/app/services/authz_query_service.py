from __future__ import annotations

from app.core.authz_catalog import (
    AUTHZ_RESOURCE_ACTION,
    AUTHZ_RESOURCE_FEATURE,
    AUTHZ_RESOURCE_MODULE,
    AUTHZ_RESOURCE_PAGE,
    MODULE_PERMISSION_BY_MODULE_CODE,
    PAGE_PERMISSION_BY_PAGE_CODE,
)
from app.core.authz_hierarchy_catalog import FEATURE_BY_PERMISSION_CODE, module_permission_code


def _effective_permission_codes_from_granted(
    *,
    granted_codes: set[str],
    row_by_code: dict[str, object],
) -> set[str]:
    if not granted_codes:
        return set()

    effective: set[str] = set()
    enabled_modules: set[str] = set()

    for code in granted_codes:
        row = row_by_code.get(code)
        if row is None or getattr(row, "resource_type", None) != AUTHZ_RESOURCE_MODULE:
            continue
        enabled_modules.add(code)
    effective.update(enabled_modules)

    enabled_pages: set[str] = set()
    for code in granted_codes:
        row = row_by_code.get(code)
        if row is None or getattr(row, "resource_type", None) != AUTHZ_RESOURCE_PAGE:
            continue
        module_code_value = str(getattr(row, "module_code", "")).strip()
        module_permission = MODULE_PERMISSION_BY_MODULE_CODE.get(
            module_code_value,
            module_permission_code(module_code_value),
        )
        if module_permission in enabled_modules:
            enabled_pages.add(code)
    effective.update(enabled_pages)

    enabled_features: set[str] = set()
    remaining_feature_codes = {
        code
        for code in granted_codes
        if (row := row_by_code.get(code)) is not None
        and getattr(row, "resource_type", None) == AUTHZ_RESOURCE_FEATURE
    }
    changed = True
    while changed:
        changed = False
        for code in list(remaining_feature_codes):
            row = row_by_code.get(code)
            if row is None:
                remaining_feature_codes.discard(code)
                continue
            module_code_value = str(getattr(row, "module_code", "")).strip()
            module_permission = MODULE_PERMISSION_BY_MODULE_CODE.get(
                module_code_value,
                module_permission_code(module_code_value),
            )
            if module_permission not in enabled_modules:
                continue
            feature_definition = FEATURE_BY_PERMISSION_CODE.get(code)
            feature_page_code = (
                PAGE_PERMISSION_BY_PAGE_CODE.get(feature_definition.page_code)
                if feature_definition is not None
                else getattr(row, "parent_permission_code", None)
            )
            if feature_page_code and feature_page_code not in enabled_pages:
                continue
            dependency_codes = (
                set(feature_definition.dependency_permission_codes)
                if feature_definition is not None
                else set()
            )
            if dependency_codes and not dependency_codes.issubset(enabled_features):
                continue
            enabled_features.add(code)
            remaining_feature_codes.discard(code)
            changed = True
    effective.update(enabled_features)

    linked_action_codes: set[str] = set()
    for code in enabled_features:
        feature_definition = FEATURE_BY_PERMISSION_CODE.get(code)
        if feature_definition is None:
            continue
        linked_action_codes.update(feature_definition.action_permission_codes)

    enabled_actions: set[str] = set()
    for code in granted_codes.union(linked_action_codes):
        row = row_by_code.get(code)
        if row is None or getattr(row, "resource_type", None) != AUTHZ_RESOURCE_ACTION:
            continue
        module_code_value = str(getattr(row, "module_code", "")).strip()
        module_permission = MODULE_PERMISSION_BY_MODULE_CODE.get(
            module_code_value,
            module_permission_code(module_code_value),
        )
        if module_permission not in enabled_modules:
            continue
        parent_page_code = getattr(row, "parent_permission_code", None)
        if (
            parent_page_code
            and str(parent_page_code).startswith("page.")
            and parent_page_code not in enabled_pages
        ):
            continue
        enabled_actions.add(code)
    effective.update(enabled_actions)
    return effective


def _filter_effective_permission_codes_by_module(
    *,
    effective_codes: set[str],
    row_by_code: dict[str, object],
    normalized_module_code: str | None,
) -> set[str]:
    if normalized_module_code is None:
        return effective_codes
    return {
        code
        for code in effective_codes
        if (row := row_by_code.get(code)) is not None
        and str(getattr(row, "module_code", "")).strip() == normalized_module_code
    }
