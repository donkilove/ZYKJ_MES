# 工具化验证日志：ripgrep 安装与 rg 恢复

- 执行日期：2026-04-12
- 对应主日志：`evidence/task_log_20260412_ripgrep_install.md`
- 当前状态：已通过

## 1. 任务分类
| 主分类 | 次分类 | 分类依据 | 对应门禁 |
| --- | --- | --- | --- |
| CAT-05 | 本地命令恢复 | 用户要求安装可用的 `ripgrep` 并提交相关改动 | G1、G2、G4、G5、G7 |

## 2. 工具触发记录
| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 启动 | `MCP_DOCKER Sequential Thinking` | 默认 `MCP_DOCKER` | 按规则先拆解安装与验证路径 | 任务边界与验证口径 | 2026-04-12 16:53:57 |
| 2 | 启动 | `update_plan` | 默认 | 维护步骤与状态 | 工作流状态 | 2026-04-12 16:53:57 |
| 3 | 验证 | PowerShell + `winget` | 降级 | 本地安装与命令验证无对应 `MCP_DOCKER` 执行工具 | 安装结果与新鲜验证证据 | 2026-04-12 16:53:57 |

## 3. 执行留痕
| 序号 | 工具 | 操作对象 | 实际动作 | 结果摘要 | 输出物 |
| --- | --- | --- | --- | --- | --- |
| 1 | PowerShell | `winget` | 执行可用性探测 | `winget` 可调用 | E3 |
| 2 | PowerShell + `winget` | `ripgrep` 包标识 | 执行 `winget search ripgrep` | 确认安装目标为 `BurntSushi.ripgrep.MSVC` 15.1.0 | E4 |
| 3 | PowerShell + `winget` | `ripgrep` 安装 | 执行 `winget install --id BurntSushi.ripgrep.MSVC -e --scope user --accept-package-agreements --accept-source-agreements` | 安装成功并提示添加 `rg` 命令行别名 | E5 |
| 4 | PowerShell | `rg` 命令来源 | 执行 `Get-Command rg -All`、`Get-Command rg`、`Get-Item` | PowerShell 默认命中新安装的 `C:\Users\Donki\AppData\Local\OpenAI\Codex\bin\rg.exe` | E6、E8 |
| 5 | PowerShell | `rg` 版本验证 | 执行 `rg --version` | 成功返回 `ripgrep 15.1.0` | E7 |
| 6 | PowerShell | `where.exe` 对照 | 执行 `where.exe rg` | 仍只列出旧 `WindowsApps` 入口 | E10 |
| 7 | `cmd` | `rg` 版本验证 | 执行 `cmd /c rg --version` | 成功返回 `ripgrep 15.1.0` | E9 |

## 4. 验证留痕
| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G1 | 通过 | E1 | 已判定为 CAT-05 |
| G2 | 通过 | E1、E3 | 已记录默认工具与降级原因 |
| G4 | 通过 | E4、E5、E6、E7、E8、E9、E10 | 已执行安装与新鲜验证命令 |
| G5 | 通过 | E1、E2、E3、E4、E5、E6、E7、E8、E9、E10 | 已完成触发、执行、验证与收口 |
| G7 | 通过 | E1 | 已声明无迁移 |

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| PowerShell | `winget` | `Get-Command winget` | 通过 | 当前环境可执行系统包管理命令 |
| PowerShell + `winget` | `ripgrep` | `winget search ripgrep` | 通过 | 包标识已确认 |
| PowerShell + `winget` | `ripgrep` | `winget install --id BurntSushi.ripgrep.MSVC -e --scope user ...` | 通过 | 用户级安装成功 |
| PowerShell | `rg` | `Get-Command rg`、`Get-Command rg -All` | 通过 | 当前 PowerShell 默认命中新安装的 `rg.exe` |
| PowerShell | `rg` | `rg --version` | 通过 | `rg` 现可正常运行 |
| `cmd` | `rg` | `cmd /c rg --version` | 通过 | `cmd` 也可正常运行 |
| PowerShell | `rg` 对照 | `where.exe rg` | 通过 | 旧入口仍存在，但不影响实际可用性 |

## 5. 失败重试
| 轮次 | 失败阶段 | 失败现象 | 根因判断 | 修复动作 | 复检工具 | 复检结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 无 | 无 | 无 | 无 | 无 | 无 |

## 6. 降级/阻塞/代记
- 前置说明是否已披露默认 `MCP_DOCKER` 缺失与影响：是
- 工具降级：安装与本地验证由宿主 PowerShell/`winget` 补偿
- 阻塞记录：无
- evidence 代记：否

## 7. 通过判定
- 是否完成闭环：是
- 是否满足门禁：是
- 是否存在残余风险：有
- 最终判定：通过

## 8. 迁移说明
- 无迁移，直接替换
