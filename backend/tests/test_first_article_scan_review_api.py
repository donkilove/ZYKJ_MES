import sys
import time
import unittest
from datetime import date
from pathlib import Path
from urllib.parse import parse_qs, urlparse
from unittest.mock import patch

from fastapi.testclient import TestClient


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.config import settings  # noqa: E402
from app.core.security import get_password_hash  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.main import app  # noqa: E402
from app.models.daily_verification_code import DailyVerificationCode  # noqa: E402
from app.models.first_article_record import FirstArticleRecord  # noqa: E402
from app.models.first_article_review_session import (  # noqa: E402
    FirstArticleReviewSession,
)
from app.models.first_article_template import FirstArticleTemplate  # noqa: E402
from app.models.process import Process  # noqa: E402
from app.models.process_stage import ProcessStage  # noqa: E402
from app.models.production_order import ProductionOrder  # noqa: E402
from app.models.production_order_process import ProductionOrderProcess  # noqa: E402
from app.models.production_sub_order import ProductionSubOrder  # noqa: E402
from app.models.product import Product  # noqa: E402
from app.models.role import Role  # noqa: E402
from app.models.supplier import Supplier  # noqa: E402
from app.models.user import User  # noqa: E402
from app.services.bootstrap_seed_service import seed_initial_data  # noqa: E402


class FirstArticleScanReviewApiTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)

    def setUp(self) -> None:
        self._previous_jwt_secret_key = settings.jwt_secret_key
        settings.jwt_secret_key = "first-article-scan-review-test-secret"
        self._ensure_admin()
        self.token = self._login("admin")
        self.stage_ids: list[int] = []
        self.process_ids: list[int] = []
        self.product_ids: list[int] = []
        self.supplier_ids: list[int] = []
        self.order_ids: list[int] = []
        self.user_ids: list[int] = []

    def tearDown(self) -> None:
        settings.jwt_secret_key = self._previous_jwt_secret_key
        db = SessionLocal()
        try:
            for order_id in reversed(self.order_ids):
                row = db.get(ProductionOrder, order_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
            for user_id in reversed(self.user_ids):
                row = db.get(User, user_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
            for supplier_id in reversed(self.supplier_ids):
                row = db.get(Supplier, supplier_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
            for product_id in reversed(self.product_ids):
                row = db.get(Product, product_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
            for process_id in reversed(self.process_ids):
                row = db.get(Process, process_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
            for stage_id in reversed(self.stage_ids):
                row = db.get(ProcessStage, stage_id)
                if row is not None:
                    db.delete(row)
                    db.commit()
        finally:
            db.close()

    def _headers(self, token: str | None = None) -> dict[str, str]:
        return {"Authorization": f"Bearer {token or self.token}"}

    def _ensure_admin(self) -> None:
        db = SessionLocal()
        try:
            seed_initial_data(
                db,
                admin_username="admin",
                admin_password="Admin@123456",
            )
        finally:
            db.close()

    def _login(self, username: str, password: str = "Admin@123456") -> str:
        return self._login_with_client(self.client, username, password)

    def _login_with_client(
        self,
        client: TestClient,
        username: str,
        password: str = "Admin@123456",
    ) -> str:
        response = client.post(
            "/api/v1/auth/login",
            data={"username": username, "password": password},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["data"]["access_token"]

    def _create_stage(self, suffix: str) -> dict:
        unique = f"FA-SCAN-ST-{suffix}-{int(time.time() * 1000)}"
        response = self.client.post(
            "/api/v1/craft/stages",
            headers=self._headers(),
            json={
                "code": unique,
                "name": unique,
                "sort_order": 0,
                "remark": "首件扫码复核测试",
            },
        )
        self.assertEqual(response.status_code, 201, response.text)
        row = response.json()["data"]
        self.stage_ids.append(int(row["id"]))
        return row

    def _create_process(self, *, stage_id: int, stage_code: str, suffix: str) -> dict:
        unique = f"{stage_code}-01"
        response = self.client.post(
            "/api/v1/craft/processes",
            headers=self._headers(),
            json={
                "code": unique,
                "name": unique,
                "stage_id": stage_id,
                "remark": "首件扫码复核测试",
            },
        )
        self.assertEqual(response.status_code, 201, response.text)
        row = response.json()["data"]
        self.process_ids.append(int(row["id"]))
        return row

    def _create_product(self, suffix: str) -> dict:
        unique = f"扫码首件产品{suffix}{int(time.time() * 1000)}"
        response = self.client.post(
            "/api/v1/products",
            headers=self._headers(),
            json={"name": unique, "category": "贴片", "remark": "首件扫码复核测试"},
        )
        self.assertEqual(response.status_code, 201, response.text)
        row = response.json()["data"]
        self.product_ids.append(int(row["id"]))
        return row

    def _activate_product(self, product: dict) -> None:
        version = int(product.get("current_version", 1))
        expected_effective_version = int(product.get("effective_version", 0) or 0)
        with patch("app.api.v1.endpoints.products.create_message_for_users"):
            response = self.client.post(
                f"/api/v1/products/{product['id']}/versions/{version}/activate",
                headers=self._headers(),
                json={
                    "confirmed": True,
                    "expected_effective_version": expected_effective_version,
                },
            )
        self.assertEqual(response.status_code, 200, response.text)

    def _create_supplier(self, name: str) -> dict:
        response = self.client.post(
            "/api/v1/quality/suppliers",
            headers=self._headers(),
            json={"name": name, "remark": "首件扫码复核测试", "is_enabled": True},
        )
        self.assertEqual(response.status_code, 201, response.text)
        row = response.json()["data"]
        self.supplier_ids.append(int(row["id"]))
        return row

    def _create_order(self, *, product_id: int, stage_id: int, process_id: int) -> dict:
        order_code = f"PO-SCAN-{int(time.time() * 1000)}"
        supplier = self._create_supplier(f"扫码首件供应商{order_code[-6:]}")
        with patch("app.services.production_order_service.create_message_for_users"):
            response = self.client.post(
                "/api/v1/production/orders",
                headers=self._headers(),
                json={
                    "order_code": order_code,
                    "product_id": product_id,
                    "supplier_id": supplier["id"],
                    "quantity": 10,
                    "process_steps": [
                        {
                            "step_order": 1,
                            "stage_id": stage_id,
                            "process_id": process_id,
                        }
                    ],
                },
            )
        self.assertEqual(response.status_code, 201, response.text)
        row = response.json()["data"]
        self.order_ids.append(int(row["id"]))
        return row

    def _create_context(self, suffix: str = "A") -> dict[str, int | str]:
        stage = self._create_stage(suffix)
        process = self._create_process(
            stage_id=int(stage["id"]),
            stage_code=str(stage["code"]),
            suffix=suffix,
        )
        product = self._create_product(suffix)
        self._activate_product(product)
        order = self._create_order(
            product_id=int(product["id"]),
            stage_id=int(stage["id"]),
            process_id=int(process["id"]),
        )

        db = SessionLocal()
        try:
            order_row = db.get(ProductionOrder, int(order["id"]))
            admin = db.query(User).filter(User.username == "admin").first()
            assert order_row is not None and admin is not None
            process_row = (
                db.query(ProductionOrderProcess)
                .filter(ProductionOrderProcess.order_id == order_row.id)
                .first()
            )
            assert process_row is not None
            process_row.visible_quantity = order_row.quantity
            order_row.current_process_code = process_row.process_code
            today_code = (
                db.query(DailyVerificationCode)
                .filter(DailyVerificationCode.verify_date == date.today())
                .first()
            )
            if today_code is None:
                db.add(
                    DailyVerificationCode(
                        verify_date=date.today(),
                        code="legacy-code",
                        created_by_user_id=admin.id,
                    )
                )
            template = FirstArticleTemplate(
                product_id=order_row.product_id,
                process_code=process_row.process_code,
                template_name=f"扫码首件模板-{suffix}",
                check_content="模板检验内容",
                test_value="模板检验值",
                is_enabled=True,
            )
            sub_order = ProductionSubOrder(
                order_process_id=process_row.id,
                operator_user_id=admin.id,
                completed_quantity=0,
                status="pending",
            )
            db.add(template)
            db.add(sub_order)
            db.commit()
            db.refresh(template)
            return {
                "order_id": order_row.id,
                "order_code": order_row.order_code,
                "order_process_id": process_row.id,
                "template_id": template.id,
            }
        finally:
            db.close()

    def _extract_token(self, review_url: str) -> str:
        parsed = urlparse(review_url)
        token = parse_qs(parsed.query).get("token", [""])[0]
        self.assertGreater(len(token), 16)
        return token

    def test_scan_review_approval_creates_reviewed_first_article(self) -> None:
        context = self._create_context("PASS")

        create_response = self.client.post(
            f"/api/v1/production/orders/{context['order_id']}/first-article/review-sessions",
            headers=self._headers(),
            json={
                "order_process_id": context["order_process_id"],
                "template_id": context["template_id"],
                "check_content": "外观无划伤",
                "test_value": "长度 10.01",
                "participant_user_ids": [],
            },
        )

        self.assertEqual(create_response.status_code, 201, create_response.text)
        create_data = create_response.json()["data"]
        token = self._extract_token(create_data["review_url"])
        db = SessionLocal()
        try:
            session = db.get(FirstArticleReviewSession, int(create_data["session_id"]))
            assert session is not None
            self.assertNotEqual(session.token_hash, token)
            self.assertEqual(session.status, "pending")
        finally:
            db.close()

    def test_new_review_session_cancels_expired_session_for_same_operator_and_process(
        self,
    ) -> None:
        context = self._create_context("EXPIRE")

        create_response = self.client.post(
            f"/api/v1/production/orders/{context['order_id']}/first-article/review-sessions",
            headers=self._headers(),
            json={
                "order_process_id": context["order_process_id"],
                "template_id": context["template_id"],
                "check_content": "首轮检验内容",
                "test_value": "首轮检验值",
                "participant_user_ids": [],
            },
        )
        self.assertEqual(create_response.status_code, 201, create_response.text)
        session_id = int(create_response.json()["data"]["session_id"])

        db = SessionLocal()
        try:
            row = db.get(FirstArticleReviewSession, session_id)
            assert row is not None
            row.status = "expired"
            db.commit()
        finally:
            db.close()

        recreate_response = self.client.post(
            f"/api/v1/production/orders/{context['order_id']}/first-article/review-sessions",
            headers=self._headers(),
            json={
                "order_process_id": context["order_process_id"],
                "template_id": context["template_id"],
                "check_content": "二轮检验内容",
                "test_value": "二轮检验值",
                "participant_user_ids": [],
            },
        )
        self.assertEqual(recreate_response.status_code, 201, recreate_response.text)

        db = SessionLocal()
        try:
            old_row = db.get(FirstArticleReviewSession, session_id)
            assert old_row is not None
            self.assertEqual(old_row.status, "cancelled")
        finally:
            db.close()

    def test_scan_review_returns_backend_absolute_url_and_page_is_served(self) -> None:
        context = self._create_context("PAGE")

        with TestClient(app, base_url="http://192.168.10.5:8000") as client:
            token = self._login_with_client(client, "admin")
            create_response = client.post(
                f"/api/v1/production/orders/{context['order_id']}/first-article/review-sessions",
                headers={"Authorization": f"Bearer {token}"},
                json={
                    "order_process_id": context["order_process_id"],
                    "template_id": context["template_id"],
                    "check_content": "外观无划伤",
                    "test_value": "长度 10.01",
                    "participant_user_ids": [],
                },
            )

            self.assertEqual(create_response.status_code, 201, create_response.text)
            review_url = create_response.json()["data"]["review_url"]
            self.assertEqual(
                review_url.split("?token=")[0],
                "http://192.168.10.5:8000/first-article-review",
            )

            page_response = client.get(review_url)
            self.assertEqual(page_response.status_code, 200, page_response.text)
            self.assertIn("首件扫码复核", page_response.text)
            self.assertIn("/api/v1/auth/login", page_response.text)

    def test_scan_review_rejects_and_refresh_invalidates_old_token(self) -> None:
        context = self._create_context("FAIL")
        create_response = self.client.post(
            f"/api/v1/production/orders/{context['order_id']}/first-article/review-sessions",
            headers=self._headers(),
            json={
                "order_process_id": context["order_process_id"],
                "template_id": context["template_id"],
                "check_content": "外观待复核",
                "test_value": "长度 9.90",
                "participant_user_ids": [],
            },
        )
        self.assertEqual(create_response.status_code, 201, create_response.text)
        create_data = create_response.json()["data"]
        old_token = self._extract_token(create_data["review_url"])

        reject_response = self.client.post(
            "/api/v1/production/first-article/review-sessions/submit",
            headers=self._headers(),
            json={
                "token": old_token,
                "review_result": "failed",
                "review_remark": "尺寸偏小",
            },
        )
        self.assertEqual(reject_response.status_code, 200, reject_response.text)
        reject_data = reject_response.json()["data"]
        self.assertEqual(reject_data["status"], "rejected")
        self.assertIsNone(reject_data["first_article_record_id"])

        refresh_response = self.client.post(
            f"/api/v1/production/orders/{context['order_id']}/first-article/review-sessions/{create_data['session_id']}/refresh",
            headers=self._headers(),
            json={
                "check_content": "外观复检",
                "test_value": "长度 10.00",
                "participant_user_ids": [],
            },
        )
        self.assertEqual(refresh_response.status_code, 200, refresh_response.text)
        new_token = self._extract_token(refresh_response.json()["data"]["review_url"])
        self.assertNotEqual(new_token, old_token)

        old_detail_response = self.client.get(
            "/api/v1/production/first-article/review-sessions/detail",
            headers=self._headers(),
            params={"token": old_token},
        )
        self.assertEqual(old_detail_response.status_code, 404, old_detail_response.text)

        new_detail_response = self.client.get(
            "/api/v1/production/first-article/review-sessions/detail",
            headers=self._headers(),
            params={"token": new_token},
        )
        self.assertEqual(new_detail_response.status_code, 200, new_detail_response.text)
        self.assertEqual(
            new_detail_response.json()["data"]["test_value"],
            "长度 10.00",
        )

    def test_submit_scan_review_requires_quality_permission(self) -> None:
        context = self._create_context("AUTH")
        create_response = self.client.post(
            f"/api/v1/production/orders/{context['order_id']}/first-article/review-sessions",
            headers=self._headers(),
            json={
                "order_process_id": context["order_process_id"],
                "template_id": context["template_id"],
                "check_content": "外观无划伤",
                "test_value": "长度 10.01",
                "participant_user_ids": [],
            },
        )
        self.assertEqual(create_response.status_code, 201, create_response.text)
        token = self._extract_token(create_response.json()["data"]["review_url"])

        db = SessionLocal()
        try:
            user = User(
                username=f"scan_no_perm_{int(time.time() * 1000)}",
                full_name="无复核权限",
                password_hash=get_password_hash("Admin@123456"),
                is_active=True,
                is_superuser=False,
                remark="首件扫码复核测试",
            )
            db.add(user)
            db.commit()
            db.refresh(user)
            self.user_ids.append(int(user.id))
            username = user.username
        finally:
            db.close()
        token_without_permission = self._login(username)

        submit_response = self.client.post(
            "/api/v1/production/first-article/review-sessions/submit",
            headers=self._headers(token_without_permission),
            json={
                "token": token,
                "review_result": "passed",
                "review_remark": "参数一致",
            },
        )

        self.assertEqual(submit_response.status_code, 403, submit_response.text)


if __name__ == "__main__":
    unittest.main()
