import sys
import unittest
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = BACKEND_DIR.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

import start_backend


class StartBackendScriptUnitTest(unittest.TestCase):
    def test_parse_args_defaults_to_up_and_db_hidden(self) -> None:
        args = start_backend.parse_args([])

        self.assertEqual(args.action, "up")
        self.assertFalse(args.expose_db)
        self.assertEqual(args.db_port, 5433)

    def test_build_db_expose_override_contains_requested_loopback_port(self) -> None:
        args = start_backend.parse_args(["--expose-db", "--db-port", "55433"])

        override = start_backend.build_db_expose_override(args)

        self.assertIn("127.0.0.1:55433:5432", override)

    def test_build_compose_command_logs_defaults_to_web_and_worker(self) -> None:
        command = start_backend.build_compose_command(
            action="logs",
            services=None,
            follow=True,
            compose_files=["compose.yml"],
        )

        self.assertEqual(
            command,
            [
                "docker",
                "compose",
                "-f",
                "compose.yml",
                "logs",
                "-f",
                "backend-web",
                "backend-worker",
            ],
        )


if __name__ == "__main__":
    unittest.main()
