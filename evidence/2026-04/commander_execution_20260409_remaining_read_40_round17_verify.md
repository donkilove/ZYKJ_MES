# 任务日志：remaining_read_40 第十七轮独立验证（session/quality 复核 + 其余 47 条补证）

- 日期：2026-04-09
- 执行人：独立验证子 agent
- 当前状态：已完成
- 指挥模式：只做验证，不改代码

## 1. 输入来源

- 用户指令：
  1. 独立复核最后一轮 `session/quality` 修复；
  2. 补齐其余 `47` 条 `remaining_read_40` 场景单链 `40` 并发证据；
  3. 回答“其他所有链路是否满足 `40` 并发需求”。
- 场景基线：`tools/perf/scenarios/remaining_read_40_scan.json`
- 统一门禁参数：
  - `--concurrency 40`
  - `--session-pool-size 20`
  - `--token-count 40`
  - `--duration-seconds 6`
  - `--warmup-seconds 2`
  - `--spawn-rate 10`
  - `--login-user-prefix pa`
  - `--password Load@2026Aa`
  - `--p95-ms 500`
  - `--error-rate-threshold 0.05`
  - `--request-timeout-seconds 10`

## 2. 执行命令

1. `docker compose up -d --build backend-web`
2. `python -m pytest backend/tests/test_session_service_unit.py backend/tests/test_api_deps_unit.py backend/tests/test_list_query_optimization_unit.py backend/tests/test_quality_service_stats_unit.py backend/tests/test_quality_module_integration.py`
3. 对 `49` 条单链场景逐条执行：
   - `python tools/project_toolkit.py backend-capacity-gate --scenario-config-file tools/perf/scenarios/remaining_read_40_scan.json --scenarios <scenario> ... --output-json .tmp_runtime/remaining_read_40_single_<scenario>_round17_verify.json`

## 3. 失败重试记录

| 轮次 | 阶段 | 失败现象 | 根因判断 | 修复动作 | 复检结果 |
| --- | --- | --- | --- | --- | --- |
| 1 | 批量 gate 首次执行 | 49 条场景全部 `rc=2` 且无结果文件 | 未传 `--scenario-config-file`，内置场景不支持这些名称 | 改为显式传 `tools/perf/scenarios/remaining_read_40_scan.json` 后重跑 49 条 | 已完成并产出全部结果文件 |

## 4. 验证结果摘要

### 4.1 pytest

- 命令：
  - `python -m pytest backend/tests/test_session_service_unit.py backend/tests/test_api_deps_unit.py backend/tests/test_list_query_optimization_unit.py backend/tests/test_quality_service_stats_unit.py backend/tests/test_quality_module_integration.py`
- 结果：`43 passed`

### 4.2 49 条单链 gate 汇总

- 通过：`12`
- 未通过：`37`
- 汇总文件：`.tmp_runtime/remaining_read_40_round17_verify_summary.json`

#### 通过清单（12）

| 场景 | p95(ms) | error_rate |
| --- | ---: | ---: |
| sessions-online | 297.28 | 0.001159 |
| auth-accounts | 312.36 | 0.000000 |
| authz-capability-packs-catalog-user | 299.87 | 0.000000 |
| authz-capability-packs-role-config-user | 281.96 | 0.000000 |
| authz-capability-packs-effective-user | 289.81 | 0.000000 |
| me-profile | 499.07 | 0.000000 |
| users-online-status | 451.23 | 0.000000 |
| equipment-ledger | 485.94 | 0.000000 |
| craft-stages | 496.45 | 0.000000 |
| production-data-today-realtime | 481.23 | 0.000000 |
| production-scrap-statistics | 491.89 | 0.001597 |
| production-pipeline-instances | 492.56 | 0.000000 |

#### 未通过清单（37）

| 场景 | p95(ms) | error_rate |
| --- | ---: | ---: |
| sessions-login-logs | 917.11 | 0.000000 |
| me-session | 806.64 | 0.000000 |
| messages-unread-count | 688.47 | 0.000000 |
| messages-summary | 1112.38 | 0.000000 |
| messages-list | 1352.13 | 0.000000 |
| users-export-tasks | 625.94 | 0.000000 |
| equipment-admin-owners | 987.46 | 0.000000 |
| equipment-owners | 1112.79 | 0.000000 |
| equipment-items | 540.70 | 0.000000 |
| equipment-plans | 702.47 | 0.000000 |
| equipment-executions | 692.36 | 0.000000 |
| equipment-records | 569.37 | 0.001825 |
| equipment-rules | 536.89 | 0.000000 |
| equipment-runtime-parameters | 570.72 | 0.001733 |
| processes-list | 615.54 | 0.000000 |
| products-list | 597.18 | 0.000000 |
| products-parameter-query | 653.48 | 0.000000 |
| products-parameter-versions | 877.79 | 0.000000 |
| quality-stats-products | 574.78 | 0.000000 |
| quality-trend | 741.69 | 0.000000 |
| quality-first-articles | 670.67 | 0.001957 |
| quality-suppliers | 563.92 | 0.000000 |
| quality-scrap-statistics | 531.12 | 0.000000 |
| quality-repair-orders | 515.33 | 0.001642 |
| quality-defect-analysis | 724.39 | 0.000000 |
| craft-processes | 552.47 | 0.000000 |
| craft-stages-light | 542.72 | 0.000000 |
| craft-processes-light | 561.38 | 0.001675 |
| craft-templates | 578.66 | 0.000000 |
| production-stats-processes | 831.60 | 0.000000 |
| production-stats-operators | 958.59 | 0.000000 |
| production-data-unfinished-progress | 2191.32 | 0.000000 |
| production-data-manual | 500.19 | 0.000000 |
| production-repair-orders | 695.65 | 0.000000 |
| production-assist-authorizations | 556.40 | 0.001667 |
| production-assist-user-options | 4068.64 | 0.000000 |
| production-my-orders | 652.61 | 0.000000 |

## 5. 最终结论

- 本轮“其余 47 条 + 两条 session 复核”共 `49` 条单链验证结果为：`12` 通过、`37` 未通过。
- 因此当前**不满足**“其他所有链路都满足 `40` 并发需求”。
- 迁移说明：无迁移，直接替换。
