# 工具化验证日志：Codex 会话未完整暴露 Docker MCP 工具排查

- 执行日期：2026-04-11
- 对应主日志：`evidence/task_log_20260411_codex_docker_mcp_exposure_diagnosis.md`
- 当前状态：已通过

## 1. 任务分类
| 主分类 | 次分类 | 分类依据 | 对应门禁 |
| --- | --- | --- | --- |
| CAT-08 | Docker MCP 工具链接入排障 | 涉及 Docker Gateway、客户端连接、会话加载链路排查 | G1、G2、G4、G5、G6、G7 |

## 2. 工具触发记录
| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 启动 | `mcp__sequential_thinking__sequentialthinking` | 默认 | 按规则先拆解三层链路 | 判断标准与边界 | 2026-04-11 11:36 +08:00 |
| 2 | 启动 | `update_plan` | 默认 | 维护排查步骤 | 状态闭环 | 2026-04-11 11:36 +08:00 |
| 3 | 执行 | `shell_command` | 默认 | 真实执行 Docker CLI、Codex CLI、配置读取 | 连接状态与配置证据 | 2026-04-11 11:36-11:40 +08:00 |
| 4 | 执行 | `list_mcp_resources`、`list_mcp_resource_templates`、`mcp__serena__get_current_config` | 默认 | 核对当前会话暴露面 | 当前会话是否热更新 | 2026-04-11 11:36-11:40 +08:00 |
| 5 | 调研 | `web` | 默认 | 读取 Docker 官方接入文档 | 官方验证口径 | 2026-04-11 11:40 +08:00 |

## 3. 执行留痕
| 序号 | 工具 | 操作对象 | 实际动作 | 结果摘要 | 输出物 |
| --- | --- | --- | --- | --- | --- |
| 1 | `shell_command` | Docker server/Gateway | 执行 `docker mcp server ls`、`docker mcp tools ls` | 11 个 server 已启用，Gateway 可枚举 96 个工具 | E1 |
| 2 | `shell_command` | Docker client | 初次执行 `docker mcp client ls --global`、`--json` | `codex` 初始为 disconnected，`Cfg=null` | E2 |
| 3 | `shell_command` | 本地 Codex 配置 | 读取 `C:\Users\Donki\.codex\config.toml` 与 `codex mcp list` | 初始仅见 4 个本地 MCP，无 `MCP_DOCKER` | E3 |
| 4 | `shell_command` | `codex` client | 执行 `docker mcp client connect -g codex` 后复检 | `codex` 已 connected，`codex mcp list` 出现 `MCP_DOCKER` | E4 |
| 5 | `list_mcp_resources` 等 | 当前会话暴露面 | 重读资源、模板、当前配置 | 当前会话工具暴露面未热更新 | E5 |
| 6 | `web` | Docker 官方文档 | 读取 Codex 验证章节 | 官方期望 `codex mcp list` 出现 `MCP_DOCKER` enabled | E6 |

## 4. 验证留痕
| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G1 | 通过 | E1 | 已归类 CAT-08 |
| G2 | 通过 | E1、E2、E3、E4、E5 | 已记录默认工具、降级与补偿依据 |
| G3 | 通过 | E1 | 本次采用主检查 + 真实 CLI 验证补偿 |
| G4 | 通过 | E1、E2、E3、E4、E5 | 已执行真实命令、真实配置读取与会话枚举 |
| G5 | 通过 | E1、E2、E3、E4、E5、E6 | 已形成“发现断连 -> 重连 -> 会话边界确认 -> 官方口径对照”闭环 |
| G6 | 通过 | E5 | 已说明当前会话仍未热更新的残余影响 |
| G7 | 通过 | 主日志 | 已给出重启/新开会话的迁移口径 |

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `shell_command` | Docker server | `docker mcp server ls` | 通过 | server 正常 |
| `shell_command` | Docker client | `docker mcp client ls --global --json` | 通过 | 初始断连与重连后状态均可验证 |
| `shell_command` | 本地 Codex | `codex mcp list` | 通过 | 初始缺失 `MCP_DOCKER`，重连后恢复 |
| `shell_command` | 本地配置 | `Get-Content C:\Users\Donki\.codex\config.toml` | 通过 | 重连后已写入 `[mcp_servers.MCP_DOCKER]` |
| `list_mcp_resources`、`mcp__serena__get_current_config` | 当前会话 | 会话内重读工具暴露面 | 通过 | 当前会话未热更新新增 Docker 工具 |

## 5. 失败重试
| 轮次 | 失败阶段 | 失败现象 | 根因判断 | 修复动作 | 复检工具 | 复检结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 调研 | `docker mcp client inspect codex --global` 失败 | CLI 当前不支持该查询方式 | 改用 `docker mcp client ls --global --json` | `shell_command` | 通过 |

## 6. 降级/阻塞/代记
- 前置说明是否已披露默认 `MCP_DOCKER` 缺失与影响：是
- 工具降级：当前会话未暴露完整 `MCP_DOCKER` 工具，故以 CLI 与会话枚举补偿
- 阻塞记录：无
- evidence 代记：否

## 7. 通过判定
- 是否完成闭环：是
- 是否满足门禁：是
- 是否存在残余风险：有
- 最终判定：通过

## 8. 迁移说明
- 切换步骤：
1. 本地 Codex 已恢复 `MCP_DOCKER` 连接。
2. 当前旧会话需结束。
3. 新开会话后再核对 `codex mcp list` 与实际工具暴露面。
