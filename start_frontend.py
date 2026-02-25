from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent
FRONTEND_DIR = ROOT_DIR / "mes_client"


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
    return parser.parse_args()


def run_command(command: list[str], cwd: Path) -> int:
    print(f"[INFO] Working directory: {cwd}")
    print(f"[INFO] Command: {' '.join(command)}")
    result = subprocess.run(command, cwd=cwd, check=False)
    return result.returncode


def main() -> int:
    args = parse_args()

    if not FRONTEND_DIR.exists():
        print(f"[ERROR] Frontend directory not found: {FRONTEND_DIR}")
        return 1

    flutter = resolve_flutter()
    if not flutter:
        print("[ERROR] Flutter executable not found. Add flutter to PATH or install to C:/tools/flutter.")
        return 1

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

