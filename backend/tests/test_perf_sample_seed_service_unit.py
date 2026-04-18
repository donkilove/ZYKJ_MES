import sys
import unittest
from pathlib import Path

from sqlalchemy import select


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.db.session import SessionLocal  # noqa: E402
from app.models.process import Process  # noqa: E402
from app.models.process_stage import ProcessStage  # noqa: E402
from app.models.production_order import ProductionOrder  # noqa: E402
from app.models.production_order_process import ProductionOrderProcess  # noqa: E402
from app.models.product_process_template import ProductProcessTemplate  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services.craft_service import create_template  # noqa: E402
from app.services.production_order_service import create_order  # noqa: E402
from app.services.bootstrap_seed_service import seed_initial_data  # noqa: E402
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


def _admin_user(db):
    seed_initial_data(
        db,
        admin_username="admin",
        admin_password="Admin@123456",
    )
    return db.execute(select(User).where(User.username == "admin")).scalars().first()


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
        self.assertIn("first_article_template_id", result_first.context)
        self.assertIn("verification_code", result_first.context)
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

    def test_seed_production_craft_samples_cleans_stale_perf_artifacts(self) -> None:
        db = SessionLocal()
        try:
            baseline = seed_production_craft_samples(db, run_id="baseline")
            admin = _admin_user(db)
            assert admin is not None

            stale_template = create_template(
                db,
                product_id=int(baseline.context["product_id"]),
                template_name="PERF-TPL-STALE",
                is_default=False,
                remark="stale perf template",
                steps=[
                    {
                        "step_order": 1,
                        "stage_id": int(baseline.context["stage_id"]),
                        "process_id": int(baseline.context["process_id"]),
                    }
                ],
                operator=admin,
            )
            stale_template.lifecycle_status = "published"
            stale_template.published_version = stale_template.version
            db.commit()

            create_order(
                db,
                order_code="PERF-ORDER-STALE",
                product_id=int(baseline.context["product_id"]),
                supplier_id=int(baseline.context["supplier_id"]),
                quantity=10,
                start_date=None,
                due_date=None,
                remark="stale perf order",
                process_codes=[],
                template_id=stale_template.id,
                process_steps=None,
                save_as_template=False,
                new_template_name=None,
                new_template_set_default=False,
                operator=admin,
            )
            db.commit()

            refreshed = seed_production_craft_samples(db, run_id="baseline")
            stale_template_row = db.execute(
                select(ProductProcessTemplate).where(
                    ProductProcessTemplate.template_name == "PERF-TPL-STALE"
                )
            ).scalars().first()
            stale_order_row = _find_order_by_code("PERF-ORDER-STALE")
        finally:
            db.close()

        self.assertIsNone(stale_template_row)
        self.assertIsNone(stale_order_row)
        self.assertEqual(refreshed.context["production_order_id"], baseline.context["production_order_id"])

    def test_seed_production_craft_samples_can_skip_stale_perf_cleanup(self) -> None:
        db = SessionLocal()
        try:
            baseline = seed_production_craft_samples(db, run_id="baseline")
            admin = _admin_user(db)
            assert admin is not None

            stale_template = create_template(
                db,
                product_id=int(baseline.context["product_id"]),
                template_name="PERF-TPL-RUNTIME-KEEP",
                is_default=False,
                remark="runtime perf template",
                steps=[
                    {
                        "step_order": 1,
                        "stage_id": int(baseline.context["stage_id"]),
                        "process_id": int(baseline.context["process_id"]),
                    }
                ],
                operator=admin,
            )
            stale_template.lifecycle_status = "published"
            stale_template.published_version = stale_template.version
            db.commit()

            create_order(
                db,
                order_code="PERF-ORDER-RUNTIME-KEEP",
                product_id=int(baseline.context["product_id"]),
                supplier_id=int(baseline.context["supplier_id"]),
                quantity=10,
                start_date=None,
                due_date=None,
                remark="runtime perf order",
                process_codes=[],
                template_id=stale_template.id,
                process_steps=None,
                save_as_template=False,
                new_template_name=None,
                new_template_set_default=False,
                operator=admin,
            )
            db.commit()

            seed_production_craft_samples(
                db,
                run_id="runtime-check",
                cleanup_stale_perf_artifacts=False,
            )

            stale_template_row = db.execute(
                select(ProductProcessTemplate).where(
                    ProductProcessTemplate.template_name == "PERF-TPL-RUNTIME-KEEP"
                )
            ).scalars().first()
            stale_order_row = db.execute(
                select(ProductionOrder).where(
                    ProductionOrder.order_code == "PERF-ORDER-RUNTIME-KEEP"
                )
            ).scalars().first()
        finally:
            db.close()

        self.assertIsNotNone(stale_template_row)
        self.assertIsNotNone(stale_order_row)

    def test_seed_production_craft_samples_rebuilds_stale_order_process_rows(self) -> None:
        db = SessionLocal()
        try:
            baseline = seed_production_craft_samples(db, run_id="baseline")
            order_id = int(baseline.context["production_order_id"])
            rows = db.execute(
                select(ProductionOrderProcess)
                .where(ProductionOrderProcess.order_id == order_id)
                .order_by(ProductionOrderProcess.process_order.asc())
            ).scalars().all()
            self.assertGreaterEqual(len(rows), 2)
            stale_first_id = rows[0].id

            for row in rows:
                db.delete(row)
            db.flush()

            db.add(
                ProductionOrderProcess(
                    order_id=order_id,
                    process_id=int(baseline.context["process_id"]),
                    stage_id=int(baseline.context["stage_id"]),
                    stage_code=str(baseline.context["stage_code"]),
                    stage_name=str(baseline.context["stage_code"]),
                    process_code=str(baseline.context["process_code"]),
                    process_name=str(baseline.context["process_code"]),
                    process_order=1,
                    status="pending",
                    visible_quantity=0,
                    completed_quantity=0,
                )
            )
            db.commit()

            refreshed = seed_production_craft_samples(db, run_id="baseline")
        finally:
            db.close()

        self.assertNotEqual(refreshed.context["order_process_id"], stale_first_id)
        self.assertNotEqual(
            refreshed.context["order_process_id"],
            refreshed.context["secondary_order_process_id"],
        )

    def test_seed_production_craft_samples_cleans_stale_stage_and_process_artifacts(
        self,
    ) -> None:
        db = SessionLocal()
        try:
            baseline = seed_production_craft_samples(db, run_id="baseline")
            stage = ProcessStage(
                code="PERF-STAGE-TMP-001",
                name="PERF-STAGE-TMP-001",
                sort_order=99,
                is_enabled=True,
                remark="runtime perf stage",
            )
            db.add(stage)
            db.flush()
            db.commit()

            refreshed = seed_production_craft_samples(db, run_id="baseline")
            stale_stage = db.execute(
                select(ProcessStage).where(ProcessStage.code == "PERF-STAGE-TMP-001")
            ).scalars().first()
            stale_processes = db.execute(
                select(Process).where(
                    Process.code.like(f"{baseline.context['stage_code']}-%")
                )
            ).scalars().all()
        finally:
            db.close()

        self.assertIsNone(stale_stage)
        self.assertEqual(stale_processes, [])
        self.assertEqual(refreshed.context["stage_code"], baseline.context["stage_code"])


if __name__ == "__main__":
    unittest.main()
