# 本地 MCP 安装规划发现

## 2026-04-13 当前发现

1. 仓库根目录当前不存在 `.mcp.json`，说明本项目目前没有生效中的项目级 MCP 配置文件。
2. `C:\Users\Donki\.claude.json` 中 `mcpServers` 为空，未见可直接复用的用户级 MCP server 定义。
3. `docker mcp client ls --global` 显示：
   - `continue`、`cursor`、`lmstudio`、`vscode` 已连接 `MCP_DOCKER`
   - `claude-code`、`codex`、`gemini`、`goose`、`opencode` 处于 disconnected
4. `docker mcp server ls` 当前返回 `No server is enabled`，说明 Docker 侧并未启用目标 server。
5. `docker mcp config read` 当前可见配置项只有：
   - `ast-grep`
   - `database-server`
   - `filesystem`
   - `openapi`
   - `git`
6. `claude` 命令当前不可用，系统提示需要执行 `npm install -g @anthropic-ai/claude-code`。
7. 历史 evidence 已经出现过以下长期难点：
   - `sequential_thinking`、`serena`、`postgres`、`context7`、`playwright` 曾被列为“应补齐但当前不可用”
   - Docker / 客户端接入和“宿主安装”不是同一件事，服务启用、客户端注册、CLI 可见性需要分别验证

## 初步判断

1. 这次安装不能当成“批量 npm install”类简单任务处理。
2. 需要拆成三层：
   - Docker 端 server 启用
   - 客户端接入与命令可见
   - 每个 MCP 的专属凭据或运行时依赖
3. 难点最高的不是 `git`、`filesystem`、`fetch` 这类本地或只读型能力，而是：
   - `github`
   - `playwright`
   - `postgre`
   - `context7`
   - `serena`
4. `memory`、`sequential thinking` 这类能力是否走 Docker 官方目录、第三方 server、还是客户端自带扩展，需要在正式安装前先统一来源。

## 2026-04-13 外部资料补证

1. Docker 官方文档说明：
   - Docker Desktop 4.62 及以上版本支持 MCP Toolkit。
   - CLI 路径已经从简单的 `docker mcp server enable <server>` 演进到 profile 体系。
   - 官方 CLI 文档推荐：
     - 先 `docker mcp profile create --name <profile-id>`
     - 再 `docker mcp profile server add <profile-id> --server catalog://mcp/docker-mcp-catalog/<server-id>`
2. Docker 官方示例明确给出了 `github-official` 和 `playwright` 两个 server ID。
3. Context7 官方页当前推荐：
   - 直接执行 `npx ctx7 setup`
   - 或手动把 `https://mcp.context7.com/mcp` 注册为 MCP server
   - API Key 不是绝对必需，但官方明确写了“推荐”，用于更高限额
4. Serena 当前公开推荐入口是：
   - 先安装 `uv`
   - 再用 `uvx --from git+https://github.com/oraios/serena serena start-mcp-server --help`
5. `modelcontextprotocol/servers` 当前仍提供这些官方/半官方基线包名：
   - `@modelcontextprotocol/server-memory`
   - `@modelcontextprotocol/server-filesystem`
   - `@modelcontextprotocol/server-github`
   - `@modelcontextprotocol/server-postgres`
   - `mcp-server-git`
6. 由此可以确定：
   - `git`、`filesystem`、`memory`、`postgres`、`github` 可以优先用官方生态包
   - `context7`、`serena` 更适合走各自项目的原生安装方式
   - `playwright`、`github` 若能走 Docker 官方 catalog，优先级高于手搓本地命令

## 2026-04-13 用户新增约束

1. 用户明确要求：不把 MCP 装在 Docker 中。
2. 这意味着前一版“优先走 Docker 官方 catalog”的建议失效，需要整体改为本机原生安装。
3. 因此后续来源统一调整为：
   - npm / npx：`filesystem`、`memory`、`github`、`fetch`、`postgre`
   - Python `uvx`：`serena`
   - 客户端或独立官方入口：`context7`
   - 本机已安装程序能力桥接：`git`、`playwright`、`openapi`
4. `docker` 本身如果仍在目标列表中，只能解释为“Docker 作为被调用对象的本机 MCP server”，而不是“把所有 MCP 装进 Docker”。

## 2026-04-13 CC SWITCH 实机验证

1. 本机已安装桌面版 `CC Switch 3.13.0`：
   - `C:\Users\Donki\AppData\Local\Programs\CC Switch\cc-switch.exe`
2. 桌面版可执行文件本身是 GUI，不直接输出 CLI 帮助。
3. 已安装官方 `cc-switch-cli` 到：
   - `C:\Users\Donki\.local\bin\cc-switch.exe`
4. 实测 `cc-switch.exe --help` 返回：
   - `mcp` 子命令可用
   - 支持 `list`、`add`、`edit`、`delete`、`sync`
5. 实测 `cc-switch.exe mcp list` 返回：
   - `No MCP servers found.`
6. 由此可以确定：
   - 这台机器后续可以直接把 MCP 加到 `CC SWITCH`
   - 不必依赖 Docker
   - 也不必只靠手写 Claude / Codex 配置文件

## 2026-04-13 第一批 MCP 安装结果

1. npm 安装成功：
   - `@modelcontextprotocol/server-filesystem@2026.1.14`
   - `@modelcontextprotocol/server-memory@2026.1.26`
   - `@modelcontextprotocol/server-sequential-thinking@2025.12.18`
2. pip 用户级安装成功：
   - `mcp-server-fetch==2025.4.7`
   - `mcp-server-git==2026.1.14`
3. 真实可执行路径已确认：
   - `C:\Users\Donki\AppData\Roaming\npm\mcp-server-filesystem.cmd`
   - `C:\Users\Donki\AppData\Roaming\npm\mcp-server-memory.cmd`
   - `C:\Users\Donki\AppData\Roaming\npm\mcp-server-sequential-thinking.cmd`
   - `C:\Users\Donki\AppData\Roaming\Python\Python312\Scripts\mcp-server-fetch.exe`
   - `C:\Users\Donki\AppData\Roaming\Python\Python312\Scripts\mcp-server-git.exe`
4. `CC SWITCH` 数据库与 Codex live config 已同步出现 5 个 MCP。
5. 本轮对 `filesystem` 与 `git` 采用了最小权限假设：
   - 只允许访问当前仓库 `C:\Users\Donki\UserData\Code\ZYKJ_MES`
6. 残余风险：
   - `mcp-server-fetch`、`mcp-server-git` 的脚本目录不在系统 PATH，但因 `CC SWITCH` 使用绝对路径，不构成当前阻塞。
   - `memory`、`sequential-thinking` 采用 stdio 常驻模式，运行时表现仍建议在实际客户端里再做一次最小工具调用。

## 2026-04-13 第二批 MCP 安装结果

1. 已安装并启用到 Codex：
   - `context7`
   - `playwright`
   - `serena`
2. 已安装并登记到 `CC SWITCH`，但暂未启用：
   - `github`
   - `openapi`
   - `postgre`
3. 未启用原因：
   - `github` 需要 `GITHUB_PERSONAL_ACCESS_TOKEN`
   - `openapi` 需要真实的 OpenAPI 规范 URL 或本地文件路径
   - `postgre` 需要真实 PostgreSQL 连接串
4. 关键风险与说明：
   - `serena-agent` 安装过程中降级了部分共享 Python 依赖，并出现 `black` 与 `pathspec` 的兼容警告；当前未影响本轮 MCP 录入，但属于后续环境风险。
   - `@modelcontextprotocol/server-github` 与 `@modelcontextprotocol/server-postgres` 在 npm 安装时都带有“deprecated”提示；当前仍可安装使用，但后续应关注官方替代路线。
   - `playwright` 已装 MCP 包，但浏览器运行时是否需要额外下载组件，建议在首次真实调用时再补证。

## 2026-04-13 第三批收尾结果

1. 已读取后端配置，确认 PostgreSQL 应连接：
   - `postgresql://mes_user:mes_password@127.0.0.1:5432/mes_db`
2. 已确认当前宿主 `127.0.0.1:5432` 可连通，因此该 PostgreSQL 口径兼容本机直连与 Docker 映射后的后端数据库。
3. 已从 FastAPI 应用本地生成：
   - `C:\Users\Donki\UserData\Code\ZYKJ_MES\backend\openapi.generated.json`
4. `openapi` 的有效参数不是只有 `--openapi-spec`，还必须同时给：
   - `--api-base-url http://127.0.0.1:8000`
5. 已启用完成：
   - `github`
   - `openapi`
   - `postgre`
6. 当前 11 个目标 MCP 已全部进入 `CC SWITCH`，并对 `Codex` 启用。
7. 额外提醒：
   - GitHub PAT 已写入本机 `CC SWITCH` / live config 配置源，后续如需轮换，应同步更新对应 MCP 配置。

## 2026-04-13 Skills 清理与重装结果

1. 已从 `CC SWITCH` 中删除全部原有 skills。
2. `superpowers` 来源于当前 Codex app skills 目录中的未托管 skill，已通过 `import-from-apps` 导入 SSOT 并启用。
3. `planning-with-files` 在 `CC SWITCH` 仓库元数据中无法直接安装，最终采用：
   - 先在 `C:\Users\Donki\.codex\skills\planning-with-files\SKILL.md` 恢复 skill 文件
   - 再通过 `cc-switch.exe skills import-from-apps planning-with-files --app codex` 导入
4. 当前 `CC SWITCH` 的 skills 列表中仅保留：
   - `planning-with-files`
   - `superpowers`
