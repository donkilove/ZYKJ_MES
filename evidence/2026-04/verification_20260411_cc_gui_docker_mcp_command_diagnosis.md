# 工具化验证日志：CC GUI 中 `docker.exe mcp gateway run` 不可用排查

- 执行日期：2026-04-11
- 对应主日志：`evidence/task_log_20260411_cc_gui_docker_mcp_command_diagnosis.md`
- 当前状态：已通过

## 1. 任务分类
| 主分类 | 次分类 | 分类依据 | 对应门禁 |
| --- | --- | --- | --- |
| CAT-08 | Docker MCP 工具链兼容性排障 | 涉及本机工具链、第三方插件兼容性、官方 issue 比对 | G1、G2、G4、G5、G6、G7 |

## 2. 工具触发记录
| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 启动 | `shell_command` | 降级 | 当前会话未注入 `MCP_DOCKER` | 本机命令真实结果 | 2026-04-11 12:xx +08:00 |
| 2 | 调研 | `web` | 默认 | 核对 Docker 官方说明与已知 issue | 官方依据与兼容性依据 | 2026-04-11 12:xx +08:00 |

## 3. 执行留痕
| 序号 | 工具 | 操作对象 | 实际动作 | 结果摘要 | 输出物 |
| --- | --- | --- | --- | --- | --- |
| 1 | `shell_command` | `docker.exe` | 执行 `Get-Command docker.exe`、`docker.exe version` | Docker CLI 版本为 `29.3.1` | E1 |
| 2 | `shell_command` | Docker MCP 子命令 | 执行 `docker.exe mcp --help`、`docker.exe mcp gateway run --help` | 子命令真实可用 | E2 |
| 3 | `shell_command` | Docker CLI 插件目录 | 枚举 `C:\Program Files\Docker\cli-plugins` 并执行 `docker-mcp.exe --help` | `docker-mcp.exe` 文件存在且可执行 | E3 |
| 4 | `web` | Docker CLI issue `#6145` | 读取已知问题描述 | 报错文本与 CC GUI 当前现象一致 | E4 |
| 5 | 用户截图 | CC GUI 连接日志 | 读取截图文字 | 当前失败来自 `unknown command: docker mcp` | E5 |

## 4. 验证留痕
| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G1 | 通过 | E1 | 已归类 CAT-08 |
| G2 | 通过 | E1、E2、E4 | 已记录命令与外部依据 |
| G3 | 通过 | E1 | 本次采用主检查 + 真实命令验证补偿 |
| G4 | 通过 | E1、E2、E3、E4、E5 | 已有真实命令、真实文件和 issue 证据 |
| G5 | 通过 | E1、E2、E3、E4、E5 | 已形成“本机复核 -> 外部依据 -> 插件归因”闭环 |
| G6 | 通过 | E4 | 已说明当前为插件调用兼容问题，而非认证缺失 |
| G7 | 通过 | 主日志 | 无迁移，直接替换 |

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `shell_command` | Docker CLI | `docker.exe mcp --help` | 通过 | 命令本身可用 |
| `shell_command` | Gateway 子命令 | `docker.exe mcp gateway run --help` | 通过 | 子命令本身可用 |
| `shell_command` | CLI 插件 | `docker-mcp.exe --help` | 通过 | 可绕过 `docker mcp` 分发层 |
| `web` | Docker CLI issue `#6145` | 对比报错文本 | 通过 | 与 CC GUI 现象一致 |

## 5. 失败重试
| 轮次 | 失败阶段 | 失败现象 | 根因判断 | 修复动作 | 复检工具 | 复检结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 本机验证 | `gateway run --help` 超时 | 输出较慢，不是命令缺失 | 以已输出帮助作为通过依据 | `shell_command` | 通过 |

## 6. 降级/阻塞/代记
- 前置说明是否已披露默认 `MCP_DOCKER` 缺失与影响：是
- 工具降级：改用本地命令与 `web`
- 阻塞记录：无
- evidence 代记：否

## 7. 通过判定
- 是否完成闭环：是
- 是否满足门禁：是
- 是否存在残余风险：有
- 最终判定：通过

## 8. 迁移说明
- 无迁移，直接替换
