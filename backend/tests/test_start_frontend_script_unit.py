import os
import sys
import unittest
from argparse import Namespace
from pathlib import Path
from unittest.mock import patch


BACKEND_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = BACKEND_DIR.parent
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

import start_frontend


class StartFrontendScriptUnitTest(unittest.TestCase):
    def test_merge_no_proxy_preserves_existing_entries_and_deduplicates_local_hosts(self) -> None:
        merged = start_frontend._merge_no_proxy("corp.local;127.0.0.1,LOCALHOST")

        self.assertEqual(merged, "corp.local,127.0.0.1,LOCALHOST,::1")

    def test_build_subprocess_env_injects_plugin_runtime_paths(self) -> None:
        with patch.dict(
            os.environ,
            {
                "PATH": "test-path",
            },
            clear=True,
        ):
            env = start_frontend.build_subprocess_env()

        self.assertEqual(env["PATH"], "test-path")
        self.assertEqual(
            env["MES_PLUGIN_ROOT"],
            str(start_frontend.ROOT_DIR / "plugins"),
        )
        self.assertEqual(
            env["MES_PYTHON_RUNTIME_DIR"],
            str(start_frontend.ROOT_DIR / "plugins" / "runtime" / "python312"),
        )

    def test_build_subprocess_env_respects_existing_plugin_runtime_override(self) -> None:
        with patch.dict(
            os.environ,
            {
                "PATH": "test-path",
                "MES_PLUGIN_ROOT": r"D:\external\plugins",
                "MES_PYTHON_RUNTIME_DIR": r"D:\external\runtime",
            },
            clear=True,
        ):
            env = start_frontend.build_subprocess_env()

        self.assertEqual(env["PATH"], "test-path")
        self.assertEqual(env["MES_PLUGIN_ROOT"], r"D:\external\plugins")
        self.assertEqual(env["MES_PYTHON_RUNTIME_DIR"], r"D:\external\runtime")

    @patch("start_frontend.run_command")
    @patch("start_frontend.bootstrap_admin")
    @patch("start_frontend.resolve_flutter", return_value="C:/tools/flutter/bin/flutter.bat")
    @patch("start_frontend.parse_args")
    def test_main_passes_built_env_to_pub_get_and_flutter_run(
        self,
        mock_parse_args,
        _mock_resolve_flutter,
        _mock_bootstrap_admin,
        mock_run_command,
    ) -> None:
        mock_parse_args.return_value = Namespace(
            device="windows",
            skip_pub_get=False,
            release=False,
            api_base_url="http://127.0.0.1:8000/api/v1",
            skip_bootstrap_admin=True,
            wait_backend_seconds=45,
        )
        mock_run_command.side_effect = [0, 0]
        expected_env = {
            "PATH": "test-path",
            "NO_PROXY": "corp.local,localhost,127.0.0.1,::1",
            "no_proxy": "corp.local,localhost,127.0.0.1,::1",
            "MES_PLUGIN_ROOT": str(start_frontend.ROOT_DIR / "plugins"),
            "MES_PYTHON_RUNTIME_DIR": str(
                start_frontend.ROOT_DIR / "plugins" / "runtime" / "python312"
            ),
        }

        with patch.dict(os.environ, {"PATH": "test-path", "NO_PROXY": "corp.local"}, clear=True):
            exit_code = start_frontend.main()

        self.assertEqual(exit_code, 0)
        self.assertEqual(mock_run_command.call_count, 2)
        pub_get_call = mock_run_command.call_args_list[0]
        run_call = mock_run_command.call_args_list[1]
        self.assertEqual(pub_get_call.args[0], ["C:/tools/flutter/bin/flutter.bat", "pub", "get"])
        self.assertEqual(pub_get_call.args[1], start_frontend.FRONTEND_DIR)
        self.assertEqual(pub_get_call.args[2], expected_env)
        self.assertEqual(
            run_call.args[0],
            [
                "C:/tools/flutter/bin/flutter.bat",
                "run",
                "-d",
                "windows",
                "--dart-define=MES_API_BASE_URL=http://127.0.0.1:8000/api/v1",
            ],
        )
        self.assertEqual(run_call.args[1], start_frontend.FRONTEND_DIR)
        self.assertEqual(run_call.args[2], expected_env)


if __name__ == "__main__":
    unittest.main()
