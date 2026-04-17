from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from tools.perf.write_gate.sample_runtime import SampleHandler


@dataclass(slots=True)
class NoOpSampleHandler(SampleHandler):
    sample_name: str

    def prepare(self) -> None:
        return None

    def restore(self, strategy: str | None) -> None:
        return None


def build_sample_registry(
    *,
    sample_context: dict[str, Any],
    api_client: Any,
) -> dict[str, SampleHandler]:
    _ = sample_context
    _ = api_client
    return {
        "order:create-ready": NoOpSampleHandler("order:create-ready"),
        "order:line-items-ready": NoOpSampleHandler("order:line-items-ready"),
        "supplier:create-ready": NoOpSampleHandler("supplier:create-ready"),
        "craft:template-publish-ready": NoOpSampleHandler(
            "craft:template-publish-ready"
        ),
    }
