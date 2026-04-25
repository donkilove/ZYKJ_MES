import json
import os
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
plugin_dir = Path(os.environ.get("MES_PLUGIN_DIR", str(BASE_DIR)))
vendor_dir = Path(os.environ.get("MES_PLUGIN_VENDOR_DIR", str(plugin_dir / "vendor")))
app_dir = Path(os.environ.get("MES_PLUGIN_APP_DIR", str(plugin_dir / "app")))

sys.path.insert(0, str(vendor_dir))
sys.path.insert(0, str(plugin_dir))
sys.path.insert(0, str(app_dir))

from app.server import start_server  # noqa: E402


if __name__ == "__main__":
    port, heartbeat_path = start_server(base_dir=BASE_DIR)
    print(
        json.dumps(
            {
                "event": "ready",
                "pid": os.getpid(),
                "entry_url": f"http://127.0.0.1:{port}/index.html",
                "heartbeat_url": f"http://127.0.0.1:{port}{heartbeat_path}",
            }
        ),
        flush=True,
    )
    try:
        sys.stdin.read()
    except KeyboardInterrupt:
        pass
