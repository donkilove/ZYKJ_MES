# 任务日志：CC GUI 插件无法添加 MCP 服务原因排查

- 日期：2026-04-12
- 执行人：Codex 主 agent
- 当前状态：已完成
- 指挥模式：命中排查闭环，但受当前会话更高优先级工具策略限制，未显式派发子 agent，采用主流程执行 + 独立验证补偿

## 1. 输入来源
- 用户指令：我的CC GUI插件添加不了MCP服务了，帮我排查原因
- 需求基线：`AGENTS.md`、`docs/opencode_tooling_bundle.md`、`docs/pycharm_cc_gui_mcp_docker.md`
- 代码范围：仓库根目录 `.mcp.json`、PyCharm 项目状态文件、`~/.claude` 本地配置、`evidence/`

## 1.1 前置说明
- 默认主线工具：`MCP_DOCKER Sequential Thinking`、`MCP_DOCKER ast-grep`、`update_plan`
- 缺失工具：`MCP_DOCKER` 全量工具、`rg`
- 缺失/降级原因：当前会话未暴露 `MCP_DOCKER`；宿主未安装 `rg`
- 替代工具：`update_plan`、`shell_command`、PowerShell `Select-String`
- 影响范围：无法用 Docker 宿主 MCP 做结构化定位与独立验证，改由宿主命令和本地文件证据补偿

## 2. 任务目标、范围与非目标
### 任务目标
1. 判断 CC GUI “添加不了 MCP 服务”是命令不可用、配置无效，还是配置入口使用错误。
2. 给出当前仓库与本机环境下可执行的修复路径。

### 任务范围
1. 根目录项目级 `.mcp.json`
2. PyCharm `.idea` 状态文件
3. `~/.claude` 本地 Claude Code 配置
4. Docker MCP 启动命令与 Claude Code CLI 识别结果

### 非目标
1. 不修改 JetBrains 插件源码
2. 不新增具体第三方 MCP 服务定义
3. 不输出或传播本机敏感凭据

## 3. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | `list_mcp_resources`、`list_mcp_resource_templates` | 2026-04-12 00:1x +08:00 | 当前会话未注入可用 MCP 资源，需走宿主降级路径 | Codex |
| E2 | `Get-Content .mcp.json` | 2026-04-12 00:1x +08:00 | 当前项目级 MCP 配置只声明了 `MCP_DOCKER` | Codex |
| E3 | `Get-Content docs/pycharm_cc_gui_mcp_docker.md` | 2026-04-12 00:1x +08:00 | 仓库既有口径明确：PyCharm 中 Claude Code GUI 读取项目级 `.mcp.json` | Codex |
| E4 | `Get-Content .idea/workspace.xml` | 2026-04-12 00:1x +08:00 | JetBrains `McpProjectServerCommands` 当前为空，未见额外项目 MCP 命令 | Codex |
| E5 | `& 'C:\Program Files\Docker\cli-plugins\docker-mcp.exe' gateway run --help` | 2026-04-12 00:23 +08:00 | Docker MCP 底层命令真实可用，不是 Docker 损坏 | Codex |
| E6 | `& 'C:\Users\Donki\AppData\Roaming\npm\claude.cmd' mcp list` | 2026-04-12 00:23 +08:00 | Claude Code CLI 在当前项目目录下可识别并连接 `MCP_DOCKER` | Codex |
| E7 | `Get-Content $env:USERPROFILE\.claude\settings.json` | 2026-04-12 00:24 +08:00 | 用户级 Claude Code 配置中的 `mcpServers` 当前为空，没有额外服务来源 | Codex |

## 4. 指挥拆解结果
| 序号 | 原子任务 | 目标 | 执行子 agent | 验证子 agent | 验收标准 | 当前状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 配置入口确认 | 确认 CC GUI 实际读取哪套 MCP 配置 | 受限未派发，主流程代偿 | 主流程独立验证补偿 | 能区分 `.mcp.json` 与 JetBrains 项目设置的职责边界 | 已完成 |
| 2 | 运行态复核 | 确认 Docker MCP 与 Claude Code CLI 是否正常 | 受限未派发，主流程代偿 | 主流程独立验证补偿 | 命令可执行，CLI 可识别项目级 MCP | 已完成 |
| 3 | 根因归纳 | 给出“无法添加”的原因与修复路径 | 受限未派发，主流程代偿 | 主流程独立验证补偿 | 形成明确、可执行结论 | 已完成 |

## 5. 子 agent 输出摘要
- 调研摘要：受当前会话上层策略限制，未显式派发子 agent；由主流程代记调研与验证结论。
- 执行摘要：完成项目级 `.mcp.json`、PyCharm `.idea/workspace.xml`、`~/.claude/settings.json` 与既有说明文档交叉核对；同时执行 Docker MCP 命令和 Claude Code CLI 的真实验证。
- 验证摘要：Docker MCP 可执行文件工作正常，Claude Code CLI 可读取当前项目的 `.mcp.json` 并连接 `MCP_DOCKER`；问题不在服务启动层，而在 CC GUI 配置入口认知偏差。

## 6. 失败重试记录
| 轮次 | 原子任务 | 失败现象 | 根因判断 | 修复动作 | 复检结果 |
| --- | --- | --- | --- | --- | --- |
| 1 | 仓库检索 | `rg` 不可用 | 宿主未安装 ripgrep | 改用 PowerShell `Select-String` | 已收口 |

## 7. 工具降级、硬阻塞与限制
- 默认 `MCP_DOCKER` 主线：`Sequential Thinking`、`ast-grep`
- 不可用工具：当前会话未注入 `MCP_DOCKER`
- 降级原因：运行态未提供 Docker 宿主 MCP 能力
- 替代流程：本地命令复核 + 项目文件交叉验证 + 既有 evidence 补证
- 影响范围：无法直接从当前会话调用 Docker MCP 工具自身做二次验证
- 补偿措施：使用 `docker-mcp.exe` 与 `claude.cmd mcp list` 的真实输出补齐
- 硬阻塞：无

## 8. 交付判断
- 已完成项：配置入口确认、项目级与用户级 MCP 配置复核、Docker MCP 命令验证、Claude Code CLI 读取验证、根因与修复路径归纳
- 未完成项：无
- 是否满足任务目标：是
- 主 agent 最终结论：可交付

## 9. 迁移说明
- 无迁移，直接替换
