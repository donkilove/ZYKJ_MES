import sys
import unittest
from pathlib import Path

from sqlalchemy import select


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.db.session import SessionLocal  # noqa: E402
from app.models.production_order import ProductionOrder  # noqa: E402
from app.services.perf_sample_seed_service import (  # noqa: E402
    reset_runtime_samples,
    seed_production_craft_samples,
)


STABLE_PRODUCT_NAME = "PERF-PRODUCT-STD-01"
STABLE_ORDER_CODE = "PERF-ORDER-OPEN-01"
RUNTIME_ORDER_PREFIX = "PERF-RUN-"


def _cleanup_runtime_orders() -> None:
    db = SessionLocal()
    try:
        for row in db.execute(
            select(ProductionOrder).where(
                ProductionOrder.order_code.like(f"{RUNTIME_ORDER_PREFIX}%")
            )
        ).scalars():
            db.delete(row)
        db.commit()
    finally:
        db.close()


def _find_order_by_code(order_code: str) -> ProductionOrder | None:
    db = SessionLocal()
    try:
        return (
            db.execute(
                select(ProductionOrder).where(ProductionOrder.order_code == order_code)
            )
            .scalars()
            .first()
        )
    finally:
        db.close()


class PerfSampleSeedServiceUnitTest(unittest.TestCase):
    def setUp(self) -> None:
        _cleanup_runtime_orders()

    def tearDown(self) -> None:
        _cleanup_runtime_orders()

    def test_seed_production_craft_samples_is_idempotent(self) -> None:
        db = SessionLocal()
        try:
            result_first = seed_production_craft_samples(db, run_id="baseline")
            result_second = seed_production_craft_samples(db, run_id="baseline")
        finally:
            db.close()

        self.assertEqual(result_first.baseline_refs["product"], STABLE_PRODUCT_NAME)
        self.assertEqual(
            result_second.context["production_order_id"],
            result_first.context["production_order_id"],
        )
        self.assertEqual(result_second.created_count, 0)

    def test_reset_runtime_samples_only_removes_run_scoped_entities(self) -> None:
        db = SessionLocal()
        try:
            runtime = seed_production_craft_samples(
                db, run_id="run-001", mode="runtime"
            )
            reset_runtime_samples(
                db,
                runtime.run_scoped_refs,
                restore_strategy="rebuild",
            )
        finally:
            db.close()

        self.assertIsNotNone(runtime.context["production_order_id"])
        self.assertIsNotNone(_find_order_by_code(STABLE_ORDER_CODE))


if __name__ == "__main__":
    unittest.main()
