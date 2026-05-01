# 任务日志：后端当前 P95 状态核对

- 日期：2026-04-10
- 执行人：Codex
- 当前状态：已完成
- 任务目标：核对仓库内后端当前可用的 P95 证据，并用当前运行中的本地后端做短时复核。

## 输入来源

- 用户指令：后端现在的P95怎么样？
- 需求基线：
  - `AGENTS.md`
  - `evidence/`
  - `tools/perf/backend_capacity_gate.py`
- 代码范围：
  - `tools/perf/`
  - `.tmp_runtime/`
  - `evidence/`

## 关键过程

1. 当前会话未注入 `Sequential Thinking`，改用书面拆解：现有证据检索 -> 当前服务连通性核对 -> 短时 live smoke 复核。
2. 发现环境未安装 `rg`，检索链路降级为 PowerShell `Get-ChildItem` + `Select-String`。
3. 读取最近两类基线：
   - 默认正式门禁：`.tmp_runtime/capacity_fix_round4_40_pwdcache.json`，代表 `login/authz/users/production-orders/production-stats` 五场景混合压测。
   - 扩展读链路扫描：`evidence/perf/other_authenticated_read_round24_scan_40_summary_refresh4_rebuilt.json`，代表其余 61 条已登录读链路的 40 并发汇总。
4. 确认 `http://127.0.0.1:8000/health` 返回 `{"status":"ok"}`，随后对当前运行中的本地后端执行三组短时复核：
   - 默认正式门禁口径 live smoke 两轮；
   - `login-only@10` 单链核对；
   - `login-only@40` 单链核对。
5. 对比历史正式门禁与今天的 live smoke 后，确认当前退化主要集中在 `login@40`，并已把结论写入验证日志。

## 证据编号表

| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | 用户会话指令 | 2026-04-10 | 本轮需回答“后端当前 P95” | Codex |
| E2 | `AGENTS.md` | 2026-04-10 | 本轮需补 task log 与 verification log | Codex |
| E3 | 当前终端工具探测 | 2026-04-10 | `Sequential Thinking` 未注入，`rg` 不可用，已按规则降级 | Codex |
| E4 | `/health` 响应 | 2026-04-10 | 本地后端当前可访问，可执行短时复核 | Codex |
| E5 | `.tmp_runtime/capacity_fix_round4_40_pwdcache.json` | 2026-04-09 02:21:52 | 最近正式门禁口径 `40` 并发总体 `P95 499.04ms`，当时通过 | Codex |
| E6 | `evidence/perf/other_authenticated_read_round24_scan_40_summary_refresh4_rebuilt.json` | 2026-04-09 20:54:13 | 61 条已登录读链路 `40` 并发总体 `P95 254.24ms`，当时通过 | Codex |
| E7 | `.tmp_runtime/backend_p95_live_smoke_20260410.json` | 2026-04-10 14:38:32 | 当前默认正式门禁口径 live smoke 第 1 轮总体 `P95 1881.01ms`，失败 | Codex |
| E8 | `.tmp_runtime/backend_p95_live_smoke_20260410_run2.json` | 2026-04-10 14:39:25 | 当前默认正式门禁口径 live smoke 第 2 轮总体 `P95 2139.91ms`，再次失败 | Codex |
| E9 | `.tmp_runtime/backend_login_only_live_smoke_20260410.json` | 2026-04-10 14:39:06 | `login-only@10` 当前 `P95 186.05ms`，通过 | Codex |
| E10 | `.tmp_runtime/backend_login_only_40_live_smoke_20260410.json` | 2026-04-10 14:40:16 | `login-only@40` 当前 `P95 3745.33ms`，失败，且说明登录链路在 40 并发下放大明显 | Codex |

## 执行命令摘要

- 仓库检索：`Get-ChildItem`、`Select-String`
- 健康检查：`Invoke-WebRequest http://127.0.0.1:8000/health`
- 单次登录探测：`Invoke-RestMethod -Method Post http://127.0.0.1:8000/api/v1/auth/login ...`
- 默认正式门禁 live smoke：
  - `python -m tools.project_toolkit backend-capacity-gate --base-url http://127.0.0.1:8000 --scenarios login,authz,users,production-orders,production-stats --concurrency 40 --session-pool-size 20 --token-count 40 --duration-seconds 8 --warmup-seconds 2 --spawn-rate 10 --login-user-prefix pa --password Load@2026Aa --p95-ms 500 --error-rate-threshold 0.05 --request-timeout-seconds 10 --output-json .tmp_runtime/backend_p95_live_smoke_20260410.json`
  - 同命令复跑一次，输出 `.tmp_runtime/backend_p95_live_smoke_20260410_run2.json`
- 登录单链复核：
  - `login-only@10` 输出 `.tmp_runtime/backend_login_only_live_smoke_20260410.json`
  - `login-only@40` 输出 `.tmp_runtime/backend_login_only_40_live_smoke_20260410.json`

## 结果

- 若按“最近正式门禁口径”看：
  - 2026-04-09 02:21:52 的 `40` 并发总体 `P95 = 499.04ms`，通过门禁。
- 若按“当前本地运行态 live smoke”看：
  - 2026-04-10 14:38:32 第 1 轮总体 `P95 = 1881.01ms`；
  - 2026-04-10 14:39:25 第 2 轮总体 `P95 = 2139.91ms`；
  - 两轮都 `success_rate = 1.0` 但 `gate_passed = false`，说明当前主要是时延退化，不是错误率问题。
- 若看“当前登录链路”：
  - `login-only@10`：`P95 = 186.05ms`，通过；
  - `login-only@40`：`P95 = 3745.33ms`，失败。
- 若看“其余 61 条已登录读链路”的最新汇总基线：
  - 2026-04-09 20:54:13，总体 `P95 = 254.24ms`，通过。

## 风险与说明

- 当前不存在一个脱离场景的唯一 P95；至少要区分“默认正式门禁混合场景”和“其余已登录读链路扫描”。
- 今天的两轮 live smoke 与 2026-04-09 的正式门禁差异明显，默认正式门禁口径大约从 `499ms` 上升到 `1.9s~2.1s`，退化主要由 `login@40` 放大。
- `login-only@40` 命令在 shell 包装层接近超时，但 JSON 输出已完整落盘，可用于本轮结论。
- 本轮结论仅代表当前工作区本地运行态，不代表生产环境 SLA。

## 迁移说明

- 无迁移，直接替换。
