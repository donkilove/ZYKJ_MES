import asyncio
import sys
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app import main as app_main
from app import worker_main


class AppStartupWorkerSplitUnitTest(unittest.TestCase):
    def test_web_lifespan_skips_bootstrap_and_background_loops_when_disabled(self) -> None:
        async def run_case() -> None:
            maintenance_mock = AsyncMock()
            message_mock = AsyncMock()
            with (
                patch.object(app_main.settings, "web_run_bootstrap", False),
                patch.object(app_main.settings, "web_run_background_loops", False),
                patch.object(app_main, "run_startup_bootstrap") as bootstrap_mock,
                patch.object(
                    app_main,
                    "run_maintenance_auto_generate_loop",
                    maintenance_mock,
                ),
                patch.object(
                    app_main,
                    "run_message_delivery_maintenance_loop",
                    message_mock,
                ),
            ):
                async with app_main.lifespan(app_main.app):
                    pass
            bootstrap_mock.assert_not_called()
            maintenance_mock.assert_not_awaited()
            message_mock.assert_not_awaited()

        asyncio.run(run_case())

    def test_worker_runs_bootstrap_and_background_loops_when_enabled(self) -> None:
        async def run_case() -> None:
            maintenance_started = asyncio.Event()
            message_started = asyncio.Event()
            stop_event = asyncio.Event()

            async def fake_maintenance_loop() -> None:
                maintenance_started.set()
                await stop_event.wait()

            async def fake_message_loop() -> None:
                message_started.set()
                await stop_event.wait()

            with (
                patch.object(worker_main.settings, "worker_run_bootstrap", True),
                patch.object(worker_main.settings, "worker_run_background_loops", True),
                patch.object(
                    worker_main.settings,
                    "maintenance_auto_generate_enabled",
                    True,
                ),
                patch.object(
                    worker_main.settings,
                    "message_delivery_maintenance_enabled",
                    True,
                ),
                patch.object(worker_main, "run_startup_bootstrap") as bootstrap_mock,
                patch.object(
                    worker_main,
                    "run_maintenance_auto_generate_loop",
                    new=fake_maintenance_loop,
                ),
                patch.object(
                    worker_main,
                    "run_message_delivery_maintenance_loop",
                    new=fake_message_loop,
                ),
            ):
                task = asyncio.create_task(worker_main.run_worker())
                await asyncio.wait_for(maintenance_started.wait(), timeout=1)
                await asyncio.wait_for(message_started.wait(), timeout=1)
                stop_event.set()
                await asyncio.wait_for(task, timeout=1)
            bootstrap_mock.assert_called_once()

        asyncio.run(run_case())


if __name__ == "__main__":
    unittest.main()
