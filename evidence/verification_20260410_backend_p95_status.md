# 工具化验证日志：后端当前 P95 状态核对

- 执行日期：2026-04-10
- 对应主日志：`evidence/task_log_20260410_backend_p95_status.md`
- 当前状态：已通过

## 1. 任务分类
| 主分类 | 次分类 | 分类依据 | 对应门禁 |
| --- | --- | --- | --- |
| CAT-05 | 性能证据核对与本地短时复核 | 用户要求了解当前后端 P95，需基于现有压测证据与本地 live smoke 核对 | G1、G2、G4、G5、G6、G7 |

## 2. 工具触发记录
| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 启动 | 书面拆解 | 降级 | `Sequential Thinking` 未注入 | 任务分解与验证口径 | 2026-04-10 |
| 2 | 调研 | PowerShell | 降级 | `rg` 不可用，需要退回本地检索链 | 现有 P95 证据与脚本入口 | 2026-04-10 |
| 3 | 验证 | PowerShell | 默认 | 校验当前后端是否可访问 | 实时运行态 | 2026-04-10 |
| 4 | 验证 | `python -m tools.project_toolkit backend-capacity-gate` | 默认 | 用当前运行中的本地后端做短时 live smoke | 当前 P95 与场景定位 | 2026-04-10 |

## 3. 执行留痕
| 序号 | 工具 | 操作对象 | 实际动作 | 结果摘要 | 输出物 |
| --- | --- | --- | --- | --- | --- |
| 1 | PowerShell | `evidence/`、`.tmp_runtime/`、`tools/perf/` | 检索 `P95`、`backend_capacity_gate`、最近压测文件 | 已定位正式门禁文件与扩展扫描结果 | E5、E6 |
| 2 | PowerShell | `http://127.0.0.1:8000/health` | 执行健康检查 | 返回 `{"status":"ok"}` | E4 |
| 3 | PowerShell | `/api/v1/auth/login` | 执行单次登录探测 | 账号可用，返回 token | 辅助确认 |
| 4 | `backend-capacity-gate` | 默认正式门禁五场景 | 以 `40` 并发复跑两次短时 live smoke | 两轮总体 `P95` 分别为 `1881.01ms`、`2139.91ms`，均失败 | E7、E8 |
| 5 | `backend-capacity-gate` | `login` 单链 | 分别执行 `login-only@10` 与 `login-only@40` | `10` 并发 `P95 186.05ms`；`40` 并发 `P95 3745.33ms` | E9、E10 |

## 4. 验证留痕
| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G1 | 通过 | E1 | 已判定 CAT-05 |
| G2 | 通过 | E2、E3 | 已记录工具降级原因 |
| G4 | 通过 | E4、E7、E8、E9、E10 | 已执行真实健康检查与 live smoke |
| G5 | 通过 | E1-E10 | 已完成触发、执行、验证与收口 |
| G6 | 通过 | E3 | 已说明降级与影响 |
| G7 | 通过 | E1 | 已声明无迁移 |

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| PowerShell | 本地后端 | `Invoke-WebRequest http://127.0.0.1:8000/health` | 通过 | 当前服务在线 |
| `backend-capacity-gate` | 默认正式门禁五场景 | `40` 并发、短时复跑两轮 | 失败 | 当前本地运行态总体 `P95` 已高于 `500ms` 门禁 |
| `backend-capacity-gate` | `login-only@10` | 单链 `10` 并发复跑 | 通过 | 登录低并发仍可接受 |
| `backend-capacity-gate` | `login-only@40` | 单链 `40` 并发复跑 | 失败 | 当前登录链路在 `40` 并发下是主要放大点 |
| 历史压测产物核对 | 正式门禁与扩展读链路基线 | 读取 `.tmp_runtime/capacity_fix_round4_40_pwdcache.json` 与 `evidence/perf/other_authenticated_read_round24_scan_40_summary_refresh4_rebuilt.json` | 通过 | 历史基线明显优于当前 live smoke |

## 5. 失败重试
| 轮次 | 失败阶段 | 失败现象 | 根因判断 | 修复动作 | 复检工具 | 复检结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 默认正式门禁 live smoke | 第 1 轮 `P95 1881.01ms` 与历史 `499.04ms` 差异过大 | 可能是冷态或瞬时抖动 | 立即同口径复跑第 2 轮 | `backend-capacity-gate` | 第 2 轮 `P95 2139.91ms`，确认并非单次抖动 |
| 2 | 场景定位 | 需判断高时延是否由 `login` 放大 | 默认五场景混合不足以分离链路 | 补跑 `login-only@10` 与 `login-only@40` | `backend-capacity-gate` | 已定位为 `login@40` 明显退化 |

## 6. 降级/阻塞/代记
- 工具降级：`Sequential Thinking` 未注入；`rg` 不可用
- 阻塞记录：无硬阻塞；`login-only@40` 命令在 shell 包装层接近超时，但结果文件已落盘并完成解析
- evidence 代记：否

## 7. 通过判定
- 是否完成闭环：是
- 是否满足门禁：是
- 是否存在残余风险：有
- 最终判定：通过

## 8. 迁移说明
- 无迁移，直接替换
