from __future__ import annotations

import copy
import json
from threading import Event
import time


def get_authz_read_cache(
    *,
    local_cache: dict[str, tuple[float, object]],
    local_cache_lock,
    cache_key: str,
    copy_payload: bool = False,
):
    with local_cache_lock:
        cached = local_cache.get(cache_key)
        if cached is None:
            return None
        expire_at, payload = cached
        if expire_at <= time.monotonic():
            local_cache.pop(cache_key, None)
            return None
        if copy_payload:
            return copy.deepcopy(payload)
        return payload


def set_authz_read_cache(
    *,
    local_cache: dict[str, tuple[float, object]],
    local_cache_lock,
    cache_key: str,
    payload: object,
    ttl_seconds: int,
    copy_payload: bool = False,
) -> None:
    expire_at = time.monotonic() + ttl_seconds
    with local_cache_lock:
        if copy_payload:
            local_cache[cache_key] = (expire_at, copy.deepcopy(payload))
            return
        local_cache[cache_key] = (expire_at, payload)


def get_or_build_authz_read_cache(
    *,
    local_cache: dict[str, tuple[float, object]],
    local_cache_lock,
    inflight: dict[str, Event],
    inflight_lock,
    cache_key: str,
    builder,
    ttl_seconds: int,
    copy_payload: bool = False,
):
    cached = get_authz_read_cache(
        local_cache=local_cache,
        local_cache_lock=local_cache_lock,
        cache_key=cache_key,
        copy_payload=copy_payload,
    )
    if cached is not None:
        return cached

    event: Event | None = None
    while True:
        with inflight_lock:
            cached = get_authz_read_cache(
                local_cache=local_cache,
                local_cache_lock=local_cache_lock,
                cache_key=cache_key,
                copy_payload=copy_payload,
            )
            if cached is not None:
                return cached
            event = inflight.get(cache_key)
            if event is None:
                event = Event()
                inflight[cache_key] = event
                break
        event.wait(timeout=max(0.05, float(ttl_seconds)))
        cached = get_authz_read_cache(
            local_cache=local_cache,
            local_cache_lock=local_cache_lock,
            cache_key=cache_key,
            copy_payload=copy_payload,
        )
        if cached is not None:
            return cached

    try:
        payload = builder()
        set_authz_read_cache(
            local_cache=local_cache,
            local_cache_lock=local_cache_lock,
            cache_key=cache_key,
            payload=payload,
            ttl_seconds=ttl_seconds,
            copy_payload=copy_payload,
        )
        return payload
    finally:
        with inflight_lock:
            current = inflight.get(cache_key)
            if current is event:
                inflight.pop(cache_key, None)
                event.set()


def build_authz_read_revision_state(
    revision_by_module: dict[str, int],
) -> tuple[dict[str, int], str]:
    revision_token = json.dumps(
        sorted(
            (str(module_code), int(revision))
            for module_code, revision in revision_by_module.items()
        ),
        ensure_ascii=True,
        separators=(",", ":"),
    )
    return dict(revision_by_module), revision_token
