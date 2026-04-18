from __future__ import annotations

import argparse
import os
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path
from typing import Mapping, Sequence


ROOT_DIR = Path(__file__).resolve().parent
COMPOSE_FILE = ROOT_DIR / "compose.yml"
RUNTIME_DIR = ROOT_DIR / ".tmp_runtime"
DB_EXPOSE_OVERRIDE_FILE = RUNTIME_DIR / "start_backend.compose.override.yml"
DEFAULT_ACTION = "up"
DEFAULT_DB_PORT = 5433
DEFAULT_UP_SERVICES = ["backend-web", "backend-worker", "postgres", "redis"]
DEFAULT_LOG_SERVICES = ["backend-web", "backend-worker"]
DEFAULT_BACKEND_HTTP_HOST = "127.0.0.1"
DEFAULT_BACKEND_HTTP_PORT = 8000
DEFAULT_WAIT_TIMEOUT_SECONDS = 90.0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="后端 Docker 编排控制器。")
    parser.add_argument(
        "action",
        nargs="?",
        choices=("up", "logs", "ps", "down", "restart", "rebuild"),
        default=DEFAULT_ACTION,
        help="执行动作，默认 up。",
    )
    parser.add_argument(
        "--expose-db",
        action="store_true",
        help=f"临时暴露 PostgreSQL 到 127.0.0.1:{DEFAULT_DB_PORT}。",
    )
    parser.add_argument(
        "--db-port",
        type=int,
        default=DEFAULT_DB_PORT,
        help=f"临时暴露 PostgreSQL 的宿主端口，默认 {DEFAULT_DB_PORT}。",
    )
    parser.add_argument(
        "--service",
        dest="services",
        action="append",
        help="限定服务名称，可多次传入。",
    )
    parser.add_argument(
        "--no-build",
        action="store_true",
        help="up 动作跳过 build 步骤（rebuild 无效）。",
    )
    parser.add_argument(
        "--no-follow",
        dest="follow",
        action="store_false",
        help="logs 动作不跟随输出。",
    )
    parser.set_defaults(follow=True)
    return parser.parse_args(argv)


def build_db_expose_override(args: argparse.Namespace) -> str:
    if not args.expose_db:
        return ""
    return (
        "services:\n"
        "  postgres:\n"
        "    ports:\n"
        f'      - "127.0.0.1:{args.db_port}:5432"\n'
    )


def write_db_expose_override(args: argparse.Namespace) -> Path | None:
    override_content = build_db_expose_override(args)
    if not override_content:
        return None
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    DB_EXPOSE_OVERRIDE_FILE.write_text(override_content, encoding="utf-8")
    return DB_EXPOSE_OVERRIDE_FILE


def build_compose_command(
    *,
    action: str,
    services: Sequence[str] | None,
    follow: bool,
    compose_files: Sequence[str],
    detach: bool = False,
) -> list[str]:
    command = ["docker", "compose"]
    for compose_file in compose_files:
        command.extend(["-f", compose_file])

    if action == "logs":
        command.append("logs")
        if follow:
            command.append("-f")
        target_services = list(services) if services else list(DEFAULT_LOG_SERVICES)
        command.extend(target_services)
        return command

    if action == "up":
        command.append("up")
        if detach:
            command.append("-d")
    elif action == "build":
        command.append("build")
    elif action == "ps":
        command.append("ps")
    elif action == "down":
        command.append("down")
    elif action == "restart":
        command.append("restart")
    else:
        raise ValueError(f"不支持的 compose 动作：{action}")

    if services:
        command.extend(services)
    return command


def require_docker() -> None:
    docker_path = shutil.which("docker")
    if not docker_path:
        raise RuntimeError("未检测到 docker，请先安装并启动 Docker Desktop。")

    compose_check = subprocess.run(
        ["docker", "compose", "version"],
        cwd=ROOT_DIR,
        text=True,
        capture_output=True,
        check=False,
    )
    if compose_check.returncode != 0:
        stderr = (compose_check.stderr or "").strip()
        stdout = (compose_check.stdout or "").strip()
        details = stderr or stdout or "无额外输出"
        raise RuntimeError(f"docker compose 不可用：{details}")


def run_compose(
    command: Sequence[str],
    env: dict[str, str],
    *,
    capture_output: bool = True,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        list(command),
        cwd=ROOT_DIR,
        text=True,
        capture_output=capture_output,
        check=False,
        env=env,
    )


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


def print_start_summary(
    *,
    services: Sequence[str],
    db_exposed: bool,
    db_port: int,
    backend_http_port: int | None,
) -> None:
    print("[INFO] 后端 Docker 服务已启动。")
    print(f"[INFO] 服务集合：{', '.join(services)}")
    if backend_http_port is not None:
        print(f"[INFO] 后端 HTTP 地址：http://{DEFAULT_BACKEND_HTTP_HOST}:{backend_http_port}")
    else:
        print("[INFO] 后端 HTTP 地址：未启动 backend-web，未提供 HTTP 入口。")
    if db_exposed:
        print(f"[INFO] 数据库暴露：已开启（127.0.0.1:{db_port} -> 5432）")
    else:
        print("[INFO] 数据库暴露：未开启（仅容器网络可见）")
    print("[INFO] 常用命令：")
    print("[INFO]   python start_backend.py logs")
    print("[INFO]   python start_backend.py ps")
    print("[INFO]   python start_backend.py down")


def resolve_backend_http_port(env: Mapping[str, str]) -> int:
    raw_port = (env.get("BACKEND_WEB_HOST_PORT") or "").strip()
    if not raw_port:
        return DEFAULT_BACKEND_HTTP_PORT
    try:
        return int(raw_port)
    except ValueError:
        print(
            f"[WARN] BACKEND_WEB_HOST_PORT={raw_port!r} 不是合法端口，回退默认端口 {DEFAULT_BACKEND_HTTP_PORT}。"
        )
        return DEFAULT_BACKEND_HTTP_PORT


def print_compose_result(result: subprocess.CompletedProcess[str]) -> None:
    stdout = (result.stdout or "").strip()
    stderr = (result.stderr or "").strip()
    if stdout:
        print(stdout)
    if stderr:
        print(stderr, file=sys.stderr)


def resolve_compose_files(args: argparse.Namespace) -> list[str]:
    compose_files = [str(COMPOSE_FILE.relative_to(ROOT_DIR))]
    override_file = write_db_expose_override(args)
    if override_file:
        compose_files.append(str(override_file.relative_to(ROOT_DIR)))
    return compose_files


def run_simple_action(
    *,
    action: str,
    args: argparse.Namespace,
    env: dict[str, str],
    compose_files: Sequence[str],
) -> int:
    services = args.services
    if action == "restart" and not services:
        services = DEFAULT_UP_SERVICES
    command = build_compose_command(
        action=action,
        services=services,
        follow=args.follow,
        compose_files=compose_files,
    )
    is_logs_action = action == "logs"
    try:
        result = run_compose(command, env, capture_output=not is_logs_action)
    except KeyboardInterrupt:
        print("[WARN] 已中断日志跟随。")
        return 130

    if not is_logs_action:
        print_compose_result(result)
    return result.returncode


def run_up_action(
    *,
    args: argparse.Namespace,
    env: dict[str, str],
    compose_files: Sequence[str],
    force_rebuild: bool,
) -> int:
    services = list(args.services) if args.services else list(DEFAULT_UP_SERVICES)
    need_build = force_rebuild or (not args.no_build)

    if need_build:
        build_command = build_compose_command(
            action="build",
            services=services,
            follow=args.follow,
            compose_files=compose_files,
        )
        build_result = run_compose(build_command, env)
        print_compose_result(build_result)
        if build_result.returncode != 0:
            print("[ERROR] Docker 镜像构建失败，请修复后重试。")
            return build_result.returncode

    up_command = build_compose_command(
        action="up",
        services=services,
        follow=args.follow,
        compose_files=compose_files,
        detach=True,
    )
    up_result = run_compose(up_command, env)
    print_compose_result(up_result)
    if up_result.returncode != 0:
        print("[ERROR] Docker 服务启动失败，可执行 `python start_backend.py logs` 排查。")
        return up_result.returncode

    if "backend-web" not in services:
        print("[INFO] 未包含 backend-web，跳过 HTTP 健康等待。")
        print_start_summary(
            services=services,
            db_exposed=args.expose_db,
            db_port=args.db_port,
            backend_http_port=None,
        )
        return 0

    backend_http_port = resolve_backend_http_port(env)
    try:
        backend_ready = wait_for_port(
            DEFAULT_BACKEND_HTTP_HOST,
            backend_http_port,
            DEFAULT_WAIT_TIMEOUT_SECONDS,
        )
    except Exception as exc:
        print(f"[ERROR] backend-web 健康检查异常：{exc}")
        print("[ERROR] 请执行 `python start_backend.py logs` 查看容器日志后重试。")
        return 1

    if backend_ready:
        print_start_summary(
            services=services,
            db_exposed=args.expose_db,
            db_port=args.db_port,
            backend_http_port=backend_http_port,
        )
        return 0

    print(
        f"[ERROR] backend-web 等待超时（{DEFAULT_BACKEND_HTTP_HOST}:{backend_http_port}），"
        "请执行 `python start_backend.py logs` 查看容器日志后重试。"
    )
    return 1


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    try:
        require_docker()
    except RuntimeError as exc:
        print(f"[ERROR] {exc}")
        return 1

    if not COMPOSE_FILE.exists():
        print(f"[ERROR] 未找到 compose 文件：{COMPOSE_FILE}")
        return 1

    env = os.environ.copy()
    compose_files = resolve_compose_files(args)
    action = args.action

    if action == "rebuild":
        return run_up_action(
            args=args,
            env=env,
            compose_files=compose_files,
            force_rebuild=True,
        )
    if action == "up":
        return run_up_action(
            args=args,
            env=env,
            compose_files=compose_files,
            force_rebuild=False,
        )
    return run_simple_action(
        action=action,
        args=args,
        env=env,
        compose_files=compose_files,
    )


if __name__ == "__main__":
    raise SystemExit(main())
