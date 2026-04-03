import base64
import sys
import time
import unittest
from datetime import UTC, date, datetime
from pathlib import Path
from unittest.mock import patch

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
from app.models.first_article_participant import FirstArticleParticipant  # noqa: E402
from app.models.first_article_record import FirstArticleRecord  # noqa: E402
from app.models.first_article_template import FirstArticleTemplate  # noqa: E402
from app.models.message import Message  # noqa: E402
from app.models.message_recipient import MessageRecipient  # noqa: E402
from app.models.process import Process  # noqa: E402
from app.models.process_stage import ProcessStage  # noqa: E402
from app.models.production_record import ProductionRecord  # noqa: E402
from app.models.production_scrap_statistics import ProductionScrapStatistics  # noqa: E402
from app.models.product import Product  # noqa: E402
from app.models.production_order import ProductionOrder  # noqa: E402
from app.models.production_order_process import ProductionOrderProcess  # noqa: E402
from app.models.repair_cause import RepairCause  # noqa: E402
from app.models.repair_defect_phenomenon import RepairDefectPhenomenon  # noqa: E402
from app.models.repair_order import RepairOrder  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services.production_repair_service import complete_repair_order  # noqa: E402
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
        self.scrap_statistics_ids: list[int] = []
        self.repair_defect_ids: list[int] = []
        self.repair_cause_ids: list[int] = []
        self.message_ids: list[int] = []
        self.user_ids: list[int] = []
        self.template_ids: list[int] = []
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
            for scrap_statistics_id in reversed(self.scrap_statistics_ids):
                row = self.db.get(ProductionScrapStatistics, scrap_statistics_id)
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
                self.db.query(FirstArticleParticipant).filter(
                    FirstArticleParticipant.record_id == record_id
                ).delete()
                record = self.db.get(FirstArticleRecord, record_id)
                if record is not None:
                    self.db.delete(record)
                self.db.commit()
            for template_id in reversed(self.template_ids):
                row = self.db.get(FirstArticleTemplate, template_id)
                if row is not None:
                    self.db.delete(row)
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
        order, order_process = self._create_order_context(token=token)
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

    def _create_order_context(
        self,
        *,
        token: str,
    ) -> tuple[ProductionOrder, ProductionOrderProcess]:
        stage = self._create_stage(token=token)
        process = self._create_process(stage=stage, token=token)
        product = self._create_product(token=token)
        order = self._create_order(product=product, token=token)
        order_process = self._create_order_process(
            order=order,
            process=process,
            stage=stage,
        )
        return order, order_process

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

    def _create_first_article_template(
        self,
        *,
        product: Product,
        process_code: str,
        token: str,
    ) -> FirstArticleTemplate:
        row = FirstArticleTemplate(
            product_id=product.id,
            process_code=process_code,
            template_name=f"品质首件模板-{token}",
            check_content=f"模板检验内容-{token}",
            test_value=f"模板测试值-{token}",
            is_enabled=True,
        )
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        self.template_ids.append(int(row.id))
        return row

    def _create_repair_order(
        self,
        *,
        record: FirstArticleRecord,
        repair_quantity: int = 5,
    ) -> RepairOrder:
        order = self.db.get(ProductionOrder, record.order_id)
        order_process = self.db.get(ProductionOrderProcess, record.order_process_id)
        self.assertIsNotNone(order)
        self.assertIsNotNone(order_process)
        return self._create_repair_order_for_context(
            order=order,
            order_process=order_process,
            repair_quantity=repair_quantity,
        )

    def _create_repair_order_for_context(
        self,
        *,
        order: ProductionOrder,
        order_process: ProductionOrderProcess,
        repair_quantity: int = 5,
    ) -> RepairOrder:
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
            repair_quantity=repair_quantity,
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

    def _create_scrap_statistics_for_context(
        self,
        *,
        order: ProductionOrder,
        order_process: ProductionOrderProcess,
        scrap_reason: str,
        scrap_quantity: int,
    ) -> ProductionScrapStatistics:
        row = ProductionScrapStatistics(
            order_id=order.id,
            order_code=order.order_code,
            product_id=order.product_id,
            product_name=order.product.name,
            process_id=order_process.id,
            process_code=order_process.process_code,
            process_name=order_process.process_name,
            operator_username=self.admin_user.username,
            scrap_reason=scrap_reason,
            scrap_quantity=scrap_quantity,
            last_scrap_time=datetime(2026, 3, 2, 9, 30, tzinfo=UTC),
            progress="pending_apply",
        )
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        self.scrap_statistics_ids.append(int(row.id))
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

    def _create_scrap_statistics(
        self,
        *,
        record: FirstArticleRecord,
        scrap_reason: str,
        scrap_quantity: int,
    ) -> ProductionScrapStatistics:
        order = self.db.get(ProductionOrder, record.order_id)
        order_process = self.db.get(ProductionOrderProcess, record.order_process_id)
        self.assertIsNotNone(order)
        self.assertIsNotNone(order_process)
        row = ProductionScrapStatistics(
            order_id=order.id,
            order_code=order.order_code,
            product_id=order.product_id,
            product_name=order.product.name,
            process_id=order_process.id,
            process_code=order_process.process_code,
            process_name=order_process.process_name,
            operator_username=self.admin_user.username,
            scrap_reason=scrap_reason,
            scrap_quantity=scrap_quantity,
            last_scrap_time=datetime(2026, 3, 2, 9, 30, tzinfo=UTC),
            progress="pending_apply",
        )
        self.db.add(row)
        self.db.commit()
        self.db.refresh(row)
        self.scrap_statistics_ids.append(int(row.id))
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

    def test_first_article_detail_includes_rich_fields(self) -> None:
        record = self._create_first_article_record(result="failed")
        order = self.db.get(ProductionOrder, record.order_id)
        order_process = self.db.get(ProductionOrderProcess, record.order_process_id)
        self.assertIsNotNone(order)
        self.assertIsNotNone(order_process)
        assert order is not None and order_process is not None

        template = self._create_first_article_template(
            product=order.product,
            process_code=order_process.process_code,
            token=f"{self._suffix}-template",
        )
        participant = self._create_operator_user(token=f"{self._suffix}-participant")

        record.template_id = template.id
        record.check_content = "首件内容-品质详情"
        record.test_value = "首件测试值-品质详情"
        self.db.add(FirstArticleParticipant(record_id=record.id, user_id=participant.id))
        self.db.commit()

        detail = get_first_article_by_id(self.db, record_id=record.id)
        assert detail is not None
        self.assertEqual(detail["template_id"], template.id)
        self.assertEqual(detail["template_name"], template.template_name)
        self.assertEqual(detail["check_content"], "首件内容-品质详情")
        self.assertEqual(detail["test_value"], "首件测试值-品质详情")
        self.assertEqual(len(detail["participants"]), 1)
        self.assertEqual(detail["participants"][0]["user_id"], participant.id)

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
            payload["product_quality_comparison"][0]["repair_total"],
            1,
        )

    def test_quality_scrap_and_repair_contracts_are_available(self) -> None:
        record = self._create_first_article_record(result="failed")
        repair_order = self._create_repair_order(record=record)
        scrap = self._create_scrap_statistics(
            record=record,
            scrap_reason="焊点脱落",
            scrap_quantity=2,
        )
        defect_row = self._create_repair_defect(
            repair_order=repair_order,
            phenomenon="虚焊",
            quantity=2,
        )
        production_record = ProductionRecord(
            order_id=record.order_id,
            order_process_id=record.order_process_id,
            sub_order_id=None,
            operator_user_id=self.admin_user.id,
            production_quantity=8,
            record_type="production",
        )
        self.db.add(production_record)
        self.db.commit()
        self.db.refresh(production_record)
        defect_row.production_record_id = production_record.id
        defect_row.production_time = datetime(2026, 3, 2, 8, 45, tzinfo=UTC)
        self.db.commit()

        scrap_list_response = self.client.get(
            "/api/v1/quality/scrap-statistics",
            headers=self._headers(),
            params={"keyword": record.order.order_code},
        )
        self.assertEqual(scrap_list_response.status_code, 200, scrap_list_response.text)
        scrap_list_payload = scrap_list_response.json()["data"]
        self.assertEqual(scrap_list_payload["total"], 1)
        self.assertEqual(scrap_list_payload["items"][0]["id"], scrap.id)

        scrap_detail_response = self.client.get(
            f"/api/v1/quality/scrap-statistics/{scrap.id}",
            headers=self._headers(),
        )
        self.assertEqual(
            scrap_detail_response.status_code,
            200,
            scrap_detail_response.text,
        )
        scrap_detail_payload = scrap_detail_response.json()["data"]
        self.assertEqual(scrap_detail_payload["scrap_reason"], "焊点脱落")
        self.assertEqual(scrap_detail_payload["applied_at"], None)
        self.assertEqual(
            scrap_detail_payload["related_repair_orders"][0]["repair_order_code"],
            repair_order.repair_order_code,
        )

        repair_list_response = self.client.get(
            "/api/v1/quality/repair-orders",
            headers=self._headers(),
            params={"keyword": repair_order.repair_order_code},
        )
        self.assertEqual(
            repair_list_response.status_code, 200, repair_list_response.text
        )
        repair_list_payload = repair_list_response.json()["data"]
        self.assertEqual(repair_list_payload["total"], 1)
        self.assertEqual(
            repair_list_payload["items"][0]["repair_order_code"],
            repair_order.repair_order_code,
        )

        repair_detail_response = self.client.get(
            f"/api/v1/quality/repair-orders/{repair_order.id}/detail",
            headers=self._headers(),
        )
        self.assertEqual(
            repair_detail_response.status_code,
            200,
            repair_detail_response.text,
        )
        repair_detail_payload = repair_detail_response.json()["data"]
        self.assertEqual(
            repair_detail_payload["repair_order_code"], repair_order.repair_order_code
        )
        self.assertEqual(repair_detail_payload["defect_rows"][0]["phenomenon"], "虚焊")
        self.assertEqual(
            repair_detail_payload["defect_rows"][0]["production_record_id"],
            production_record.id,
        )
        self.assertEqual(
            repair_detail_payload["defect_rows"][0]["production_record_quantity"],
            8,
        )

    def test_quality_stats_do_not_drop_repair_and_scrap_without_first_article(self) -> None:
        token = f"{self._suffix}-scope"
        order, order_process = self._create_order_context(token=token)
        operator_user = self._create_operator_user(token=f"{token}-worker")
        repair_order = self._create_repair_order_for_context(
            order=order,
            order_process=order_process,
            repair_quantity=2,
        )
        repair_order.sender_user_id = operator_user.id
        repair_order.sender_username = operator_user.username
        self.db.commit()
        defect_row = self._create_repair_defect(
            repair_order=repair_order,
            phenomenon="虚焊",
            quantity=2,
        )
        defect_row.operator_user_id = operator_user.id
        defect_row.operator_username = operator_user.username
        production_record = ProductionRecord(
            order_id=order.id,
            order_process_id=order_process.id,
            sub_order_id=None,
            operator_user_id=self.admin_user.id,
            production_quantity=8,
            record_type="production",
        )
        self.db.add(production_record)
        self.db.commit()
        self.db.refresh(production_record)
        defect_row.production_record_id = production_record.id
        defect_row.production_time = datetime(2026, 3, 2, 8, 45, tzinfo=UTC)
        self.db.commit()
        scrap_row = self._create_scrap_statistics_for_context(
            order=order,
            order_process=order_process,
            scrap_reason="焊点脱落",
            scrap_quantity=2,
        )
        scrap_row.operator_user_id = operator_user.id
        scrap_row.operator_username = operator_user.username
        self.db.commit()

        overview_response = self.client.get(
            "/api/v1/quality/stats/overview",
            headers=self._headers(),
            params={"start_date": "2026-03-01", "end_date": "2026-03-03"},
        )
        self.assertEqual(overview_response.status_code, 200, overview_response.text)
        overview_payload = overview_response.json()["data"]
        self.assertEqual(overview_payload["first_article_total"], 0)
        self.assertEqual(overview_payload["defect_total"], 2)
        self.assertEqual(overview_payload["scrap_total"], 2)
        self.assertEqual(overview_payload["repair_total"], 1)
        self.assertEqual(overview_payload["covered_order_count"], 1)
        self.assertEqual(overview_payload["covered_process_count"], 1)
        self.assertEqual(overview_payload["covered_operator_count"], 1)

        process_response = self.client.get(
            "/api/v1/quality/stats/processes",
            headers=self._headers(),
            params={"start_date": "2026-03-01", "end_date": "2026-03-03"},
        )
        self.assertEqual(process_response.status_code, 200, process_response.text)
        process_item = next(
            item
            for item in process_response.json()["data"]["items"]
            if item["process_code"] == order_process.process_code
        )
        self.assertEqual(process_item["first_article_total"], 0)
        self.assertEqual(process_item["process_name"], order_process.process_name)
        self.assertEqual(process_item["defect_total"], 2)
        self.assertEqual(process_item["scrap_total"], 2)
        self.assertEqual(process_item["repair_total"], 1)

        operator_response = self.client.get(
            "/api/v1/quality/stats/operators",
            headers=self._headers(),
            params={"start_date": "2026-03-01", "end_date": "2026-03-03"},
        )
        self.assertEqual(operator_response.status_code, 200, operator_response.text)
        operator_item = next(
            item
            for item in operator_response.json()["data"]["items"]
            if item["operator_username"] == operator_user.username
        )
        self.assertEqual(operator_item["operator_user_id"], operator_user.id)
        self.assertEqual(operator_item["first_article_total"], 0)
        self.assertEqual(operator_item["defect_total"], 2)
        self.assertEqual(operator_item["scrap_total"], 2)
        self.assertEqual(operator_item["repair_total"], 1)

        products_response = self.client.get(
            "/api/v1/quality/stats/products",
            headers=self._headers(),
            params={"start_date": "2026-03-01", "end_date": "2026-03-03"},
        )
        self.assertEqual(products_response.status_code, 200, products_response.text)
        product_item = products_response.json()["data"]["items"][0]
        self.assertEqual(product_item["product_id"], order.product_id)
        self.assertEqual(product_item["first_article_total"], 0)
        self.assertEqual(product_item["defect_total"], 2)
        self.assertEqual(product_item["scrap_total"], 2)
        self.assertEqual(product_item["repair_total"], 1)

        trend_response = self.client.get(
            "/api/v1/quality/trend",
            headers=self._headers(),
            params={"start_date": "2026-03-01", "end_date": "2026-03-03"},
        )
        self.assertEqual(trend_response.status_code, 200, trend_response.text)
        trend_items = trend_response.json()["data"]["items"]
        matched = next(item for item in trend_items if item["stat_date"] == "2026-03-02")
        self.assertEqual(matched["first_article_total"], 0)
        self.assertEqual(matched["defect_total"], 2)
        self.assertEqual(matched["scrap_total"], 2)
        self.assertEqual(matched["repair_total"], 1)

    def test_quality_repair_complete_and_export_contracts_are_available(self) -> None:
        record = self._create_first_article_record(result="failed")
        repair_order = self._create_repair_order(record=record)
        repair_order.sender_user_id = None
        repair_order.sender_username = None
        self.db.commit()
        self._create_repair_defect(
            repair_order=repair_order,
            phenomenon="虚焊",
            quantity=5,
        )

        summary_response = self.client.get(
            f"/api/v1/quality/repair-orders/{repair_order.id}/phenomena-summary",
            headers=self._headers(),
        )
        self.assertEqual(summary_response.status_code, 200, summary_response.text)
        self.assertEqual(summary_response.json()["data"]["items"][0]["quantity"], 5)

        export_scrap_response = self.client.post(
            "/api/v1/quality/scrap-statistics/export",
            headers=self._headers(),
            json={"keyword": record.order.order_code},
        )
        self.assertEqual(
            export_scrap_response.status_code,
            200,
            export_scrap_response.text,
        )

        complete_response = self.client.post(
            f"/api/v1/quality/repair-orders/{repair_order.id}/complete",
            headers=self._headers(),
            json={
                "cause_items": [
                    {
                        "phenomenon": "虚焊",
                        "reason": "治具偏移",
                        "quantity": 5,
                        "is_scrap": False,
                    }
                ],
                "scrap_replenished": False,
                "return_allocations": [
                    {
                        "target_order_process_id": record.order_process_id,
                        "quantity": 5,
                    }
                ],
            },
        )
        self.assertEqual(complete_response.status_code, 200, complete_response.text)
        self.assertEqual(complete_response.json()["data"]["status"], "completed")

        export_repair_response = self.client.post(
            "/api/v1/quality/repair-orders/export",
            headers=self._headers(),
            json={"keyword": repair_order.repair_order_code},
        )
        self.assertEqual(
            export_repair_response.status_code,
            200,
            export_repair_response.text,
        )

    def test_repair_completion_message_jumps_to_quality_tab(self) -> None:
        record = self._create_first_article_record(result="failed")
        repair_order = self._create_repair_order(record=record)

        with patch(
            "app.services.production_repair_service.create_message_for_users"
        ) as mocked_create_message:
            complete_repair_order(
                self.db,
                repair_order_id=repair_order.id,
                cause_items=[
                    {
                        "phenomenon": "虚焊",
                        "reason": "治具偏移",
                        "quantity": 5,
                        "is_scrap": False,
                    }
                ],
                scrap_replenished=False,
                return_allocations=[
                    {
                        "target_order_process_id": record.order_process_id,
                        "quantity": 5,
                    }
                ],
                operator=self.admin_user,
            )

        mocked_create_message.assert_called_once()
        self.assertEqual(
            mocked_create_message.call_args.kwargs["target_page_code"],
            "quality",
        )
        self.assertEqual(
            mocked_create_message.call_args.kwargs["target_tab_code"],
            "quality_repair_orders",
        )
        self.assertEqual(
            mocked_create_message.call_args.kwargs["source_module"],
            "quality",
        )

    def test_quality_repair_completion_closes_pending_scrap_to_applied(self) -> None:
        record = self._create_first_article_record(result="failed")
        repair_order = self._create_repair_order(record=record, repair_quantity=2)
        scrap_row = self._create_scrap_statistics(
            record=record,
            scrap_reason="治具偏移",
            scrap_quantity=1,
        )

        with patch("app.services.production_repair_service.create_message_for_users"):
            response = self.client.post(
                f"/api/v1/quality/repair-orders/{repair_order.id}/complete",
                headers=self._headers(),
                json={
                    "cause_items": [
                        {
                            "phenomenon": "虚焊",
                            "reason": "治具偏移",
                            "quantity": 2,
                            "is_scrap": True,
                        }
                    ],
                    "scrap_replenished": False,
                    "return_allocations": [],
                },
            )
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()["data"]["status"], "completed")

        self.db.refresh(scrap_row)
        self.assertEqual(scrap_row.progress, "applied")
        self.assertIsNotNone(scrap_row.applied_at)

        detail_response = self.client.get(
            f"/api/v1/quality/scrap-statistics/{scrap_row.id}",
            headers=self._headers(),
        )
        self.assertEqual(detail_response.status_code, 200, detail_response.text)
        detail_payload = detail_response.json()["data"]
        self.assertEqual(detail_payload["progress"], "applied")
        self.assertIsNotNone(detail_payload["applied_at"])


if __name__ == "__main__":
    unittest.main()
