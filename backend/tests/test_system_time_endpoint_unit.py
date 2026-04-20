import sys
import unittest
from pathlib import Path

from fastapi.testclient import TestClient


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.main import app


class SystemTimeEndpointUnitTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.client = TestClient(app)

    def test_system_time_endpoint_returns_snapshot_without_auth(self) -> None:
        response = self.client.get("/api/v1/system/time")

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["code"], 0)
        self.assertEqual(payload["message"], "ok")

        data = payload["data"]
        self.assertTrue(data["server_utc_iso"].endswith("Z"))
        self.assertIsInstance(data["server_timezone_offset_minutes"], int)
        self.assertIsInstance(data["sampled_at_epoch_ms"], int)
        self.assertGreater(data["sampled_at_epoch_ms"], 0)


if __name__ == "__main__":
    unittest.main()
