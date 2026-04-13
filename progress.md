# 本地 MCP 安装规划进度

## 2026-04-13

### 会话 1
- 已读取根 `AGENTS.md` 与 `docs/AGENTS/` 全部分册。
- 已读取 `planning-with-files` 与 `writing-plans` 技能，确定本轮采用文件化规划。
- 已检查仓库根目录、`evidence/`、历史 MCP 相关日志。
- 已核实当前关键运行态：
  - `docker mcp server ls` => `No server is enabled`
  - `docker mcp client ls --global` => 多个客户端已注册，但 `claude-code` / `codex` 未连通
  - `claude` 命令不存在
- 当前进入“整理安装顺序、难点、验证口径”阶段。

### 会话 2
- 已补充外部官方资料：
  - Docker MCP Toolkit CLI / Get Started
  - Context7 官方安装说明
  - Serena 官方注册页
  - `modelcontextprotocol/servers` 官方仓库入口
- 已完成本轮书面计划归纳，准备对用户交付。

### 会话 3
- 用户新增硬约束：MCP 不走 Docker 安装。
- 已切换计划方向为“本机原生安装”。
- 正在重排安装来源、顺序与难点说明。

### 会话 4
- 已只读检查 `CC SWITCH` 本地目录：
  - `C:\Users\Donki\AppData\Roaming\com.ccswitch.desktop\app_paths.json`
  - `C:\Users\Donki\AppData\Local\com.ccswitch.desktop\...`
- 当前未发现明确的 MCP 配置文件；仅看到空的 `app_paths.json` 和大量 WebView 缓存数据。
- 结论倾向：可直接写实际客户端配置，但暂不能确认 `CC SWITCH` 是否存在独立 MCP 配置入口。

### 会话 5
- 已安装官方 `cc-switch-cli` 到 `C:\Users\Donki\.local\bin\cc-switch.exe`。
- 已验证 `cc-switch.exe --help`，确认存在 `mcp list/add/edit/delete/sync` 能力。
- 已验证 `cc-switch.exe mcp list`，当前 `CC SWITCH` 中没有任何 MCP server。
- 结论更新：后续可以直接通过 `CC SWITCH` 官方 CLI 录入 MCP。

### 会话 6
- 已完成第一批 5 个 MCP 的本机安装：
  - `@modelcontextprotocol/server-filesystem`
  - `@modelcontextprotocol/server-memory`
  - `@modelcontextprotocol/server-sequential-thinking`
  - `mcp-server-fetch`
  - `mcp-server-git`
- 已把 5 个 MCP 写入 `CC SWITCH` 的 `mcp_servers` 表，并仅给 `Codex` 启用。
- 已执行 `cc-switch.exe --app codex mcp sync`，成功回写到 `C:\Users\Donki\.codex\config.toml`。
- 当前进入“等待用户决定是否继续第二批安装”阶段。

### 会话 7
- 已完成第二批安装与接入整理：
  - 已安装：`@modelcontextprotocol/server-github`、`@playwright/mcp`、`@upstash/context7-mcp`、`@ivotoby/openapi-mcp-server`、`serena-agent`、`@modelcontextprotocol/server-postgres`
- 已写入 `CC SWITCH`：
  - 已启用给 Codex：`context7`、`playwright`、`serena`
  - 已登记待配置：`github`、`openapi`、`postgre`
- 已再次执行 `cc-switch.exe --app codex mcp sync`，Codex live config 与数据库状态一致。

### 会话 8
- 已读取 `backend/.env`、`compose.yml` 与 `backend/app/main.py`，确认：
  - FastAPI 默认端口为 `8000`
  - PostgreSQL 主机口径为 `127.0.0.1:5432`
  - Docker Compose 也将 PostgreSQL 映射到宿主 `5432:5432`
- 已本地生成 `backend/openapi.generated.json`。
- 已启用 `github`、`openapi`、`postgre` 到 `CC SWITCH`，并同步到 Codex。
- 当前 11 个目标 MCP 已全部接入完成。

### 会话 9
- 已读取 `CC SWITCH` 当前 skills 与 repos 状态。
- 已删除全部既有 skills。
- 已重新导入并启用：
  - `planning-with-files`
  - `superpowers`
- 当前 `CC SWITCH -> Codex` 仅保留上述 2 个 skill。
