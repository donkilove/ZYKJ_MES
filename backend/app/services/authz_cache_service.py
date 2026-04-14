from __future__ import annotations

import hashlib


AUTHZ_PERMISSION_CACHE_ALL_MODULES = "__all__"


def _authz_permission_cache_ttl_seconds(*, ttl_seconds: int) -> int:
    return max(1, ttl_seconds)


def _authz_read_cache_ttl_seconds(*, ttl_seconds: int) -> int:
    return max(5, min(60, ttl_seconds))


def _authz_read_cache_key(*, cache_prefix: str, cache_type: str, values: list[str]) -> str:
    joined = "|".join(values)
    digest = hashlib.sha1(f"{cache_type}|{joined}".encode("utf-8")).hexdigest()
    return f"{cache_prefix}:read:{cache_type}:{digest}"


def _authz_permission_cache_key(
    *,
    cache_prefix: str,
    normalized_roles: list[str],
    normalized_module_code: str | None,
    all_modules_token: str = AUTHZ_PERMISSION_CACHE_ALL_MODULES,
) -> str:
    module_token = normalized_module_code or all_modules_token
    joined_roles = ",".join(normalized_roles)
    digest = hashlib.sha1(f"{joined_roles}|{module_token}".encode("utf-8")).hexdigest()
    return f"{cache_prefix}:{digest}"
