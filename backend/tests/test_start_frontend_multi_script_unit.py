import os
import sys
import tempfile
import unittest
from argparse import Namespace
from pathlib import Path
from unittest.mock import MagicMock, patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = BACKEND_DIR.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

import start_frontend_multi


class StartFrontendMultiScriptUnitTest(unittest.TestCase):
    def test_build_windows_executable_path_uses_mode_directory(self) -> None:
        self.assertEqual(
            start_frontend_multi.build_windows_executable_path("debug"),
            start_frontend_multi.FRONTEND_DIR
            / "build"
            / "windows"
            / "x64"
            / "runner"
            / "Debug"
            / "mes_client.exe",
        )

    def test_sync_workspace_copies_files_and_skips_build_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as source_tmp, tempfile.TemporaryDirectory() as target_tmp:
            source_dir = Path(source_tmp)
            target_dir = Path(target_tmp)

            (source_dir / "lib").mkdir(parents=True)
            (source_dir / "build").mkdir(parents=True)
            (source_dir / "windows" / "flutter" / "ephemeral").mkdir(parents=True)

            (source_dir / "lib" / "main.dart").write_text("main-v1", encoding="utf-8")
            (source_dir / "build" / "ignored.txt").write_text("ignored", encoding="utf-8")
            (
                source_dir / "windows" / "flutter" / "ephemeral" / "ignored.txt"
            ).write_text("ignored", encoding="utf-8")

            result = start_frontend_multi.sync_workspace(source_dir, target_dir)

            self.assertEqual(result.copied_count, 1)
            self.assertTrue((target_dir / "lib" / "main.dart").exists())
            self.assertFalse((target_dir / "build" / "ignored.txt").exists())
            self.assertFalse(
                (target_dir / "windows" / "flutter" / "ephemeral" / "ignored.txt").exists()
            )

    @patch("start_frontend_multi.subprocess.Popen")
    def test_launch_frontend_instances_spawns_requested_count(self, mock_popen) -> None:
        mock_processes = []
        for index in range(1, 5):
            process = MagicMock()
            process.pid = 1000 + index
            process.poll.return_value = None
            mock_processes.append(process)
        mock_popen.side_effect = mock_processes

        env = {"PATH": "test-path", "NO_PROXY": "corp.local", "no_proxy": "corp.local"}
        executable = (
            start_frontend_multi.FRONTEND_DIR
            / "build"
            / "windows"
            / "x64"
            / "runner"
            / "Debug"
            / "mes_client.exe"
        )

        processes = start_frontend_multi.launch_frontend_instances(executable, 4, env)

        self.assertEqual(processes, mock_processes)
        self.assertEqual(mock_popen.call_count, 4)
        for index, call in enumerate(mock_popen.call_args_list, start=1):
            self.assertEqual(call.args[0], [str(executable)])
            self.assertEqual(call.kwargs["cwd"], executable.parent)
            self.assertEqual(call.kwargs["env"]["MES_FRONTEND_INSTANCE_INDEX"], str(index))
            self.assertEqual(call.kwargs["env"]["MES_FRONTEND_INSTANCE_COUNT"], "4")
        self.assertNotIn("MES_FRONTEND_INSTANCE_INDEX", env)

    @patch("start_frontend_multi.wait_for_processes", return_value=0)
    @patch("start_frontend_multi.launch_frontend_instances")
    @patch("start_frontend_multi.build_windows_executable_path")
    @patch("start_frontend_multi.run_command")
    @patch("start_frontend_multi.bootstrap_admin")
    @patch("start_frontend_multi.resolve_flutter", return_value="C:/tools/flutter/bin/flutter.bat")
    @patch("start_frontend_multi.parse_args")
    def test_main_exe_mode_builds_once_and_launches_four_instances(
        self,
        mock_parse_args,
        mock_resolve_flutter,
        mock_bootstrap_admin,
        mock_run_command,
        mock_build_windows_executable_path,
        mock_launch_frontend_instances,
        mock_wait_for_processes,
    ) -> None:
        mock_parse_args.return_value = Namespace(
            count=4,
            mode="exe",
            device="windows",
            build_mode="debug",
            skip_build=False,
            skip_pub_get=False,
            api_base_url="http://127.0.0.1:8000/api/v1",
            skip_bootstrap_admin=True,
            wait_backend_seconds=45,
            startup_delay_seconds=2.0,
            machine_start_timeout_seconds=180,
        )
        fake_executable = MagicMock()
        fake_executable.exists.return_value = True
        mock_build_windows_executable_path.return_value = fake_executable
        mock_run_command.side_effect = [0, 0]

        with patch.dict(
            os.environ,
            {
                "PATH": "test-path",
                "NO_PROXY": "corp.local",
                "no_proxy": "corp.local",
            },
            clear=True,
        ):
            exit_code = start_frontend_multi.main()

        self.assertEqual(exit_code, 0)
        mock_resolve_flutter.assert_called_once()
        mock_bootstrap_admin.assert_not_called()
        self.assertEqual(mock_run_command.call_count, 2)
        self.assertEqual(
            mock_run_command.call_args_list[0].args[0],
            ["C:/tools/flutter/bin/flutter.bat", "pub", "get"],
        )
        self.assertEqual(
            mock_run_command.call_args_list[1].args[0],
            [
                "C:/tools/flutter/bin/flutter.bat",
                "build",
                "windows",
                "--debug",
                "--dart-define=MES_API_BASE_URL=http://127.0.0.1:8000/api/v1",
            ],
        )
        mock_launch_frontend_instances.assert_called_once_with(
            fake_executable,
            4,
            {
                "PATH": "test-path",
                "NO_PROXY": "corp.local,localhost,127.0.0.1,::1",
                "no_proxy": "corp.local,localhost,127.0.0.1,::1",
                "MES_PLUGIN_ROOT": str(start_frontend_multi.ROOT_DIR / "plugins"),
                "MES_PYTHON_RUNTIME_DIR": str(
                    start_frontend_multi.ROOT_DIR / "plugins" / "runtime" / "python312"
                ),
            },
        )
        mock_wait_for_processes.assert_called_once()

    @patch("start_frontend_multi.stop_hot_reload_instances")
    @patch("start_frontend_multi.interactive_hot_reload_loop", return_value=0)
    @patch("start_frontend_multi.launch_hot_reload_instances")
    @patch("start_frontend_multi.prepare_hot_reload_workspaces")
    @patch("start_frontend_multi.bootstrap_admin")
    @patch("start_frontend_multi.resolve_flutter", return_value="C:/tools/flutter/bin/flutter.bat")
    @patch("start_frontend_multi.parse_args")
    def test_main_hot_reload_mode_uses_machine_flow(
        self,
        mock_parse_args,
        mock_resolve_flutter,
        mock_bootstrap_admin,
        mock_prepare_hot_reload_workspaces,
        mock_launch_hot_reload_instances,
        mock_interactive_hot_reload_loop,
        mock_stop_hot_reload_instances,
    ) -> None:
        mock_parse_args.return_value = Namespace(
            count=4,
            mode="hot-reload",
            device="windows",
            build_mode="debug",
            skip_build=False,
            skip_pub_get=True,
            api_base_url="http://127.0.0.1:8000/api/v1",
            skip_bootstrap_admin=True,
            wait_backend_seconds=45,
            startup_delay_seconds=2.0,
            machine_start_timeout_seconds=180,
        )
        workspaces = [Path(f"C:/tmp/instance_{index}/frontend") for index in range(1, 5)]
        mock_prepare_hot_reload_workspaces.return_value = workspaces
        instances = [MagicMock(), MagicMock(), MagicMock(), MagicMock()]
        mock_launch_hot_reload_instances.return_value = instances

        with patch.dict(
            os.environ,
            {
                "PATH": "test-path",
                "NO_PROXY": "corp.local",
                "no_proxy": "corp.local",
            },
            clear=True,
        ):
            exit_code = start_frontend_multi.main()

        self.assertEqual(exit_code, 0)
        mock_resolve_flutter.assert_called_once()
        mock_bootstrap_admin.assert_not_called()
        mock_prepare_hot_reload_workspaces.assert_called_once_with(4)
        mock_launch_hot_reload_instances.assert_called_once()
        self.assertEqual(mock_launch_hot_reload_instances.call_args.kwargs["workspaces"], workspaces)
        self.assertEqual(mock_launch_hot_reload_instances.call_args.kwargs["device"], "windows")
        self.assertTrue(mock_interactive_hot_reload_loop.called)
        mock_stop_hot_reload_instances.assert_called_once_with(instances)


if __name__ == "__main__":
    unittest.main()
