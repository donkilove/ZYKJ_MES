# 任务日志：本地原生 MCP 安装规划

- 日期：2026-04-13
- 执行人：Codex
- 当前状态：进行中
- 指挥模式：主 agent 规划与归纳，当前未进入实际安装

## 1. 输入来源
- 用户指令：先为本地安装 `docker`、`git`、`github`、`sequential thinking`、`playwright`、`openapi`、`memory`、`filesystem`、`fetch`、`postgre`、`context7`、`serena` 写出计划，并体现难点与风险；后续补充“不要装在 Docker 中”。
- 需求基线：根 `AGENTS.md`、`docs/AGENTS/*.md`、历史 `evidence/`
- 代码范围：仓库根目录、用户级 Claude 配置、Docker MCP 运行态

## 1.1 前置说明
- 默认主线工具：`MCP_DOCKER Sequential Thinking`、`update_plan`
- 缺失工具：`MCP_DOCKER`
- 缺失/降级原因：当前会话未提供可调用的 `MCP_DOCKER` 工具入口
- 替代工具：`update_plan`、PowerShell 宿主安全命令、仓库文档与历史 `evidence/`
- 影响范围：本轮只能做书面拆解、环境核实与计划输出，不能使用默认 Docker MCP 工具链直接验证

## 2. 任务目标、范围与非目标
### 任务目标
1. 盘点当前本机 MCP 相关现状。
2. 输出目标 MCP 的本机原生安装顺序、依赖关系、难点与验证方式。
3. 给出后续正式安装的执行建议。

### 任务范围
1. 本机客户端与 CLI 可用性核对。
2. 目标 MCP 清单的本地原生安装规划与风险归纳。
3. 对先前 Docker 假设进行纠偏。

### 非目标
1. 本轮不直接安装任何 MCP。
2. 本轮不修改业务代码。
3. 本轮不处理与 MCP 无关的环境问题。

## 3. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | 根 `AGENTS.md` 与 `docs/AGENTS/*.md` | 2026-04-13 | 本轮需先留痕并在前置说明中披露 `MCP_DOCKER` 缺失 | Codex |
| E2 | `docker mcp server ls` 等宿主检查 | 2026-04-13 | 旧环境不存在可复用的 Docker 方案，但用户已明确不采用该路线 | Codex |
| E3 | `docker mcp client ls --global` | 2026-04-13 | 历史上客户端注册与服务可用是两层问题 | Codex |
| E4 | `claude mcp list` / `claude mcp get MCP_DOCKER` | 2026-04-13 | 当前机器未安装或未暴露 `claude` CLI 命令 | Codex |
| E5 | 历史 `evidence/` | 2026-04-13 | `sequential_thinking`、`serena`、`postgres`、`context7`、`playwright` 为长期缺口 | Codex |
| E6 | 用户新增约束 | 2026-04-13 | 本轮必须改为本机原生安装方案，不走 Docker | Codex |
| E7 | `cc-switch.exe --help` / `cc-switch.exe mcp list` | 2026-04-13 | `CC SWITCH` 官方 CLI 可用，且当前未配置任何 MCP | Codex |
| E8 | npm / pip 安装结果 | 2026-04-13 | 第一批 5 个 MCP 已完成本机安装 | Codex |
| E9 | `cc-switch.exe mcp list` / `cc-switch.exe --app codex mcp sync` / `.codex/config.toml` | 2026-04-13 | 5 个 MCP 已写入 `CC SWITCH` 并同步到 Codex live config | Codex |
| E10 | 第二批 npm / pip 安装结果 | 2026-04-13 | `context7`、`playwright`、`serena` 等第二批包已完成本机安装 | Codex |
| E11 | 第二批 `cc-switch` 写入与同步结果 | 2026-04-13 | `context7`、`playwright`、`serena` 已启用；`github`、`openapi`、`postgre` 已登记待配置 | Codex |
| E12 | `backend/.env` / `compose.yml` / `backend/app/main.py` | 2026-04-13 | PostgreSQL 与 FastAPI 的最终接入口径已确认 | Codex |
| E13 | `backend/openapi.generated.json` 生成结果 | 2026-04-13 | 已获得可供 `openapi` MCP 使用的本地规范文件 | Codex |
| E14 | 第三批 `cc-switch` 启用与同步结果 | 2026-04-13 | `github`、`openapi`、`postgre` 已启用并同步到 Codex | Codex |
| E15 | `cc-switch.exe skills list` / `skills repos list` | 2026-04-13 | 已盘点当前 skills 与 skill repos 状态 | Codex |
| E16 | `cc-switch.exe skills uninstall` 批量结果 | 2026-04-13 | 已清空全部既有 skills | Codex |
| E17 | `cc-switch.exe skills import-from-apps` / `enable` / `sync` | 2026-04-13 | `planning-with-files` 与 `superpowers` 已导入、启用并同步 | Codex |

## 4. 指挥拆解结果
| 序号 | 原子任务 | 目标 | 执行子 agent | 验证子 agent | 验收标准 | 当前状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 规则与证据读取 | 明确本轮规划边界 | 主 agent | 同阶段补偿验证 | 规则、技能、历史 evidence 已核对 | 已完成 |
| 2 | 本机现状摸底 | 确认客户端 / CLI 现状与历史问题 | 主 agent | 同阶段补偿验证 | 形成当前环境结论 | 已完成 |
| 3 | 安装计划编制 | 产出本机原生安装计划与难点说明 | 主 agent | 同阶段补偿验证 | 交付可执行方案 | 已完成 |
| 4 | `CC SWITCH` 接入口确认 | 验证是否可直接管理 MCP | 主 agent | 同阶段补偿验证 | 官方 CLI 可用且能列出 MCP | 已完成 |
| 5 | 第一批 MCP 安装与录入 | 完成本机安装并接入 `CC SWITCH` | 主 agent | 同阶段补偿验证 | 5 个 MCP 可见且已同步到 Codex | 已完成 |
| 6 | 第二批 MCP 安装与录入 | 完成第二批安装并区分启用/待配置项 | 主 agent | 同阶段补偿验证 | 新增 3 个已启用项和 3 个待配置项 | 已完成 |
| 7 | 第三批配置补全与启用 | 基于用户提供的凭据与后端口径启用剩余 3 个 MCP | 主 agent | 同阶段补偿验证 | 3 个待配置项全部启用 | 已完成 |
| 8 | Skills 清理与重装 | 删除全部既有 skills，仅保留两个目标 skill | 主 agent | 同阶段补偿验证 | 最终仅剩 `planning-with-files` 与 `superpowers` | 已完成 |

## 5. 子 agent 输出摘要
- 调研摘要：无，本轮未派发子 agent。
- 执行摘要：已完成环境与历史证据摸底，并根据用户新增约束撤销 Docker 安装路线；已额外安装 `cc-switch-cli`；已完成 11 个目标 MCP 的本机安装与 `CC SWITCH` 接入；随后按用户要求清空全部既有 skills，并重新导入 `planning-with-files` 与 `superpowers`。
- 验证摘要：已用真实命令确认当前 CLI 基础能力缺口，并将 Docker 结果降为背景信息；已确认 `CC SWITCH` 官方 CLI 可直接管理 MCP；已确认 11 个目标 MCP 全部进入 Codex live config 并在 `CC SWITCH` 中对 Codex 处于启用状态；已确认当前 skills 列表仅剩两个目标 skill。

## 6. 失败重试记录
| 轮次 | 原子任务 | 失败现象 | 根因判断 | 修复动作 | 复检结果 |
| --- | --- | --- | --- | --- | --- |
| 1 | 本机现状摸底 | `.mcp.json` 不存在 | 当前项目未配置项目级 MCP | 转查用户级配置与 Docker 运行态 | 已收口 |

## 7. 工具降级、硬阻塞与限制
- 默认 `MCP_DOCKER` 主线：`MCP_DOCKER Sequential Thinking`
- 不可用工具：`MCP_DOCKER`
- 降级原因：当前会话未暴露对应工具入口
- 替代流程：书面拆解 + 宿主安全命令 + 历史 evidence 复核
- 影响范围：计划可输出，但默认工具链下的真实连通验证不足
- 补偿措施：将命令证据、历史阻塞、残余风险一并写入计划
- 硬阻塞：无，本轮先做规划即可继续

## 8. 交付判断
- 已完成项：规则读取、历史证据摸底、本机现状核对、用户新增约束收敛、`CC SWITCH` 本地目录只读检查、`CC SWITCH` CLI 接入口确认、11 个目标 MCP 的本机安装、配置写入与 Codex 启用同步、skills 清理与重装
- 未完成项：无
- 是否满足任务目标：是
- 主 agent 最终结论：可交付

## 9. 迁移说明
- 无迁移，直接替换
