from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


PLUGIN_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = PLUGIN_DIR.parents[1]
LAUNCHER = PLUGIN_DIR / "launcher.py"
EMBEDDED_PYTHON = REPO_ROOT / "plugins" / "runtime" / "python312" / "python.exe"


def test_launcher_emits_ready_payload_when_started_from_plugin_dir() -> None:
    result = subprocess.run(
        [str(EMBEDDED_PYTHON), str(LAUNCHER)],
        cwd=PLUGIN_DIR,
        input="",
        text=True,
        capture_output=True,
        timeout=10,
    )

    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout.strip())
    assert payload["event"] == "ready"
    assert payload["entry_url"].startswith("http://127.0.0.1:")
    assert payload["heartbeat_url"].endswith("/__heartbeat__")
