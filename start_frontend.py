from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent
FRONTEND_DIR = ROOT_DIR / "mes_client"
DEFAULT_API_BASE_URL = "http://127.0.0.1:8000/api/v1"
LOCAL_NO_PROXY_ENTRIES = ("localhost", "127.0.0.1", "::1")


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


def _merge_no_proxy(existing: str | None) -> str:
    entries: list[str] = []
    if existing:
        normalized = existing.replace(";", ",")
        entries.extend(part.strip() for part in normalized.split(",") if part.strip())
    entries.extend(LOCAL_NO_PROXY_ENTRIES)

    merged: list[str] = []
    seen: set[str] = set()
    for entry in entries:
        key = entry.lower()
        if key in seen:
            continue
        seen.add(key)
        merged.append(entry)
    return ",".join(merged)


def build_subprocess_env() -> dict[str, str]:
    env = os.environ.copy()
    merged_no_proxy = _merge_no_proxy(env.get("NO_PROXY") or env.get("no_proxy"))
    env["NO_PROXY"] = merged_no_proxy
    env["no_proxy"] = merged_no_proxy
    return env


def _is_local_host_url(url: str) -> bool:
    host = (urllib.parse.urlparse(url).hostname or "").lower()
    return host in {"localhost", "127.0.0.1", "::1"}


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


def run_command(command: list[str], cwd: Path, env: dict[str, str]) -> int:
    print(f"[INFO] Working directory: {cwd}")
    print(f"[INFO] Command: {' '.join(command)}")
    result = subprocess.run(command, cwd=cwd, check=False, env=env)
    return result.returncode


def bootstrap_admin(api_base_url: str) -> None:
    url = f"{api_base_url.rstrip('/')}/auth/bootstrap-admin"
    request = urllib.request.Request(
        url=url,
        method="POST",
        headers={"Content-Type": "application/json"},
        data=b"{}",
    )
    open_url = urllib.request.urlopen
    if _is_local_host_url(api_base_url):
        print("[INFO] bootstrap admin uses direct localhost connection (proxy bypass).")
        open_url = urllib.request.build_opener(urllib.request.ProxyHandler({})).open
    try:
        with open_url(request, timeout=8) as response:
            raw = response.read().decode("utf-8", errors="replace")
            payload = json.loads(raw) if raw else {}
            data = payload.get("data", {}) if isinstance(payload, dict) else {}
            username = data.get("username", "admin")
            created = bool(data.get("created", False))
            role_repaired = bool(data.get("role_repaired", False))
            normalized_users_count = int(data.get("normalized_users_count", 0) or 0)
            print(
                "[INFO] Bootstrap admin success: "
                f"username={username}, created={created}, role_repaired={role_repaired}, "
                f"normalized_users_count={normalized_users_count}"
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

    env = build_subprocess_env()
    os.environ["NO_PROXY"] = env["NO_PROXY"]
    os.environ["no_proxy"] = env["no_proxy"]
    print(f"[INFO] Local addresses bypass proxy via NO_PROXY: {env['NO_PROXY']}")

    if args.skip_bootstrap_admin:
        print("[INFO] Skip bootstrap admin by argument.")
    else:
        bootstrap_admin(args.api_base_url)

    if not args.skip_pub_get:
        pub_get_code = run_command([flutter, "pub", "get"], FRONTEND_DIR, env)
        if pub_get_code != 0:
            return pub_get_code

    run_args = [flutter, "run", "-d", args.device]
    if args.release:
        run_args.append("--release")
    return run_command(run_args, FRONTEND_DIR, env)


if __name__ == "__main__":
    raise SystemExit(main())
