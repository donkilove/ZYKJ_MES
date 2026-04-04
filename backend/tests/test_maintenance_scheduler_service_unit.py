import sys
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch
from zoneinfo import ZoneInfoNotFoundError

BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.services import maintenance_scheduler_service


class MaintenanceSchedulerServiceUnitTest(unittest.TestCase):
    def test_resolve_timezone_falls_back_to_fixed_shanghai_offset_when_zoneinfo_missing(self) -> None:
        with (
            patch.object(
                maintenance_scheduler_service.settings,
                "maintenance_auto_generate_timezone",
                "Asia/Shanghai",
            ),
            patch.object(
                maintenance_scheduler_service,
                "ZoneInfo",
                side_effect=ZoneInfoNotFoundError("missing tzdata"),
            ),
        ):
            tz = maintenance_scheduler_service._resolve_timezone()

        self.assertEqual(tz.utcoffset(datetime.now(timezone.utc)), timedelta(hours=8))
        self.assertEqual(tz.tzname(None), "Asia/Shanghai")

    def test_resolve_timezone_falls_back_to_utc_without_zoneinfo_database(self) -> None:
        with (
            patch.object(
                maintenance_scheduler_service.settings,
                "maintenance_auto_generate_timezone",
                "UTC",
            ),
            patch.object(
                maintenance_scheduler_service,
                "ZoneInfo",
                side_effect=ZoneInfoNotFoundError("missing tzdata"),
            ),
        ):
            tz = maintenance_scheduler_service._resolve_timezone()

        self.assertIs(tz, timezone.utc)


if __name__ == "__main__":
    unittest.main()
