import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = BACKEND_DIR.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

import start_backend


def _completed_process(returncode: int = 0, stdout: str = "", stderr: str = "") -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess(
        args=["docker", "compose"],
        returncode=returncode,
        stdout=stdout,
        stderr=stderr,
    )


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

    @patch("start_backend.print_compose_result")
    @patch("start_backend.run_compose")
    @patch("start_backend.build_compose_command")
    def test_logs_action_uses_streaming_mode_without_capture_output(
        self,
        mock_build_compose_command,
        mock_run_compose,
        mock_print_compose_result,
    ) -> None:
        args = start_backend.parse_args(["logs"])
        env = {"PATH": "fake"}
        compose_files = ["compose.yml"]
        command = ["docker", "compose", "logs", "-f", "backend-web"]
        mock_build_compose_command.return_value = command
        mock_run_compose.return_value = _completed_process(returncode=0)

        return_code = start_backend.run_simple_action(
            action="logs",
            args=args,
            env=env,
            compose_files=compose_files,
        )

        self.assertEqual(return_code, 0)
        mock_run_compose.assert_called_once_with(command, env, capture_output=False)
        mock_print_compose_result.assert_not_called()

    @patch("start_backend.print")
    @patch("start_backend.run_compose", side_effect=KeyboardInterrupt)
    @patch("start_backend.build_compose_command", return_value=["docker", "compose", "logs"])
    def test_logs_action_handles_keyboard_interrupt(
        self,
        _mock_build_compose_command,
        _mock_run_compose,
        mock_print,
    ) -> None:
        args = start_backend.parse_args(["logs"])

        return_code = start_backend.run_simple_action(
            action="logs",
            args=args,
            env={},
            compose_files=["compose.yml"],
        )

        self.assertEqual(return_code, 130)
        mock_print.assert_called()

    @patch("start_backend.print_start_summary")
    @patch("start_backend.wait_for_port")
    @patch("start_backend.print_compose_result")
    @patch("start_backend.run_compose")
    @patch("start_backend.build_compose_command")
    def test_up_without_backend_web_skips_health_wait(
        self,
        mock_build_compose_command,
        mock_run_compose,
        _mock_print_compose_result,
        mock_wait_for_port,
        mock_print_start_summary,
    ) -> None:
        args = start_backend.parse_args(["up", "--service", "backend-worker"])
        mock_build_compose_command.return_value = ["docker", "compose", "up", "-d", "backend-worker"]
        mock_run_compose.return_value = _completed_process(returncode=0)

        return_code = start_backend.run_up_action(
            args=args,
            env={},
            compose_files=["compose.yml"],
            force_rebuild=False,
        )

        self.assertEqual(return_code, 0)
        mock_wait_for_port.assert_not_called()
        mock_print_start_summary.assert_called_once()

    @patch("start_backend.print_start_summary")
    @patch("start_backend.wait_for_port", return_value=True)
    @patch("start_backend.print_compose_result")
    @patch("start_backend.run_compose")
    @patch("start_backend.build_compose_command")
    def test_up_uses_backend_port_from_environment(
        self,
        mock_build_compose_command,
        mock_run_compose,
        _mock_print_compose_result,
        mock_wait_for_port,
        mock_print_start_summary,
    ) -> None:
        args = start_backend.parse_args(["up"])
        env = {"BACKEND_WEB_HOST_PORT": "18080"}
        mock_build_compose_command.side_effect = [
            ["docker", "compose", "build", "backend-web"],
            ["docker", "compose", "up", "-d", "backend-web"],
        ]
        mock_run_compose.side_effect = [
            _completed_process(returncode=0),
            _completed_process(returncode=0),
        ]

        return_code = start_backend.run_up_action(
            args=args,
            env=env,
            compose_files=["compose.yml"],
            force_rebuild=False,
        )

        self.assertEqual(return_code, 0)
        mock_wait_for_port.assert_called_once_with("127.0.0.1", 18080, start_backend.DEFAULT_WAIT_TIMEOUT_SECONDS)
        mock_print_start_summary.assert_called_once()

    @patch("start_backend.wait_for_port", side_effect=RuntimeError("unexpected"))
    @patch("start_backend.print_compose_result")
    @patch("start_backend.run_compose")
    @patch("start_backend.build_compose_command")
    def test_up_handles_health_wait_exception_as_failure(
        self,
        mock_build_compose_command,
        mock_run_compose,
        _mock_print_compose_result,
        _mock_wait_for_port,
    ) -> None:
        args = start_backend.parse_args(["up"])
        mock_build_compose_command.side_effect = [
            ["docker", "compose", "build", "backend-web"],
            ["docker", "compose", "up", "-d", "backend-web"],
        ]
        mock_run_compose.side_effect = [
            _completed_process(returncode=0),
            _completed_process(returncode=0),
        ]

        return_code = start_backend.run_up_action(
            args=args,
            env={},
            compose_files=["compose.yml"],
            force_rebuild=False,
        )

        self.assertEqual(return_code, 1)

    @patch("start_backend.wait_for_port", return_value=False)
    @patch("start_backend.print_compose_result")
    @patch("start_backend.run_compose")
    @patch("start_backend.build_compose_command")
    def test_up_returns_failure_when_health_wait_timeout(
        self,
        mock_build_compose_command,
        mock_run_compose,
        _mock_print_compose_result,
        _mock_wait_for_port,
    ) -> None:
        args = start_backend.parse_args(["up"])
        mock_build_compose_command.side_effect = [
            ["docker", "compose", "build", "backend-web"],
            ["docker", "compose", "up", "-d", "backend-web"],
        ]
        mock_run_compose.side_effect = [
            _completed_process(returncode=0),
            _completed_process(returncode=0),
        ]

        return_code = start_backend.run_up_action(
            args=args,
            env={},
            compose_files=["compose.yml"],
            force_rebuild=False,
        )

        self.assertEqual(return_code, 1)

    @patch("start_backend.print_compose_result")
    @patch("start_backend.run_compose")
    @patch("start_backend.build_compose_command")
    def test_up_returns_build_failure_code(
        self,
        mock_build_compose_command,
        mock_run_compose,
        _mock_print_compose_result,
    ) -> None:
        args = start_backend.parse_args(["up"])
        mock_build_compose_command.return_value = ["docker", "compose", "build", "backend-web"]
        mock_run_compose.return_value = _completed_process(returncode=17, stderr="build failed")

        return_code = start_backend.run_up_action(
            args=args,
            env={},
            compose_files=["compose.yml"],
            force_rebuild=False,
        )

        self.assertEqual(return_code, 17)


if __name__ == "__main__":
    unittest.main()
