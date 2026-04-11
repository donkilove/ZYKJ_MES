# 任务日志：remaining_read_40 第六轮独立验证（分组公平检查）

- 日期：2026-04-09
- 执行人：独立验证子 agent
- 当前状态：已完成
- 指挥模式：只做验证，不改代码

## 1. 输入来源
- 用户指令：公平检查“其余所有链路是否满足 40 并发”，避免再次出现大量 `total_requests=0`。
- 场景基线：`tools/perf/scenarios/remaining_read_40_scan.json`
- 统一参数：`--concurrency 40 --session-pool-size 20 --token-count 40 --duration-seconds 6 --warmup-seconds 2 --spawn-rate 10 --login-user-prefix pa --password Load@2026Aa --p95-ms 500 --error-rate-threshold 0.05 --request-timeout-seconds 10`

## 2. 前置检查
- `docker inspect -f "{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}" zykj_mes-backend-web-1`
- 结果：`running healthy`
- 结论：未重复执行 `docker compose up -d --build backend-web`

## 3. 执行命令
1. group1 -> `.tmp_runtime/remaining_read_40_group1_round6.json`
2. group2 -> `.tmp_runtime/remaining_read_40_group2_round6.json`
3. group3 -> `.tmp_runtime/remaining_read_40_group3_round6.json`
4. group4 -> `.tmp_runtime/remaining_read_40_group4_round6.json`
5. group5 -> `.tmp_runtime/remaining_read_40_group5_round6.json`
6. group6 -> `.tmp_runtime/remaining_read_40_group6_round6.json`
7. group7 -> `.tmp_runtime/remaining_read_40_group7_round6.json`
8. group8 -> `.tmp_runtime/remaining_read_40_group8_round6.json`

## 4. 分组结果摘要
- group1：gate 不通过；失败链路 8 条。
- group2：gate 不通过；失败链路 8 条。
- group3：gate 不通过；失败链路 3 条。
- group4：gate 通过；失败链路 0 条。
- group5：gate 通过；但按逐链路门禁仍有 `roles-list` 超线。
- group6：gate 通过；失败链路 0 条。
- group7：gate 通过；但按逐链路门禁仍有 `production-data-unfinished-progress` 超线。
- group8：gate 不通过；失败链路 4 条。

## 5. 关键结论
- 本轮 8 组分组后，`total_requests=0` 的链路数为 0，说明“全量混跑导致大量 0 样本”的问题已被规避。
- 分组后仍真实失败的链路共 25 条：
  - `auth-me`
  - `auth-accounts`
  - `auth-register-requests`
  - `authz-permissions-catalog-user`
  - `authz-snapshot`
  - `authz-role-permissions-user`
  - `authz-role-permissions-matrix-user`
  - `authz-hierarchy-catalog-user`
  - `authz-hierarchy-role-config-user`
  - `authz-capability-packs-catalog-user`
  - `authz-capability-packs-role-config-user`
  - `authz-capability-packs-effective-user`
  - `me-profile`
  - `me-session`
  - `messages-unread-count`
  - `messages-summary`
  - `equipment-ledger`
  - `equipment-admin-owners`
  - `equipment-owners`
  - `roles-list`
  - `production-data-unfinished-progress`
  - `production-scrap-statistics`
  - `production-assist-user-options`
  - `production-pipeline-instances`
  - `production-my-orders`

## 6. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | Docker inspect 输出 | 2026-04-09 | `backend-web` 容器健康，无需重建 | 独立验证子 agent |
| E2 | `remaining_read_40_group1_round6.json` | 2026-04-09 | group1 auth/authz 热路径整体超线 | 独立验证子 agent |
| E3 | `remaining_read_40_group2_round6.json` | 2026-04-09 | group2 authz/me/messages 热路径整体超线 | 独立验证子 agent |
| E4 | `remaining_read_40_group3_round6.json` | 2026-04-09 | group3 设备账册与所有者相关链路部分超线 | 独立验证子 agent |
| E5 | `remaining_read_40_group4_round6.json` | 2026-04-09 | group4 全部通过 | 独立验证子 agent |
| E6 | `remaining_read_40_group5_round6.json` | 2026-04-09 | group5 整体 gate 通过，但 `roles-list` 逐链路超线 | 独立验证子 agent |
| E7 | `remaining_read_40_group6_round6.json` | 2026-04-09 | group6 全部通过 | 独立验证子 agent |
| E8 | `remaining_read_40_group7_round6.json` | 2026-04-09 | group7 整体 gate 通过，但 `production-data-unfinished-progress` 逐链路超线 | 独立验证子 agent |
| E9 | `remaining_read_40_group8_round6.json` | 2026-04-09 | group8 生产相关链路仍有 4 条超线 | 独立验证子 agent |

## 7. 迁移说明
- 无迁移，直接替换
