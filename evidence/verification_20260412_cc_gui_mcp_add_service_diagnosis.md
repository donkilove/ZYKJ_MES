# 工具化验证日志：CC GUI 插件无法添加 MCP 服务原因排查

- 执行日期：2026-04-12
- 对应主日志：`evidence/task_log_20260412_cc_gui_mcp_add_service_diagnosis.md`
- 当前状态：已通过

## 1. 任务分类
| 主分类 | 次分类 | 分类依据 | 对应门禁 |
| --- | --- | --- | --- |
| CAT-05 | IDE 本地联调与启动 | 涉及 PyCharm/Claude Code GUI 的本地 MCP 接入与识别链路 | G1、G2、G3、G4、G5、G6、G7 |

## 2. 工具触发记录
| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 启动 | `update_plan` | 降级 | `MCP_DOCKER Sequential Thinking` 不可用 | 任务拆解与状态维护 | 2026-04-12 00:1x +08:00 |
| 2 | 调研 | `shell_command` | 降级 | `MCP_DOCKER ast-grep`、`rg` 不可用 | 配置文件与命令状态证据 | 2026-04-12 00:1x +08:00 |
| 3 | 验证 | `shell_command` | 降级 | 需要真实命令确认运行态 | Docker MCP 与 Claude Code CLI 结果 | 2026-04-12 00:23 +08:00 |

## 3. 执行留痕
| 序号 | 工具 | 操作对象 | 实际动作 | 结果摘要 | 输出物 |
| --- | --- | --- | --- | --- | --- |
| 1 | `shell_command` | 仓库根目录 `.mcp.json` | 读取项目级 MCP 配置 | 当前仅声明 `MCP_DOCKER` | E2 |
| 2 | `shell_command` | `docs/pycharm_cc_gui_mcp_docker.md` | 读取既有接入说明 | 说明明确 CC GUI 读取项目级 `.mcp.json` | E3 |
| 3 | `shell_command` | `.idea/workspace.xml` | 读取 JetBrains 项目状态 | `McpProjectServerCommands` 为空 | E4 |
| 4 | `shell_command` | `~/.claude/settings.json` | 读取用户级 Claude Code 配置 | `mcpServers` 当前为空 | E7 |

## 4. 验证留痕
| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G1 | 通过 | E2、E3 | 已判定为 CAT-05 |
| G2 | 通过 | E1 | 已记录默认工具缺失与降级路径 |
| G3 | 通过 | E5、E6 | 受上层策略限制未派发子 agent，已用独立验证步骤补偿 |
| G4 | 通过 | E5、E6 | 已执行真实命令验证 |
| G5 | 通过 | 主日志、E2-E7 | 已形成“触发 -> 执行 -> 验证 -> 收口”闭环 |
| G6 | 通过 | E1 | 已记录缺失工具、替代工具与影响范围 |
| G7 | 通过 | 主日志 | 无迁移，直接替换 |

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `shell_command` | Docker MCP 可执行文件 | `& 'C:\Program Files\Docker\cli-plugins\docker-mcp.exe' gateway run --help` | 通过 | 底层命令真实可用 |
| `shell_command` | Claude Code 项目级 MCP 读取 | `& 'C:\Users\Donki\AppData\Roaming\npm\claude.cmd' mcp list` | 通过 | 当前项目目录已识别并连接 `MCP_DOCKER` |
| `shell_command` | PyCharm 项目状态 | `Get-Content .idea/workspace.xml` | 通过 | JetBrains 项目 MCP 命令列表为空，不构成 CC GUI 的额外来源 |

## 5. 失败重试
| 轮次 | 失败阶段 | 失败现象 | 根因判断 | 修复动作 | 复检工具 | 复检结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 调研 | 检索工具不完整 | 当前宿主无 `rg` 且无 `MCP_DOCKER ast-grep` | 改用 PowerShell 文本检索 | `shell_command` | 通过 |

## 6. 降级/阻塞/代记
- 前置说明是否已披露默认 `MCP_DOCKER` 缺失与影响：是
- 工具降级：`update_plan` 与 `shell_command` 替代 `MCP_DOCKER` 主线工具
- 阻塞记录：无
- evidence 代记：是，主 agent 代记调研与验证过程

## 7. 通过判定
- 是否完成闭环：是
- 是否满足门禁：是
- 是否存在残余风险：有
- 最终判定：通过

## 8. 迁移说明
- 无迁移，直接替换
