import base64
import sys
import time
import unittest
from datetime import UTC, date, datetime
from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import select


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.db.session import SessionLocal  # noqa: E402
from app.api.v1.endpoints.quality import (  # noqa: E402
    get_first_article_detail_api,
    get_first_article_disposition_detail_api,
)
from app.main import app  # noqa: E402
from app.models.first_article_disposition import FirstArticleDisposition  # noqa: E402
from app.models.first_article_disposition_history import (  # noqa: E402
    FirstArticleDispositionHistory,
)
from app.models.first_article_record import FirstArticleRecord  # noqa: E402
from app.models.message import Message  # noqa: E402
from app.models.message_recipient import MessageRecipient  # noqa: E402
from app.models.process import Process  # noqa: E402
from app.models.process_stage import ProcessStage  # noqa: E402
from app.models.product import Product  # noqa: E402
from app.models.production_order import ProductionOrder  # noqa: E402
from app.models.production_order_process import ProductionOrderProcess  # noqa: E402
from app.models.repair_cause import RepairCause  # noqa: E402
from app.models.repair_defect_phenomenon import RepairDefectPhenomenon  # noqa: E402
from app.models.repair_order import RepairOrder  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services.quality_service import (  # noqa: E402
    get_first_article_by_id,
    submit_first_article_disposition,
)


class QualityModuleIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)

    def setUp(self) -> None:
        self.db = SessionLocal()
        self._suffix = str(int(time.time() * 1000000))
        self.stage_ids: list[int] = []
        self.process_ids: list[int] = []
        self.product_ids: list[int] = []
        self.order_ids: list[int] = []
        self.order_process_ids: list[int] = []
        self.record_ids: list[int] = []
        self.repair_order_ids: list[int] = []
        self.repair_defect_ids: list[int] = []
        self.repair_cause_ids: list[int] = []
        self.message_ids: list[int] = []
        self.user_ids: list[int] = []
        self.token = self._login()
        self.admin_user = (
            self.db.execute(select(User).where(User.username == "admin"))
            .scalars()
            .first()
        )
        assert self.admin_user is not None

    def tearDown(self) -> None:
        try:
            self.db.rollback()
            for message_id in reversed(self.message_ids):
                self.db.query(MessageRecipient).filter(
                    MessageRecipient.message_id == message_id
                ).delete()
                self.db.query(Message).filter(Message.id == message_id).delete()
                self.db.commit()
            for cause_id in reversed(self.repair_cause_ids):
                row = self.db.get(RepairCause, cause_id)
                if row is not None:
                    self.db.delete(row)
                    self.db.commit()
            for defect_id in reversed(self.repair_defect_ids):
                row = self.db.get(RepairDefectPhenomenon, defect_id)
                if row is not None:
                    self.db.delete(row)
                    self.db.commit()
            for repair_order_id in reversed(self.repair_order_ids):
                row = self.db.get(RepairOrder, repair_order_id)
                if row is not None:
                    self.db.delete(row)
                    self.db.commit()
            for record_id in reversed(self.record_ids):
                self.db.query(FirstArticleDispositionHistory).filter(
                    FirstArticleDispositionHistory.first_article_record_id == record_id
                ).delete()
                self.db.query(FirstArticleDisposition).filter(
                    FirstArticleDisposition.first_article_record_id == record_id
                ).delete()
                record = self.db.get(FirstArticleRecord, record_id)
                if record is not None:
                    self.db.delete(record)
                self.db.commit()
            for order_process_id in reversed(self.order_process_ids):
                row = self.db.get(ProductionOrderProcess, order_process_id)
                if row is not None:
                    self.db.delete(row)
                    self.db.commit()
            for order_id in reversed(self.order_ids):
                row = self.db.get(ProductionOrder, order_id)
                if row is not None:
                    self.db.delete(row)
                    self.db.commit()
            for product_id in reversed(self.product_ids):
                row = self.db.get(Product, product_id)
                if row is not None:
                    self.db.delete(row)
                    self.db.commit()
            for process_id in reversed(self.process_ids):
                row = self.db.get(Process, process_id)
                if row is not None:
                    self.db.delete(row)
                    self.db.commit()
            for stage_id in reversed(self.stage_ids):
                row = self.db.get(ProcessStage, stage_id)
                if row is not None:
                    self.db.delete(row)
                    self.db.commit()
            for user_id in reversed(self.user_ids):
                row = self.db.get(User, user_id)
                if row is not None:
                    self.db.delete(row)
                    self.db.commit()
        finally:
            self.db.close()

    def _login(self) -> str:
        response = self.client.post(
            "/api/v1/auth/login",
            data={"username": "admin", "password": "Admin@123456"},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["data"]["access_token"]

    def _headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self.token}"}

    def _create_stage(self, *, token: str) -> ProcessStage:
        row = ProcessStage(
            code=f"quality_stage_{token}",
            name=f"品质测试工段-{token}",
            sort_order=0,
            remark="品质模块集成测试",
            is_enabled=True,
        )
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        self.stage_ids.append(int(row.id))
        return row

    def _create_process(self, *, stage: ProcessStage, token: str) -> Process:
        row = Process(
            code=f"quality_process_{token}",
            name=f"品质测试工序-{token}",
            stage_id=stage.id,
            is_enabled=True,
            remark="品质模块集成测试",
        )
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        self.process_ids.append(int(row.id))
        return row

    def _create_product(self, *, token: str) -> Product:
        row = Product(
            name=f"品质模块测试产品-{token}",
            category="品质测试",
            remark="品质模块集成测试",
        )
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        self.product_ids.append(int(row.id))
        return row

    def _create_order(self, *, product: Product, token: str) -> ProductionOrder:
        row = ProductionOrder(
            order_code=f"QO-{token}",
            product_id=product.id,
            product_version=1,
            quantity=10,
            status="in_progress",
            current_process_code=f"quality_process_{token}",
            start_date=date(2026, 3, 1),
            due_date=date(2026, 3, 5),
            remark="品质模块集成测试",
        )
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        self.order_ids.append(int(row.id))
        return row

    def _create_order_process(
        self,
        *,
        order: ProductionOrder,
        process: Process,
        stage: ProcessStage,
    ) -> ProductionOrderProcess:
        row = ProductionOrderProcess(
            order_id=order.id,
            process_id=process.id,
            stage_id=stage.id,
            stage_code=stage.code,
            stage_name=stage.name,
            process_code=process.code,
            process_name=process.name,
            process_order=1,
            status="in_progress",
            visible_quantity=10,
            completed_quantity=0,
        )
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        self.order_process_ids.append(int(row.id))
        return row

    def _create_first_article_record(self, *, result: str) -> FirstArticleRecord:
        token = f"{self._suffix}-{len(self.record_ids) + 1}"
        stage = self._create_stage(token=token)
        process = self._create_process(stage=stage, token=token)
        product = self._create_product(token=token)
        order = self._create_order(product=product, token=token)
        order_process = self._create_order_process(
            order=order,
            process=process,
            stage=stage,
        )
        row = FirstArticleRecord(
            order_id=order.id,
            order_process_id=order_process.id,
            operator_user_id=self.admin_user.id,
            verification_date=date(2026, 3, 2),
            verification_code=f"QA-{token}",
            result=result,
            remark="品质模块集成测试",
        )
        self.db.add(row)
        self.db.commit()
        row.created_at = datetime(2026, 3, 2, 8, 0, tzinfo=UTC)
        self.db.commit()
        self.db.refresh(row)
        self.record_ids.append(int(row.id))
        return row

    def _create_operator_user(self, *, token: str) -> User:
        row = User(
            username=f"quality_operator_{token}",
            full_name=f"品质测试操作员-{token}",
            password_hash="test-password-hash",
            is_active=True,
            is_superuser=False,
            remark="品质模块集成测试",
        )
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        self.user_ids.append(int(row.id))
        return row

    def _create_repair_order(self, *, record: FirstArticleRecord) -> RepairOrder:
        order = self.db.get(ProductionOrder, record.order_id)
        order_process = self.db.get(ProductionOrderProcess, record.order_process_id)
        self.assertIsNotNone(order)
        self.assertIsNotNone(order_process)
        row = RepairOrder(
            repair_order_code=f"RO-{self._suffix}-{len(self.repair_order_ids) + 1}",
            source_order_id=order.id,
            source_order_code=order.order_code,
            product_id=order.product_id,
            product_name=order.product.name,
            source_order_process_id=order_process.id,
            source_process_code=order_process.process_code,
            source_process_name=order_process.process_name,
            sender_user_id=self.admin_user.id,
            sender_username=self.admin_user.username,
            production_quantity=10,
            repair_quantity=5,
            repaired_quantity=0,
            scrap_quantity=0,
            repair_time=datetime(2026, 3, 2, 9, 0, tzinfo=UTC),
            status="in_repair",
            repair_operator_user_id=self.admin_user.id,
            repair_operator_username=self.admin_user.username,
        )
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        self.repair_order_ids.append(int(row.id))
        return row

    def _create_repair_defect(
        self,
        *,
        repair_order: RepairOrder,
        phenomenon: str,
        quantity: int,
    ) -> RepairDefectPhenomenon:
        row = RepairDefectPhenomenon(
            repair_order_id=repair_order.id,
            order_id=repair_order.source_order_id,
            order_code=repair_order.source_order_code,
            product_id=repair_order.product_id,
            product_name=repair_order.product_name,
            process_id=repair_order.source_order_process_id,
            process_code=repair_order.source_process_code,
            process_name=repair_order.source_process_name,
            phenomenon=phenomenon,
            quantity=quantity,
            operator_user_id=self.admin_user.id,
            operator_username=self.admin_user.username,
            production_time=datetime(2026, 3, 2, 8, 30, tzinfo=UTC),
        )
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        self.repair_defect_ids.append(int(row.id))
        return row

    def _create_repair_cause(
        self,
        *,
        repair_order: RepairOrder,
        phenomenon: str,
        reason: str,
        quantity: int,
    ) -> RepairCause:
        row = RepairCause(
            repair_order_id=repair_order.id,
            order_id=repair_order.source_order_id,
            order_code=repair_order.source_order_code,
            product_id=repair_order.product_id,
            product_name=repair_order.product_name,
            process_id=repair_order.source_order_process_id,
            process_code=repair_order.source_process_code,
            process_name=repair_order.source_process_name,
            phenomenon=phenomenon,
            reason=reason,
            is_scrap=False,
            quantity=quantity,
            cause_time=datetime(2026, 3, 2, 9, 15, tzinfo=UTC),
            operator_user_id=self.admin_user.id,
            operator_username=self.admin_user.username,
        )
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        self.repair_cause_ids.append(int(row.id))
        return row

    def test_trend_export_includes_defect_total_column(self) -> None:
        response = self.client.post(
            "/api/v1/quality/trend/export",
            headers=self._headers(),
            json={"start_date": "2026-03-01", "end_date": "2026-03-07"},
        )
        self.assertEqual(response.status_code, 200, response.text)
        payload = response.json()["data"]
        csv_text = base64.b64decode(payload["content_base64"]).decode("utf-8-sig")
        self.assertEqual(payload["filename"], "quality_trend.csv")
        self.assertIn("不良数", csv_text.splitlines()[0])

    def test_disposition_requires_failed_record_and_preserves_history(self) -> None:
        failed_record = self._create_first_article_record(result="failed")
        passed_record = self._create_first_article_record(result="passed")

        submit_first_article_disposition(
            self.db,
            record_id=failed_record.id,
            disposition_opinion="首次处置",
            recheck_result="failed",
            final_judgment="rework",
            operator=self.admin_user,
        )
        self.db.commit()
        submit_first_article_disposition(
            self.db,
            record_id=failed_record.id,
            disposition_opinion="二次处置",
            recheck_result="passed",
            final_judgment="accept",
            operator=self.admin_user,
        )
        self.db.commit()

        detail = get_first_article_by_id(self.db, record_id=failed_record.id)
        assert detail is not None
        self.assertEqual(detail["disposition_opinion"], "二次处置")
        self.assertEqual(detail["final_judgment"], "accept")
        self.assertEqual(
            [item["version"] for item in detail["disposition_history"]],
            [2, 1],
        )

        with self.assertRaisesRegex(ValueError, "仅不通过首件记录允许执行处置"):
            submit_first_article_disposition(
                self.db,
                record_id=passed_record.id,
                disposition_opinion="不应允许",
                recheck_result="failed",
                final_judgment="reject",
                operator=self.admin_user,
            )

    def test_detail_and_disposition_detail_permissions_are_isolated(self) -> None:
        record = self._create_first_article_record(result="failed")
        detail_response = get_first_article_detail_api(
            record_id=record.id,
            db=self.db,
            _=self.admin_user,
        )
        disposition_response = get_first_article_disposition_detail_api(
            record_id=record.id,
            db=self.db,
            _=self.admin_user,
        )

        self.assertEqual(detail_response.data.id, record.id)
        self.assertEqual(disposition_response.data.id, record.id)

        detail_route = next(
            route
            for route in app.routes
            if getattr(route, "path", "")
            == "/api/v1/quality/first-articles/{record_id}"
            and "GET" in getattr(route, "methods", set())
        )
        disposition_route = next(
            route
            for route in app.routes
            if getattr(route, "path", "")
            == "/api/v1/quality/first-articles/{record_id}/disposition-detail"
            and "GET" in getattr(route, "methods", set())
        )
        detail_permission = (
            detail_route.dependant.dependencies[1].call.__closure__[0].cell_contents
        )
        disposition_permission = (
            disposition_route.dependant.dependencies[1]
            .call.__closure__[0]
            .cell_contents
        )

        self.assertEqual(detail_permission, "quality.first_articles.detail")
        self.assertEqual(disposition_permission, "quality.first_articles.disposition")

    def test_disposition_message_contains_first_article_detail_payload(self) -> None:
        operator_user = self._create_operator_user(token=f"{self._suffix}-operator")
        record = self._create_first_article_record(result="failed")
        record.operator_user_id = operator_user.id
        self.db.commit()

        response = self.client.post(
            f"/api/v1/quality/first-articles/{record.id}/disposition",
            headers=self._headers(),
            json={
                "disposition_opinion": "复检后需返工",
                "recheck_result": "failed",
                "final_judgment": "rework",
            },
        )
        self.assertEqual(response.status_code, 200, response.text)

        message = (
            self.db.execute(
                select(Message).where(
                    Message.dedupe_key
                    == f"first_article_disposition_{record.id}_rework"
                )
            )
            .scalars()
            .first()
        )
        self.assertIsNotNone(message)
        assert message is not None
        self.message_ids.append(int(message.id))
        self.assertEqual(message.target_page_code, "quality")
        self.assertEqual(message.target_tab_code, "first_article_management")
        self.assertEqual(
            message.target_route_payload_json,
            f'{{"action": "detail", "record_id": {record.id}}}',
        )

    def test_defect_analysis_returns_top_reasons_and_product_quality_comparison(
        self,
    ) -> None:
        record = self._create_first_article_record(result="failed")
        repair_order = self._create_repair_order(record=record)
        self._create_repair_defect(
            repair_order=repair_order,
            phenomenon="虚焊",
            quantity=3,
        )
        self._create_repair_defect(
            repair_order=repair_order,
            phenomenon="偏位",
            quantity=2,
        )
        self._create_repair_cause(
            repair_order=repair_order,
            phenomenon="虚焊",
            reason="治具偏移",
            quantity=4,
        )
        self._create_repair_cause(
            repair_order=repair_order,
            phenomenon="偏位",
            reason="来料异常",
            quantity=1,
        )

        order = self.db.get(ProductionOrder, record.order_id)
        self.assertIsNotNone(order)

        response = self.client.get(
            "/api/v1/quality/defect-analysis",
            headers=self._headers(),
            params={
                "start_date": "2026-03-01",
                "end_date": "2026-03-03",
                "product_id": order.product_id,
            },
        )

        self.assertEqual(response.status_code, 200, response.text)
        payload = response.json()["data"]
        self.assertEqual(payload["total_defect_quantity"], 5)
        self.assertEqual(payload["top_defects"][0]["phenomenon"], "虚焊")
        self.assertEqual(payload["top_reasons"][0]["reason"], "治具偏移")
        self.assertEqual(payload["top_reasons"][0]["quantity"], 4)
        self.assertEqual(
            payload["product_quality_comparison"][0]["product_id"], order.product_id
        )
        self.assertEqual(
            payload["product_quality_comparison"][0]["first_article_total"],
            1,
        )
        self.assertEqual(
            payload["product_quality_comparison"][0]["repair_order_count"],
            1,
        )


if __name__ == "__main__":
    unittest.main()
