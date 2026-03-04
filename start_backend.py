from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent
BACKEND_DIR = ROOT_DIR / "backend"
DEFAULT_ENV_FILE = BACKEND_DIR / ".env"
LOCAL_NO_PROXY_ENTRIES = ("localhost", "127.0.0.1", "::1")


def resolve_python() -> str:
    venv_python = ROOT_DIR / ".venv" / "Scripts" / "python.exe"
    if venv_python.exists():
        return str(venv_python)
    return sys.executable


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


def build_command(args: argparse.Namespace) -> list[str]:
    command = [
        resolve_python(),
        "-m",
        "uvicorn",
        "app.main:app",
        "--host",
        args.host,
        "--port",
        str(args.port),
    ]
    if args.reload:
        command.append("--reload")
    return command


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Start FastAPI backend server.")
    parser.add_argument("--host", default="0.0.0.0", help="Bind host, default: 0.0.0.0")
    parser.add_argument("--port", type=int, default=8000, help="Bind port, default: 8000")
    reload_group = parser.add_mutually_exclusive_group()
    reload_group.add_argument("--reload", dest="reload", action="store_true", help="Enable auto-reload.")
    reload_group.add_argument("--no-reload", dest="reload", action="store_false", help="Disable auto-reload.")
    parser.set_defaults(reload=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if not BACKEND_DIR.exists():
        print(f"[ERROR] Backend directory not found: {BACKEND_DIR}")
        return 1

    if not DEFAULT_ENV_FILE.exists():
        print(f"[WARN] Env file not found: {DEFAULT_ENV_FILE}")

    command = build_command(args)
    env = build_subprocess_env()
    print(f"[INFO] Working directory: {BACKEND_DIR}")
    print(f"[INFO] Command: {' '.join(command)}")
    print(f"[INFO] Local addresses bypass proxy via NO_PROXY: {env['NO_PROXY']}")

    try:
        result = subprocess.run(command, cwd=BACKEND_DIR, check=False, env=env)
        if result.returncode != 0:
            print(
                f"[ERROR] Backend process exited with code {result.returncode}. "
                "If startup stopped at migration, check alembic errors in the traceback above."
            )
        return result.returncode
    except KeyboardInterrupt:
        print("\n[INFO] Backend server stopped.")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
