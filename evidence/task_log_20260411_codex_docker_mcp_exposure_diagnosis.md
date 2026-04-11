# 任务日志：Codex 会话未完整暴露 Docker MCP 工具排查

- 日期：2026-04-11
- 执行人：Codex 主 agent
- 当前状态：已完成
- 指挥模式：未触发指挥官模式；受当前会话更高优先级约束，未派发子 agent，采用主检查 + 真实 CLI 验证补偿

## 1. 输入来源
- 用户指令：继续排查为什么 Docker Desktop 里已配置的 server 没有全部暴露到当前会话。
- 需求基线：[AGENTS.md](C:/Users/Donki/UserData/Code/ZYKJ_MES/AGENTS.md)、[docs/opencode_tooling_bundle.md](C:/Users/Donki/UserData/Code/ZYKJ_MES/docs/opencode_tooling_bundle.md)
- 代码范围：`C:\Users\Donki\.codex\config.toml`、Docker MCP Toolkit 全局 client 状态、当前 Codex 会话工具暴露面、`evidence/`

## 1.1 前置说明
- 默认主线工具：`MCP_DOCKER Sequential Thinking`、`update_plan`、Docker MCP CLI、当前会话 MCP 枚举能力
- 缺失工具：当前会话未完整暴露 `MCP_DOCKER ast-grep`、`Context7`、`OpenAPI Toolkit`、`Git/GitHub`、`Filesystem`、`Fetch`、`Memory`
- 缺失/降级原因：当前会话启动时未完整注入 Docker Gateway 工具；只能通过当前会话已暴露工具与宿主 CLI 排查
- 替代工具：`mcp__sequential_thinking__sequentialthinking`、`shell_command`、`list_mcp_resources`、`mcp__serena__get_current_config`
- 影响范围：结构化定位与官方宿主注入证据部分改为 CLI 和当前会话枚举补证

## 2. 任务目标、范围与非目标
### 任务目标
1. 判断问题发生在 Docker server、Docker client 连接、Codex 本地配置，还是当前会话热加载阶段。
2. 给出当前会话为什么仍未出现全部 Docker MCP 工具的可验证结论。

### 任务范围
1. Docker MCP Toolkit 的 `server ls`、`client ls`、`tools ls`。
2. 本地 `codex` CLI 的 `mcp list` 与 `C:\Users\Donki\.codex\config.toml`。
3. 当前会话的 MCP 资源、模板与工具暴露面。

### 非目标
1. 不修改业务代码。
2. 不扩展 Docker Catalog 中不存在的自定义 MCP 能力。

## 3. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | `docker mcp server ls`、`docker mcp tools ls` | 2026-04-11 11:36 +08:00 | Docker Gateway 与 11 个 server 工作正常，问题不在 server 端 | Codex |
| E2 | `docker mcp client ls --global`、`docker mcp client ls --global --json` 初次读取 | 2026-04-11 11:36 +08:00 | 初次排查时 `codex` 为 `disconnected` 且 `Cfg=null`，而 `opencode`、`gemini`、`vscode` 仍保持 connected | Codex |
| E3 | `C:\Users\Donki\.codex\config.toml` 与 `codex mcp list` 初次读取 | 2026-04-11 11:36 +08:00 | 本地 Codex 只加载了 `playwright`、`postgres`、`sequential_thinking`、`serena`，未加载 `MCP_DOCKER` | Codex |
| E4 | `docker mcp client connect -g codex`、后续 `client ls --global`、`codex mcp list`、`config.toml` | 2026-04-11 11:40 +08:00 | 根因是 `codex` 全局 Docker client 连接已丢失；重连后 `MCP_DOCKER` 重新写入并出现在 `codex mcp list` | Codex |
| E5 | `list_mcp_resources`、`list_mcp_resource_templates`、`mcp__serena__get_current_config` 重读 | 2026-04-11 11:40 +08:00 | 当前这条已启动会话的工具暴露面未因重连而热更新，仍不是 Docker Gateway 全量工具集 | Codex |
| E6 | Docker 官方文档 `Get started with Docker MCP Toolkit` | 2026-04-11 11:40 +08:00 | Codex 正常接入后的验证标准应是 `codex mcp list` 出现 `MCP_DOCKER` enabled | Codex |

## 4. 指挥拆解结果
| 序号 | 原子任务 | 目标 | 执行子 agent | 验证子 agent | 验收标准 | 当前状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 三层状态比对 | 比对 Docker server、Docker client、当前会话暴露面 | 不适用 | 不适用 | 能定位缺口所在层级 | 已完成 |
| 2 | Codex 连接复测 | 验证 `codex` 是否真正连到 Docker Gateway | 不适用 | 不适用 | `docker mcp client ls` 与 `codex mcp list` 一致 | 已完成 |
| 3 | 会话热加载判断 | 验证当前会话是否会随本地配置变更实时更新工具 | 不适用 | 不适用 | 能明确当前会话是否需要重启/新开 | 已完成 |

## 5. 子 agent 输出摘要
- 调研摘要：无
- 执行摘要：先确认 Docker server 和 Gateway 工具链正常，再发现 `codex` 全局 client 初次排查时为 `disconnected`，且本地 `codex mcp list` 缺少 `MCP_DOCKER`；随后执行 `docker mcp client connect -g codex`，确认 `codex` 重新接入 Docker Gateway，并将 `MCP_DOCKER` 写回 `C:\Users\Donki\.codex\config.toml`。
- 验证摘要：当前本地 Codex 已恢复 `MCP_DOCKER`，但这条已启动会话的工具暴露面未变化，说明当前问题由“两段原因”组成：一是 `codex` 连接丢失，二是当前会话不支持热更新新接入的 Docker 工具。

## 6. 失败重试记录
| 轮次 | 原子任务 | 失败现象 | 根因判断 | 修复动作 | 复检结果 |
| --- | --- | --- | --- | --- | --- |
| 1 | Docker client 细节读取 | `docker mcp client inspect codex --global` 返回 unknown flag | 当前 CLI 不支持该子命令参数组合 | 改用 `docker mcp client ls --global --json` 读取 client 详细状态 | 通过 |

## 7. 工具降级、硬阻塞与限制
- 默认 `MCP_DOCKER` 主线：`MCP_DOCKER Sequential Thinking`、Docker Gateway、当前会话 MCP 枚举
- 不可用工具：当前会话未全量暴露的 `MCP_DOCKER` 工具
- 降级原因：本轮排查时当前会话启动前已缺失 `codex` 对 Docker Gateway 的连接；当前会话本身也不支持热更新新注入工具
- 替代流程：以 `docker mcp` CLI、`codex mcp list`、本地配置文件与当前会话 MCP 枚举交叉验证
- 影响范围：当前会话中仍不能直接使用 Docker Gateway 的全量 96 个工具
- 补偿措施：已重连本地 Codex 到 Docker Gateway，并明确需新开会话才能读取新的工具集
- 硬阻塞：无

## 8. 交付判断
- 已完成项：Docker server/Gateway 复核、Codex client 断连定位、最小重连实测、当前会话热加载边界确认、evidence 留痕
- 未完成项：无
- 是否满足任务目标：是
- 主 agent 最终结论：可交付

## 9. 迁移说明
- 切换步骤：
1. 本地 `codex` 已通过 `docker mcp client connect -g codex` 恢复连接。
2. 关闭当前已启动的旧 Codex 会话。
3. 新开一次 Codex 会话或重启 Codex 客户端，让新会话按最新 `config.toml` 和 Docker client 状态重新加载 `MCP_DOCKER`。
