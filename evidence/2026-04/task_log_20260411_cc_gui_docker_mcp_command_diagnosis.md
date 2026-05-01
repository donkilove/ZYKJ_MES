# 任务日志：CC GUI 中 `docker.exe mcp gateway run` 不可用排查

- 日期：2026-04-11
- 执行人：Codex 主 agent
- 当前状态：已完成
- 指挥模式：未触发指挥官模式；本次采用主检查 + 真实命令验证闭环

## 1. 输入来源
- 用户指令：检查一下为什么 `docker.exe mcp gateway run` 这个命令不可用！
- 需求基线：[AGENTS.md](C:/Users/Donki/UserData/Code/ZYKJ_MES/AGENTS.md)
- 代码范围：本机 Docker CLI、Docker CLI 插件目录、CC GUI 的 MCP JSON 配置、`evidence/`

## 1.1 前置说明
- 默认主线工具：`MCP_DOCKER Sequential Thinking`
- 缺失工具：当前会话未注入 `MCP_DOCKER`
- 缺失/降级原因：本轮会话未自动暴露 Docker 工具
- 替代工具：`shell_command`、`web`
- 影响范围：宿主工具链与插件兼容性证据改由本地命令和官方/issue 页面补证

## 2. 任务目标、范围与非目标
### 任务目标
1. 判断 `docker.exe mcp gateway run` 在本机是否真实不可用。
2. 判断 CC GUI 报错来源于 Docker 本体，还是插件调用方式。

### 任务范围
1. `docker.exe` 路径、版本与 `mcp` 子命令帮助。
2. `docker-mcp.exe` 插件文件存在性。
3. Docker 官方文档与 Docker CLI 已知 issue。

### 非目标
1. 不修改业务代码。
2. 不直接改动 JetBrains 插件源码。

## 3. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | `Get-Command docker.exe`、`docker.exe version` | 2026-04-11 12:xx +08:00 | 当前机器实际执行的是 `C:\Program Files\Docker\Docker\resources\bin\docker.exe`，版本 `29.3.1` | Codex |
| E2 | `docker.exe mcp --help`、`docker.exe mcp gateway run --help` | 2026-04-11 12:xx +08:00 | 该命令在当前终端真实可用，并非机器本身不支持 | Codex |
| E3 | `Get-ChildItem C:\Program Files\Docker\cli-plugins`、`docker-mcp.exe --help` | 2026-04-11 12:xx +08:00 | `docker-mcp.exe` 插件文件存在，且可直接启动 | Codex |
| E4 | Docker CLI issue `#6145` | 2026-04-11 12:xx +08:00 | 存在已知兼容问题：某些 MCP SDK/stdio 调用 `command=docker, args=[mcp,gateway,run]` 会报 `unknown command: docker mcp` | Codex |
| E5 | 用户提供的 CC GUI 日志截图 | 2026-04-11 12:46 +08:00 | CC GUI 当前报错与 Docker CLI issue 中的已知报错一致，说明更像插件调用兼容问题而不是认证问题 | Codex |

## 4. 指挥拆解结果
| 序号 | 原子任务 | 目标 | 执行子 agent | 验证子 agent | 验收标准 | 当前状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 本机命令复核 | 确认命令本身是否可用 | 不适用 | 不适用 | `docker.exe mcp` 可真实执行 | 已完成 |
| 2 | 插件二进制复核 | 确认 `docker-mcp.exe` 是否存在 | 不适用 | 不适用 | 插件文件可见且可执行 | 已完成 |
| 3 | 兼容性归因 | 比对 CC GUI 报错与已知 issue | 不适用 | 不适用 | 能判断责任层级 | 已完成 |

## 5. 子 agent 输出摘要
- 调研摘要：无
- 执行摘要：已确认本机 Docker CLI 与 `docker-mcp.exe` 插件文件都正常，`docker.exe mcp gateway run --help` 能在终端中正常输出帮助。
- 验证摘要：CC GUI 中的报错并不是“命令本身不可用”，而是 JetBrains 插件通过 stdio/MCP SDK 拉起 Docker MCP Gateway 时命中了 Docker CLI 已知兼容问题。

## 6. 失败重试记录
| 轮次 | 原子任务 | 失败现象 | 根因判断 | 修复动作 | 复检结果 |
| --- | --- | --- | --- | --- | --- |
| 1 | `gateway run --help` | 命令首次 30 秒超时 | `gateway run --help` 输出较慢但实际已打印帮助 | 将帮助输出作为有效证据纳入，不再误判为不可用 | 通过 |

## 7. 工具降级、硬阻塞与限制
- 默认 `MCP_DOCKER` 主线：未注入
- 不可用工具：当前会话未注入 `MCP_DOCKER`
- 降级原因：会话运行态未提供 Docker MCP 工具
- 替代流程：用本地 Docker CLI 和 Docker 官方/issue 页面交叉验证
- 影响范围：只能给出插件兼容性口径，不能直接读取 CC GUI 内部源码日志
- 补偿措施：已使用真实命令与公开 issue 证据补齐
- 硬阻塞：无

## 8. 交付判断
- 已完成项：Docker CLI 可用性验证、CLI 插件文件验证、已知 issue 比对、CC GUI 报错归因
- 未完成项：无
- 是否满足任务目标：是
- 主 agent 最终结论：可交付

## 9. 迁移说明
- 无迁移，直接替换
