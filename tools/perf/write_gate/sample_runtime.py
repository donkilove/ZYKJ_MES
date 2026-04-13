from __future__ import annotations

from dataclasses import dataclass, field
from typing import Protocol

from tools.perf.write_gate.sample_contract import SampleContract


class SampleHandler(Protocol):
    def prepare(self) -> None: ...

    def restore(self, strategy: str | None) -> None: ...


@dataclass(slots=True)
class SampleExecutionResult:
    scenario_name: str
    prepare_calls: list[str] = field(default_factory=list)
    restore_calls: list[str] = field(default_factory=list)
    failed: bool = False


class WriteSampleRuntime:
    def __init__(self, registry: dict[str, SampleHandler]) -> None:
        self._registry = registry

    def prepare_contract(self, contract: SampleContract) -> list[str]:
        prepared: list[str] = []
        for sample_name in contract.runtime_samples:
            handler = self._registry[sample_name]
            handler.prepare()
            prepared.append(sample_name)
        return prepared

    def restore_contract(self, contract: SampleContract) -> list[str]:
        restored: list[str] = []
        for sample_name in reversed(contract.runtime_samples):
            handler = self._registry[sample_name]
            handler.restore(contract.restore_strategy)
            restored.append(sample_name)
        return restored

    def execute_contract(
        self,
        *,
        scenario_name: str,
        contract: SampleContract,
    ) -> SampleExecutionResult:
        prepared = self.prepare_contract(contract)
        restored = self.restore_contract(contract)
        return SampleExecutionResult(
            scenario_name=scenario_name,
            prepare_calls=prepared,
            restore_calls=restored,
            failed=False,
        )
