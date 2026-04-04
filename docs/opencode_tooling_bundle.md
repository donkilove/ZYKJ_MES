# OpenCode 工具能力接入说明

## 目标

本文档说明当前仓库已接入的 OpenCode 工具能力、对应实体、启动方式、环境变量与启用前提。

## 工具清单

| 能力 | 接入实体 | 状态 | 启动方式 | 关键环境变量/前置条件 |
| --- | --- | --- | --- | --- |
| 顺序思考 MCP | `opencode.json > mcp.sequential_thinking` | 已连接 | `npx -y @modelcontextprotocol/server-sequential-thinking` | 需要本机可用 `npx` |
| Context7 文档 MCP | `opencode.json > mcp.context7` | 已连接 | 远程 `https://mcp.context7.com/mcp` | 需要可访问公网 |
| Serena 代码 MCP | `opencode.json > mcp.serena` | 已连接 | `python -m uv tool run --from git+https://github.com/oraios/serena serena start-mcp-server --context ide-assistant` | 需要 `python -m uv` 可用，首次启动需联网下载 |
| Playwright MCP | `opencode.json > mcp.playwright` | 已连接 | `npx -y @playwright/mcp@latest` | 需要本机可用 `npx` |
| PostgreSQL MCP | `opencode.json > mcp.postgres` + `tools/project_toolkit.py postgres-mcp` | 已接入，默认启用 | `python tools/project_toolkit.py postgres-mcp` | 默认按 `MCP_POSTGRES_URL` -> `DB_*` -> `backend/.env` -> `backend/.env.example` 解析本地连接 |
| OpenAPI 校验 | `tools/project_toolkit.py openapi-validate` | 已接入 | `python tools/project_toolkit.py openapi-validate` | 需要本地接口服务可访问，默认 `http://127.0.0.1:8000/openapi.json` |
| Flutter UI/集成测试 | `tools/project_toolkit.py flutter-ui` | 已接入 | `python tools/project_toolkit.py flutter-ui [路径]` | 需要本机可用 `flutter`；默认优先 `frontend/integration_test`，不存在时退回 `frontend/test` |
| GitHub REST API | `tools/project_toolkit.py github-api` | 已接入 | `python tools/project_toolkit.py github-api <endpoint>` | 若存在 `GITHUB_TOKEN` 则自动鉴权；缺失时回退为匿名访问公开 API |
| 文本代码搜索 | `tools/project_toolkit.py code-search` | 已接入 | `python tools/project_toolkit.py code-search <pattern>` | 需要本机可用 `rg`；脚本会优先从 `PATH` 查找，再回退常见 Windows 安装路径 |
| 结构化代码搜索 | `tools/project_toolkit.py code-struct-search` | 已接入 | `python tools/project_toolkit.py code-struct-search <pattern>` | 需要本机可用 `npx`，首次运行会下载 `@ast-grep/cli` |
| 本地 HTTP 探测 | `tools/project_toolkit.py http-probe` | 已接入 | `python tools/project_toolkit.py http-probe <url>` | 仅支持 `http://` 或 `https://` 地址 |
| 中文编码巡检 | `tools/project_toolkit.py encoding-check` | 已接入 | `python tools/project_toolkit.py encoding-check` | 聚合执行 `backend/scripts/check_chinese_mojibake.py` 与 `backend/scripts/check_frontend_chinese_mojibake.py` |

## PostgreSQL MCP 启用方式

当前配置已默认启用 PostgreSQL MCP，本地连接按以下顺序解析：

```json
"postgres": {
  "type": "local",
  "command": [
    "python",
    "tools/project_toolkit.py",
    "postgres-mcp"
  ],
  "enabled": true
}
```

连接信息来源优先级：

1. 直接设置 `MCP_POSTGRES_URL`。
2. 设置 `DB_HOST`、`DB_PORT`、`DB_NAME`、`DB_USER`、`DB_PASSWORD`。
3. 若未设置上述变量，脚本会回退读取 `backend/.env`。
4. 若 `backend/.env` 也不存在或字段不全，再回退读取 `backend/.env.example`。

检查步骤：

1. 确认数据库可访问且凭证有效。
2. 按上述优先级准备本地连接来源；若仓库已有 `backend/.env`，通常无需额外设置。
3. 在当前 Windows 环境执行 `C:\Users\Donki\AppData\Local\OpenCode\opencode-cli.exe mcp list` 确认已加载；若已将 OpenCode CLI 加入 `PATH`，也可直接执行 `opencode mcp list`。

## 常用示例

```bash
python tools/project_toolkit.py openapi-validate
python tools/project_toolkit.py flutter-ui
python tools/project_toolkit.py github-api repos/octocat/Hello-World
python tools/project_toolkit.py code-search "router" backend --include "*.py"
python tools/project_toolkit.py code-struct-search "requests.get($URL)" backend
python tools/project_toolkit.py http-probe http://127.0.0.1:8000/health
python tools/project_toolkit.py encoding-check
```

## 说明

- Serena 与 Playwright 首次运行都可能触发依赖下载，耗时取决于网络。
- `openapi-validate` 仅负责抓取并调用 Redocly 校验，不负责启动后端服务。
- `flutter-ui` 默认优先执行 `frontend/integration_test`，若仓库中不存在该目录，则自动退回 `frontend/test`；也允许在路径后继续透传 `flutter test` 参数。
- `github-api` 在无 `GITHUB_TOKEN` 时会打印一条简短提示到标准错误，并继续访问公开 GitHub API。
- `code-search` 依赖 ripgrep；当前环境若未将 `rg` 加入 `PATH`，脚本也会尝试定位常见 Windows 安装路径。若本机尚未安装，可执行 `winget install BurntSushi.ripgrep --accept-source-agreements --accept-package-agreements`。
- `code-search` 与 `code-struct-search` 都支持附加原生命令参数，便于细化检索。
- 无迁移，直接替换。
