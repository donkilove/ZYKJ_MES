from __future__ import annotations

import argparse
import json
import os
import queue
import shutil
import subprocess
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import IO, Any

from start_frontend import (
    DEFAULT_API_BASE_URL,
    FRONTEND_DIR,
    _is_local_host_url,
    bootstrap_admin,
    build_subprocess_env,
    resolve_flutter,
    run_command,
    wait_backend_ready,
)

try:
    import msvcrt
except ImportError:  # pragma: no cover - 当前脚本只面向 Windows
    msvcrt = None


ROOT_DIR = Path(__file__).resolve().parent
WINDOWS_RUNNER_DIR = FRONTEND_DIR / "build" / "windows" / "x64" / "runner"
HOT_RELOAD_RUNTIME_DIR = ROOT_DIR / ".tmp_runtime" / "frontend_multi_hot_reload"
BUILD_MODE_DIRS = {
    "debug": "Debug",
    "profile": "Profile",
    "release": "Release",
}
SYNC_EXCLUDED_DIR_NAMES = {
    ".dart_tool",
    ".git",
    ".pub",
    "build",
    "coverage",
}
SYNC_EXCLUDED_RELATIVE_DIRS = {
    Path("windows") / "flutter" / "ephemeral",
}
SYNC_EXCLUDED_FILE_NAMES = {
    ".flutter-plugins",
    ".flutter-plugins-dependencies",
    ".packages",
}
HOT_RELOAD_SUPPORT_FILES = ("logo.ico",)
DEFAULT_INSTANCE_COUNT = 4
DEFAULT_STARTUP_DELAY_SECONDS = 2.0
DEFAULT_MACHINE_START_TIMEOUT_SECONDS = 600


@dataclass
class WorkspaceSyncResult:
    copied_count: int = 0
    deleted_count: int = 0
    changed_files: set[str] = field(default_factory=set)
    deleted_files: set[str] = field(default_factory=set)


@dataclass
class HotReloadInstance:
    index: int
    workspace_dir: Path
    log_path: Path
    process: subprocess.Popen[str]
    log_handle: IO[str]
    request_lock: threading.Lock = field(default_factory=threading.Lock)
    pending_responses: dict[int, queue.Queue[dict[str, Any]]] = field(default_factory=dict)
    next_request_id: int = 1
    app_id: str | None = None
    started_event: threading.Event = field(default_factory=threading.Event)
    reader_thread: threading.Thread | None = None
    exit_announced: bool = False


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="同时启动多个前端实例。")
    parser.add_argument(
        "--count",
        type=int,
        default=DEFAULT_INSTANCE_COUNT,
        help=f"同时启动的实例数量，默认: {DEFAULT_INSTANCE_COUNT}",
    )
    parser.add_argument(
        "--mode",
        choices=("hot-reload", "exe"),
        default="hot-reload",
        help="启动模式：hot-reload=开发热重载，exe=构建后多开，默认: hot-reload",
    )
    parser.add_argument(
        "--device",
        default="windows",
        help="Flutter 设备 ID，默认: windows",
    )
    parser.add_argument(
        "--build-mode",
        choices=("debug", "profile", "release"),
        default="debug",
        help="exe 模式使用的 Flutter Windows 构建模式，默认: debug",
    )
    parser.add_argument(
        "--skip-build",
        action="store_true",
        help="exe 模式下跳过构建，直接启动已有可执行文件。",
    )
    parser.add_argument(
        "--skip-pub-get",
        action="store_true",
        help="跳过执行 'flutter pub get'。",
    )
    parser.add_argument(
        "--skip-bootstrap-admin",
        action="store_true",
        help="跳过调用 bootstrap 管理员接口。",
    )
    parser.add_argument(
        "--api-base-url",
        default=DEFAULT_API_BASE_URL,
        help=f"后端 API 基础地址，默认: {DEFAULT_API_BASE_URL}",
    )
    parser.add_argument(
        "--wait-backend-seconds",
        type=int,
        default=45,
        help="等待本地后端 /health 的秒数，默认: 45",
    )
    parser.add_argument(
        "--startup-delay-seconds",
        type=float,
        default=DEFAULT_STARTUP_DELAY_SECONDS,
        help=(
            "hot-reload 模式下，相邻实例启动间隔秒数，"
            f"默认: {DEFAULT_STARTUP_DELAY_SECONDS}"
        ),
    )
    parser.add_argument(
        "--machine-start-timeout-seconds",
        type=int,
        default=DEFAULT_MACHINE_START_TIMEOUT_SECONDS,
        help=(
            "hot-reload 模式下，等待单个实例接入 machine daemon 的超时秒数，"
            f"默认: {DEFAULT_MACHINE_START_TIMEOUT_SECONDS}"
        ),
    )
    return parser.parse_args()


def build_windows_executable_path(build_mode: str) -> Path:
    return WINDOWS_RUNNER_DIR / BUILD_MODE_DIRS[build_mode] / "mes_client.exe"


def build_windows_frontend(
    flutter: str,
    env: dict[str, str],
    build_mode: str,
    api_base_url: str,
) -> int:
    build_args = [
        flutter,
        "build",
        "windows",
        f"--{build_mode}",
        f"--dart-define=MES_API_BASE_URL={api_base_url}",
    ]
    return run_command(build_args, FRONTEND_DIR, env)


def launch_frontend_instances(
    executable: Path,
    count: int,
    env: dict[str, str],
) -> list[subprocess.Popen]:
    processes: list[subprocess.Popen] = []
    for index in range(1, count + 1):
        child_env = env.copy()
        child_env["MES_FRONTEND_INSTANCE_INDEX"] = str(index)
        child_env["MES_FRONTEND_INSTANCE_COUNT"] = str(count)
        process = subprocess.Popen(
            [str(executable)],
            cwd=executable.parent,
            env=child_env,
        )
        print(
            f"[INFO] 已启动前端实例 {index}/{count}，PID={process.pid}，"
            f"可执行文件={executable}"
        )
        processes.append(process)
    return processes


def wait_for_processes(processes: list[subprocess.Popen]) -> int:
    tracked = list(processes)
    exit_codes: dict[int, int] = {}

    try:
        while len(exit_codes) < len(tracked):
            for process in tracked:
                if process.pid in exit_codes:
                    continue
                exit_code = process.poll()
                if exit_code is None:
                    continue
                exit_codes[process.pid] = exit_code
                print(f"[INFO] 前端实例退出，PID={process.pid}，退出码={exit_code}")
            if len(exit_codes) < len(tracked):
                time.sleep(1.0)
    except KeyboardInterrupt:
        print("[WARN] 收到中断信号，准备停止所有前端实例。")
        stop_processes(tracked)
        return 130

    non_zero_exit_codes = [code for code in exit_codes.values() if code != 0]
    if non_zero_exit_codes:
        first_error = non_zero_exit_codes[0]
        print(f"[WARN] 至少有一个前端实例异常退出，退出码={first_error}")
        return first_error
    return 0


def stop_processes(processes: list[subprocess.Popen]) -> None:
    for process in processes:
        if process.poll() is None:
            process.terminate()

    deadline = time.monotonic() + 10
    for process in processes:
        if process.poll() is not None:
            continue
        timeout = max(0.0, deadline - time.monotonic())
        try:
            process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            process.kill()


def _is_excluded_relative_dir(relative_dir: Path) -> bool:
    if relative_dir == Path("."):
        return False
    if any(part in SYNC_EXCLUDED_DIR_NAMES for part in relative_dir.parts):
        return True
    return any(
        relative_dir == excluded or relative_dir.is_relative_to(excluded)
        for excluded in SYNC_EXCLUDED_RELATIVE_DIRS
    )


def _should_skip_file(relative_file: Path) -> bool:
    if relative_file.name in SYNC_EXCLUDED_FILE_NAMES:
        return True
    parent = relative_file.parent
    return _is_excluded_relative_dir(parent)


def sync_workspace(source_dir: Path, workspace_dir: Path) -> WorkspaceSyncResult:
    result = WorkspaceSyncResult()
    workspace_dir.mkdir(parents=True, exist_ok=True)

    source_files: set[Path] = set()
    for root, dirs, files in os.walk(source_dir):
        root_path = Path(root)
        relative_root = root_path.relative_to(source_dir)

        filtered_dirs: list[str] = []
        for directory_name in dirs:
            relative_dir = relative_root / directory_name
            if _is_excluded_relative_dir(relative_dir):
                continue
            filtered_dirs.append(directory_name)
        dirs[:] = filtered_dirs

        for file_name in files:
            relative_file = relative_root / file_name
            if _should_skip_file(relative_file):
                continue
            source_files.add(relative_file)

            source_file = source_dir / relative_file
            target_file = workspace_dir / relative_file
            target_file.parent.mkdir(parents=True, exist_ok=True)

            if target_file.exists():
                source_stat = source_file.stat()
                target_stat = target_file.stat()
                if (
                    source_stat.st_size == target_stat.st_size
                    and source_stat.st_mtime_ns == target_stat.st_mtime_ns
                ):
                    continue

            shutil.copy2(source_file, target_file)
            result.copied_count += 1
            result.changed_files.add(str(relative_file).replace("\\", "/"))

    for root, dirs, files in os.walk(workspace_dir, topdown=False):
        root_path = Path(root)
        relative_root = root_path.relative_to(workspace_dir)
        if _is_excluded_relative_dir(relative_root):
            dirs[:] = []
            continue

        for file_name in files:
            relative_file = relative_root / file_name
            if _should_skip_file(relative_file):
                continue
            if relative_file in source_files:
                continue
            target_file = workspace_dir / relative_file
            target_file.unlink(missing_ok=True)
            result.deleted_count += 1
            result.deleted_files.add(str(relative_file).replace("\\", "/"))

        if relative_root == Path("."):
            continue
        if _is_excluded_relative_dir(relative_root):
            continue
        if not any(root_path.iterdir()):
            root_path.rmdir()

    return result


def sync_hot_reload_workspace(source_dir: Path, workspace_dir: Path) -> WorkspaceSyncResult:
    result = sync_workspace(source_dir, workspace_dir)

    workspace_instance_dir = workspace_dir.parent
    for file_name in HOT_RELOAD_SUPPORT_FILES:
        source_file = ROOT_DIR / file_name
        if not source_file.exists():
            continue
        target_file = workspace_instance_dir / file_name
        target_file.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_file, target_file)

    return result


def prepare_hot_reload_workspaces(count: int) -> list[Path]:
    workspaces: list[Path] = []
    for index in range(1, count + 1):
        workspace_dir = HOT_RELOAD_RUNTIME_DIR / f"instance_{index}" / "frontend"
        workspaces.append(workspace_dir)
    return workspaces


def _reader_loop(instance: HotReloadInstance) -> None:
    stdout = instance.process.stdout
    if stdout is None:
        return

    for raw_line in stdout:
        instance.log_handle.write(raw_line)
        instance.log_handle.flush()

        stripped = raw_line.strip()
        if not stripped.startswith("[{") or not stripped.endswith("}]"):
            continue

        try:
            payload = json.loads(stripped)
        except json.JSONDecodeError:
            continue

        if not isinstance(payload, list):
            continue

        for message in payload:
            if not isinstance(message, dict):
                continue
            _handle_machine_message(instance, message)


def _handle_machine_message(instance: HotReloadInstance, message: dict[str, Any]) -> None:
    if "id" in message:
        request_id = message["id"]
        if not isinstance(request_id, int):
            return
        pending = instance.pending_responses.get(request_id)
        if pending is not None:
            pending.put(message)
        return

    event_name = message.get("event")
    params = message.get("params") or {}
    if not isinstance(event_name, str) or not isinstance(params, dict):
        return

    app_id = params.get("appId")
    if isinstance(app_id, str) and app_id:
        instance.app_id = app_id

    if event_name == "app.started":
        instance.started_event.set()


def launch_hot_reload_instances(
    flutter: str,
    env: dict[str, str],
    workspaces: list[Path],
    device: str,
    api_base_url: str,
    startup_delay_seconds: float,
    machine_start_timeout_seconds: int,
    skip_pub_get: bool,
) -> list[HotReloadInstance]:
    instances: list[HotReloadInstance] = []

    log_dir = HOT_RELOAD_RUNTIME_DIR / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)

    for index, workspace_dir in enumerate(workspaces, start=1):
        sync_result = sync_hot_reload_workspace(FRONTEND_DIR, workspace_dir)
        print(
            f"[INFO] 实例 {index} 工作区已同步，"
            f"复制 {sync_result.copied_count} 个文件，删除 {sync_result.deleted_count} 个文件。"
        )

        if not skip_pub_get:
            pub_get_code = run_command([flutter, "pub", "get"], workspace_dir, env)
            if pub_get_code != 0:
                raise RuntimeError(f"实例 {index} 执行 flutter pub get 失败，退出码={pub_get_code}")

        child_env = env.copy()
        child_env["MES_FRONTEND_INSTANCE_INDEX"] = str(index)
        child_env["MES_FRONTEND_INSTANCE_COUNT"] = str(len(workspaces))

        log_path = log_dir / f"instance_{index}.log"
        log_handle = log_path.open("w", encoding="utf-8", errors="replace")
        run_args = [
            flutter,
            "run",
            "--machine",
            "--no-pub",
            "-d",
            device,
            f"--dart-define=MES_API_BASE_URL={api_base_url}",
        ]

        process = subprocess.Popen(
            run_args,
            cwd=workspace_dir,
            env=child_env,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            bufsize=1,
        )

        instance = HotReloadInstance(
            index=index,
            workspace_dir=workspace_dir,
            log_path=log_path,
            process=process,
            log_handle=log_handle,
        )
        reader_thread = threading.Thread(
            target=_reader_loop,
            args=(instance,),
            name=f"frontend-multi-reader-{index}",
            daemon=True,
        )
        instance.reader_thread = reader_thread
        reader_thread.start()

        print(
            f"[INFO] 已启动 hot-reload 实例 {index}/{len(workspaces)}，PID={process.pid}，"
            f"日志={log_path}"
        )
        print(
            f"[INFO] 实例 {index} 正在执行 Flutter Windows 构建。"
            "首次启动可能需要几分钟，窗口会在构建完成后弹出。"
        )

        if not instance.started_event.wait(timeout=machine_start_timeout_seconds):
            raise RuntimeError(
                f"实例 {index} 未在 {machine_start_timeout_seconds}s 内完成启动，"
                f"请查看日志：{log_path}"
            )

        print(f"[INFO] 实例 {index} 已接入 Flutter machine daemon，可接受热重载。")
        instances.append(instance)

        if startup_delay_seconds > 0:
            time.sleep(startup_delay_seconds)

    return instances


def send_machine_request(
    instance: HotReloadInstance,
    method: str,
    params: dict[str, Any],
    timeout_seconds: int = 120,
) -> dict[str, Any]:
    stdin = instance.process.stdin
    if stdin is None:
        raise RuntimeError(f"实例 {instance.index} stdin 不可用。")

    with instance.request_lock:
        request_id = instance.next_request_id
        instance.next_request_id += 1
        response_queue: queue.Queue[dict[str, Any]] = queue.Queue(maxsize=1)
        instance.pending_responses[request_id] = response_queue

        message = [{"id": request_id, "method": method, "params": params}]
        stdin.write(json.dumps(message, ensure_ascii=False) + "\n")
        stdin.flush()

    try:
        response = response_queue.get(timeout=timeout_seconds)
    except queue.Empty as error:
        raise RuntimeError(
            f"实例 {instance.index} 调用 {method} 超时，日志：{instance.log_path}"
        ) from error
    finally:
        instance.pending_responses.pop(request_id, None)

    if "error" in response:
        raise RuntimeError(
            f"实例 {instance.index} 调用 {method} 失败：{response['error']}"
        )
    return response


def rerun_pub_get_if_needed(
    flutter: str,
    env: dict[str, str],
    instances: list[HotReloadInstance],
    sync_results: list[WorkspaceSyncResult],
) -> None:
    dependency_files = {"pubspec.yaml", "pubspec.lock"}
    dependency_changed = any(
        dependency_files.intersection(result.changed_files)
        or dependency_files.intersection(result.deleted_files)
        for result in sync_results
    )
    if not dependency_changed:
        return

    print("[WARN] 检测到 pubspec 相关变更，先为所有实例重新执行 flutter pub get。")
    for instance in instances:
        pub_get_code = run_command([flutter, "pub", "get"], instance.workspace_dir, env)
        if pub_get_code != 0:
            raise RuntimeError(
                f"实例 {instance.index} 重新执行 flutter pub get 失败，退出码={pub_get_code}"
            )


def sync_all_hot_reload_workspaces(
    instances: list[HotReloadInstance],
) -> list[WorkspaceSyncResult]:
    sync_results: list[WorkspaceSyncResult] = []
    total_copied = 0
    total_deleted = 0
    for instance in instances:
        result = sync_hot_reload_workspace(FRONTEND_DIR, instance.workspace_dir)
        sync_results.append(result)
        total_copied += result.copied_count
        total_deleted += result.deleted_count

    print(
        f"[INFO] 本轮同步完成：共复制 {total_copied} 个文件，删除 {total_deleted} 个文件。"
    )
    return sync_results


def broadcast_restart(
    instances: list[HotReloadInstance],
    full_restart: bool,
) -> None:
    action_name = "热重启" if full_restart else "热重载"
    for instance in instances:
        if instance.process.poll() is not None:
            print(f"[WARN] 实例 {instance.index} 已退出，跳过{action_name}。")
            continue
        if not instance.app_id:
            print(f"[WARN] 实例 {instance.index} 尚未拿到 appId，跳过{action_name}。")
            continue

        send_machine_request(
            instance,
            "app.restart",
            {
                "appId": instance.app_id,
                "fullRestart": full_restart,
                "pause": False,
                "reason": "start_frontend_multi.py",
                "debounce": True,
            },
        )
        print(f"[INFO] 实例 {instance.index} 已触发{action_name}。")


def stop_hot_reload_instances(instances: list[HotReloadInstance]) -> None:
    for instance in instances:
        if instance.process.poll() is not None:
            continue
        if instance.app_id:
            try:
                send_machine_request(
                    instance,
                    "app.stop",
                    {"appId": instance.app_id},
                    timeout_seconds=30,
                )
                continue
            except RuntimeError as error:
                print(f"[WARN] 实例 {instance.index} 优雅停止失败：{error}")
        instance.process.terminate()

    deadline = time.monotonic() + 10
    for instance in instances:
        if instance.process.poll() is not None:
            continue
        timeout = max(0.0, deadline - time.monotonic())
        try:
            instance.process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            instance.process.kill()

    for instance in instances:
        if instance.reader_thread is not None:
            instance.reader_thread.join(timeout=1.0)
        instance.log_handle.close()


def print_hot_reload_help() -> None:
    print("[INFO] 热重载控制：r=热重载，R=热重启，h=帮助，q=退出。")


def interactive_hot_reload_loop(
    flutter: str,
    env: dict[str, str],
    instances: list[HotReloadInstance],
) -> int:
    if msvcrt is None:
        raise RuntimeError("hot-reload 模式仅支持 Windows 控制台。")

    print_hot_reload_help()
    first_non_zero_exit: int | None = None

    try:
        while True:
            alive_count = 0
            for instance in instances:
                exit_code = instance.process.poll()
                if exit_code is None:
                    alive_count += 1
                    continue
                if instance.exit_announced:
                    continue
                instance.exit_announced = True
                print(f"[INFO] 实例 {instance.index} 已退出，退出码={exit_code}")
                if exit_code != 0 and first_non_zero_exit is None:
                    first_non_zero_exit = exit_code

            if alive_count == 0:
                return first_non_zero_exit or 0

            if msvcrt.kbhit():
                command = msvcrt.getwch()
                if command == "r":
                    sync_results = sync_all_hot_reload_workspaces(instances)
                    dependency_files = {"pubspec.yaml", "pubspec.lock"}
                    dependency_changed = any(
                        dependency_files.intersection(result.changed_files)
                        or dependency_files.intersection(result.deleted_files)
                        for result in sync_results
                    )
                    if dependency_changed:
                        print("[WARN] 检测到依赖改动，建议按 R 做热重启。")
                    broadcast_restart(instances, full_restart=False)
                elif command == "R":
                    sync_results = sync_all_hot_reload_workspaces(instances)
                    rerun_pub_get_if_needed(flutter, env, instances, sync_results)
                    broadcast_restart(instances, full_restart=True)
                elif command in {"h", "H", "?"}:
                    print_hot_reload_help()
                elif command in {"q", "Q"}:
                    stop_hot_reload_instances(instances)
                    return first_non_zero_exit or 0
            time.sleep(0.2)
    except KeyboardInterrupt:
        print("[WARN] 收到中断信号，准备停止所有 hot-reload 实例。")
        stop_hot_reload_instances(instances)
        return 130


def prepare_runtime_env(args: argparse.Namespace) -> tuple[str, dict[str, str]] | tuple[None, None]:
    flutter = resolve_flutter()
    if not flutter:
        print(
            "[ERROR] 未找到 Flutter 可执行文件。请将 flutter 加入 PATH，"
            "或安装到 C:/tools/flutter。"
        )
        return None, None

    env = build_subprocess_env()
    os.environ["NO_PROXY"] = env["NO_PROXY"]
    os.environ["no_proxy"] = env["no_proxy"]
    print(f"[INFO] 本地地址将绕过代理: {env['NO_PROXY']}")

    if args.skip_bootstrap_admin:
        print("[INFO] 按参数跳过 bootstrap 管理员。")
    else:
        if _is_local_host_url(args.api_base_url):
            print(
                f"[INFO] 等待本地后端健康检查后再 bootstrap，"
                f"超时: {args.wait_backend_seconds}s。"
            )
            if wait_backend_ready(args.api_base_url, args.wait_backend_seconds):
                print("[INFO] 后端健康检查通过。")
            else:
                print("[WARN] 后端健康检查超时，仍会继续尝试 bootstrap。")
        bootstrap_admin(args.api_base_url)

    return flutter, env


def run_exe_mode(args: argparse.Namespace, flutter: str, env: dict[str, str]) -> int:
    if not args.skip_pub_get:
        pub_get_code = run_command([flutter, "pub", "get"], FRONTEND_DIR, env)
        if pub_get_code != 0:
            return pub_get_code

    executable = build_windows_executable_path(args.build_mode)
    if not args.skip_build:
        build_code = build_windows_frontend(
            flutter,
            env,
            args.build_mode,
            args.api_base_url,
        )
        if build_code != 0:
            return build_code

    if not executable.exists():
        print(f"[ERROR] 未找到前端可执行文件: {executable}")
        return 1

    processes = launch_frontend_instances(executable, args.count, env)
    print(
        f"[INFO] 已全部启动 {args.count} 个前端实例。"
        "如需热重载，请改用默认的 hot-reload 模式。"
    )
    return wait_for_processes(processes)


def run_hot_reload_mode(args: argparse.Namespace, flutter: str, env: dict[str, str]) -> int:
    if args.device != "windows":
        print("[WARN] hot-reload 多开默认按 Windows 桌面端设计，其他设备未做专项验证。")

    workspaces = prepare_hot_reload_workspaces(args.count)
    instances: list[HotReloadInstance] = []
    try:
        instances = launch_hot_reload_instances(
            flutter=flutter,
            env=env,
            workspaces=workspaces,
            device=args.device,
            api_base_url=args.api_base_url,
            startup_delay_seconds=args.startup_delay_seconds,
            machine_start_timeout_seconds=args.machine_start_timeout_seconds,
            skip_pub_get=args.skip_pub_get,
        )
        print(
            f"[INFO] 已全部启动 {args.count} 个 hot-reload 前端实例。"
            "在当前终端按 r 可同时热重载，按 R 可同时热重启。"
        )
        return interactive_hot_reload_loop(flutter, env, instances)
    finally:
        if instances:
            stop_hot_reload_instances(instances)


def main() -> int:
    args = parse_args()

    if os.name != "nt":
        print("[ERROR] 该脚本仅支持 Windows 桌面端。")
        return 1

    if args.count < 1:
        print("[ERROR] 实例数量必须大于 0。")
        return 1

    if not FRONTEND_DIR.exists():
        print(f"[ERROR] 前端目录不存在: {FRONTEND_DIR}")
        return 1

    runtime = prepare_runtime_env(args)
    if runtime == (None, None):
        return 1
    flutter, env = runtime
    assert flutter is not None and env is not None

    if args.mode == "exe":
        return run_exe_mode(args, flutter, env)
    return run_hot_reload_mode(args, flutter, env)


if __name__ == "__main__":
    raise SystemExit(main())
