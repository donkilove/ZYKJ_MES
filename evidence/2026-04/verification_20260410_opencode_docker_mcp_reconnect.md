# 工具化验证日志：opencode 接入 Docker MCP 服务复核与收口

- 执行日期：2026-04-10
- 对应主日志：`evidence/task_log_20260410_opencode_docker_mcp_reconnect.md`
- 当前状态：已通过

## 1. 任务分类
| 主分类 | 次分类 | 分类依据 | 对应门禁 |
| --- | --- | --- | --- |
| CAT-08 | MCP 工具链接入复核 | 涉及 Docker MCP Toolkit 与 opencode 配置收口 | G1、G2、G4、G5、G6、G7 |

## 2. 工具触发记录
| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 启动 | `read` | 默认 | 读取 `opencode.json` 与现有 evidence | 初始配置基线 | 2026-04-10 |
| 2 | 启动 | `TodoWrite` | 降级 | 当前会话无 `Sequential Thinking`，需维护步骤状态 | 书面拆解与状态跟踪 | 2026-04-10 |
| 3 | 执行 | `docker mcp` CLI | 默认 | 需真实确认 Gateway、client、server 状态 | 实际接入证据 | 2026-04-10 |
| 4 | 收尾 | `apply_patch` | 默认 | 写入任务日志与验证日志 | evidence 闭环 | 2026-04-10 |

## 3. 执行留痕
| 序号 | 工具 | 操作对象 | 实际动作 | 结果摘要 | 输出物 |
| --- | --- | --- | --- | --- | --- |
| 1 | `read` | `opencode.json` | 读取当前项目 MCP 配置 | 已确认仅保留本地 `serena`、`postgres` | E1 |
| 2 | `docker mcp` CLI | 全局 client 状态 | 执行 `docker mcp client ls --global`、`--json` | 初次复核发现 `opencode` 为 `disconnected` | E2 |
| 3 | `docker mcp` CLI | `opencode` client | 执行 `docker mcp client connect --global opencode` | `opencode` 已连接 `MCP_DOCKER` | E3 |
| 4 | `docker mcp` CLI | Docker Gateway | 执行 `docker mcp tools ls`、`docker mcp tools count` | Gateway 可枚举 30 个工具 | E4 |
| 5 | 独立验证子 agent | 全局 client 与 Gateway | 只读复检 `client ls --global`、`--json`、`tools count` | `dockerMCPCatalogConnected=true` | E5 |

## 4. 验证留痕
| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G1 | 通过 | E1 | 已完成任务分类 |
| G2 | 通过 | E1 | 已记录工具触发与降级原因 |
| G4 | 通过 | E2、E3、E4、E5 | 已有真实 Docker CLI 证据与独立复检 |
| G5 | 通过 | E1、E2、E3、E4、E5 | 已形成“发现漂移 -> 重连 -> 复检 -> 收尾”闭环 |
| G6 | 通过 | E1 | 已记录降级代偿 |
| G7 | 通过 | E5 | 已明确混合接入与重启客户端口径 |

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `docker mcp` CLI | `opencode` client | `docker mcp client ls --global` | 通过 | 可见 `opencode: connected` |
| `docker mcp` CLI | Gateway 标识 | `docker mcp client ls --global --json` | 通过 | `dockerMCPCatalogConnected=true`，且 `STDIOServers[0].name="MCP_DOCKER"` |
| `docker mcp` CLI | Gateway 工具目录 | `docker mcp tools count` | 通过 | 当前可枚举 30 个工具 |

## 5. 失败重试
| 轮次 | 失败阶段 | 失败现象 | 根因判断 | 修复动作 | 复检工具 | 复检结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 执行 | `docker mcp client connect opencode` 返回需使用 `--global` | `opencode` 接入点为全局 client 配置 | 改为 `docker mcp client connect --global opencode` | `docker mcp` CLI | 通过 |

## 6. 降级/阻塞/代记
- 工具降级：`Sequential Thinking` 未注入，改为书面拆解 + `TodoWrite`
- 阻塞记录：无
- evidence 代记：否

## 7. 通过判定
- 是否完成闭环：是
- 是否满足门禁：是
- 是否存在残余风险：有
- 最终判定：通过

## 8. 迁移说明
- 混合接入切换步骤：
- 1. 保持仓库 `opencode.json` 中本地 `serena`、`postgres` 不变。
- 2. 通过全局 Docker client 连接提供 `MCP_DOCKER` Gateway。
- 3. 若 `opencode` 已在运行，重启一次客户端使连接生效。
