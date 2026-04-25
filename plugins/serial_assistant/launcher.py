import json
import os
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR / "vendor"))
sys.path.insert(0, str(BASE_DIR))

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
