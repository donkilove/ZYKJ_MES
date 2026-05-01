# 任务日志：remaining_read_40 第五轮独立验证（仅验证）

- 日期：2026-04-09
- 执行人：独立验证子 agent
- 当前状态：存在阻塞（全量门禁不通过）
- 指挥模式：只做验证，不改代码

## 1. 输入来源
- 用户指令：`sessions-online` 三轮验证全部通过后，再检查其他链路是否满足 40 并发需求。
- 场景基线：`tools/perf/scenarios/remaining_read_40_scan.json`

## 2. 执行命令
1. `python -m pytest backend/tests/test_session_service_unit.py`
2. `docker compose up -d --build backend-web`
3. `python -m tools.project_toolkit backend-capacity-gate --scenario-config-file tools/perf/scenarios/remaining_read_40_scan.json --scenarios sessions-online --concurrency 40 --session-pool-size 20 --token-count 40 --duration-seconds 6 --warmup-seconds 2 --spawn-rate 10 --login-user-prefix pa --password Load@2026Aa --p95-ms 500 --error-rate-threshold 0.05 --request-timeout-seconds 10 --output-json .tmp_runtime/sessions_online_40_verify_round5_run1.json`
4. `python -m tools.project_toolkit backend-capacity-gate --scenario-config-file tools/perf/scenarios/remaining_read_40_scan.json --scenarios sessions-online --concurrency 40 --session-pool-size 20 --token-count 40 --duration-seconds 6 --warmup-seconds 2 --spawn-rate 10 --login-user-prefix pa --password Load@2026Aa --p95-ms 500 --error-rate-threshold 0.05 --request-timeout-seconds 10 --output-json .tmp_runtime/sessions_online_40_verify_round5_run2.json`
5. `python -m tools.project_toolkit backend-capacity-gate --scenario-config-file tools/perf/scenarios/remaining_read_40_scan.json --scenarios sessions-online --concurrency 40 --session-pool-size 20 --token-count 40 --duration-seconds 6 --warmup-seconds 2 --spawn-rate 10 --login-user-prefix pa --password Load@2026Aa --p95-ms 500 --error-rate-threshold 0.05 --request-timeout-seconds 10 --output-json .tmp_runtime/sessions_online_40_verify_round5_run3.json`
6. 提取场景列表（63 条）写入 `.tmp_runtime/remaining_read_40_round5_scenarios.txt`
7. `python -m tools.project_toolkit backend-capacity-gate --scenario-config-file tools/perf/scenarios/remaining_read_40_scan.json --scenarios <63条逗号拼接> --concurrency 40 --session-pool-size 20 --token-count 40 --duration-seconds 6 --warmup-seconds 2 --spawn-rate 10 --login-user-prefix pa --password Load@2026Aa --p95-ms 500 --error-rate-threshold 0.05 --request-timeout-seconds 10 --output-json .tmp_runtime/remaining_read_40_full_round5.json`

## 3. 结果摘要
- 定向单测：`15 passed`。
- `sessions-online` 三轮单链路门禁：
  - run1：通过，`p95=496.46ms`，`error_rate=0.001488`。
  - run2：通过，`p95=447.53ms`，`error_rate=0.0`。
  - run3：通过，`p95=428.81ms`，`error_rate=0.0`。
- 进入全量 63 条检查后：
  - `gate_passed=false`
  - overall：`p95=1769.32ms`，`error_rate=0.0`
  - 逐项统计：`passed=23`，`failed=40`，其中 `total_requests=0` 的链路 `21` 条（本轮无有效采样）。
  - 首个失败链路：`auth-register-requests`（`p95=815.36ms`）。

## 4. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | pytest 输出 | 2026-04-09 | session_service 单测通过 | 独立验证子 agent |
| E2 | `.tmp_runtime/sessions_online_40_verify_round5_run1.json` | 2026-04-09 | `sessions-online` run1 通过 | 独立验证子 agent |
| E3 | `.tmp_runtime/sessions_online_40_verify_round5_run2.json` | 2026-04-09 | `sessions-online` run2 通过 | 独立验证子 agent |
| E4 | `.tmp_runtime/sessions_online_40_verify_round5_run3.json` | 2026-04-09 | `sessions-online` run3 通过 | 独立验证子 agent |
| E5 | `.tmp_runtime/remaining_read_40_full_round5.json` | 2026-04-09 | 全量 63 条门禁失败，尚不满足“其他所有链路 40 并发”最低要求 | 独立验证子 agent |

## 5. 迁移说明
- 无迁移，直接替换
