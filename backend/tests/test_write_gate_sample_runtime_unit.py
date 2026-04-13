import sys
import unittest
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = BACKEND_DIR.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.perf.write_gate.sample_contract import SampleContract
from tools.perf.write_gate.sample_runtime import WriteSampleRuntime


class FakeSampleHandler:
    def __init__(self, event_log: list[str], sample_name: str) -> None:
        self._event_log = event_log
        self._sample_name = sample_name

    def prepare(self) -> None:
        self._event_log.append(f"prepare:{self._sample_name}")

    def restore(self, strategy: str | None) -> None:
        self._event_log.append(f"restore:{self._sample_name}:{strategy}")


class WriteSampleRuntimeUnitTest(unittest.TestCase):
    def test_sample_runtime_runs_prepare_assert_restore_in_order(self) -> None:
        event_log: list[str] = []
        runtime = WriteSampleRuntime(
            registry={
                "order:create-ready": FakeSampleHandler(event_log, "order:create-ready"),
                "order:line-items-ready": FakeSampleHandler(
                    event_log,
                    "order:line-items-ready",
                ),
            }
        )

        result = runtime.execute_contract(
            scenario_name="production-order-create",
            contract=SampleContract(
                runtime_samples=["order:create-ready", "order:line-items-ready"],
                restore_strategy="rebuild",
                state_assertions=["order.exists"],
            ),
        )

        self.assertEqual(
            event_log,
            [
                "prepare:order:create-ready",
                "prepare:order:line-items-ready",
                "restore:order:line-items-ready:rebuild",
                "restore:order:create-ready:rebuild",
            ],
        )
        self.assertEqual(
            result.prepare_calls,
            ["order:create-ready", "order:line-items-ready"],
        )
        self.assertEqual(
            result.restore_calls,
            ["order:line-items-ready", "order:create-ready"],
        )
        self.assertFalse(result.failed)


if __name__ == "__main__":
    unittest.main()
