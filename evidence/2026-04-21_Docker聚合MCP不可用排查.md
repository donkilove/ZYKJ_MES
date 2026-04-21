# 任务日志：Docker 聚合 MCP 不可用排查

- 日期：2026-04-21
- 执行人：Codex 主 agent
- 当前状态：已完成
- 指挥模式：单任务直执；采用系统化调试流程，先收集根因证据，再做最小修复

## 1. 输入来源

- 用户指令：我给你接了 docker 提供的聚合 MCP 服务呀，你检查一下为什么用不了。
- 排查对象：
  - `C:\Users\Donki\.codex\config.toml`
  - 当前会话 `list_mcp_resources` / `list_mcp_resource_templates`
  - `docker mcp client ls --global`
  - `docker mcp gateway run --dry-run --verbose`

## 1.1 前置说明

- 默认主线工具：`update_plan`、宿主安全命令、当前会话 MCP 枚举工具
- 缺失工具：会话级 `Sequential Thinking` 可调用入口
- 缺失/降级原因：当前线程未暴露对应函数工具
- 替代工具：书面拆解 + `systematic-debugging` 技能 + 真实命令验证
- 影响范围：不影响本轮根因判断与修复动作

## 2. 证据编号表

| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | `C:\Users\Donki\.codex\config.toml` | 2026-04-21 12:19:40 | Codex 配置中已声明 `mcp_servers."Docker Toolkit"`，命令为 `docker mcp gateway run` | Codex |
| E2 | `docker mcp gateway run --dry-run --verbose` | 2026-04-21 12:19:40 | Docker Gateway 可正常启动，并可枚举 `duckduckgo`、`fetch`、`filesystem`、`git`、`github`、`memory`、`playwright`、`sequentialthinking` 等服务 | Codex |
| E3 | `docker mcp tools count` | 2026-04-21 12:19:40 | Docker 聚合网关当前可提供 89 个工具 | Codex |
| E4 | `docker mcp client ls --global`（修复前） | 2026-04-21 12:19:40 | `codex` 在 Docker Toolkit 中为 `disconnected`，说明客户端尚未连到聚合网关 | Codex |
| E5 | `docker mcp client connect codex -g` | 2026-04-21 12:19:40 | 已将 `codex` 系统级连接到 `MCP_DOCKER: Docker MCP Catalog (gateway server)` | Codex |
| E6 | `docker mcp client ls --global`（修复后） | 2026-04-21 12:19:40 | `codex: connected`，连接状态已修复 | Codex |
| E7 | 当前会话 `list_mcp_resources` / `list_mcp_resource_templates` | 2026-04-21 12:19:40 | 当前这条会话仍未热注入 Docker MCP 资源，说明还需要重启或新开 Codex 会话 | Codex |

## 3. 根因判断

1. 问题不在 Docker 聚合 MCP 服务本身。
2. 问题也不在 `C:\Users\Donki\.codex\config.toml` 的声明缺失。
3. 真实根因是：Docker Toolkit 侧的 `codex` 客户端此前处于 `disconnected`，因此当前 Codex 会话没有拿到 Docker 聚合网关暴露的工具。
4. 补连后系统层状态已恢复为 `connected`，但当前线程工具集不会热刷新，所以本线程仍表现为“用不了”。

## 4. 执行动作

已执行最小修复命令：

```powershell
docker mcp client connect codex -g
```

修复结果：

- 系统级 Docker MCP 客户端状态已从 `disconnected` 变为 `connected`
- Docker Gateway 可正常枚举 89 个工具
- 当前线程仍需重启后才能看到新注入的工具

## 5. 结论与下一步

- 本轮结论：根因已定位并已完成系统层修复。
- 剩余动作：重启 Codex 或新开一个会话，使新的 MCP 工具集重新注入。
- 迁移说明：无迁移，直接替换。
