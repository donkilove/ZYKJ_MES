from __future__ import annotations

import json
import re
import time
from pathlib import Path
from typing import Any


SAMPLE_TOKEN_PATTERN = re.compile(r"{sample:([a-zA-Z0-9_.-]+)}")


def load_sample_context(path: str | None) -> dict[str, Any]:
    if not path:
        return {}
    sample_path = Path(path).resolve()
    if not sample_path.exists():
        raise FileNotFoundError(f"sample context file not found: {sample_path}")
    payload = json.loads(sample_path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("sample context must be a JSON object")
    return payload


def materialize_sample_value(raw: Any, sample_values: dict[str, Any]) -> Any:
    if isinstance(raw, str):
        def _replace(match: re.Match[str]) -> str:
            key = match.group(1)
            if key not in sample_values:
                raise KeyError(f"missing sample context key: {key}")
            return str(sample_values[key])

        replaced = SAMPLE_TOKEN_PATTERN.sub(_replace, raw)
        replaced = replaced.replace("{RANDOM_INT}", str(time.time_ns()))
        replaced = replaced.replace("{RANDOM_SHORT}", str(time.time_ns())[-6:])
        if replaced.isdigit():
            return int(replaced)
        return replaced
    if isinstance(raw, list):
        return [materialize_sample_value(item, sample_values) for item in raw]
    if isinstance(raw, dict):
        return {
            key: materialize_sample_value(value, sample_values)
            for key, value in raw.items()
        }
    return raw
