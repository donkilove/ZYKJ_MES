import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.services import user_export_task_service


class UserExportTaskServiceUnitTest(unittest.TestCase):
    def setUp(self) -> None:
        user_export_task_service._USER_EXPORT_TASK_CLEANUP_NEXT_AT = 0.0

    @staticmethod
    def test_cleanup_user_export_tasks_throttles_repeated_calls() -> None:
        db = MagicMock()

        with (
            patch.object(
                user_export_task_service.time, "monotonic", side_effect=[10.0, 15.0]
            ),
            patch.object(
                user_export_task_service, "_run_cleanup_user_export_tasks"
            ) as run_cleanup,
        ):
            user_export_task_service.cleanup_user_export_tasks(
                db,
                min_interval_seconds=30,
            )
            user_export_task_service.cleanup_user_export_tasks(
                db,
                min_interval_seconds=30,
            )

        run_cleanup.assert_called_once_with(db)

    def test_cleanup_user_export_tasks_resets_window_after_failure(self) -> None:
        db = MagicMock()

        with (
            patch.object(
                user_export_task_service.time,
                "monotonic",
                side_effect=[10.0, 11.0],
            ),
            patch.object(
                user_export_task_service,
                "_run_cleanup_user_export_tasks",
                side_effect=[RuntimeError("boom"), None],
            ) as run_cleanup,
        ):
            with self.assertRaises(RuntimeError):
                user_export_task_service.cleanup_user_export_tasks(
                    db,
                    min_interval_seconds=30,
                )
            user_export_task_service.cleanup_user_export_tasks(
                db,
                min_interval_seconds=30,
            )

        self.assertEqual(run_cleanup.call_count, 2)


if __name__ == "__main__":
    unittest.main()
