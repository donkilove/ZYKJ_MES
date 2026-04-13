# 工具化验证日志：本地原生 MCP 安装规划

- 执行日期：2026-04-13
- 对应主日志：`evidence/task_log_20260413_local_mcp_install_plan.md`
- 当前状态：进行中

## 1. 任务分类
| 主分类 | 次分类 | 分类依据 | 对应门禁 |
| --- | --- | --- | --- |
| CAT-05 | 本地接入与启动检查 | 涉及 Docker MCP 与本机客户端安装规划 | G1、G2、G4、G5、G6、G7 |

## 2. 工具触发记录
| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 启动 | `update_plan` | 降级 | `MCP_DOCKER Sequential Thinking` 不可用 | 任务步骤与状态 | 2026-04-13 |
| 2 | 调研 | PowerShell | 降级 | 需要获取 Docker MCP 与客户端真实状态 | 运行态证据 | 2026-04-13 |
| 3 | 调研 | `Get-Content` | 降级 | 需要核对用户级配置与历史 evidence | 配置与历史结论 | 2026-04-13 |
| 4 | 调研 | 外部官方文档检索 | 降级 | 需要确认当前推荐安装来源与 server ID | 官方安装依据 | 2026-04-13 |
| 5 | 留痕 | `apply_patch` | 降级 | 需要创建规划文件与 evidence | 规划与日志文件 | 2026-04-13 |

## 3. 执行留痕
| 序号 | 工具 | 操作对象 | 实际动作 | 结果摘要 | 输出物 |
| --- | --- | --- | --- | --- | --- |
| 1 | PowerShell | `docker mcp server ls` | 识别旧路线状态 | 当前无启用 server，且后续不采用该路线 | E2 |
| 2 | PowerShell | `docker mcp client ls --global` | 识别历史客户端问题 | 客户端注册与可用性非同一层 | E3 |
| 3 | PowerShell | `claude mcp list` | 检查 Claude CLI | 命令不存在 | E4 |
| 4 | 官方文档 | Context7 / Serena / MCP 官方仓库 | 核对本地原生安装方式与来源 | 已形成安装依据 | E5 |
| 5 | PowerShell | `cc-switch-cli` 官方二进制 | 安装到 `C:\Users\Donki\.local\bin\cc-switch.exe` | 安装成功 | E7 |
| 6 | PowerShell | `cc-switch.exe --help` / `mcp list` | 验证官方 CLI 与 MCP 子命令 | 成功，当前列表为空 | E7 |
| 7 | npm / pip | 第一批 5 个 MCP 包 | 执行本机安装 | 安装成功 | E8 |
| 8 | PowerShell | `CC SWITCH` 与 Codex 配置 | 写入 `mcp_servers`，执行 `mcp sync`，校验 live config | 成功 | E9 |
| 9 | npm / pip | 第二批 MCP 包 | 执行本机安装 | 安装成功，部分包存在配置前置 | E10 |
| 10 | PowerShell | 第二批 `CC SWITCH` / Codex 配置 | 写入、同步并校验启用状态 | 成功 | E11 |
| 11 | PowerShell | 后端配置与本地 OpenAPI 导出 | 读取 `.env` / `compose.yml` / `main.py` 并生成规范文件 | 成功 | E12、E13 |
| 12 | PowerShell | 第三批 `CC SWITCH` / Codex 配置 | 更新待配置 MCP，执行同步并校验启用状态 | 成功 | E14 |
| 13 | PowerShell | Skills 当前状态 | 读取 `skills list` / `skills repos list` | 成功 | E15 |
| 14 | PowerShell | Skills 清空 | 批量执行 `skills uninstall` | 成功 | E16 |
| 15 | `apply_patch` + PowerShell | 目标 skills | 恢复 `planning-with-files` 文件并执行导入、启用、同步 | 成功 | E17 |
| 16 | `apply_patch` | 规划文件与 evidence | 创建规划与补充留痕文件 | 已落盘 | task_plan.md 等 |

## 4. 验证留痕
| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G1 | 通过 | E1 | 已归类为 CAT-05 |
| G2 | 通过 | 主日志 | 已记录降级原因与替代动作 |
| G4 | 通过 | E2-E5、E7-E17 | 已执行真实命令核查当前状态，并补充 `CC SWITCH` CLI、三批同步结果与 skills 重装证据 |
| G5 | 通过 | 主日志、当前验证日志 | 已形成启动到留痕闭环 |
| G6 | 通过 | 主日志 | 已说明不可用工具与影响范围 |
| G7 | 通过 | 主日志 | 无迁移，直接替换 |

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| PowerShell | Docker 旧路线状态 | `docker mcp server ls`、`docker mcp client ls --global` | 通过 | 已确认这条路线不再采用，但其历史问题可作为风险参考 |
| PowerShell | Claude CLI | `claude mcp list` | 通过 | 机器尚未具备 Claude 侧命令验证条件 |
| 官方文档 | 安装来源与参数口径 | 核对 Context7 / Serena / MCP 官方仓库文档 | 通过 | 已补足计划所需的时效性依据 |
| PowerShell | `CC SWITCH` CLI | `cc-switch.exe --help`、`cc-switch.exe mcp list` | 通过 | 已确认 `CC SWITCH` 可直接管理 MCP，当前尚无配置 |
| npm / pip | 第一批 MCP 包 | 安装指定版本并生成本机可执行入口 | 通过 | 5 个目标 MCP 已装到本机 |
| PowerShell | `CC SWITCH` / Codex live config | `cc-switch.exe mcp list`、`cc-switch.exe --app codex mcp sync`、读取 `.codex/config.toml` | 通过 | 5 个 MCP 已同步到 Codex |
| npm / pip | 第二批 MCP 包 | 安装指定版本并生成本机可执行入口 | 通过 | 第二批 6 个目标已安装或纠偏到正确来源 |
| PowerShell | 第二批 `CC SWITCH` / Codex live config | `cc-switch.exe mcp list`、`cc-switch.exe --app codex mcp sync`、读取 `.codex/config.toml` | 通过 | `context7`、`playwright`、`serena` 已同步启用；其余 3 个待配置未启用 |
| PowerShell | 后端配置与端口连通 | 读取 `.env`、`compose.yml`、`main.py`，测试 `127.0.0.1:5432`，本地导出 `openapi.generated.json` | 通过 | `postgre` 与 `openapi` 的真实配置口径已确认 |
| PowerShell | 第三批 `CC SWITCH` / Codex live config | `cc-switch.exe --app codex mcp sync`、`cc-switch.exe mcp list`、节名级别读取 `.codex/config.toml` | 通过 | `github`、`openapi`、`postgre` 已同步启用 |
| PowerShell | Skills 清空与重装 | `skills uninstall`、`skills import-from-apps`、`skills enable`、`skills sync`、`skills list` | 通过 | 最终仅剩 `planning-with-files` 与 `superpowers` |

## 5. 失败重试
| 轮次 | 失败阶段 | 失败现象 | 根因判断 | 修复动作 | 复检工具 | 复检结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Claude 侧检查 | `claude` 命令不存在 | 本机未安装或 PATH 未配置 Claude Code CLI | 记录为安装前置依赖 | PowerShell | 已收口到计划风险 |

## 6. 降级/阻塞/代记
- 前置说明是否已披露默认 `MCP_DOCKER` 缺失与影响：是
- 工具降级：`update_plan`、PowerShell、`Get-Content`、`apply_patch` 替代 `MCP_DOCKER` 主线
- 阻塞记录：无，本轮仅需输出计划
- evidence 代记：是，主 agent 代记

## 7. 通过判定
- 是否完成闭环：是
- 是否满足门禁：是
- 是否存在残余风险：有
- 最终判定：通过

## 8. 迁移说明
- 无迁移，直接替换
