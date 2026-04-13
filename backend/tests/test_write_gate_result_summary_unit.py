import sys
import unittest
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = BACKEND_DIR.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.perf.write_gate.result_summary import (
    ScenarioResult,
    build_write_gate_summary,
)


class WriteGateResultSummaryUnitTest(unittest.TestCase):
    def test_write_gate_summary_groups_results_by_layer_and_error_type(self) -> None:
        summary = build_write_gate_summary(
            [
                ScenarioResult(
                    name="production-order-create",
                    layer="L1",
                    success=True,
                    status_code=201,
                    p95_ms=180,
                    restore_ok=True,
                ),
                ScenarioResult(
                    name="quality-supplier-create",
                    layer="L2",
                    success=False,
                    status_code=422,
                    p95_ms=90,
                    restore_ok=True,
                ),
            ]
        )

        self.assertEqual(summary.by_layer["L1"].success_rate, 1.0)
        self.assertEqual(summary.by_layer["L2"].error_types["422"], 1)
        self.assertEqual(summary.overall.restore_success_rate, 1.0)


if __name__ == "__main__":
    unittest.main()
