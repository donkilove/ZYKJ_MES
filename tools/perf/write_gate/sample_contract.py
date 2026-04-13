from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class SampleContract:
    baseline_refs: list[str] = field(default_factory=list)
    runtime_samples: list[str] = field(default_factory=list)
    state_assertions: list[str] = field(default_factory=list)
    restore_strategy: str | None = None


def _normalize_str_list(raw: Any, *, field_name: str) -> list[str]:
    if raw is None:
        return []
    if not isinstance(raw, list):
        raise ValueError(f"{field_name} must be an array of strings")
    values: list[str] = []
    for index, item in enumerate(raw):
        if not isinstance(item, str):
            raise ValueError(f"{field_name}[{index}] must be a string")
        value = item.strip()
        if not value:
            raise ValueError(f"{field_name}[{index}] must not be empty")
        values.append(value)
    return values


def normalize_sample_contract(raw: Any) -> SampleContract | None:
    if raw is None:
        return None
    if not isinstance(raw, dict):
        raise ValueError("sample_contract must be an object")
    baseline_refs = _normalize_str_list(
        raw.get("baseline_refs"),
        field_name="sample_contract.baseline_refs",
    )
    runtime_samples = _normalize_str_list(
        raw.get("runtime_samples"),
        field_name="sample_contract.runtime_samples",
    )
    state_assertions = _normalize_str_list(
        raw.get("state_assertions"),
        field_name="sample_contract.state_assertions",
    )
    restore_strategy_raw = raw.get("restore_strategy")
    if restore_strategy_raw is None:
        restore_strategy = None
    elif not isinstance(restore_strategy_raw, str):
        raise ValueError("sample_contract.restore_strategy must be a string")
    else:
        restore_strategy = restore_strategy_raw.strip() or None
    return SampleContract(
        baseline_refs=baseline_refs,
        runtime_samples=runtime_samples,
        state_assertions=state_assertions,
        restore_strategy=restore_strategy,
    )
