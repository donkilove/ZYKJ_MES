import sys
import unittest
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = BACKEND_DIR.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

import start_backend


class StartBackendScriptUnitTest(unittest.TestCase):
    def test_build_command_uses_uvicorn_in_dev_mode(self) -> None:
        args = start_backend.argparse.Namespace(
            host="0.0.0.0",
            port=8000,
            reload=True,
            mode="dev",
            workers=4,
            skip_postgres_check=False,
        )

        command = start_backend.build_command(args)

        self.assertEqual(
            command,
            [
                start_backend.resolve_python(),
                "-m",
                "uvicorn",
                "app.main:app",
                "--host",
                "0.0.0.0",
                "--port",
                "8000",
                "--reload",
            ],
        )

    def test_build_command_uses_gunicorn_in_perf_mode(self) -> None:
        args = start_backend.argparse.Namespace(
            host="0.0.0.0",
            port=18081,
            reload=False,
            mode="perf",
            workers=4,
            skip_postgres_check=False,
        )

        command = start_backend.build_command(args)

        self.assertEqual(
            command,
            [
                start_backend.find_executable("gunicorn"),
                "app.main:app",
                "--worker-class",
                "uvicorn.workers.UvicornWorker",
                "--workers",
                "4",
                "--bind",
                "0.0.0.0:18081",
                "--timeout",
                "60",
                "--graceful-timeout",
                "20",
                "--access-logfile",
                "-",
                "--error-logfile",
                "-",
            ],
        )

    def test_build_subprocess_env_applies_perf_mode_overrides(self) -> None:
        env = {
            "NO_PROXY": "corp.local",
            "BOOTSTRAP_ON_STARTUP": "true",
            "WEB_RUN_BOOTSTRAP": "true",
            "WEB_RUN_BACKGROUND_LOOPS": "true",
            "MAINTENANCE_AUTO_GENERATE_ENABLED": "true",
            "MESSAGE_DELIVERY_MAINTENANCE_ENABLED": "true",
        }
        args = start_backend.argparse.Namespace(
            host="0.0.0.0",
            port=18081,
            reload=False,
            mode="perf",
            workers=4,
            skip_postgres_check=False,
        )

        merged = start_backend.build_subprocess_env(args, base_env=env)

        self.assertIn("corp.local", merged["NO_PROXY"])
        self.assertIn("127.0.0.1", merged["NO_PROXY"])
        self.assertEqual(merged["BOOTSTRAP_ON_STARTUP"], "false")
        self.assertEqual(merged["WEB_RUN_BOOTSTRAP"], "false")
        self.assertEqual(merged["WEB_RUN_BACKGROUND_LOOPS"], "false")
        self.assertEqual(merged["MAINTENANCE_AUTO_GENERATE_ENABLED"], "false")
        self.assertEqual(merged["MESSAGE_DELIVERY_MAINTENANCE_ENABLED"], "false")
        self.assertEqual(merged["UVICORN_RELOAD"], "false")
        self.assertEqual(merged["RELOAD"], "false")


if __name__ == "__main__":
    unittest.main()
