from __future__ import annotations

import hashlib
from pathlib import Path
import time


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


def _authz_cache_generation_marker_path() -> Path:
    repo_root = Path(__file__).resolve().parents[3]
    return repo_root / ".tmp_runtime" / "authz_cache_generation.marker"


def _authz_cache_generation_value() -> int:
    marker_path = _authz_cache_generation_marker_path()
    try:
        return int(marker_path.stat().st_mtime_ns)
    except FileNotFoundError:
        return 0


def _bump_authz_cache_generation() -> int:
    marker_path = _authz_cache_generation_marker_path()
    marker_path.parent.mkdir(parents=True, exist_ok=True)
    now_ns = time.time_ns()
    marker_path.write_text(str(now_ns), encoding="utf-8")
    return now_ns
