# 任务日志：remaining_read_40 当前确认状态收口

- 日期：2026-04-09
- 执行人：Codex 主 agent（指挥官模式）
- 当前状态：未完成，按用户指令先行收口当前已确认结论
- 指挥模式：主 agent 汇总当前证据，不继续推进未完成复测

## 1. 当前已确认结论

- `remaining_read_40` 全量场景数：`63`
- `round9` 已确认单链通过：
  - `auth-me`
  - `authz-hierarchy-role-config-user`
- `round9` 已确认单链未通过：
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

## 2. 当前轮已确认代码与本地验证

- 分页列表/会话链与 quality 链已有新修改落地。
- 本地定向验证已通过：
  - `python -m pytest backend/tests/test_session_service_unit.py backend/tests/test_quality_service_stats_unit.py`
  - 结果：`19 passed`
- `authz/ui` 收口仍未完成；当前定向验证存在失败：
  - `python -m pytest backend/tests/test_authz_service_unit.py backend/tests/test_api_deps_unit.py backend/tests/test_me_endpoint_unit.py backend/tests/test_auth_endpoint_unit.py`
  - 结果：`2 failed, 29 passed`
  - 失败点：`test_get_permission_codes_for_role_codes_coalesces_concurrent_miss`、`test_get_role_permission_matrix_coalesces_concurrent_miss`

## 3. 当前未确认范围

- 上述分页列表/会话链与 quality 链虽然已有代码修改和本地单测通过，但尚未重建容器并重跑 `40` 并发门禁，因此**不能确认已经达标**。
- `authz/ui` 侧当前仍在收口过程中，本地并发缓存相关单测未通过，因此**不能确认已经达标**。
- 除 `round9` 已逐链验证的 `16` 条场景外，其余 `47` 条场景当前缺少“单链独立 40 并发通过”证据，仅能视为**未确认**。

## 4. 后续需补跑清单

### 4.1 失败链优先补跑

1. `auth-register-requests`
2. `authz-permissions-catalog-user`
3. `authz-snapshot`
4. `authz-role-permissions-user`
5. `authz-role-permissions-matrix-user`
6. `authz-hierarchy-catalog-user`
7. `roles-list`
8. `audits-list`
9. `sessions-login-logs`
10. `sessions-online`
11. `ui-page-catalog`
12. `quality-stats-overview`
13. `quality-stats-processes`
14. `quality-stats-operators`

### 4.2 其余未逐链确认场景

- `63 - 16 = 47` 条 remaining_read_40 场景仍需按最终门禁口径补证；在本轮提前收口前，尚未完成它们的逐链独立确认。

## 5. 迁移说明

- 无迁移，直接替换
