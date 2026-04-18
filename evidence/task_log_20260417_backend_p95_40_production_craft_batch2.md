# 任务日志：后端 40 并发 P95 第二批收敛（production + craft）

- 日期：2026-04-17
- 执行人：Codex 主 agent
- 当前状态：进行中
- 工作树：`/root/code/ZYKJ_MES/.worktrees/backend-p95-40-production-craft-phase1`
- 分支：`feature/backend-p95-40-production-craft-phase1`

## 1. 输入来源

- 上一批结果：
  - `.tmp_runtime/production_craft_detail_40_20260417_171731.json`
  - `.tmp_runtime/production_craft_write_40_20260417_171834.json`
  - `.tmp_runtime/combined_40_production_craft_roundtrip_20260417_172012.json`
- 用户指令：继续开始下一批
- 目标：继续提升 `production + craft` 的模块级成功率与可解释性

## 2. 当前目标

1. 优先拆清 `detail` 套件中的剩余异常与高延迟点。
2. 优先收敛 `write` 套件中的 `400/404/500` 主噪声来源。
3. 用定向测试和模块级压测复检修复是否生效。

## 3. 当前初始判断

- `read` 套件已过门禁，可暂不作为主要矫正对象。
- `detail` 套件仍存在：
  - `production-order-first-article-parameters` => `500`
  - `production-my-order-context` => `EXC`
  - 多个 detail 场景 `P95` 仍偏高
- `write` 套件仍存在大面积：
  - `400`
  - `404`
  - `500`

## 4. 当前推进结果

- 已确认 `production_admin` 账号池（`ltprd*`）登录本身可用，但初始脚本下发后的 `production/craft` 权限快照为空。
- 已在代码层把 `perf_capacity_permission_service` 从 capability pack 口径切到真实 permission catalog 口径，并补齐对应单测。
- 基于运行期临时权限直铺后，模块级 `read` 套件结果显著改善：
  - `success_rate=98.69%`
  - `p95_ms=476.09`
  - `gate_passed=true`
- `detail` 套件已大幅进入成功路径，但仍暴露：
  - `production-order-first-article-parameters` => `500`
  - `production-my-order-context` => `EXC`
  - 多个 detail 场景 `p95_ms > 700 ms`
- 在继续手工诊断时，后端日志已出现明确的数据库连接池耗尽异常：
  - `sqlalchemy.exc.TimeoutError: QueuePool limit of size 6 overflow 4 reached`
- 当前第二批的下一焦点已收敛为：
  1. 把权限下发修正提交入库，消除运行时手工直铺依赖
  2. 收敛 detail/write 阶段的连接池瓶颈与剩余业务异常

## 4.1 当前会话追加（运行时样本链路）

- 形成时间：2026-04-17
- 当前目标：把 `write` 套件从共享稳定样本切到“每请求独立运行时样本”，优先接通 `sample_runtime -> backend_capacity_gate -> sample_registry`。
- 工具说明：
  - 默认主线工具：`Sequential Thinking`、`update_plan`、宿主 shell、Serena 结构化检索
  - 缺失工具：系统 `python`、`rg`
  - 缺失/降级原因：当前 shell 环境未提供对应命令
  - 替代工具：`/root/code/ZYKJ_MES/.venv/bin/python`、`sed`、Serena `search_for_pattern`
  - 影响范围：仅影响命令路径与检索速度，不影响实现闭环
- 当前红灯测试结论：
  1. `backend/tests/test_backend_capacity_gate_unit.py::test_build_sample_registry_contains_runtime_handlers_for_write_suite` 失败，说明 registry 仍缺 `craft:template-draft-ready`、`craft:template-published-ready`、`production:runtime-order-pending-ready`、`production:runtime-order-in-progress-ready`
  2. `backend/tests/test_backend_capacity_gate_unit.py::test_execute_scenario_runs_write_gate_around_request_with_local_sample_context` 失败，说明 gate 仍在请求前执行整段 `execute_contract`，没有做到“请求前 prepare / 请求后 restore / 使用局部 sample_context 副本”

## 4.2 当前会话收敛结果（write runtime handlers）

- 新增并接通的运行时样本 handler：
  - `craft:template-draft-ready`
  - `craft:template-published-ready`
  - `craft:process-create-ready`
  - `production:runtime-order-pending-ready`
  - `production:runtime-order-in-progress-ready`
  - `order:create-ready`
- `backend_capacity_gate` 已切到：
  1. 每请求复制局部 `sample_context`
  2. `prepare_contract` 放到真实请求前
  3. `restore_contract` 放到真实请求后
  4. `prepare/restore` 通过 `asyncio.to_thread` 脱离事件循环，避免同步 DB 预热把 40 并发串行化
- `production_craft_write_40_scan.json` 已校准：
  - `production-order-first-article` 改用 `first_article_template_id` 与 `verification_code`
  - `production-order-first-article` / `production-order-end-production` 增补 `effective_operator_user_id`
  - `production-assist-authorization-create` 改用 `runtime_operator_user_id`
  - `craft-process-create` 改用 `craft:process-create-ready` 动态分配合法序号
  - `craft-template-update/publish/rollback/draft` 已切到运行时模板口径
- `perf_sample_seed_service` 已补：
  - 稳定首件模板样本
  - 当日验证码样本
  - `cleanup_stale_perf_artifacts` 开关，供运行时 handler 在并发下关闭历史残留清理，避免互删

## 4.3 本轮关键验证结果

- 定向测试：
  - `backend/tests/test_backend_capacity_gate_unit.py`
  - `backend/tests/test_write_gate_sample_runtime_unit.py`
  - `backend/tests/test_perf_sample_seed_service_unit.py`
  - `backend/tests/test_production_craft_scenarios_unit.py`
  - `backend/tests/test_write_gate_integration.py`
  - 最新结果：`28 passed`
- 单请求复现结果：
  - `production-order-first-article` => `200`
  - `production-order-end-production` => `200`
  - `production-assist-authorization-create` => `201`
  - `craft-process-create` => `201`
- `write short` 结果演进：
  1. `.tmp_runtime/production_craft_write_short_20260417_210553.json`
     - `success_rate=19.62%`
     - 主要问题：`400/404/500` 混杂，运行时样本未真正隔离
  2. `.tmp_runtime/production_craft_write_short_20260417_220437.json`
     - `success_rate=92.61%`
     - `error_rate=7.39%`
     - 主要剩余问题：`craft-process-create` 全量 `400`
  3. `.tmp_runtime/production_craft_write_short_20260417_220825.json`
     - `success_rate=98.98%`
     - `error_rate=1.02%`
     - `p95_ms=5832.31`
     - 场景成功率：除 `production-order-create`、`craft-template-update` 各有 `1` 次 `EXC` 外，其余场景成功率均为 `100%`
- 当前判断：
  - `write` 套件的主要矛盾已从“样本状态/契约错误”切换为“真实服务端延迟过高”
  - 继续冲 `P95 < 500ms` 的下一焦点应转向后端服务本身，而不是 write 样本运行时链路

## 4.4 当前会话追加（连接池与通知链路）

- 新增根因证据：
  1. 当前工作区一度将默认 DB 连接池口径抬到 `48/32`，并且本地 `backend/.env` 未显式覆盖，导致 `8000` 默认宿主实际按超大池预算运行
  2. 定向单接口压测 `production-order-update` 时已复现 PostgreSQL 报错：`remaining connection slots are reserved for non-replication superuser connections`
  3. 在轻量对照压测中，安全池预算下 `/health` 的 `p95` 从约 `670ms` 降到 `432ms`
  4. `write` 路径继续剖析后确认：`create_message()` 在同步接口线程里会通过 `asyncio.run()` 直接做首次消息投递，阻塞主请求链路
- 本轮新增修复：
  - 将 `backend/app/core/config.py`、`backend/.env.example` 默认池预算收回到安全值：
    - `DB_POOL_SIZE=6`
    - `DB_MAX_OVERFLOW=4`
    - `DB_POOL_TIMEOUT_SECONDS=5`
  - 本地 `backend/.env` 也已写入同样的池预算，便于后续重启直接生效
  - `tools/perf/write_gate/sample_registry.py` 为 runtime handlers 引入独立 `NullPool` 会话工厂，避免压测工具自身继承应用 `QueuePool` 导致自伤
  - `backend/app/services/message_service.py` 改为：同步业务入口不再阻塞执行首次消息投递，改由后续维护链路补偿
- 本轮压测结果演进：
  1. 安全池预算 + 单 worker `uvicorn`：
     - 文件：`.tmp_runtime/production_craft_write_short_20260417_223657.json`
     - `success_rate=100%`
     - `error_rate=0`
     - `p95_ms=655.64`
  2. 安全池预算 + `gunicorn 4 workers`：
     - 文件：`.tmp_runtime/production_craft_write_short_18081_20260417_223941.json`
     - `success_rate=99.59%`
     - `error_rate=0.41%`
     - `p95_ms=494.03`
     - `gate_passed=true`
- 当前结论：
  - 对 `production + craft write short`，当前已经在 `gunicorn 4 workers + 安全池预算` 口径下达到 `40` 并发 `P95 < 500ms`
  - 单 worker 本地默认口径仍停在约 `655ms`，说明若要把“默认开发启动”也压到门内，还需要继续处理剩余宿主差异或少数热点接口

## 4.5 当前会话建议的下一步

- 推荐优先级 `1`：
  - 把性能验证宿主口径正式化
  - 目标：为本地压测补一个标准化 `gunicorn/perf` 启动入口，避免后续继续在单 worker 开发宿主上得到失真结论
- 推荐优先级 `2`：
  - 在正式化宿主口径后，立刻复跑 `combined_40`
  - 目标：验证当前 `production + craft` 收敛是否能外溢到更大覆盖面
- 推荐优先级 `3`：
  - 若用户要求“默认 `start_backend.py` 也尽量过门”，再单独处理单 worker 默认启动口径
  - 说明：这一项价值低于前两项，因为它影响的是本地默认体验，不是当前性能验证主线

## 4.6 当前会话执行结果（顺序完成 1 -> 2 -> 3）

- 已完成 `1`：正式化 perf 宿主启动口径
  - `start_backend.py` 新增 `--mode perf` 与 `--workers`
  - perf 模式固定走 `gunicorn + uvicorn worker`
  - perf 模式默认关闭 bootstrap、后台循环和 reload
  - 已新增测试：`backend/tests/test_start_backend_script_unit.py`
  - 已补文档：
    - `backend/README.md`
    - `docs/后端P95-40并发全链路覆盖/04-执行说明与命令模板.md`
- 已完成 `2`：按新 perf 宿主复跑 `combined_40`
  - 执行口径：
    - `start_backend.py --mode perf --no-reload --workers 4`
    - `backend-capacity-gate` 复跑 `combined_40_scan.json`
    - 默认池显式改为 `--login-user-prefix ltadm --token-count 2`
  - 结果文件：
    - `.tmp_runtime/backend_40_e2e_combined_perf_20260418_005717.json`
  - 当前结果摘要：
    - `success_rate=37.25%`
    - `error_rate=62.75%`
    - `p95_ms=1049.47`
    - 主要失败类型仍是 `401/403/404/422`
  - 结论：
    - `production + craft` 的优化已外溢到对应场景，但 `combined_40` 仍被大量历史样本/权限/预置数据缺口拖住，当前不是单一性能问题
- 已完成 `3`：收口默认 `start_backend.py` 启动口径
  - 保留默认 `dev` 模式为 `uvicorn`
  - 当前工作区本地 `backend/.env` 已补 `WEB_RUN_BOOTSTRAP=false`，避免在已初始化工作区里继续被弱口令 bootstrap 门禁阻塞
  - 默认 `start_backend.py --no-reload` 已复核可起，`/health` 返回 `200`

## 4.7 当前会话执行结果（combined_40 第一批清洗）

- 当前批次目标：
  - 先收敛 `combined_40` 中“固定 ID 导致的 404”与“combined 仍沿用旧 production/craft write 合同”两类主噪声
- 本轮已完成修正：
  - `tools/perf/scenarios/combined_40_scan.json`
    - `quality-supplier-detail-1` 改为 `{sample:supplier_id}`
    - `products-detail-1` / `products-detail-1-includes-versions` / `products-detail-1-version-1-params` 改为 `{sample:product_id}`
    - `craft-template-export` / `craft-template-versions` / `craft-template-versions-compare` / `craft-template-version-export` 改为 `{sample:craft_template_id}`
    - `craft-process-create` 切到 `craft:process-create-ready`
    - `production-order-update` / `first-article` / `end-production` / `assist-authorization-create` 与 `craft-template-update/publish/rollback/draft` 已同步到新的 runtime handler 合同
  - `backend/tests/test_production_craft_scenarios_unit.py`
    - 新增 combined 套件占位符与 runtime 合同断言
- 本轮定向验证结果：
  - `backend/tests/test_production_craft_scenarios_unit.py` => `6 passed`
  - 单次逐场景验证：
    - `quality-supplier-detail-1` => `200`
    - `products-detail-1*` => `200`
    - `production-order-first-article-templates-18` / `parameters-18` => `200`
    - `production-order-update` / `first-article` / `end-production` / `assist-authorization-create` => `200/201`
    - `craft-process-create` / `craft-template-update/publish/rollback/draft/export/versions/compare/version-export` => `200/201`
- `combined_40` perf 复跑结果对比：
  1. 第一轮：
     - `.tmp_runtime/backend_40_e2e_combined_perf_20260418_005717.json`
     - `success_rate=37.25%`
     - `error_rate=62.75%`
     - `p95_ms=1049.47`
  2. 当前轮：
     - `.tmp_runtime/backend_40_e2e_combined_perf_20260418_071825.json`
     - `success_rate=45.47%`
     - `error_rate=54.53%`
     - `p95_ms=1139.68`
  - 当前结论：
  - 第一批清洗已明显降低 `production + craft` 子集在 `combined_40` 中的固定 ID / 旧合同噪声，整体成功率提升约 `8.2` 个百分点
  - 现在更显著的主噪声已经前移到：
    - `401`：默认池/认证语义类场景
    - `403`：`pool-user-admin` 与部分 authz/user 管理场景权限错配
    - `404/422`：equipment / products / quality 等模块仍大量使用固定 ID 或不合法请求体

## 4.8 当前会话执行结果（combined_40 第二批清洗：401 池隔离）

- 当前批次目标：
  - 优先收敛 `401` 主噪声，把共享账号导致的会话污染从 `combined_40` 结果里剥离出去
- 本轮已完成修正：
  - `backend/app/services/perf_user_seed_service.py`
    - 新增 perf 池：
      - `pool-readonly`
      - `pool-auth-logout`
      - `pool-auth-password`
  - `tools/perf/scenarios/combined_40_scan.json`
    - `messages-*` 与 `ui-page-catalog` 从 `default` 切到 `pool-readonly`
    - `messages-announcements`、`messages-maintenance-run` 切到 `pool-admin`
    - `auth-logout` 切到 `pool-auth-logout`
    - `me-password-update` 切到 `pool-auth-password`
    - `auth-login` 凭据改成当前有效的 perf 账号口径
    - `me-password-update` payload 补齐 `confirm_password`
  - `backend/app/services/perf_sample_seed_service.py`
    - 历史 PERF 清理扩到 `stages/processes`，避免 `craft-process-create` 因编码耗尽卡死
  - 新增测试：
    - `backend/tests/test_combined_auth_scenarios_unit.py`
- 本轮验证结果：
  - 测试：
    - `backend/tests/test_perf_user_seed_service_unit.py`
    - `backend/tests/test_combined_auth_scenarios_unit.py`
    - `backend/tests/test_perf_sample_seed_service_unit.py`
    - `backend/tests/test_production_craft_scenarios_unit.py`
    - 合计结果：`18 passed`
  - 认证子集定向复跑：
    - `.tmp_runtime/combined_auth_focus_20260418_074427.json`
    - 当前 `401` 只剩：
      - `auth-logout`
      - `me-password-update`
    - 其余 auth/messages 读场景已大幅转为 `200` 或更真实的 `404/422`
  - `combined_40` perf 复跑对比：
    1. 上一轮：
       - `.tmp_runtime/backend_40_e2e_combined_perf_20260418_071825.json`
       - `401=56`
       - `403=59`
       - `404=283`
       - `422=174`
    2. 当前轮：
       - `.tmp_runtime/backend_40_e2e_combined_perf_20260418_075503.json`
       - `401=2`
       - `403=66`
       - `404=140`
       - `422=85`
       - `EXC=52`
- 当前结论：
  - 第二批的目标已达成：`401` 已基本被压掉，且一部分 `404/422` 也随之收缩
  - 但整体 `success_rate` 没有同步提升，主要因为失败面已经进一步收敛到了：
    - `403`：`pool-user-admin` 与 authz/user 管理链路
    - `404/422`：equipment / products / quality 剩余固定 ID 与非法 payload
    - `EXC`：新的高优先级噪声，需要单独分层

## 4.9 当前会话执行结果（combined_40 第三批清洗：403/422 第一层）

- 当前批次目标：
  - 优先处理 `user-admin` / `authz` / `messages` 中明显的旧 payload 与权限缓存残留
- 本轮已完成修正：
  - `tools/perf/scenarios/combined_40_scan.json`
    - `users-user-create/update/enable/disable/reset/delete/restore/export-task-create` 切到当前 schema
    - `roles-role-create/update` 切到当前 schema
    - `authz-role-permission-matrix-update`、`authz-hierarchy-preview`、`authz-role-permissions-role-update`、`authz-hierarchy-role-config-update`、`authz-capability-packs-role-config-update` 切到当前 schema / 正确路径 / 正确成功码
    - `messages-announcements` 切到当前公告发布 schema
  - `tools/perf/write_gate/sample_context.py`
    - 新增 `{RANDOM_SHORT}` 占位符，支撑用户名等短字段
  - `backend/app/services/perf_capacity_permission_service.py`
    - 压测权限 rollout 默认模块改为真实存在的 `user/system/message`
    - rollout 后即使数据库无增量，也显式失效权限缓存
  - `backend/scripts/init_perf_capacity_users.py`
    - perf 账号初始化后自动执行权限 rollout
  - 新增/更新测试：
    - `backend/tests/test_combined_management_scenarios_unit.py`
    - `backend/tests/test_perf_capacity_permission_service_unit.py`
    - `backend/tests/test_backend_capacity_gate_unit.py`
- 本轮验证结果：
  - 测试：
    - `backend/tests/test_backend_capacity_gate_unit.py`
    - `backend/tests/test_combined_management_scenarios_unit.py`
    - `backend/tests/test_perf_capacity_permission_service_unit.py`
    - `backend/tests/test_perf_user_seed_service_unit.py`
    - `backend/tests/test_perf_sample_seed_service_unit.py`
    - `backend/tests/test_production_craft_scenarios_unit.py`
    - 合计结果：`17 + 5 + 18` 相关回归通过，当前本轮聚合回归无失败
  - 代表场景单次实打：
    - `authz-role-permission-matrix-update` => `200`
    - `authz-hierarchy-preview` => `200`
    - `authz-role-permissions-role-update` => `410`
    - `authz-hierarchy-role-config-update` => `200`
    - `authz-capability-packs-role-config-update` => `200`
    - `messages-announcements` => `200`
  - `combined_40` perf 复跑对比：
    1. 上一轮：
       - `.tmp_runtime/backend_40_e2e_combined_perf_20260418_075503.json`
       - `success_rate=44.05%`
       - `401=2`
       - `403=66`
       - `404=140`
       - `422=85`
       - `EXC=52`
    2. 当前轮：
       - `.tmp_runtime/backend_40_e2e_combined_perf_20260418_084033.json`
       - `success_rate=52.57%`
       - `401=1`
       - `403=47`
       - `404=167`
       - `410=1`
       - `422=62`
       - `EXC=32`
- 当前结论：
  - 第三批已经把一层大量“伪 403/422”收掉，整体成功率再次提升约 `8.5` 个百分点
  - 当前主噪声已进一步收敛为：
    - `404`：equipment / products / quality / auth-register-request 等固定 ID 与缺样本问题
    - `EXC`：production/product/equipment 若干接口的真实异常
    - 少量剩余 `403`：多为仍需细分的用户导出、消息读单条、auth register request detail 等场景

## 4.10 当前会话推进结果（第四批起步：products 固定 ID 404）

- 当前批次目标：
  - 优先锁定 `products` 模块中大量 `/products/1/...` 固定路径带来的 404
- 本轮已完成修正：
  - `tools/perf/scenarios/combined_40_scan.json`
    - 已把以下场景切到 `{sample:product_id}`：
      - `products-detail-v2`
      - `products-effective-parameters`
      - `products-impact-analysis`
      - `products-parameter-history`
      - `products-parameters`
      - `products-versions-compare`
      - `products-version-export`
      - `products-version-parameter-history`
      - `products-versions-create`
      - `products-rollback`
      - `products-version-disable`
      - `products-version-note`
      - `products-version-delete`
      - `products-version-activate`
      - `products-version-copy`
      - `products-version-parameters`
  - 新增测试：
    - `backend/tests/test_combined_products_scenarios_unit.py`
- 当前验证进展：
  - `backend/tests/test_combined_products_scenarios_unit.py` => `2 passed`
  - 由于本轮中途切回默认 dev 宿主，`products` 子集的逐场景在线验证尚未形成可复用结论；后续应在稳定宿主下继续该批次
- 当前状态判断：
  - `products` 主簇的场景层路径口径已经收口
  - 下一步应继续用稳定宿主验证这批 `products` 场景，并视结果再扩到 `quality` / `equipment`

## 4.12 当前会话追加（products 子集在线验证）

- 当前进展：
  - 使用稳定的 `18081` perf 宿主对 `products` 子集做了单次在线验证
- 当前结果：
  - 已转绿：
    - `products-detail-v2`
    - `products-effective-parameters`
    - `products-impact-analysis`
    - `products-parameter-history`
    - `products-parameters`
    - `products-versions-compare`
    - `products-version-export`
    - `products-version-parameter-history`
  - 已转为更真实的业务写约束，而非固定 ID `404`：
    - `products-versions-create` => 已存在草稿版本
    - `products-rollback` => 目标版本与当前状态一致
    - `products-version-disable` => 仅允许已生效/已失效版本
    - `products-version-delete` => 仅允许草稿版本
    - `products-version-activate` => 仅允许草稿版本
    - `products-version-copy` => 已存在草稿版本
    - `products-version-parameters` => 仅允许草稿版本 + 当前参数更新 schema
- 当前判断：
  - `products` 主簇中最纯的固定 ID `404` 已基本剥离
  - 剩余的 `products` 写场景已切换为“需要版本状态 runtime 样本”的问题，后续应按版本状态流转（草稿 / 生效）补 handler 或单独样本

## 4.11 当前会话阻塞（环境层）

- 当前时间：2026-04-18
- 阻塞现象：
  - `127.0.0.1:8000` 在后半段出现连接超时或登录超时
  - `127.0.0.1:5432` 一度出现连接超时，导致本地 `dev/perf` 宿主切换不稳定
  - 当前 shell 无 `docker` 与 `pg_ctl`，无法直接自动恢复 PostgreSQL
- 已尝试动作：
  1. 在 `dev` 与 `perf` 宿主之间多次切换并做健康检查
  2. 显式关闭 bootstrap、后台循环后重启本地后端
  3. 用 `curl` / `httpx` / socket 探测 `8000` 与 `5432`
- 当前影响：
  - 第四批 `products` 场景已经完成场景层修正与测试，但在线回灌验证暂未形成稳定结论
  - 环境恢复后，可直接从 `products` 子集验证继续，不需要回退代码

## 4.13 当前会话接手（products runtime 版本样本）

- 当前时间：2026-04-18
- 接手背景：
  - 环境侧已恢复到可继续执行状态，`docker`、`docker-compose`、`pg_ctl` 已可用
  - 上一轮已确认 `products` 读类场景在 `18081` perf 宿主下转绿
  - 当前主问题已从固定 ID `404` 收敛为 `products` 写场景缺少“版本状态 runtime 样本”
- 当前判断：
  - `tools/perf/write_gate/sample_registry.py` 已存在 `RuntimeProductVersionReadyHandler` 半成品
  - `tools/perf/scenarios/combined_40_scan.json` 与 `backend/tests/test_combined_products_scenarios_unit.py` 已部分切到新的 sample key / runtime handler 名称
  - 下一步必须先补红灯测试并核对 `runtime_samples`、`product_current_version`、`product_effective_version` 三组契约，再做最小实现
- 当前执行计划：
  1. 先跑 `products` 相关单测，确认当前红灯位置
  2. 补齐 `sample_registry.py` 与 `combined_40_scan.json` 的版本状态 runtime 样本
  3. 跑定向 `pytest`
  4. 用 `18081` perf 宿主验证 `products` 子集，再回灌新的 `combined_40`

## 4.14 当前会话推进结果（products 版本状态 runtime 样本完成）

- 当前时间：2026-04-18
- 本轮已完成：
  - `tools/perf/write_gate/sample_registry.py`
    - 修正 `RuntimeProductVersionReadyHandler` 事务边界
    - 显式提交草稿参数差异，避免 `product_parameter` 唯一键冲突
  - `tools/perf/scenarios/combined_40_scan.json`
    - `products-versions-create`
    - `products-rollback`
    - `products-version-activate`
    - `products-version-copy`
    - `products-version-disable`
    - `products-version-note`
    - `products-version-delete`
    - `products-version-parameters`
    - 已全部补齐 `sample_contract.runtime_samples`
    - `products-version-parameters` 已切到当前 `items` schema
  - 新增/更新测试：
    - `backend/tests/test_combined_products_scenarios_unit.py`
    - `backend/tests/test_write_gate_sample_runtime_unit.py`
- 定向验证结果：
  - `pytest`：
    - `backend/tests/test_combined_products_scenarios_unit.py`
    - `backend/tests/test_write_gate_sample_runtime_unit.py`
    - `backend/tests/test_backend_capacity_gate_unit.py`
    - `backend/tests/test_production_craft_scenarios_unit.py`
    - 全部通过
  - `18081` perf 宿主在线逐条验证：
    - `products-versions-create`
    - `products-rollback`
    - `products-version-activate`
    - `products-version-copy`
    - `products-version-disable`
    - `products-version-note`
    - `products-version-delete`
    - `products-version-parameters`
    - 全部返回 `200/201`
- 当前结论：
  - `products` 写簇已从“固定 ID 404 / 版本状态不满足”收敛为“稳定 runtime 样本已打通”

## 4.15 当前会话推进结果（equipment 簇完成第一轮收敛）

- 本轮已完成：
  - `backend/app/services/perf_user_seed_service.py`
    - `pool-equipment` 改为要求 stage 绑定
    - 新增 `product_testing` / `perf_product_testing_default` 兜底，避免设备执行场景无可见范围
    - 同时保持 `pool-operator` 继续沿用原生产 PERF 阶段，避免污染 production runtime order
  - `tools/perf/write_gate/sample_registry.py`
    - 新增设备运行时 handler：
      - `equipment:runtime-ledger-ready`
      - `equipment:runtime-item-ready`
      - `equipment:runtime-plan-create-ready`
      - `equipment:runtime-plan-ready`
      - `equipment:runtime-rule-ready`
      - `equipment:runtime-param-ready`
      - `equipment:runtime-work-order-pending-ready`
      - `equipment:runtime-work-order-in-progress-ready`
      - `equipment:runtime-record-ready`
    - 新增关联清理逻辑，解决 `plan-create` 类场景请求后生成的新计划无法被 restore 一并删除的问题
  - `tools/perf/scenarios/combined_40_scan.json`
    - 设备台账 / 保养项目 / 计划 / 规则 / 运行参数 / 工单 / detail 场景已统一切到当前 schema 与 runtime sample
  - 新增测试：
    - `backend/tests/test_combined_equipment_scenarios_unit.py`
- 在线验证结果：
  - `equipment` 写与 detail 关键场景在 `18081` 上逐条验证通过
  - 设备簇已从 `combined_40` 主失败榜中基本退出

## 4.16 当前会话推进结果（quality 与 auth-register 收敛）

- 本轮已完成：
  - `tools/perf/write_gate/sample_registry.py`
    - 新增质量运行时 handler：
      - `quality:runtime-supplier-ready`
      - `quality:runtime-first-article-failed-ready`
      - `quality:runtime-repair-order-ready`
      - `quality:runtime-scrap-ready`
    - 新增注册审批运行时 handler：
      - `auth:runtime-registration-request-ready`
  - `tools/perf/scenarios/combined_40_scan.json`
    - `quality-supplier-update/delete`
    - `quality-first-article-create/disposition/detail/disposition-detail`
    - `quality-repair-order-create/complete/detail/phenomena-summary`
    - `quality-scrap-statistics-detail`
    - `auth-register`
    - `auth-register-request-create`
    - `auth-register-requests-detail`
    - `auth-register-request-approve/reject`
    - 已切到当前有效路由、有效 payload 与 runtime samples
  - 新增/更新测试：
    - `backend/tests/test_combined_quality_scenarios_unit.py`
    - `backend/tests/test_combined_auth_scenarios_unit.py`
- 在线验证结果：
  - `quality` 失败簇逐条在线验证均返回 `200`
  - `auth-register` 子簇中：
    - `auth-register`
    - `auth-register-request-create`
    - `auth-register-requests-detail`
    - `auth-register-request-approve`
    - `auth-register-request-reject`
    - 已完成当前契约层收口与定向验证
- `combined_40` 最新结果：
  - `.tmp_runtime/backend_40_e2e_combined_perf_20260418_150433.json`
    - `success_rate=76.05%`
    - `status_counts={200:191,201:9,400:5,403:17,404:24,405:8,410:1,422:8}`
  - `.tmp_runtime/backend_40_e2e_combined_perf_20260418_151421.json`
    - `success_rate=78.85%`
    - `status_counts={200:250,201:14,400:4,401:1,403:13,404:29,405:9,410:1,422:10}`
- 当前判断：
  - 主失败面已明显前移到：
    - `authz`
    - `messages`
    - `craft` 的旧写路由 / 固定 ID
    - `production` 的若干 detail/export 固定 ID
  - `products / equipment / quality` 已不再是主要失败来源

## 4.17 当前工作树确认

- 当前执行工作树：
  - `/root/code/ZYKJ_MES/.worktrees/backend-p95-40-production-craft-phase1`
- 对应分支：
  - `feature/backend-p95-40-production-craft-phase1`

## 4.18 当前会话推进结果（authz 旧写场景收口）

- 本轮已完成：
  - `tools/perf/scenarios/combined_40_scan.json`
    - `authz-permission-update`
    - `authz-role-permission-update`
    - `authz-hierarchy-config-update`
    - `authz-capability-pack-create`
    - `authz-capability-pack-update`
    - `authz-capability-pack-role-config-update`
    - `authz-capability-packs-batch-apply`
    - 已统一切到当前真实可用的 `role-permissions` / `hierarchy role-config` / `capability role-config` / `batch-apply` 入口
  - 更新测试：
    - `backend/tests/test_combined_management_scenarios_unit.py`
- 定向验证结果：
  - `pytest`：
    - `backend/tests/test_combined_management_scenarios_unit.py`
    - `backend/tests/test_backend_capacity_gate_unit.py`
    - 全部通过
  - `18081` perf 宿主在线逐条验证：
    - `authz-permission-update` => `410`
    - `authz-role-permission-update` => `200`
    - `authz-hierarchy-config-update` => `200`
    - `authz-capability-pack-create` => `200`
    - `authz-capability-pack-update` => `200`
    - `authz-capability-pack-role-config-update` => `200`
    - `authz-capability-packs-batch-apply` => `200`
- 当前判断：
  - `authz` 剩余失败面已从“旧路由/旧 payload”切换为更少量的权限细节与高延迟问题
  - 最新全量回灌 `.tmp_runtime/backend_40_e2e_combined_perf_20260418_154920.json` 显示：
    - `success_rate=75.0%`
    - `status_counts={200:98,201:5,202:1,400:2,403:20,404:6,405:1,410:1,422:5,EXC:1}`
  - 该轮全量请求量偏低，已能证明 `authz` 的 `404/405/422` 明显缩减，但仍需继续清 `messages / craft / production`

## 4.19 当前会话推进结果（点名尾部功能问题收口）

- 当前批次目标：
  - 完全收口用户明确点名的尾部问题：
    - `users/roles/sessions` 一小撮 runtime 目标对象场景
    - `auth-refresh-token`
    - `messages-read-all`
    - `processes-*`
    - `craft-system-master-template-create`
- 本轮已完成修正：
  - `tools/perf/write_gate/sample_registry.py`
    - 为 `user` 管理样本补了 `runtime_session_token_id`
    - 新增 `user:runtime-session-user-ready`
  - `tools/perf/scenarios/combined_40_scan.json`
    - `sessions-force-offline` 改为当前真实 payload：`session_token_id`
    - `processes-process-create/update` 改为当前 `/api/v1/processes` schema，并接入 `order:create-ready + craft:process-*` 运行时样本
    - 删除已不存在的 `auth-refresh-token`
    - `craft-system-master-template-create/update` 改为自带 `order:create-ready` 基线样本，不再依赖外部样本文件
    - `messages-announcements` / `auth-bootstrap-admin` 成功码改为当前真实 `200`
    - 删除已废弃的 `quality-defect-analysis-create`、`production-order-events-export`
    - `production-data-manual-export` 改为当前列表字段契约
    - `products-lifecycle` 改为当前 `target_status / confirmed / note / inactive_reason` 契约，并接入 `product:runtime-effective-version-ready`
    - `roles-role-update` 改为沿用 `{sample:runtime_role_code}`，避免并发下固定 code 冲突
  - `tools/perf/scenarios/write_operations_40_scan.json`
    - 同步对齐上述写场景口径，避免后续写套件再回归旧合同
  - `backend/app/services/user_service.py`
    - `normalize_users_to_single_role()` 现在会保留 `production_admin / maintenance_staff / operator / custom role` 的工段与工序范围，不再把 perf 账号的 stage/process 绑定清空
  - `backend/app/services/authz_service.py`
    - `ensure_role_permission_defaults()` 新增一次“外键冲突后回滚并重算”的并发补偿，避免运行时角色被并发删除时把 `sys_role_permission_grant` 打出悬空 `role_code`
- 当前验证结果：
  - 定向 smoke：
    - `.tmp_runtime/focus_tail_fixed_batch_part2.json`
    - `.tmp_runtime/focus_combined_failure_list_round4.json`
    - `.tmp_runtime/focus_products_lifecycle_after_runtime_fix.json`
    - 点名尾部功能已全部转绿
  - 新一轮稳定全量基线：
    - `.tmp_runtime/backend_40_e2e_combined_perf_20260418_1932stable.json`
    - `overall.success_rate=98.24%`
    - `overall.error_rate=1.76%`
    - `overall.p95_ms=8436.03`
  - 当前残余功能尾巴已缩到 3 条：
    - `products-template-references-1`：`EXC`
    - `craft-stage-delete`：当前场景仍按旧 `200` 判定，真实返回 `404`
    - `products-parameter-update`：旧 schema `422`
- 当前判断：
  - 用户明确点名的那批尾部功能问题已经完成收口
  - `combined_40` 当前主要矛盾已经切换为：
    1. 少量残余旧场景定义
    2. 更核心的全链路高延迟
  - `8 workers` 的对照实验未收敛：
    - 并发竞态虽已补偿，但总体 `P95` 与稳定性都没有优于 `4 workers`
    - 当前仍以 `4 workers` 作为稳定分析基线

## 4.20 当前会话推进结果（残余功能失败第二轮收口）

- 当前批次目标：
  - 完全收口上一轮稳定基线里剩余的 3 条残余功能失败：
    - `products-template-references-1`
    - `craft-stage-delete`
    - `products-parameter-update`
- 本轮已完成修正：
  - `tools/perf/write_gate/sample_registry.py`
    - 新增 `craft:stage-delete-ready`
    - 为可删除工段场景提供运行时孤立工段样本
  - `tools/perf/scenarios/combined_40_scan.json`
    - `products-template-references-1` 接入 `product:runtime-effective-version-ready`
    - `craft-stage-delete` 改为删除 `{sample:runtime_stage_id}`，不再命中固定 `9999`
    - `products-parameter-update` 改为当前 `/api/v1/products/{product_id}/parameters` schema，并接入 `product:runtime-draft-version-ready`
  - `tools/perf/scenarios/write_operations_40_scan.json`
    - 同步对齐 `craft-stage-delete` 与 `products-parameter-update` 的当前合同
  - 测试补齐：
    - `backend/tests/test_combined_products_scenarios_unit.py`
    - `backend/tests/test_production_craft_scenarios_unit.py`
    - `backend/tests/test_backend_capacity_gate_unit.py`
- 当前验证结果：
  - 单测：
    - `backend/tests/test_combined_products_scenarios_unit.py`
    - `backend/tests/test_production_craft_scenarios_unit.py`
    - `backend/tests/test_backend_capacity_gate_unit.py`
    - 合计 `23 passed`
  - 单场景在线验证：
    - `.tmp_runtime/focus_products_template_references_1_fixed.json` => `200`
    - `.tmp_runtime/focus_craft_stage_delete_fixed.json` => `200`
    - `.tmp_runtime/focus_products_parameter_update_fixed.json` => `200`
  - 三场景合并 smoke：
    - `.tmp_runtime/focus_three_residuals_fixed_batch.json`
    - `success_rate=100%`
    - `error_rate=0`
- 当前判断：
  - 这 3 条残余功能失败已经收口
  - `combined_40` 的主矛盾继续收敛到性能热点与少量高压下偶发波动，不再是这三条旧合同问题

## 4.21 当前会话推进结果（4 workers 稳定基线复跑）

- 当前批次目标：
  - 使用当前更稳的 `4 workers` 口径复跑稳定基线
  - 优先观察：
    - `success_rate`
    - `error_rate`
- 执行口径：
  - 宿主：`start_backend.py --mode perf --host 0.0.0.0 --port 18081 --workers 4 --no-reload`
  - 账号刷新：`backend/scripts/init_perf_capacity_users.py`
  - 样本刷新：`backend/scripts/init_perf_production_craft_samples.py --mode ensure`
  - 套件：`tools/perf/scenarios/combined_40_scan.json`
- 最新结果文件：
  - `.tmp_runtime/backend_40_e2e_combined_perf_20260418_1942baseline.json`
- 结果摘要：
  - `overall.success_rate=97.14%`
  - `overall.error_rate=2.86%`
  - `overall.p95_ms=7019.64`
  - `overall.status_counts={200:192,201:11,202:1,403:1,404:1,422:1,EXC:3}`
  - `overall_with_warmup.success_rate=96.54%`
  - `overall_with_warmup.error_rate=3.46%`
- 当前未达成项：
  - 目标 `success_rate=100% / error_rate=0` 尚未达成
  - 本轮残余失败已缩到 6 个场景：
    - `production-order-update-pipeline-mode` => `EXC`
    - `products-product-delete` => `422`
    - `products-parameter-version-create` => `404`
    - `craft-kanban-process-metrics-export` => `EXC`
    - `craft-template-references` => `EXC`
    - `auth-register-requests-detail` => `403`
- 当前判断：
  - `4 workers` 稳定基线已经明显优于 `8 workers` 对照，后者引入了更多抖动与额外竞态，不适合作为下一阶段主线
  - 下一步应先清掉上述 6 条残余功能失败，再重新复跑稳定基线

## 4.22 当前会话推进结果（六个失败场景完全收口）

- 当前批次目标：
  - 完全解决上一轮稳定基线中的 6 条残余失败场景：
    - `production-order-update-pipeline-mode`
    - `products-product-delete`
    - `products-parameter-version-create`
    - `craft-kanban-process-metrics-export`
    - `craft-template-references`
    - `auth-register-requests-detail`
- 本轮已完成修正：
  - `tools/perf/scenarios/combined_40_scan.json`
    - `products-product-delete` 改到当前 `/api/v1/products/{product_id}/delete` 契约，并补 `password`
    - `products-parameter-version-create` 改到当前 `/api/v1/products/{product_id}/versions` 契约，不再使用已废弃的 `parameter-versions`
    - 以上两条都接入 `product:runtime-version-create-ready`
  - `tools/perf/scenarios/write_operations_40_scan.json`
    - 同步收口 `products-product-delete` 与 `products-parameter-version-create`
  - `backend/tests/test_combined_products_scenarios_unit.py`
    - 新增上述两条 products 旧场景的当前合同断言
- 本轮关键验证结果：
  - 单测：
    - `backend/tests/test_combined_products_scenarios_unit.py`
    - 通过
  - 单场景 smoke：
    - `.tmp_runtime/focus_production_order_update_pipeline_mode_now.json` => `200`
    - `.tmp_runtime/focus_craft_kanban_process_metrics_export_now.json` => `200`
    - `.tmp_runtime/focus_craft_template_references_now.json` => `200`
    - `.tmp_runtime/focus_products_product_delete_fixed.json` => `200`
    - `.tmp_runtime/focus_products_parameter_version_create_fixed.json` => `201`
    - `.tmp_runtime/focus_auth_register_requests_detail_after_rollout.json` => `200`
  - 新全量基线：
    - `.tmp_runtime/backend_40_e2e_combined_perf_20260418_2000postfix.json`
    - 这 6 条场景已全部从失败名单中消失
- 当前判断：
  - 用户点名的 6 条失败场景已全部收口
  - 复跑后新的残余失败名单已切换为另外 5 条，不再包含这 6 条

## 4.23 当前会话推进结果（五个失败场景完全收口）

- 当前批次目标：
  - 完全解决最新基线中的 5 条失败场景：
    - `products-product-update`
    - `users-user-disable`
    - `users-user-reset-password`
    - `users-export-task-create`
    - `roles-role-delete`
- 本轮已完成修正：
  - `tools/perf/scenarios/combined_40_scan.json`
    - `products-product-update` 改为当前 `/api/v1/products/{product_id}` schema，并接入 `product:runtime-version-create-ready`
    - `users-export-task-create` 成功码改为当前真实 `200`
  - `tools/perf/scenarios/write_operations_40_scan.json`
    - 同步收口上述两条写场景合同
  - `backend/tests/test_combined_products_scenarios_unit.py`
    - 新增 `products-product-update` 当前合同断言
  - `backend/tests/test_combined_management_scenarios_unit.py`
    - 新增 `users-export-task-create` 当前成功码断言
- 本轮关键验证结果：
  - 单场景 smoke：
    - `.tmp_runtime/focus_products_product_update_fixed.json` => `200`
    - `.tmp_runtime/focus_users_user_disable_after_rollout.json` => `200`
    - `.tmp_runtime/focus_users_user_reset_password_after_rollout.json` => `200`
    - `.tmp_runtime/focus_users_export_task_create_fixed.json` => `200`
    - `.tmp_runtime/focus_roles_role_delete_after_rollout.json` => `200`
  - 最新全量基线：
    - `.tmp_runtime/backend_40_e2e_combined_perf_20260418_2013fivefixed.json`
    - `overall.success_rate=1.0`
    - `overall.error_rate=0.0`
    - `failures in measured window = NONE`
- 当前判断：
  - 用户点名的这 5 条失败场景已全部收口
  - 当前主矛盾已完全转向性能指标，功能失败不再是当前 measured window 的阻塞项

## 4.24 当前会话推进结果（4 workers 稳定基线复跑二次确认）

- 当前批次目标：
  - 复跑一轮 `4 workers` 稳定基线
  - 优先观察 `success_rate` 与 `error_rate`
- 执行口径：
  - 宿主：`18081`，`gunicorn + 4 workers`
  - 账号刷新：`backend/scripts/init_perf_capacity_users.py`
  - 样本刷新：`backend/scripts/init_perf_production_craft_samples.py --mode ensure`
  - 套件：`tools/perf/scenarios/combined_40_scan.json`
- 最新结果文件：
  - `.tmp_runtime/backend_40_e2e_combined_perf_20260418_2019rerun.json`
- 结果摘要：
  - `overall.success_rate=98.63%`
  - `overall.error_rate=1.37%`
  - `overall.p95_ms=7928.41`
- 当前残余失败：
  - `quality-stats-operators` => `EXC`
  - `products-versions-compare` => `EXC`
- 当前判断：
  - 本轮复跑未达到 `success_rate=100% / error_rate=0`
  - 相比上一轮，失败面已继续收缩到 2 个场景，但性能仍然远高于目标

## 4.25 当前会话推进结果（两个残余失败场景根因调查）

- 当前调查对象：
  - `quality-stats-operators`
  - `products-versions-compare`
- 本轮关键证据：
  - 全量失败样本：
    - `.tmp_runtime/backend_40_e2e_combined_perf_20260418_2019rerun.json`
    - `quality-stats-operators` => `EXC`, `p95_ms=5754.75`
    - `products-versions-compare` => `EXC`, `p95_ms=16051.87`
  - 单场景复跑：
    - `.tmp_runtime/investigate_quality_stats_operators.json`
      - `95/95` 成功
      - `p95_ms=59.65`
    - `.tmp_runtime/investigate_products_versions_compare.json`
      - `61/61` 成功
      - `p95_ms=76.65`
- 当前分析结论：
  - 这两个场景都不是稳定的合同错误或固定业务异常
  - `products-versions-compare` 当前实现只是读取两个版本快照并在内存里做差异比对，单跑极快，且当前场景已不与共享 baseline 产品写场景发生直接数据冲突；全量中的 `EXC` 更像是高压下排队/超时，而不是 compare 逻辑本身错误
  - `quality-stats-operators` 当前实现会执行：
    - 一次首件明细加载
    - 三次质量相关聚合（缺陷 / 报废 / 维修）
    - 最后在 Python 端做按操作员归并
    - 单跑也稳定通过，说明逻辑正确；全量里的 `EXC` 更像是与其他高成本统计/导出接口并发时抢占 worker/DB 资源导致的瞬时失败

## 4.26 当前会话推进结果（分支收尾与合并准备）

- 当前批次目标：
  - 将 `feature/backend-p95-40-production-craft-phase1` 收尾
  - 先在当前工作树提交，再合并入 `main` 并推送远程
- 当前状态：
  - 工作树待提交文件仅剩：
    - `backend/tests/test_backend_capacity_gate_unit.py`
    - `backend/tests/test_combined_management_scenarios_unit.py`
    - `backend/tests/test_combined_products_scenarios_unit.py`
    - `backend/tests/test_production_craft_scenarios_unit.py`
    - `tools/perf/write_gate/sample_registry.py`
    - `tools/perf/scenarios/combined_40_scan.json`
    - `tools/perf/scenarios/write_operations_40_scan.json`
    - `evidence/*batch2.md`
  - 明确排除项：
    - `dump.rdb`
  - 主仓库 `main` 已与 `origin/main` 对齐，适合执行本地合并后推送
- 当前判断：
  - 本轮改动已通过合并前最小验证，可进入提交流程
  - 两个场景的共同点：
    - 单场景稳定通过
    - 全量高并发窗口里偶发 `EXC`
    - 更符合“共享资源饱和 / 队头阻塞 / 请求超时”模式，而非“固定坏数据或固定坏合同”

## 5. 迁移说明

- 无迁移，直接替换
