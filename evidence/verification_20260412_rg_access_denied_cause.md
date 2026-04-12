# 工具化验证日志：rg 拒绝访问原因诊断

- 执行日期：2026-04-12
- 对应主日志：`evidence/task_log_20260412_rg_access_denied_cause.md`
- 当前状态：已通过

## 1. 任务分类
| 主分类 | 次分类 | 分类依据 | 对应门禁 |
| --- | --- | --- | --- |
| CAT-05 | 本地命令权限诊断 | 用户要求解释 `rg` 启动时报“拒绝访问”的原因 | G1、G2、G4、G5、G7 |

## 2. 工具触发记录
| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 启动 | `update_plan` | 默认 | 维护步骤、状态与收口 | 工作流状态 | 2026-04-12 16:41:17 |
| 2 | 验证 | PowerShell | 降级 | 本地路径、ACL 与应用包诊断无对应 `MCP_DOCKER` 命令执行工具 | 真实命令结果 | 2026-04-12 16:41:17 |

## 3. 执行留痕
| 序号 | 工具 | 操作对象 | 实际动作 | 结果摘要 | 输出物 |
| --- | --- | --- | --- | --- | --- |
| 1 | PowerShell | `rg.exe` 路径 | 执行 `Get-Item` | 文件位于 Codex 的 `WindowsApps` 安装目录 | E2 |
| 2 | PowerShell | `rg.exe` ACL | 执行 `Get-Acl` 与 `icacls` | ACL 含读取与执行权限，非简单 NTFS 显式拒绝 | E3 |
| 3 | PowerShell | `rg.exe` 签名 | 执行 `Get-AuthenticodeSignature` | `rg.exe` 未签名 | E4 |
| 4 | PowerShell | 同目录其他 EXE 签名对照 | 对 `codex.exe`、`codex-command-runner.exe`、`codex-windows-sandbox-setup.exe` 执行签名检查 | 官方入口程序签名有效 | E5 |
| 5 | PowerShell | `rg.exe` 直接执行 | 执行绝对路径 `rg.exe --version` | 仍报“拒绝访问” | E6 |
| 6 | PowerShell | 包元数据补证 | 执行 `Get-AppxPackage OpenAI.Codex` | 当前平台无法加载 `Appx` 模块 | E7 |

## 4. 验证留痕
| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G1 | 通过 | E1 | 已判定为 CAT-05 |
| G2 | 通过 | E1 | 已记录降级原因 |
| G4 | 通过 | E2、E3、E4、E5、E6、E7 | 已执行真实命令并记录结果 |
| G5 | 通过 | E1、E2、E3、E4、E5、E6、E7 | 已完成触发、执行、验证与收口 |
| G7 | 通过 | E1 | 已声明无迁移 |

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| PowerShell | `rg.exe` | `Get-Item` | 通过 | 路径位于 `WindowsApps` 下的 Codex 安装目录 |
| PowerShell | `rg.exe` | `Get-Acl` + `icacls` | 通过 | ACL 不支持“普通用户被显式禁止执行”的解释 |
| PowerShell | `rg.exe` | `Get-AuthenticodeSignature` | 通过 | 文件未签名 |
| PowerShell | 对照 EXE | `Get-AuthenticodeSignature` | 通过 | 同目录官方入口 EXE 签名有效 |
| PowerShell | `rg.exe` | 绝对路径直接执行 `--version` | 失败 | 报“拒绝访问”，不是命令别名问题 |
| PowerShell | 包元数据 | `Get-AppxPackage OpenAI.Codex` | 失败 | 当前平台无法直接补充 Appx 元数据 |

## 5. 失败重试
| 轮次 | 失败阶段 | 失败现象 | 根因判断 | 修复动作 | 复检工具 | 复检结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 无 | 无 | 无 | 无 | 无 | 无 |

## 6. 降级/阻塞/代记
- 前置说明是否已披露默认 `MCP_DOCKER` 缺失与影响：是
- 工具降级：本地权限诊断由宿主 PowerShell 补偿
- 阻塞记录：无
- evidence 代记：否

## 7. 通过判定
- 是否完成闭环：是
- 是否满足门禁：是
- 是否存在残余风险：有
- 最终判定：通过

## 8. 迁移说明
- 无迁移，直接替换
