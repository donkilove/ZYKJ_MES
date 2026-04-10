# OpenCode 工具能力接入说明

## 目标

本文档说明当前仓库已接入的 OpenCode 工具能力、对应实体、启动方式、环境变量与启用前提。
项目根目录 `opencode.json` 已移除，不再作为仓库内配置来源；本文档保留为能力索引与本地包装命令说明。默认强制优先使用 Docker 提供的宿主 MCP 工具，统一口径为 `MCP_DOCKER`；MCP 可用性以当前宿主环境实际注入结果为准。

## 工具清单

| 能力 | 接入实体 | 状态 | 启动方式 | 关键环境变量/前置条件 |
| --- | --- | --- | --- | --- |
| 顺序思考 MCP | `MCP_DOCKER Sequential Thinking` | 默认主线 | 宿主注入 | 需 Docker 宿主已提供对应 MCP 能力 |
| Context7 文档 MCP | `MCP_DOCKER Context7` | 默认主线 | 宿主注入 | 需 Docker 宿主已提供对应 MCP 能力 |
| 结构化代码搜索 | `MCP_DOCKER ast-grep` | 默认主线 | 宿主注入 | 需 Docker 宿主已提供对应 MCP 能力 |
| Playwright MCP | `MCP_DOCKER Playwright` | 默认主线 | 宿主注入 | 需 Docker 宿主已提供对应 MCP 能力 |
| 数据库能力 | `MCP_DOCKER database-server` | 默认主线 | 宿主注入 | 需 Docker 宿主已提供对应 MCP 能力与数据库访问权限 |
| OpenAPI / 契约能力 | `MCP_DOCKER OpenAPI Toolkit` | 默认主线 | 宿主注入 | 需 Docker 宿主已提供对应 MCP 能力 |
| Git / GitHub 能力 | `MCP_DOCKER Git / GitHub` | 默认主线 | 宿主注入 | 需 Docker 宿主已提供对应 MCP 能力与相应权限 |
| 网页抓取补充 | `MCP_DOCKER Fetch` | 默认补充主线 | 宿主注入 | 在前述 `MCP_DOCKER` 能力不足时补充抓取 |
| 文件系统访问补充 | `MCP_DOCKER Filesystem` | 默认补充主线 | 宿主注入 | 用于目录访问、本地文件读取与受控写入；若受更高优先级文件工具约束，以更高优先级为准 |
| 长期上下文补充 | `MCP_DOCKER Memory` | 默认补充主线 | 宿主注入 | 用于跨任务稳定偏好、模块关系与长期上下文补充，不替代正式留痕 |
| PostgreSQL 本地包装命令 | `tools/project_toolkit.py postgres-mcp` | 降级/补偿 | `python tools/project_toolkit.py postgres-mcp` | 仅在所需 `MCP_DOCKER database-server` 缺失、未配置、不可达、权限不足，或受更高优先级指令约束无法使用时启用 |
| OpenAPI 校验（包装命令，非独立 MCP） | `tools/project_toolkit.py openapi-validate` | 降级/补偿 | `python tools/project_toolkit.py openapi-validate` | 需要本地接口服务可访问，默认 `http://127.0.0.1:8000/openapi.json` |
| Flutter UI/集成测试（包装命令，非独立 MCP） | `tools/project_toolkit.py flutter-ui` | 降级/补偿 | `python tools/project_toolkit.py flutter-ui [路径]` | 需要本机可用 `flutter`；默认优先 `frontend/integration_test`，不存在时退回 `frontend/test` |
| GitHub REST API | `tools/project_toolkit.py github-api` | 降级/补偿 | `python tools/project_toolkit.py github-api <endpoint>` | 若存在 `GITHUB_TOKEN` 则自动鉴权；缺失时回退为匿名访问公开 API |
| 文本代码搜索 | `tools/project_toolkit.py code-search` | 降级/补偿 | `python tools/project_toolkit.py code-search <pattern>` | 需要本机可用 `rg`；脚本会优先从 `PATH` 查找，再回退常见 Windows 安装路径 |
| 结构化代码搜索（本地包装） | `tools/project_toolkit.py code-struct-search` | 降级/补偿 | `python tools/project_toolkit.py code-struct-search <pattern>` | 需要本机可用 `npx`，首次运行会下载 `@ast-grep/cli` |
| 本地 HTTP 探测（包装命令，非独立 MCP） | `tools/project_toolkit.py http-probe` | 降级/补偿 | `python tools/project_toolkit.py http-probe <url>` | 仅支持 `http://` 或 `https://` 地址 |
| 中文编码巡检 | `tools/project_toolkit.py encoding-check` | 降级/补偿 | `python tools/project_toolkit.py encoding-check` | 聚合执行 `backend/scripts/check_chinese_mojibake.py` 与 `backend/scripts/check_frontend_chinese_mojibake.py` |

## 数据库能力降级方式

当前仓库不再维护项目级 `opencode.json`。默认应优先使用 `MCP_DOCKER database-server`。仅当所需 `MCP_DOCKER` 数据库能力缺失、未配置、不可达、权限不足，或受更高优先级指令约束无法使用时，才使用本地包装命令 `python tools/project_toolkit.py postgres-mcp`；此时仍按以下顺序解析本地连接：

连接信息来源优先级：

1. 直接设置 `MCP_POSTGRES_URL`。
2. 设置 `DB_HOST`、`DB_PORT`、`DB_NAME`、`DB_USER`、`DB_PASSWORD`。
3. 若未设置上述变量，脚本会回退读取 `backend/.env`。
4. 若 `backend/.env` 也不存在或字段不全，再回退读取 `backend/.env.example`。

检查步骤：

1. 确认数据库可访问且凭证有效。
2. 按上述优先级准备本地连接来源；若仓库已有 `backend/.env`，通常无需额外设置。
3. 若当前通过 OpenCode 宿主运行，可执行 `C:\Users\Donki\AppData\Local\OpenCode\opencode-cli.exe mcp list` 确认宿主侧已加载所需 `MCP_DOCKER` 工具；若已将 OpenCode CLI 加入 `PATH`，也可直接执行 `opencode mcp list`。

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

- 默认主线为 Docker 提供的宿主 MCP 工具，统一口径为 `MCP_DOCKER`；本地包装命令仅作为降级/补偿手段，不是默认 MCP 主线。
- 若所需 `MCP_DOCKER` 工具缺失、未配置、不可达、权限不足，或受更高优先级指令约束无法使用，必须在前置说明中写明缺失工具、原因、替代工具与影响范围，并在 `evidence/` 中同步留痕。
- `MCP_DOCKER Memory` 只能作为长期上下文补充，不能替代 `AGENTS.md`、`evidence/` 与仓库文档；`MCP_DOCKER Filesystem` 若受更高优先级文件工具约束，以更高优先级为准。
- `openapi-validate`、`http-probe`、`flutter-ui` 均由 `tools/project_toolkit.py` 暴露为本地包装命令，不是额外独立 MCP。
- `openapi-validate` 仅负责抓取并调用 Redocly 校验，不负责启动后端服务。
- `flutter-ui` 默认优先执行 `frontend/integration_test`，若仓库中不存在该目录，则自动退回 `frontend/test`；也允许在路径后继续透传 `flutter test` 参数。当前前端测试主线为 `integration_test`。
- `github-api` 在无 `GITHUB_TOKEN` 时会打印一条简短提示到标准错误，并继续访问公开 GitHub API。
- `code-search` 依赖 ripgrep；当前环境若未将 `rg` 加入 `PATH`，脚本也会尝试定位常见 Windows 安装路径。若本机尚未安装，可执行 `winget install BurntSushi.ripgrep --accept-source-agreements --accept-package-agreements`。
- `code-search` 与 `code-struct-search` 都支持附加原生命令参数，便于细化检索。
- 主机辅助工具 `Bruno`、`gh`、`Trivy`、`Syft`、`mitmproxy/Fiddler`、`WinAppDriver` 的已安装与已验证状态见 `docs/host_tooling_bundle.md`；`FlaUInspect` 已弃用，仅历史保留。
- 无迁移，直接替换。
