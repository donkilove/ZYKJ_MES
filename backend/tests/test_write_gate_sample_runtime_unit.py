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
from tools.perf.write_gate.sample_registry import RuntimeProductVersionReadyHandler
from tools.perf.write_gate.sample_runtime import WriteSampleRuntime
from app.db.session import SessionLocal
from app.models.product import Product


class FakeSampleHandler:
    def __init__(self, event_log: list[str], sample_name: str) -> None:
        self._event_log = event_log
        self._sample_name = sample_name

    def prepare(self) -> None:
        self._event_log.append(f"prepare:{self._sample_name}")

    def restore(self, strategy: str | None) -> None:
        self._event_log.append(f"restore:{self._sample_name}:{strategy}")


class ContextAwareSampleHandler:
    def __init__(self, event_log: list[str], sample_name: str) -> None:
        self._event_log = event_log
        self._sample_name = sample_name

    def prepare(self, sample_context: dict[str, object]) -> None:
        self._event_log.append(
            f"prepare:{self._sample_name}:{sample_context['seed']}"
        )
        sample_context[self._sample_name] = f"prepared:{self._sample_name}"

    def restore(
        self,
        strategy: str | None,
        sample_context: dict[str, object],
    ) -> None:
        self._event_log.append(
            f"restore:{self._sample_name}:{sample_context[self._sample_name]}:{strategy}"
        )


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
            sample_context={},
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

    def test_sample_runtime_passes_mutable_sample_context_to_handlers(self) -> None:
        event_log: list[str] = []
        runtime = WriteSampleRuntime(
            registry={
                "production:runtime-order-pending-ready": ContextAwareSampleHandler(
                    event_log,
                    "production:runtime-order-pending-ready",
                )
            }
        )
        sample_context: dict[str, object] = {"seed": "baseline"}
        contract = SampleContract(
            runtime_samples=["production:runtime-order-pending-ready"],
            restore_strategy="delete",
        )

        prepared = runtime.prepare_contract(contract, sample_context)
        restored = runtime.restore_contract(contract, sample_context)

        self.assertEqual(
            prepared,
            ["production:runtime-order-pending-ready"],
        )
        self.assertEqual(
            restored,
            ["production:runtime-order-pending-ready"],
        )
        self.assertEqual(
            sample_context["production:runtime-order-pending-ready"],
            "prepared:production:runtime-order-pending-ready",
        )
        self.assertEqual(
            event_log,
            [
                "prepare:production:runtime-order-pending-ready:baseline",
                "restore:production:runtime-order-pending-ready:prepared:production:runtime-order-pending-ready:delete",
            ],
        )

    def test_runtime_product_version_ready_handler_prepares_effective_only_sample(
        self,
    ) -> None:
        handler = RuntimeProductVersionReadyHandler(ensure_draft=False)
        sample_context: dict[str, object] = {}
        product_id: int | None = None

        try:
            handler.prepare(sample_context)
            product_id = int(sample_context["product_id"])
            self.assertEqual(sample_context["product_current_version"], 1)
            self.assertEqual(sample_context["product_effective_version"], 1)

            db = SessionLocal()
            try:
                self.assertIsNotNone(db.get(Product, product_id))
            finally:
                db.close()
        finally:
            if product_id is not None:
                handler.restore("delete", sample_context)

        db = SessionLocal()
        try:
            self.assertIsNone(db.get(Product, product_id))
        finally:
            db.close()

    def test_runtime_product_version_ready_handler_prepares_draft_sample(self) -> None:
        handler = RuntimeProductVersionReadyHandler(ensure_draft=True)
        sample_context: dict[str, object] = {}
        product_id: int | None = None

        try:
            handler.prepare(sample_context)
            product_id = int(sample_context["product_id"])
            self.assertEqual(sample_context["product_current_version"], 2)
            self.assertEqual(sample_context["product_effective_version"], 1)

            db = SessionLocal()
            try:
                product = db.get(Product, product_id)
                self.assertIsNotNone(product)
                assert product is not None
                self.assertEqual(product.current_version, 2)
                self.assertEqual(product.effective_version, 1)
            finally:
                db.close()
        finally:
            if product_id is not None:
                handler.restore("delete", sample_context)

        db = SessionLocal()
        try:
            self.assertIsNone(db.get(Product, product_id))
        finally:
            db.close()


if __name__ == "__main__":
    unittest.main()
