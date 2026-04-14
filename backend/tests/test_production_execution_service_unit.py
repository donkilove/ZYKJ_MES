import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.services import production_execution_service


class ProductionExecutionServiceUnitTest(unittest.TestCase):
    def test_get_today_verification_code_rejects_insecure_default_code(self) -> None:
        scalar_result = MagicMock()
        scalar_result.first.return_value = None
        execute_result = MagicMock()
        execute_result.scalars.return_value = scalar_result
        db = MagicMock()
        db.execute.return_value = execute_result

        with patch.object(
            production_execution_service.settings,
            "production_default_verification_code",
            "123456",
        ):
            with self.assertRaisesRegex(ValueError, "验证码"):
                production_execution_service._get_today_verification_code(
                    db,
                    operator_user_id=7,
                )

        db.add.assert_not_called()
        db.flush.assert_not_called()


if __name__ == "__main__":
    unittest.main()
