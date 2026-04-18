from __future__ import annotations

from dataclasses import dataclass, field
import inspect
from typing import Any, Protocol

from tools.perf.write_gate.sample_contract import SampleContract


class SampleHandler(Protocol):
    def prepare(self, sample_context: dict[str, Any] | None = None) -> None: ...

    def restore(
        self,
        strategy: str | None,
        sample_context: dict[str, Any] | None = None,
    ) -> None: ...


@dataclass(slots=True)
class SampleExecutionResult:
    scenario_name: str
    prepare_calls: list[str] = field(default_factory=list)
    restore_calls: list[str] = field(default_factory=list)
    failed: bool = False


class WriteSampleRuntime:
    def __init__(self, registry: dict[str, SampleHandler]) -> None:
        self._registry = registry

    def _call_prepare(
        self,
        handler: SampleHandler,
        *,
        sample_context: dict[str, Any],
    ) -> None:
        parameter_count = len(inspect.signature(handler.prepare).parameters)
        if parameter_count == 0:
            handler.prepare()
        else:
            handler.prepare(sample_context)

    def _call_restore(
        self,
        handler: SampleHandler,
        *,
        strategy: str | None,
        sample_context: dict[str, Any],
    ) -> None:
        parameter_count = len(inspect.signature(handler.restore).parameters)
        if parameter_count == 1:
            handler.restore(strategy)
        else:
            handler.restore(strategy, sample_context)

    def prepare_contract(
        self,
        contract: SampleContract,
        sample_context: dict[str, Any],
    ) -> list[str]:
        prepared: list[str] = []
        for sample_name in contract.runtime_samples:
            handler = self._registry[sample_name]
            self._call_prepare(handler, sample_context=sample_context)
            prepared.append(sample_name)
        return prepared

    def restore_contract(
        self,
        contract: SampleContract,
        sample_context: dict[str, Any],
    ) -> list[str]:
        restored: list[str] = []
        for sample_name in reversed(contract.runtime_samples):
            handler = self._registry[sample_name]
            self._call_restore(
                handler,
                strategy=contract.restore_strategy,
                sample_context=sample_context,
            )
            restored.append(sample_name)
        return restored

    def execute_contract(
        self,
        *,
        scenario_name: str,
        contract: SampleContract,
        sample_context: dict[str, Any],
    ) -> SampleExecutionResult:
        prepared = self.prepare_contract(contract, sample_context)
        restored = self.restore_contract(contract, sample_context)
        return SampleExecutionResult(
            scenario_name=scenario_name,
            prepare_calls=prepared,
            restore_calls=restored,
            failed=False,
        )
