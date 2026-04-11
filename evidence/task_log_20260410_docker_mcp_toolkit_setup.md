# 任务日志：Docker MCP Toolkit 接管安装

- 日期：2026-04-10
- 执行人：Codex 主 agent
- 当前状态：已完成
- 指挥模式：未触发指挥官模式；本次采用主检查 + 真实命令验证闭环

## 1. 输入来源
- 用户指令：要不然我们使用这个 docker MCP 来管理 MCP 工具吧？你能帮我把 MCP 工具装好吗？
- 需求基线：[AGENTS.md](C:/Users/Donki/UserData/Code/ZYKJ_MES/AGENTS.md)、[opencode.json](C:/Users/Donki/UserData/Code/ZYKJ_MES/opencode.json)
- 代码范围：Docker MCP Toolkit 本机配置、项目级 MCP 接入方式、`evidence/`

## 2. 任务目标、范围与非目标
### 任务目标
1. 确认 Docker MCP Toolkit 是否适合作为本项目 MCP 管理入口。
2. 将可直接 Docker 托管的 MCP server 安装并连接到 `codex` / `opencode` 可用链路。
3. 明确不能被 Docker Catalog 直接覆盖的项目自定义 MCP 处理方式。

### 任务范围
1. `docker mcp` CLI、catalog、server enable、client connect。
2. 当前项目已使用的 `sequential_thinking`、`context7`、`playwright`、数据库与代码语义工具。

### 非目标
1. 不修改业务代码。
2. 不强行替换 Docker Catalog 中不存在的自定义 MCP 实现。

## 3. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | Docker 官方文档 `get-started` | 2026-04-10 | Docker MCP Toolkit 支持 `codex` 与 `opencode` 客户端接入 | Codex |
| E2 | `docker mcp` 本机 CLI 实测 | 2026-04-10 | 本机已安装 Docker MCP Toolkit CLI，且当前无已启用 server | Codex |
| E3 | Docker catalog 检索与 `server inspect` | 2026-04-10 | `context7`、`playwright`、`sequentialthinking` 可直接通过 Docker catalog 提供 | Codex |
| E4 | `docker mcp server ls`、`docker mcp client ls --global`、`docker mcp tools count` | 2026-04-10 | 三个 Docker server 已启用，`codex` 与 `opencode` 已连接，Gateway 可枚举 30 个工具 | Codex |
| E5 | `docker mcp tools call resolve-library-id libraryName=pytest` | 2026-04-10 | `context7` 已完成一次真实工具调用，链路可用 | Codex |
| E6 | 配置收口结果 | 2026-04-10 | `codex` 与项目 `opencode.json` 已删除 Docker 托管项的重复本地配置，仅保留 `serena` / `postgres` 本地实现 | Codex |

## 4. 指挥拆解结果
| 序号 | 原子任务 | 目标 | 执行子 agent | 验证子 agent | 验收标准 | 当前状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 能力确认 | 核对 Docker Toolkit 文档与本机 CLI 能力 | 不适用 | 不适用 | 能明确是否支持 `codex` / `opencode` | 已完成 |
| 2 | Catalog 盘点 | 映射项目所需 MCP 到 Docker Catalog | 不适用 | 不适用 | 输出可装项与不可装项 | 已完成 |
| 3 | 安装接入 | 启用可装 server 并连接客户端 | 不适用 | 不适用 | `docker mcp server ls` 与 `client ls` 可见结果 | 已完成 |
| 4 | 留痕交付 | 更新 evidence 并输出迁移口径 | 不适用 | 不适用 | 结论可追溯 | 已完成 |

## 5. 子 agent 输出摘要
- 调研摘要：无
- 执行摘要：已启用 Docker catalog 中的 `context7`、`playwright`、`sequentialthinking`，并通过 `docker mcp client connect -g` 将 `codex` 与 `opencode` 接到 Docker Gateway；同时删除 `codex` 与项目 `opencode.json` 中已交给 Docker 托管的重复本地配置。
- 验证摘要：`docker mcp tools count` 返回 30；`docker mcp tools call resolve-library-id libraryName=pytest` 成功返回多个 `Context7-compatible library ID`；`docker mcp client ls --global` 显示 `codex` 与 `opencode` 已连接。

## 6. 失败重试记录
| 轮次 | 原子任务 | 失败现象 | 根因判断 | 修复动作 | 复检结果 |
| --- | --- | --- | --- | --- | --- |
| 1 | 安装接入 | `docker mcp server enable context7 sequentialthinking playwright` 首次执行后 `server ls` 未立即显示已启用 | 多参数批量启用未稳定落盘 | 改为单项 `server enable` 并逐项复核 | 通过 |
| 2 | 验证 | `docker mcp tools call` 首次使用 JSON 传参失败 | CLI 实际采用 `key=value` 参数格式 | 改为 `docker mcp tools call resolve-library-id libraryName=pytest` | 通过 |

## 7. 工具降级、硬阻塞与限制
- 不可用工具：无
- 降级原因：Docker catalog 当前无 `serena`，项目 `postgres` 依赖仓库自定义脚本
- 替代流程：Docker 托管 `context7` / `playwright` / `sequentialthinking`，本地保留 `serena` / `postgres`
- 影响范围：MCP 管理入口已统一到 Docker Gateway 为主，但能力来源仍为 Docker + 本地混合
- 补偿措施：已删除重复配置，避免 Docker 与本地同类 MCP 并存
- 硬阻塞：无

## 8. 交付判断
- 已完成项：官方接入方式核对、catalog 盘点、Docker server 启用、`codex` / `opencode` 连接、配置去重、真实工具调用验证
- 未完成项：无
- 是否满足任务目标：是
- 主 agent 最终结论：可交付

## 9. 迁移说明
- 混合接入切换步骤：
  1. Docker 托管：`context7`、`playwright`、`sequentialthinking`
  2. 本地保留：`serena`、`postgres`
  3. 重启 `codex` 与 `opencode` 让新 Gateway 配置生效
