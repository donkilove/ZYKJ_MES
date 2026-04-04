# 指挥官执行留痕：五项工具定向配置（2026-04-03）

## 1. 任务信息

- 任务名称：定向配置 `postgres`、`github-api`、`openapi-validate`、`code-search`、`flutter-ui`
- 执行日期：2026-04-03
- 执行方式：指挥官模式
- 当前状态：进行中

## 2. 输入来源

- 用户指令：`帮我配置好postgres、github-api、openapi-validate、code-search、flutter-ui，你不清楚的就用问题工具问我`

## 3. 已知事实

- 证据 C1：`opencode.json`
  - 结论：`postgres` 已接入但 `enabled: false`；其余 4 项已通过 `tools/project_toolkit.py` 提供脚本入口。
- 证据 C2：`tools/project_toolkit.py`
  - 结论：
    - `openapi-validate` 默认 URL 为 `http://127.0.0.1:8000/openapi.json`
    - `flutter-ui` 会优先使用 `frontend/integration_test`，不存在时退回 `frontend/test`
    - `github-api` 依赖 `GITHUB_TOKEN`
    - `code-search` 依赖 `rg`
    - `postgres-mcp` 可从 `MCP_POSTGRES_URL` 或 `DB_*` 构造连接串
- 证据 C3：仓库文件检查
  - 结论：存在 `backend/.env`，说明本地可能已有数据库实际配置；当前不存在 `frontend/integration_test/`，因此 `flutter-ui` 实际将退回 `frontend/test`
- 证据 C4：本机命令检查
  - 结论：`flutter` 可用；`rg` 当前不可用，需安装或改接其他路径

## 4. 当前待用户确认项

1. `postgres`：用户确认直接使用当前仓库已有的 `backend/.env` 数据库配置并启用 MCP。
2. `github-api`：用户确认先支持公开 GitHub API；若存在 `GITHUB_TOKEN` 则自动鉴权，否则以匿名方式请求公开接口。
3. `openapi-validate`：用户确认沿用默认地址 `http://127.0.0.1:8000/openapi.json`。
4. `code-search`：用户允许本机补装 `ripgrep`。

## 5. 当前计划

1. 收集用户确认项。
2. 派发实现子 agent：
   - 启用或细化 `postgres`
   - 为 `github-api` 落地“有 token 鉴权、无 token 匿名公开 API”策略
   - 固化 `openapi-validate` / `flutter-ui` / `code-search` 默认行为
   - 安装 `rg`（若用户未反对）
3. 派发验证子 agent 独立复检。

## 6. 实施摘要

- 实现子 agent 已完成以下改动：
  - `opencode.json`：将 `mcp.postgres.enabled` 改为 `true`
  - `tools/project_toolkit.py`：
    - `postgres-mcp` 按 `MCP_POSTGRES_URL -> DB_* -> backend/.env -> backend/.env.example` 构造连接串
    - `github-api` 改为无 `GITHUB_TOKEN` 时仍可匿名访问公开 GitHub API
    - `code-search` 增加 `rg` 自动定位逻辑，兼容 Windows 常见安装路径
    - `flutter-ui` / `openapi-validate` 帮助文案与当前默认行为对齐
  - `docs/opencode_tooling_bundle.md`：同步更新上述默认行为与前置条件
- 环境处理：已补装 `ripgrep`，并验证当前环境下可被脚本定位执行。

## 7. 验证闭环

### 7.1 首轮独立验证

- 结论：不通过。
- 失败项 F1：`openapi-validate --help` 未明确显示默认 URL `http://127.0.0.1:8000/openapi.json`，导致帮助/文档/代码不完全一致。

### 7.2 修复重派

- 修复项 R1：将 `tools/project_toolkit.py` 中 `openapi-validate` 的 `--url` 帮助改为显式包含默认值。

### 7.3 二轮独立验证

- 结论：通过。
- 关键验证结果：
  - `python tools/project_toolkit.py openapi-validate --help` 明确显示默认 URL
  - `C:\Users\Donki\AppData\Local\OpenCode\opencode-cli.exe mcp list` 显示 `postgres connected`
  - `github-api`、`code-search`、`flutter-ui` 的帮助、代码与文档一致

## 8. 最终结论

- 本轮已完成用户指定的 5 项工具定向配置。
- 当前结果：
  - `postgres`：已启用并连接
  - `github-api`：已支持匿名公开 API；若后续存在 `GITHUB_TOKEN` 则自动鉴权
  - `openapi-validate`：默认地址固定为 `http://127.0.0.1:8000/openapi.json`
  - `code-search`：已可用，支持 Windows 下 `rg` 自动定位
  - `flutter-ui`：当前仓库默认回退到 `frontend/test`
- 无迁移，直接替换。
