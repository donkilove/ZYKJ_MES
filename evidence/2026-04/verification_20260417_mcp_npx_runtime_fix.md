# 任务日志：MCP 注入异常修复（npx 运行时目录缺失）

- 日期：2026-04-17
- 执行人：Codex 主 agent
- 当前状态：已完成
- 指挥模式：单任务直执；按系统化调试流程先定位根因，再做最小修复

## 1. 输入来源
- 用户指令：修好这些问题 / 继续
- 问题背景：Codex 插件 UI 已启用 `fetch`、`filesystem`、`git`、`memory`、`playwright`、`sequential-thinking`、`serena`，但当前会话实际只注入 `serena`、`git`、`fetch`
- 排查对象：
  - `/root/.codex/config.toml`
  - `/root/.codex/logs_2.sqlite`
  - `/root/.vscode-server/extensions/openai.chatgpt-26.409.20454-linux-x64/out/extension.js`
  - `/proc/*/cmdline`

## 1.1 前置说明
- 默认主线工具：`update_plan`、宿主安全命令、`serena`、`git`、`fetch`
- 缺失工具：当前会话未直接暴露 `Sequential Thinking`；宿主环境未安装 `rg`
- 替代工具：
  - 用 `systematic-debugging` 技能 + SQLite 日志查询代替
  - 用 `grep`、`sed`、`python3`、`find` 替代 `rg`
- 影响范围：不影响本轮修复结论

## 2. 根因证据
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | `/root/.codex/config.toml` 与 `codex mcp list/get` | 2026-04-16 ~ 2026-04-17 | 7 个 MCP 服务器在配置层均已启用 | Codex |
| E2 | `logs_2.sqlite` 中新一轮 MCP 启动日志 | 2026-04-17 00:34:47 ~ 00:34:49 +0800 | `serena`、`git`、`fetch` 成功启动；`npx` 型服务器启动时报错 | Codex |
| E3 | `codex_rmcp_client::rmcp_client` 日志 | 2026-04-17 00:34:48 +0800 | `npx` stderr 明确报错：`ENOENT: no such file or directory, lstat '/root/.npm-global'` | Codex |
| E4 | 宿主检查 `npm config get prefix` 与目录状态 | 2026-04-17 00:45 +0800 | 当前 shell 的 npm 前缀是 `/usr/local`，但 `/root/.npm-global` 确实不存在 | Codex |
| E5 | 手工执行 `npx -y @modelcontextprotocol/server-sequential-thinking`、`server-memory`、`server-filesystem`、`@playwright/mcp@latest --headless` | 2026-04-17 00:46 +0800 | 补齐目录后，4 个 `npx` 型服务器均可成功启动或正常退出 | Codex |
| E6 | 独立 `codex exec --json --ephemeral` 复测输出 | 2026-04-17 00:48 +0800 | 新开 Codex 会话已实际调用 `filesystem` MCP 的 `read_text_file`，说明修复后的运行环境可被新会话使用 | Codex |

## 3. 根因判断
1. 问题不在 MCP 注册配置本身。
2. 当前缺失的 4 组 MCP 都依赖 `npx` 启动。
3. 当 Codex 重新按配置尝试启动这些服务器时，`npm exec / npx` 因 `/root/.npm-global` 缺失直接报 `ENOENT`，导致这些服务器无法完成握手与工具暴露。
4. 因此表象是“UI 已启用，但模型侧没拿到工具”，实质是“服务器启动失败，未能进入工具注入阶段”。

## 4. 修复动作
已执行最小修复：

```bash
mkdir -p /root/.npm-global /root/.npm-global/bin /root/.npm-global/lib /root/.npm-global/share
```

说明：
- 不改动项目业务代码。
- 不修改 MCP 配置项。
- 只补齐 `npx` 运行时缺失的目录结构。

## 5. 验证结果
### 5.1 直接运行验证
以下命令均返回 `EXIT:0`：

```bash
timeout 5 npx -y @modelcontextprotocol/server-sequential-thinking
timeout 5 npx -y @modelcontextprotocol/server-memory
timeout 5 npx -y @modelcontextprotocol/server-filesystem /root/CodeH /root/code /root/.codex
timeout 10 npx -y @playwright/mcp@latest --headless
```

典型输出：
- `Sequential Thinking MCP Server running on stdio`
- `Knowledge Graph MCP Server running on stdio`
- `Secure MCP Filesystem Server running on stdio`

### 5.2 Codex 新会话验证
独立执行：

```bash
timeout 25 codex exec --json --skip-git-repo-check --ephemeral '只回复 ok'
```

在输出中可见：
- 新线程已实际产生 `mcp_tool_call`
- `server:"filesystem"`
- `tool:"read_text_file"`

这说明修复后的环境已经能让新 Codex 会话实际拿到并调用此前缺失的 MCP。

## 6. 交付判断
- 已完成项：
  - 定位 MCP 未注入的真实根因
  - 修复 `npx` 运行时目录缺失
  - 用 4 条 `npx` 命令完成直接验证
  - 用独立 Codex 会话完成实际 MCP 调用验证
- 未完成项：无
- 是否满足任务目标：是
- 主 agent 最终结论：可交付

## 7. 迁移说明
- 无迁移，直接替换
