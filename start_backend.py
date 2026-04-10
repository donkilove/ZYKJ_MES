from __future__ import annotations

import argparse
import os
import socket
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parent
BACKEND_DIR = ROOT_DIR / "backend"
DEFAULT_ENV_FILE = BACKEND_DIR / ".env"
LOCAL_NO_PROXY_ENTRIES = ("localhost", "127.0.0.1", "::1")
DEFAULT_POSTGRES_PORT = 5432
DEFAULT_POSTGRES_START_TIMEOUT_SECONDS = 20.0
DEFAULT_POSTGRES_LOG_FILE = (
    Path.home() / ".local" / "state" / "postgresql" / "postgresql-start_backend.log"
)


@dataclass(frozen=True)
class PostgresTarget:
    label: str
    host: str
    port: int


def _preferred_python_candidates() -> list[Path]:
    return [
        ROOT_DIR / ".venv" / "Scripts" / "python.exe",
        ROOT_DIR / ".venv" / "bin" / "python",
    ]


def resolve_python() -> str:
    for candidate in _preferred_python_candidates():
        if candidate.exists():
            return str(candidate)
    return sys.executable


def find_executable(name: str) -> str | None:
    path_entries = [item for item in os.getenv("PATH", "").split(os.pathsep) if item]
    windows_exts = os.getenv("PATHEXT", ".COM;.EXE;.BAT;.CMD").split(";")
    resolved = None
    for entry in path_entries:
        candidates = [Path(entry) / name]
        if os.name == "nt" and not Path(name).suffix:
            candidates.extend(
                Path(entry) / f"{name}{ext.lower()}" for ext in windows_exts
            )
        for candidate in candidates:
            if candidate.exists():
                resolved = str(candidate)
                break
        if resolved:
            break
    if resolved:
        return resolved

    candidates = [
        ROOT_DIR / ".venv" / "Scripts" / f"{name}.exe",
        ROOT_DIR / ".venv" / "bin" / name,
        Path.home()
        / ".local"
        / "share"
        / "micromamba"
        / "envs"
        / "zykj-postgres"
        / "bin"
        / name,
        Path.home()
        / ".local"
        / "share"
        / "micromamba"
        / "envs"
        / "zykj-dev"
        / "bin"
        / name,
    ]
    for candidate in candidates:
        if candidate.exists():
            return str(candidate)
    return None


def load_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, _, value = line.partition("=")
        normalized_key = key.strip()
        normalized_value = value.strip()
        if (
            len(normalized_value) >= 2
            and normalized_value[0] == normalized_value[-1]
            and normalized_value[0] in {"'", '"'}
        ):
            normalized_value = normalized_value[1:-1]
        values[normalized_key] = normalized_value
    return values


def resolve_setting(
    env: dict[str, str], env_file_values: dict[str, str], key: str, default: str
) -> str:
    for env_key in (key, key.lower()):
        value = env.get(env_key)
        if value not in (None, ""):
            return value
    return env_file_values.get(key, default)


def parse_bool(value: str | None, default: bool) -> bool:
    if value is None:
        return default
    normalized = value.strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off"}:
        return False
    return default


def parse_int(value: str | None, default: int) -> int:
    if value is None:
        return default
    try:
        return int(value)
    except ValueError:
        return default


def is_local_db_host(host: str) -> bool:
    return host.strip().lower() in LOCAL_NO_PROXY_ENTRIES


def can_connect(host: str, port: int, timeout_seconds: float = 1.0) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout_seconds):
            return True
    except OSError:
        return False


def wait_for_port(host: str, port: int, timeout_seconds: float) -> bool:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        if can_connect(host, port):
            return True
        time.sleep(0.5)
    return can_connect(host, port)


def discover_pgdata(env: dict[str, str]) -> Path | None:
    pgdata = env.get("PGDATA")
    if pgdata:
        candidate = Path(pgdata).expanduser()
        if candidate.exists():
            return candidate

    base_dir = Path.home() / ".local" / "share" / "postgresql"
    if not base_dir.exists():
        return None

    candidates: list[Path] = []
    for version_dir in sorted(
        base_dir.iterdir(), key=lambda item: item.name, reverse=True
    ):
        data_dir = version_dir / "data"
        if data_dir.exists() and (data_dir / "PG_VERSION").exists():
            candidates.append(data_dir)
    if candidates:
        return candidates[0]
    return None


def resolve_postgres_log_file(env: dict[str, str]) -> Path:
    pglog = env.get("PGLOG")
    if pglog:
        return Path(pglog).expanduser()
    return DEFAULT_POSTGRES_LOG_FILE


def resolve_postgres_targets(
    env: dict[str, str], env_file_values: dict[str, str]
) -> list[PostgresTarget]:
    targets: list[PostgresTarget] = []
    seen: set[tuple[str, int]] = set()

    def add_target(label: str, host: str, port: int) -> None:
        identity = (host.strip().lower(), port)
        if identity in seen:
            return
        seen.add(identity)
        targets.append(PostgresTarget(label=label, host=host, port=port))

    db_host = resolve_setting(env, env_file_values, "DB_HOST", "127.0.0.1")
    db_port = parse_int(
        resolve_setting(env, env_file_values, "DB_PORT", str(DEFAULT_POSTGRES_PORT)),
        DEFAULT_POSTGRES_PORT,
    )
    bootstrap_enabled = parse_bool(
        resolve_setting(env, env_file_values, "BOOTSTRAP_ON_STARTUP", "true"), True
    )

    if bootstrap_enabled:
        bootstrap_host = resolve_setting(
            env, env_file_values, "DB_BOOTSTRAP_HOST", db_host
        )
        bootstrap_port = parse_int(
            resolve_setting(env, env_file_values, "DB_BOOTSTRAP_PORT", str(db_port)),
            db_port,
        )
        add_target("启动引导数据库", bootstrap_host, bootstrap_port)

    add_target("业务数据库", db_host, db_port)
    return targets


def ensure_postgresql_ready(
    env: dict[str, str],
    env_file_values: dict[str, str],
    timeout_seconds: float = DEFAULT_POSTGRES_START_TIMEOUT_SECONDS,
) -> None:
    targets = resolve_postgres_targets(env, env_file_values)
    if not targets:
        return

    not_ready_targets: list[PostgresTarget] = []
    for target in targets:
        if can_connect(target.host, target.port):
            print(
                f"[INFO] PostgreSQL 检查通过：{target.label} {target.host}:{target.port} 可连接。"
            )
        else:
            not_ready_targets.append(target)

    if not not_ready_targets:
        return

    remote_targets = [
        target for target in not_ready_targets if not is_local_db_host(target.host)
    ]
    for target in remote_targets:
        print(
            f"[WARN] PostgreSQL 未就绪：{target.label} {target.host}:{target.port} 不可连接，"
            "且不是本机地址，脚本不会自动拉起远程数据库。"
        )

    local_targets = [
        target for target in not_ready_targets if is_local_db_host(target.host)
    ]
    if not local_targets:
        return

    pg_ctl = find_executable("pg_ctl")
    if not pg_ctl:
        print("[WARN] 未找到 pg_ctl，无法自动拉起本地 PostgreSQL，将继续尝试启动后端。")
        return

    pgdata = discover_pgdata(env)
    if pgdata is None:
        print(
            "[WARN] 未找到 PGDATA 或可识别的数据目录，无法自动拉起本地 PostgreSQL，将继续尝试启动后端。"
        )
        return

    log_file = resolve_postgres_log_file(env)
    log_file.parent.mkdir(parents=True, exist_ok=True)

    print(f"[WARN] 检测到本地 PostgreSQL 未就绪，正在尝试自动启动：{pgdata}")
    start_command = [pg_ctl, "-D", str(pgdata), "-l", str(log_file), "start"]
    result = subprocess.run(start_command, check=False, env=env)
    if result.returncode != 0:
        print(
            f"[WARN] 自动启动 PostgreSQL 返回码为 {result.returncode}，"
            "将继续检查端口状态并尝试启动后端。"
        )

    for target in local_targets:
        if wait_for_port(target.host, target.port, timeout_seconds):
            print(
                f"[INFO] PostgreSQL 已就绪：{target.label} {target.host}:{target.port} 可连接。"
            )
        else:
            print(
                f"[WARN] PostgreSQL 仍未就绪：{target.label} {target.host}:{target.port} 不可连接。"
                f"请检查日志：{log_file}"
            )


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
    parser = argparse.ArgumentParser(description="启动 FastAPI 后端服务。")
    parser.add_argument("--host", default="0.0.0.0", help="监听地址，默认：0.0.0.0")
    parser.add_argument("--port", type=int, default=8000, help="监听端口，默认：8000")
    reload_group = parser.add_mutually_exclusive_group()
    reload_group.add_argument(
        "--reload", dest="reload", action="store_true", help="启用热重载。"
    )
    reload_group.add_argument(
        "--no-reload", dest="reload", action="store_false", help="禁用热重载。"
    )
    parser.add_argument(
        "--skip-postgres-check",
        action="store_true",
        help="跳过启动前的 PostgreSQL 检查与自动拉起。",
    )
    parser.set_defaults(reload=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if not BACKEND_DIR.exists():
        print(f"[ERROR] 未找到后端目录：{BACKEND_DIR}")
        return 1

    env = build_subprocess_env()
    env_file_values = load_env_file(DEFAULT_ENV_FILE)

    if not DEFAULT_ENV_FILE.exists():
        print(f"[WARN] 未找到环境变量文件：{DEFAULT_ENV_FILE}")

    if args.skip_postgres_check:
        print("[INFO] 已按参数要求跳过 PostgreSQL 检查。")
    else:
        ensure_postgresql_ready(env, env_file_values)

    command = build_command(args)
    print(f"[INFO] 后端工作目录：{BACKEND_DIR}")
    print(f"[INFO] 启动命令：{' '.join(command)}")
    print(f"[INFO] 本地地址已加入 NO_PROXY：{env['NO_PROXY']}")

    try:
        result = subprocess.run(command, cwd=BACKEND_DIR, check=False, env=env)
        if result.returncode != 0:
            print(
                f"[ERROR] 后端进程退出码为 {result.returncode}。"
                "若启动卡在迁移阶段，请查看上方 traceback 中的 alembic 或数据库错误。"
            )
        return result.returncode
    except KeyboardInterrupt:
        print("\n[INFO] 后端服务已停止。")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
