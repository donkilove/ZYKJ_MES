# 任务日志：remaining_read_40 第八轮独立验证（group1/group2/group5 优先复跑）

- 日期：2026-04-09
- 执行人：独立验证子 agent
- 当前状态：已完成
- 指挥模式：只做验证，不改代码

## 1. 输入来源
- 用户指令：先跑指定 pytest，再重建 `backend-web`，再复跑 `group1/group2/group5`；仅当这 3 组所有逐链路都通过时，才继续 `group7/group8` 与后续收口。
- 场景基线：`tools/perf/scenarios/remaining_read_40_scan.json`
- 统一门禁参数：`--concurrency 40 --session-pool-size 20 --token-count 40 --duration-seconds 6 --warmup-seconds 2 --spawn-rate 10 --login-user-prefix pa --password Load@2026Aa --p95-ms 500 --error-rate-threshold 0.05 --request-timeout-seconds 10`

## 2. 工具降级说明
- Sequential Thinking 工具：当前不可用
- 替代动作：采用书面拆解 + `update_plan` 维护步骤，并在本日志补记

## 3. 执行命令
1. `python -m pytest backend/tests/test_api_deps_unit.py backend/tests/test_auth_endpoint_unit.py backend/tests/test_me_endpoint_unit.py backend/tests/test_authz_service_unit.py backend/tests/test_message_service_unit.py`
2. `docker compose up -d --build backend-web`
3. `group1 -> .tmp_runtime/remaining_read_40_group1_round8.json`
4. `group2 -> .tmp_runtime/remaining_read_40_group2_round8.json`
5. `group5 -> .tmp_runtime/remaining_read_40_group5_round8.json`

## 4. 结果摘要
- pytest：`42 passed`
- 分组 gate：
  - group1：不通过
  - group2：不通过
  - group5：不通过
- 逐链路仍失败：
  - group1：`auth-me`、`auth-register-requests`、`authz-permissions-catalog-user`、`authz-snapshot`、`authz-role-permissions-user`、`authz-role-permissions-matrix-user`、`authz-hierarchy-catalog-user`
  - group2：`authz-hierarchy-role-config-user`
  - group5：`roles-list`、`audits-list`、`sessions-login-logs`、`sessions-online`、`ui-page-catalog`、`quality-stats-overview`、`quality-stats-processes`、`quality-stats-operators`
- `total_requests=0`：无
- 是否继续执行 `group7/group8`：否；因为 `group1/group2/group5` 未做到“所有逐链路都通过”

## 5. 结论
- 当前仍不满足“所有链路 40 并发”的最低要求。

## 6. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | pytest 输出 | 2026-04-09 | 指定 5 个单测文件全部通过 | 独立验证子 agent |
| E2 | `.tmp_runtime/remaining_read_40_group1_round8.json` | 2026-04-09 | group1 仍存在 7 条逐链路失败 | 独立验证子 agent |
| E3 | `.tmp_runtime/remaining_read_40_group2_round8.json` | 2026-04-09 | group2 收敛到 1 条逐链路失败 | 独立验证子 agent |
| E4 | `.tmp_runtime/remaining_read_40_group5_round8.json` | 2026-04-09 | group5 仍整体失败且 8 条逐链路超线 | 独立验证子 agent |

## 7. 迁移说明
- 无迁移，直接替换
