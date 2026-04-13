from __future__ import annotations

from collections import Counter, defaultdict
from dataclasses import dataclass, field


@dataclass(slots=True)
class ScenarioResult:
    name: str
    layer: str
    success: bool
    status_code: int
    p95_ms: float
    restore_ok: bool


@dataclass(slots=True)
class SummaryBucket:
    total: int
    success_count: int
    error_types: dict[str, int]
    p95_ms: float
    restore_success_rate: float

    @property
    def success_rate(self) -> float:
        if self.total == 0:
            return 0.0
        return self.success_count / self.total

    def to_dict(self) -> dict[str, object]:
        return {
            "total": self.total,
            "success_count": self.success_count,
            "success_rate": self.success_rate,
            "error_types": self.error_types,
            "p95_ms": self.p95_ms,
            "restore_success_rate": self.restore_success_rate,
        }


@dataclass(slots=True)
class WriteGateSummary:
    overall: SummaryBucket
    by_layer: dict[str, SummaryBucket] = field(default_factory=dict)

    def to_dict(self) -> dict[str, object]:
        return {
            "overall": self.overall.to_dict(),
            "by_layer": {
                layer: bucket.to_dict() for layer, bucket in self.by_layer.items()
            },
        }


def _build_bucket(results: list[ScenarioResult]) -> SummaryBucket:
    total = len(results)
    success_count = sum(1 for result in results if result.success)
    error_types = Counter(
        str(result.status_code) for result in results if not result.success
    )
    restore_success_count = sum(1 for result in results if result.restore_ok)
    max_p95 = max((float(result.p95_ms) for result in results), default=0.0)
    restore_success_rate = (
        restore_success_count / total if total else 0.0
    )
    return SummaryBucket(
        total=total,
        success_count=success_count,
        error_types=dict(sorted(error_types.items())),
        p95_ms=max_p95,
        restore_success_rate=restore_success_rate,
    )


def build_write_gate_summary(results: list[ScenarioResult]) -> WriteGateSummary:
    grouped: dict[str, list[ScenarioResult]] = defaultdict(list)
    for result in results:
        grouped[result.layer].append(result)
    return WriteGateSummary(
        overall=_build_bucket(results),
        by_layer={layer: _build_bucket(bucket) for layer, bucket in grouped.items()},
    )
