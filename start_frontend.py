from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import urllib.error
import urllib.request
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent
FRONTEND_DIR = ROOT_DIR / "mes_client"
DEFAULT_API_BASE_URL = "http://127.0.0.1:8000/api/v1"


def resolve_flutter() -> str | None:
    in_path = shutil.which("flutter")
    if in_path:
        return in_path

    common_paths = [
        Path("C:/tools/flutter/bin/flutter.bat"),
        Path("C:/src/flutter/bin/flutter.bat"),
        Path("C:/flutter/bin/flutter.bat"),
    ]
    for candidate in common_paths:
        if candidate.exists():
            return str(candidate)
    return None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Start Flutter frontend app.")
    parser.add_argument(
        "--device",
        default="windows",
        help="Flutter device id, default: windows",
    )
    parser.add_argument(
        "--skip-pub-get",
        action="store_true",
        help="Skip running 'flutter pub get' before startup.",
    )
    parser.add_argument(
        "--release",
        action="store_true",
        help="Run app in release mode.",
    )
    parser.add_argument(
        "--api-base-url",
        default=DEFAULT_API_BASE_URL,
        help=f"Backend API base url used for bootstrap, default: {DEFAULT_API_BASE_URL}",
    )
    parser.add_argument(
        "--skip-bootstrap-admin",
        action="store_true",
        help="Skip calling bootstrap admin endpoint before startup.",
    )
    return parser.parse_args()


def run_command(command: list[str], cwd: Path) -> int:
    print(f"[INFO] Working directory: {cwd}")
    print(f"[INFO] Command: {' '.join(command)}")
    result = subprocess.run(command, cwd=cwd, check=False)
    return result.returncode


def bootstrap_admin(api_base_url: str) -> None:
    url = f"{api_base_url.rstrip('/')}/auth/bootstrap-admin"
    request = urllib.request.Request(
        url=url,
        method="POST",
        headers={"Content-Type": "application/json"},
        data=b"{}",
    )
    try:
        with urllib.request.urlopen(request, timeout=8) as response:
            raw = response.read().decode("utf-8", errors="replace")
            payload = json.loads(raw) if raw else {}
            data = payload.get("data", {}) if isinstance(payload, dict) else {}
            username = data.get("username", "admin")
            created = bool(data.get("created", False))
            role_repaired = bool(data.get("role_repaired", False))
            print(
                "[INFO] Bootstrap admin success: "
                f"username={username}, created={created}, role_repaired={role_repaired}"
            )
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, json.JSONDecodeError) as error:
        print(f"[WARN] bootstrap admin failed: {error}. Continue starting frontend.")


def main() -> int:
    args = parse_args()

    if not FRONTEND_DIR.exists():
        print(f"[ERROR] Frontend directory not found: {FRONTEND_DIR}")
        return 1

    flutter = resolve_flutter()
    if not flutter:
        print("[ERROR] Flutter executable not found. Add flutter to PATH or install to C:/tools/flutter.")
        return 1

    if args.skip_bootstrap_admin:
        print("[INFO] Skip bootstrap admin by argument.")
    else:
        bootstrap_admin(args.api_base_url)

    if not args.skip_pub_get:
        pub_get_code = run_command([flutter, "pub", "get"], FRONTEND_DIR)
        if pub_get_code != 0:
            return pub_get_code

    run_args = [flutter, "run", "-d", args.device]
    if args.release:
        run_args.append("--release")
    return run_command(run_args, FRONTEND_DIR)


if __name__ == "__main__":
    raise SystemExit(main())
