# 任务日志：remaining_read_40 第九轮独立验证（剩余失败链路逐条单链复核）

- 日期：2026-04-09
- 执行人：独立验证子 agent
- 当前状态：已完成
- 指挥模式：只做验证，不改代码

## 1. 输入来源

- 用户指令：继续按同一门禁推进，识别“混合组失败”与“单链真实失败”的边界，优先确认剩余链路是否真的未达到 `40` 并发最低要求。
- 场景基线：`tools/perf/scenarios/remaining_read_40_scan.json`
- 输入样本：`round8` 验证结果显示 `group1/group2/group5` 仍有多条逐链路失败，需逐条拆开验证。
- 统一门禁参数：`--concurrency 40 --session-pool-size 20 --token-count 40 --duration-seconds 6 --warmup-seconds 2 --spawn-rate 10 --login-user-prefix pa --password Load@2026Aa --p95-ms 500 --error-rate-threshold 0.05 --request-timeout-seconds 10`

## 2. 工具降级说明

- Sequential Thinking 工具：当前不可用
- 替代动作：采用书面拆解 + `update_plan` 维护步骤，并在本日志补记

## 3. 执行命令

对以下 `16` 条场景分别执行单链 gate，结果输出到 `.tmp_runtime/remaining_read_40_single_*_round9.json`：

1. `auth-me`
2. `auth-register-requests`
3. `authz-permissions-catalog-user`
4. `authz-snapshot`
5. `authz-role-permissions-user`
6. `authz-role-permissions-matrix-user`
7. `authz-hierarchy-catalog-user`
8. `authz-hierarchy-role-config-user`
9. `roles-list`
10. `audits-list`
11. `sessions-login-logs`
12. `sessions-online`
13. `ui-page-catalog`
14. `quality-stats-overview`
15. `quality-stats-processes`
16. `quality-stats-operators`

## 4. 结果摘要

### 4.1 单链通过

| 场景 | total_requests | success_rate | error_rate | p95(ms) | p99(ms) | 结论 |
| --- | --- | --- | --- | --- | --- | --- |
| `auth-me` | 663 | 1.000000 | 0.000000 | 487.82 | 680.29 | 通过 |
| `authz-hierarchy-role-config-user` | 673 | 0.998514 | 0.001486 | 427.18 | 588.05 | 通过 |

### 4.2 单链失败

| 场景 | total_requests | success_rate | error_rate | p95(ms) | p99(ms) | 结论 |
| --- | --- | --- | --- | --- | --- | --- |
| `auth-register-requests` | 380 | 1.000000 | 0.000000 | 838.76 | 1072.92 | 未通过 |
| `authz-permissions-catalog-user` | 344 | 0.997093 | 0.002907 | 943.20 | 1381.06 | 未通过 |
| `authz-snapshot` | 421 | 1.000000 | 0.000000 | 875.07 | 1121.46 | 未通过 |
| `authz-role-permissions-user` | 554 | 1.000000 | 0.000000 | 568.16 | 771.17 | 未通过 |
| `authz-role-permissions-matrix-user` | 502 | 1.000000 | 0.000000 | 902.65 | 1108.53 | 未通过 |
| `authz-hierarchy-catalog-user` | 498 | 1.000000 | 0.000000 | 760.36 | 1017.95 | 未通过 |
| `roles-list` | 282 | 1.000000 | 0.000000 | 1521.70 | 1871.81 | 未通过 |
| `audits-list` | 373 | 1.000000 | 0.000000 | 1104.44 | 1278.75 | 未通过 |
| `sessions-login-logs` | 452 | 1.000000 | 0.000000 | 815.26 | 939.76 | 未通过 |
| `sessions-online` | 465 | 1.000000 | 0.000000 | 775.68 | 896.27 | 未通过 |
| `ui-page-catalog` | 528 | 1.000000 | 0.000000 | 678.70 | 842.12 | 未通过 |
| `quality-stats-overview` | 553 | 1.000000 | 0.000000 | 615.27 | 748.34 | 未通过 |
| `quality-stats-processes` | 551 | 0.998185 | 0.001815 | 613.87 | 776.54 | 未通过 |
| `quality-stats-operators` | 500 | 0.998000 | 0.002000 | 774.76 | 1062.06 | 未通过 |

## 5. 结论

- `round8` 中的部分混合失败并不等于单链真实失败。
- 当前已确认“混合失败但单链已通过”的场景仅有：
  - `auth-me`
  - `authz-hierarchy-role-config-user`
- 当前已确认仍不满足 `40` 并发最低要求的真实单链共 `14` 条：
  - `auth-register-requests`
  - `authz-permissions-catalog-user`
  - `authz-snapshot`
  - `authz-role-permissions-user`
  - `authz-role-permissions-matrix-user`
  - `authz-hierarchy-catalog-user`
  - `roles-list`
  - `audits-list`
  - `sessions-login-logs`
  - `sessions-online`
  - `ui-page-catalog`
  - `quality-stats-overview`
  - `quality-stats-processes`
  - `quality-stats-operators`
- 后续修复不应再以“混合组是否通过”替代“单链是否通过”的判定。

## 6. 证据编号表

| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | `.tmp_runtime/remaining_read_40_single_auth-me_round9.json` | 2026-04-09 | `auth-me` 单链 40 并发通过 | 独立验证子 agent |
| E2 | `.tmp_runtime/remaining_read_40_single_auth-register-requests_round9.json` | 2026-04-09 | `auth-register-requests` 单链 40 并发未通过 | 独立验证子 agent |
| E3 | `.tmp_runtime/remaining_read_40_single_authz-permissions-catalog-user_round9.json` | 2026-04-09 | `authz-permissions-catalog-user` 单链 40 并发未通过 | 独立验证子 agent |
| E4 | `.tmp_runtime/remaining_read_40_single_authz-snapshot_round9.json` | 2026-04-09 | `authz-snapshot` 单链 40 并发未通过 | 独立验证子 agent |
| E5 | `.tmp_runtime/remaining_read_40_single_authz-role-permissions-user_round9.json` | 2026-04-09 | `authz-role-permissions-user` 单链 40 并发未通过 | 独立验证子 agent |
| E6 | `.tmp_runtime/remaining_read_40_single_authz-role-permissions-matrix-user_round9.json` | 2026-04-09 | `authz-role-permissions-matrix-user` 单链 40 并发未通过 | 独立验证子 agent |
| E7 | `.tmp_runtime/remaining_read_40_single_authz-hierarchy-catalog-user_round9.json` | 2026-04-09 | `authz-hierarchy-catalog-user` 单链 40 并发未通过 | 独立验证子 agent |
| E8 | `.tmp_runtime/remaining_read_40_single_authz-hierarchy-role-config-user_round9.json` | 2026-04-09 | `authz-hierarchy-role-config-user` 单链 40 并发通过 | 独立验证子 agent |
| E9 | `.tmp_runtime/remaining_read_40_single_roles-list_round9.json` | 2026-04-09 | `roles-list` 单链 40 并发未通过 | 独立验证子 agent |
| E10 | `.tmp_runtime/remaining_read_40_single_audits-list_round9.json` | 2026-04-09 | `audits-list` 单链 40 并发未通过 | 独立验证子 agent |
| E11 | `.tmp_runtime/remaining_read_40_single_sessions-login-logs_round9.json` | 2026-04-09 | `sessions-login-logs` 单链 40 并发未通过 | 独立验证子 agent |
| E12 | `.tmp_runtime/remaining_read_40_single_sessions-online_round9.json` | 2026-04-09 | `sessions-online` 单链 40 并发未通过 | 独立验证子 agent |
| E13 | `.tmp_runtime/remaining_read_40_single_ui-page-catalog_round9.json` | 2026-04-09 | `ui-page-catalog` 单链 40 并发未通过 | 独立验证子 agent |
| E14 | `.tmp_runtime/remaining_read_40_single_quality-stats-overview_round9.json` | 2026-04-09 | `quality-stats-overview` 单链 40 并发未通过 | 独立验证子 agent |
| E15 | `.tmp_runtime/remaining_read_40_single_quality-stats-processes_round9.json` | 2026-04-09 | `quality-stats-processes` 单链 40 并发未通过 | 独立验证子 agent |
| E16 | `.tmp_runtime/remaining_read_40_single_quality-stats-operators_round9.json` | 2026-04-09 | `quality-stats-operators` 单链 40 并发未通过 | 独立验证子 agent |

## 7. 迁移说明

- 无迁移，直接替换
