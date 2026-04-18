from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Sequence

try:
    from perf.backend_capacity_gate import run_backend_capacity_gate
except ModuleNotFoundError:  # pragma: no cover - python -m tools.project_toolkit 场景
    from tools.perf.backend_capacity_gate import run_backend_capacity_gate


# 命令行帮助改用 ASCII-first，规避 Windows 控制台中文乱码。
REPO_ROOT = Path(__file__).resolve().parents[1]
BACKEND_ENV = REPO_ROOT / "backend" / ".env"
BACKEND_ENV_EXAMPLE = REPO_ROOT / "backend" / ".env.example"
BACKEND_MOJIBAKE_SCRIPT = REPO_ROOT / "backend" / "scripts" / "check_chinese_mojibake.py"
FRONTEND_MOJIBAKE_SCRIPT = (
    REPO_ROOT / "backend" / "scripts" / "check_frontend_chinese_mojibake.py"
)
DEFAULT_OPENAPI_URL = "http://127.0.0.1:8000/openapi.json"


def _print_error(message: str) -> None:
    print(message, file=sys.stderr)


def _run_command(command: Sequence[str], cwd: Path | None = None) -> int:
    completed = subprocess.run(list(command), cwd=str(cwd) if cwd else None)
    return completed.returncode


def _load_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def _load_env_example() -> dict[str, str]:
    return _load_env_file(BACKEND_ENV_EXAMPLE)


def _load_backend_env() -> dict[str, str]:
    return _load_env_file(BACKEND_ENV)


def _build_postgres_url() -> str:
    direct_url = os.getenv("MCP_POSTGRES_URL")
    if direct_url:
        return direct_url

    backend_env = _load_backend_env()
    defaults = _load_env_example()
    host = os.getenv("DB_HOST") or backend_env.get("DB_HOST") or defaults.get("DB_HOST")
    port = os.getenv("DB_PORT") or backend_env.get("DB_PORT") or defaults.get("DB_PORT") or "5432"
    db_name = os.getenv("DB_NAME") or backend_env.get("DB_NAME") or defaults.get("DB_NAME")
    user = os.getenv("DB_USER") or backend_env.get("DB_USER") or defaults.get("DB_USER")
    password = os.getenv("DB_PASSWORD")
    if password is None:
        password = backend_env.get("DB_PASSWORD")
    if password is None:
        password = defaults.get("DB_PASSWORD")

    missing = [
        name
        for name, value in {
            "DB_HOST": host,
            "DB_PORT": port,
            "DB_NAME": db_name,
            "DB_USER": user,
            "DB_PASSWORD": password,
        }.items()
        if value is None
    ]
    if missing:
        raise ValueError(
            "缺少 PostgreSQL 连接信息，请设置 MCP_POSTGRES_URL 或补齐环境变量："
            + ", ".join(missing)
        )

    user_info = urllib.parse.quote(user, safe="")
    if password:
        user_info = f"{user_info}:{urllib.parse.quote(password, safe='')}"
    return (
        f"postgresql://{user_info}@{host}:{port}/"
        f"{urllib.parse.quote(db_name, safe='')}"
    )


def _find_npx_binary() -> str:
    for candidate_name in ("npx.cmd", "npx.exe", "npx"):
        path_binary = shutil.which(candidate_name)
        if path_binary:
            return path_binary

    program_files = os.getenv("ProgramFiles", r"C:\Program Files")
    candidates = [
        Path(program_files) / "nodejs" / "npx.cmd",
        Path(program_files) / "nodejs" / "npx.exe",
    ]
    for candidate in candidates:
        if candidate.exists():
            return str(candidate)

    raise FileNotFoundError("未找到 npx。请确认 Node.js 已安装且 npx 可用。")


def _find_rg_binary() -> str:
    path_binary = shutil.which("rg")
    if path_binary:
        return path_binary

    local_app_data = os.getenv("LOCALAPPDATA", "")
    program_files = os.getenv("ProgramFiles", r"C:\Program Files")
    user_profile = os.getenv("USERPROFILE", "")
    candidates = [
        Path(local_app_data) / "Microsoft" / "WinGet" / "Links" / "rg.exe",
        Path(local_app_data) / "Programs" / "ripgrep" / "rg.exe",
        Path(program_files) / "ripgrep" / "rg.exe",
        Path(program_files) / "Git" / "usr" / "bin" / "rg.exe",
        Path(user_profile) / "scoop" / "apps" / "ripgrep" / "current" / "rg.exe",
    ]
    for candidate in candidates:
        if str(candidate) and candidate.exists():
            return str(candidate)

    raise FileNotFoundError(
        "未找到 ripgrep (`rg`)。请先安装 ripgrep，或将 rg.exe 加入 PATH；Windows 可尝试运行 `winget install BurntSushi.ripgrep --accept-source-agreements --accept-package-agreements`。"
    )


def _default_flutter_target() -> Path:
    integration_dir = REPO_ROOT / "frontend" / "integration_test"
    if integration_dir.exists():
        return integration_dir
    return REPO_ROOT / "frontend" / "test"


def _parse_headers(raw_headers: list[str] | None) -> dict[str, str]:
    headers: dict[str, str] = {}
    for item in raw_headers or []:
        if ":" not in item:
            raise ValueError(f"请求头格式错误：{item}，应为 Key: Value")
        key, value = item.split(":", 1)
        headers[key.strip()] = value.strip()
    return headers


def cmd_postgres_mcp(args: argparse.Namespace) -> int:
    try:
        database_url = _build_postgres_url()
        npx_binary = _find_npx_binary()
    except ValueError as error:
        _print_error(str(error))
        return 2
    except FileNotFoundError as error:
        _print_error(str(error))
        return 2

    command = [
        npx_binary,
        "-y",
        "@modelcontextprotocol/server-postgres",
        database_url,
        *args.extra_args,
    ]
    return _run_command(command, cwd=REPO_ROOT)


def cmd_openapi_validate(args: argparse.Namespace) -> int:
    try:
        npx_binary = _find_npx_binary()
    except FileNotFoundError as error:
        _print_error(str(error))
        return 2

    try:
        with urllib.request.urlopen(args.url, timeout=args.timeout) as response:
            payload = response.read()
    except urllib.error.URLError as error:
        _print_error(
            f"抓取 OpenAPI 文档失败：{error}. 请确认本地服务已启动，或通过 --url 指定可访问地址。"
        )
        return 2

    with tempfile.NamedTemporaryFile(delete=False, suffix=".json") as temp_file:
        temp_file.write(payload)
        temp_path = Path(temp_file.name)

    try:
        command = [
            npx_binary,
            "-y",
            "@redocly/cli",
            "lint",
            str(temp_path),
        ]
        return _run_command(command, cwd=REPO_ROOT)
    finally:
        temp_path.unlink(missing_ok=True)


def cmd_flutter_ui(args: argparse.Namespace) -> int:
    target = Path(args.path).resolve() if args.path else _default_flutter_target()
    if not target.exists():
        _print_error(f"Flutter 测试路径不存在：{target}")
        return 2

    command = ["flutter", "test", str(target), *args.extra_args]
    return _run_command(command, cwd=REPO_ROOT / "frontend")


def cmd_github_api(args: argparse.Namespace) -> int:
    token = os.getenv("GITHUB_TOKEN")

    url = urllib.parse.urljoin("https://api.github.com/", args.endpoint.lstrip("/"))
    request = urllib.request.Request(url, method=args.method.upper())
    request.add_header("Accept", "application/vnd.github+json")
    if token:
        request.add_header("Authorization", f"Bearer {token}")
    else:
        _print_error("未设置 GITHUB_TOKEN，改为匿名访问公开 GitHub API。")
    if args.body:
        request.add_header("Content-Type", "application/json")
        request.data = args.body.encode("utf-8")

    try:
        with urllib.request.urlopen(request, timeout=args.timeout) as response:
            body = response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as error:
        error_body = error.read().decode("utf-8", errors="replace")
        _print_error(f"GitHub API 调用失败：HTTP {error.code}\n{error_body}")
        return 1
    except urllib.error.URLError as error:
        _print_error(f"GitHub API 调用失败：{error}")
        return 1

    print(body)
    return 0


def cmd_code_search(args: argparse.Namespace) -> int:
    try:
        rg_binary = _find_rg_binary()
    except FileNotFoundError as error:
        _print_error(str(error))
        return 2

    command = [rg_binary, args.pattern]
    if args.include:
        command.extend(["-g", args.include])
    if args.count:
        command.append("--count")
    if args.stats:
        command.append("--stats")
    if args.ignore_case:
        command.append("-i")
    if args.files_with_matches:
        command.append("-l")
    command.extend(args.extra_args)
    command.append(args.path)
    return _run_command(command, cwd=REPO_ROOT)


def cmd_code_struct_search(args: argparse.Namespace) -> int:
    try:
        npx_binary = _find_npx_binary()
    except FileNotFoundError as error:
        _print_error(str(error))
        return 2

    command = [
        npx_binary,
        "-y",
        "@ast-grep/cli",
        "scan",
        "--pattern",
        args.pattern,
        *args.extra_args,
        args.path,
    ]
    return _run_command(command, cwd=REPO_ROOT)


def cmd_http_probe(args: argparse.Namespace) -> int:
    if not args.url.startswith(("http://", "https://")):
        _print_error("http-probe 仅支持 HTTP/HTTPS URL。")
        return 2

    try:
        headers = _parse_headers(args.header)
    except ValueError as error:
        _print_error(str(error))
        return 2

    data: bytes | None = None
    if args.json_body is not None:
        try:
            json_payload = json.dumps(json.loads(args.json_body), ensure_ascii=False).encode("utf-8")
        except json.JSONDecodeError as error:
            _print_error(f"JSON Body 解析失败：{error}")
            return 2
        data = json_payload
        headers.setdefault("Content-Type", "application/json")

    request = urllib.request.Request(args.url, data=data, method=args.method.upper())
    for key, value in headers.items():
        request.add_header(key, value)

    try:
        with urllib.request.urlopen(request, timeout=args.timeout) as response:
            body = response.read().decode("utf-8", errors="replace")
            print(f"HTTP {response.status}")
            print(body)
            return 0
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        _print_error(f"HTTP {error.code}")
        if body:
            _print_error(body)
        return 1
    except urllib.error.URLError as error:
        _print_error(f"请求失败：{error}")
        return 1


def cmd_encoding_check(args: argparse.Namespace) -> int:
    scripts = [
        [sys.executable, str(BACKEND_MOJIBAKE_SCRIPT)],
        [sys.executable, str(FRONTEND_MOJIBAKE_SCRIPT)],
    ]
    if args.fix:
        for command in scripts:
            command.append("--fix")

    exit_code = 0
    for command in scripts:
        result = subprocess.run(command, cwd=str(REPO_ROOT))
        if result.returncode != 0:
            exit_code = result.returncode
    return exit_code


def cmd_backend_capacity_gate(args: argparse.Namespace) -> int:
    return run_backend_capacity_gate(args)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Project toolkit for local OpenCode-related development and validation tasks."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    postgres_parser = subparsers.add_parser(
        "postgres-mcp",
        help="Launch the PostgreSQL MCP wrapper.",
        description="Build a PostgreSQL connection URL and forward to server-postgres. Resolution order: MCP_POSTGRES_URL -> DB_* env vars -> backend/.env -> backend/.env.example.",
    )
    postgres_parser.add_argument(
        "extra_args",
        nargs=argparse.REMAINDER,
        help="Extra arguments passed through to @modelcontextprotocol/server-postgres.",
    )
    postgres_parser.set_defaults(func=cmd_postgres_mcp)

    openapi_parser = subparsers.add_parser(
        "openapi-validate",
        help="Fetch and validate an OpenAPI document.",
    )
    openapi_parser.add_argument("--url", default=DEFAULT_OPENAPI_URL, help="OpenAPI JSON URL. Default: %(default)s")
    openapi_parser.add_argument("--timeout", type=int, default=15, help="HTTP timeout in seconds.")
    openapi_parser.set_defaults(func=cmd_openapi_validate)

    flutter_parser = subparsers.add_parser(
        "flutter-ui",
        help="Run Flutter UI or integration tests. Default target is frontend/integration_test, then frontend/test if integration_test is absent.",
        description="Run Flutter UI or integration tests. Default target is frontend/integration_test, then frontend/test if integration_test is absent.",
    )
    flutter_parser.add_argument("path", nargs="?", help="Optional test file or directory.")
    flutter_parser.set_defaults(func=cmd_flutter_ui)

    github_parser = subparsers.add_parser(
        "github-api",
        help="Call the GitHub REST API. Uses GITHUB_TOKEN when present and falls back to anonymous public API access when absent.",
        description="Call the GitHub REST API. Uses GITHUB_TOKEN when present and falls back to anonymous public API access when absent.",
    )
    github_parser.add_argument("endpoint", help="REST endpoint, for example repos/owner/repo/issues.")
    github_parser.add_argument("--method", default="GET", help="HTTP method. Default: GET.")
    github_parser.add_argument("--body", help="JSON string request body.")
    github_parser.add_argument("--timeout", type=int, default=20, help="HTTP timeout in seconds.")
    github_parser.set_defaults(func=cmd_github_api)

    search_parser = subparsers.add_parser(
        "code-search",
        help="Run ripgrep-based code search. Locates rg from PATH first, then common Windows install locations.",
        description="Run ripgrep-based code search. Locates rg from PATH first, then common Windows install locations.",
    )
    search_parser.add_argument("pattern", help="ripgrep search pattern.")
    search_parser.add_argument("path", nargs="?", default=".", help="Search path. Default: repository root.")
    search_parser.add_argument("--include", help="File glob filter, for example *.py.")
    search_parser.add_argument("--count", action="store_true", help="Show match count for each file.")
    search_parser.add_argument("--stats", action="store_true", help="Show ripgrep statistics.")
    search_parser.add_argument("--ignore-case", action="store_true", help="Ignore case.")
    search_parser.add_argument(
        "--files-with-matches",
        action="store_true",
        help="Show only file paths with matches.",
    )
    search_parser.set_defaults(func=cmd_code_search)

    struct_parser = subparsers.add_parser(
        "code-struct-search",
        help="Run ast-grep structural search.",
        description="Run ast-grep structural search.",
    )
    struct_parser.add_argument("pattern", help="ast-grep pattern.")
    struct_parser.add_argument("path", nargs="?", default=".", help="Scan path. Default: repository root.")
    struct_parser.set_defaults(func=cmd_code_struct_search)

    probe_parser = subparsers.add_parser(
        "http-probe",
        help="Run a local HTTP probe.",
    )
    probe_parser.add_argument("url", help="Target URL to probe.")
    probe_parser.add_argument("--method", default="GET", help="HTTP method. Default: GET.")
    probe_parser.add_argument(
        "--header",
        action="append",
        help="Request header in 'Key: Value' format. Repeat as needed.",
    )
    probe_parser.add_argument("--json-body", help="JSON string request body.")
    probe_parser.add_argument("--timeout", type=int, default=15, help="HTTP timeout in seconds.")
    probe_parser.set_defaults(func=cmd_http_probe)

    encoding_parser = subparsers.add_parser(
        "encoding-check",
        help="Run the encoding/mojibake checks.",
    )
    encoding_parser.add_argument("--fix", action="store_true", help="Try to automatically fix recognized mojibake.")
    encoding_parser.set_defaults(func=cmd_encoding_check)

    capacity_parser = subparsers.add_parser(
        "backend-capacity-gate",
        help="Run backend container capacity gate with multi-token and session-pool load.",
        description="Run backend capacity gate against built-in scenarios or custom scenarios from JSON config.",
    )
    capacity_parser.add_argument(
        "--base-url",
        default="http://127.0.0.1:8000",
        help="Backend base URL. Default: %(default)s",
    )
    capacity_parser.add_argument(
        "--gate-mode",
        choices=("read", "write"),
        default="read",
        help="Gate mode. Default: %(default)s",
    )
    capacity_parser.add_argument(
        "--scenarios",
        default="login,authz,users,production-orders,production-stats",
        help="Comma-separated scenario names. Can mix built-in scenarios and names loaded from --scenario-config-file. Default: %(default)s",
    )
    capacity_parser.add_argument(
        "--scenario-config-file",
        help="Optional JSON scenario config path. Supports top-level token_pools plus scenario fields: name, method, path, requires_auth, role_domain, token_pool, headers, query, json_body, form_body, success_statuses.",
    )
    capacity_parser.add_argument(
        "--sample-context-file",
        help="Optional sample context JSON used to replace {sample:key} placeholders.",
    )
    capacity_parser.add_argument(
        "--duration-seconds",
        type=int,
        default=90,
        help="Measured duration in seconds (excluding warmup). Default: %(default)s",
    )
    capacity_parser.add_argument(
        "--concurrency",
        type=int,
        default=40,
        help="Concurrent workers. Default: %(default)s",
    )
    capacity_parser.add_argument(
        "--spawn-rate",
        type=float,
        default=10.0,
        help="Worker ramp-up rate (workers/second). Default: %(default)s",
    )
    capacity_parser.add_argument(
        "--token-count",
        type=int,
        default=40,
        help="Token pool size. Default: %(default)s",
    )
    capacity_parser.add_argument(
        "--session-pool-size",
        type=int,
        default=20,
        help="HTTP session pool size. Default: %(default)s",
    )
    capacity_parser.add_argument(
        "--login-user-prefix",
        default="loadtest_",
        help="Login username prefix used for token acquisition and login scenario. Default: %(default)s",
    )
    capacity_parser.add_argument(
        "--password",
        default=os.getenv("LOADTEST_PASSWORD", "Admin@123456"),
        help="Login password. Default reads LOADTEST_PASSWORD, fallback Admin@123456.",
    )
    capacity_parser.add_argument(
        "--token-file",
        help="Optional token file path, one token per line.",
    )
    capacity_parser.add_argument(
        "--warmup-seconds",
        type=int,
        default=15,
        help="Warmup duration in seconds. Default: %(default)s",
    )
    capacity_parser.add_argument(
        "--p95-ms",
        type=float,
        default=500.0,
        help="P95 latency threshold in milliseconds. Default: %(default)s",
    )
    capacity_parser.add_argument(
        "--error-rate-threshold",
        type=float,
        default=0.05,
        help="Allowed error-rate threshold in [0,1). Default: %(default)s",
    )
    capacity_parser.add_argument(
        "--output-json",
        help="Optional output JSON path.",
    )
    capacity_parser.add_argument(
        "--request-timeout-seconds",
        type=float,
        default=10.0,
        help="HTTP request timeout in seconds. Default: %(default)s",
    )
    capacity_parser.set_defaults(func=cmd_backend_capacity_gate)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args, extra_args = parser.parse_known_args(argv)
    if not hasattr(args, "extra_args"):
        args.extra_args = []
    args.extra_args.extend(extra_args)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
