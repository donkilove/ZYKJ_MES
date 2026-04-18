import sys
import unittest
from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import select


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.db.session import SessionLocal  # noqa: E402
from app.core.config import settings  # noqa: E402
from app.main import app  # noqa: E402
from app.models.production_order import ProductionOrder  # noqa: E402
from app.services.bootstrap_seed_service import seed_initial_data  # noqa: E402
from app.services.perf_sample_seed_service import seed_production_craft_samples  # noqa: E402


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


class PerfProductionCraftSamplesIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)

    def setUp(self) -> None:
        _cleanup_runtime_orders()
        self._ensure_admin()
        self._previous_jwt_secret_key = settings.jwt_secret_key
        settings.jwt_secret_key = "perf-sample-test-secret"
        self.token = self._login()

    def tearDown(self) -> None:
        settings.jwt_secret_key = self._previous_jwt_secret_key
        _cleanup_runtime_orders()

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

    def _login(self) -> str:
        response = self.client.post(
            "/api/v1/auth/login",
            data={"username": "admin", "password": "Admin@123456"},
        )
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()["data"]["access_token"]

    def _headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self.token}"}

    def test_seeded_samples_support_production_and_craft_smoke_queries(self) -> None:
        db = SessionLocal()
        try:
            context = seed_production_craft_samples(db, run_id="baseline").context
        finally:
            db.close()

        production_response = self.client.get(
            f"/api/v1/production/orders/{context['production_order_id']}",
            headers=self._headers(),
        )
        craft_response = self.client.get(
            f"/api/v1/craft/templates/{context['craft_template_id']}",
            headers=self._headers(),
        )

        self.assertEqual(production_response.status_code, 200, production_response.text)
        self.assertEqual(craft_response.status_code, 200, craft_response.text)


if __name__ == "__main__":
    unittest.main()
