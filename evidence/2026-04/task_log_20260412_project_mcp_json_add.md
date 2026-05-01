# 任务日志：项目级 .mcp.json 添加

- 日期：2026-04-12
- 执行人：Claude Code 主 agent
- 当前状态：存在阻塞
- 指挥模式：未显式派发子 agent，采用主流程执行 + 独立验证补偿

## 1. 输入来源
- 用户指令：帮我添加项目级 `.mcp.json`，并确认其放置位置；判断能否放在 `.claude` 文件夹中
- 需求基线：`C:\Users\Donki\UserData\Code\ZYKJ_MES\.claude\CLAUDE.md`
- 检查范围：仓库根目录、`evidence/`、Claude CLI MCP 状态

## 1.1 前置说明
- 默认主线工具：`MCP_DOCKER Sequential Thinking`、`MCP_DOCKER Filesystem`
- 缺失工具：当前会话未暴露 `MCP_DOCKER`
- 缺失/降级原因：运行态仅提供宿主文件与命令工具
- 替代工具：`TodoWrite`、`Read`、`Glob`、`Grep`、`Write`、`Edit`、`Bash`
- 影响范围：改由本地文件操作与 Claude CLI 命令完成配置与验证

## 2. 任务目标、范围与非目标
### 任务目标
1. 明确项目级 `.mcp.json` 的正确放置位置。
2. 在仓库根目录落地项目级 `MCP_DOCKER` 配置。
3. 通过 Claude CLI 真实验证项目级配置是否生效。

### 任务范围
1. 仓库根目录 `.mcp.json`
2. `evidence/` 任务日志与验证日志
3. `claude mcp get MCP_DOCKER`、`claude mcp list`

### 非目标
1. 不修改用户级 `~/.claude.json` 或 `~/.claude/settings.json`
2. 不创建额外命名 profile
3. 不新增除 `MCP_DOCKER` 外的其他项目级 MCP 服务

## 3. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | 既有 `evidence/task_log_20260411_pycharm_cc_gui_mcp_docker_integration.md` 与 `evidence/task_log_20260412_cc_gui_docker_toolkit_web_research.md` | 2026-04-12 | 项目级 MCP 配置文件应放在仓库根目录 `.mcp.json`，不是 `.claude/` 子目录 | Claude Code |
| E2 | 仓库根目录列举 + `Glob` | 2026-04-12 | 当前仓库初始状态不存在 `.mcp.json` | Claude Code |
| E3 | `Read` 当前根目录 `.mcp.json` | 2026-04-12 | 已在仓库根目录新增项目级 `MCP_DOCKER` 配置，当前命令指向 `C:\Program Files\Docker\cli-plugins\docker-mcp.exe gateway run` | Claude Code |
| E4 | `claude mcp get MCP_DOCKER` | 2026-04-12 | Claude CLI 已优先读取项目级配置，Scope 为 Project config | Claude Code |
| E5 | `claude mcp list` | 2026-04-12 | 当前项目级 `MCP_DOCKER` 健康检查失败，连接未建立 | Claude Code |
| E6 | `docker-mcp.exe gateway run --help` | 2026-04-12 | Docker MCP 底层可执行文件存在且帮助输出正常 | Claude Code |

## 4. 指挥拆解结果
| 序号 | 原子任务 | 目标 | 执行子 agent | 验证子 agent | 验收标准 | 当前状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 放置位置确认 | 明确 `.mcp.json` 应位于仓库根目录而非 `.claude/` | 主流程代偿 | 主流程独立验证补偿 | 有当前仓库与既有证据支撑结论 | 已完成 |
| 2 | 项目级配置落地 | 创建项目级 `MCP_DOCKER` 配置 | 主流程代偿 | 主流程独立验证补偿 | 根目录 `.mcp.json` 存在且 JSON 合法 | 已完成 |
| 3 | 运行态验证 | 确认 Claude CLI 已优先读取项目级配置并成功连接 | 主流程代偿 | 主流程独立验证补偿 | `claude mcp` 输出显示项目级作用域且连接通过 | 存在阻塞 |

## 5. 子 agent 输出摘要
- 调研摘要：既有仓库 evidence 与官方资料摘要一致指向仓库根目录 `.mcp.json` 为 Claude Code 项目级 MCP 配置入口，`.claude/` 不是该文件的标准放置位置。
- 执行摘要：先在仓库根目录创建 `.mcp.json`，初版使用 `docker mcp gateway run`；由于健康检查失败，再按既有仓库验证口径改为直调 `C:\Program Files\Docker\cli-plugins\docker-mcp.exe gateway run`。
- 验证摘要：`claude mcp get MCP_DOCKER` 已显示 Scope 为 `Project config`，说明项目级覆盖生效；但 `claude mcp list` 仍返回 `Failed to connect`，当前仅完成“放置与生效来源切换”，未完成“连通通过”。

## 6. 失败重试记录
| 轮次 | 原子任务 | 失败现象 | 根因判断 | 修复动作 | 复检结果 |
| --- | --- | --- | --- | --- | --- |
| 1 | 运行态验证 | 首版 `.mcp.json` 使用 `docker mcp gateway run` 时，`claude mcp get/list` 显示项目级 scope 但连接失败 | 项目级覆盖已生效，但 `docker` 分发层在当前项目级配置场景下未连通 | 改为既有仓库已验证过的直调 `docker-mcp.exe gateway run` | 仍失败 |
| 2 | 运行态验证 | 切换为 `docker-mcp.exe gateway run` 后，`claude mcp list` 仍为 `Failed to connect` | 已确认不是文件放置位置错误，也不是可执行文件缺失；更深层运行态原因未在本轮继续展开 | 保留项目级配置并收口当前结果 | 已收口 |

## 7. 工具降级、硬阻塞与限制
- 默认 `MCP_DOCKER` 主线：`Sequential Thinking`、`Filesystem`
- 不可用工具：当前会话未注入 `MCP_DOCKER`
- 降级原因：运行态未提供 Docker 宿主 MCP 能力
- 替代流程：宿主文件读写 + Claude CLI 命令验证
- 影响范围：无法直接用 Docker 宿主 MCP 工具自身进行结构化验证
- 补偿措施：用现有 evidence、项目文件状态与 `claude mcp` 真实输出交叉确认
- 硬阻塞：项目级配置已被 Claude CLI 识别，但当前 `MCP_DOCKER` 健康检查失败，尚未达到可连接状态

## 8. 交付判断
- 已完成项：`.mcp.json` 放置位置确认、仓库根目录 `.mcp.json` 落地、项目级作用域生效验证、失败重试与留痕
- 未完成项：`MCP_DOCKER` 项目级连接通过
- 是否满足任务目标：否
- 主 agent 最终结论：因连接验证未通过，当前仅完成配置落地与作用域切换，暂未达到完全可用

## 9. 迁移说明
- 无迁移，直接替换
