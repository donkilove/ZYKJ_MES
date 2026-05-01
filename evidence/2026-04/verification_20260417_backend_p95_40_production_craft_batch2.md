# 工具化验证日志：后端 40 并发 P95 第二批收敛（production + craft）

- 执行日期：2026-04-17
- 对应主日志：`evidence/task_log_20260417_backend_p95_40_production_craft_batch2.md`
- 当前状态：已完成一轮 write runtime handlers 收敛

## 1. 任务分类

| 主分类 | 次分类 | 分类依据 | 对应门禁 |
| --- | --- | --- | --- |
| CAT-05 | write 门禁与本地压测 | 本轮以 `backend-capacity-gate`、本地后端实例、样本上下文和运行时 handler 为核心 | G1~G7 |

## 2. 工具触发记录

| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 启动 | `Sequential Thinking` | 默认 | 对第二批 write runtime handlers 做拆解 | 任务顺序与完成标准 | 2026-04-17 |
| 2 | 启动 | `update_plan` | 默认 | 维护当前会话步骤状态 | 可追踪执行计划 | 2026-04-17 |
| 3 | 执行 | Serena + shell | 默认/降级 | 结构化检索代码；当前 shell 缺 `rg` 与系统 `python`，改用 Serena / `sed` / `/root/code/ZYKJ_MES/.venv/bin/python` | 精准定位与可执行命令 | 2026-04-17 |
| 4 | 验证 | `pytest` | 默认 | 验证 runtime sample handlers、gate、scenario 契约、integration | 单测/集成测试结果 | 2026-04-17 |
| 5 | 验证 | `backend-capacity-gate` | 默认 | 复跑 `production + craft write short` | 成功率、错误率、P95、分场景结果 | 2026-04-17 |

## 3. 执行留痕

| 序号 | 工具 | 操作对象 | 实际动作 | 结果摘要 | 输出物 |
| --- | --- | --- | --- | --- | --- |
| 1 | `apply_patch` | `tools/perf/write_gate/sample_registry.py` | 新增运行时 handler，补充 runtime operator/process/template 样本逻辑 | `write` 套件脱离共享稳定样本，切到每请求运行时样本 | 代码改动 |
| 2 | `apply_patch` | `tools/perf/backend_capacity_gate.py` | 改为局部 `sample_context`，并将 `prepare/restore` 放入 `asyncio.to_thread` | 解决请求前 restore 与事件循环阻塞问题 | 代码改动 |
| 3 | `apply_patch` | `backend/app/services/perf_sample_seed_service.py` | 增补稳定首件模板、验证码与 cleanup 开关 | 修正 `first-article` 契约与并发互删问题 | 代码改动 |
| 4 | `apply_patch` | `tools/perf/scenarios/production_craft_write_40_scan.json` | 校准首件、报工、代班、工序创建、模板类场景占位符 | write 场景契约与运行时样本口径对齐 | 场景文件 |
| 5 | `apply_patch` | 多个 `backend/tests/*.py` | 补红灯测试并回归 | 覆盖 registry、gate、seed service、integration 新行为 | 测试改动 |

## 4. 验证留痕

| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G1 | 通过 | E1 | 本轮定位为 CAT-05 write 门禁与本地压测 |
| G2 | 通过 | E2 | 已记录 shell 缺 `rg` / 系统 `python` 的降级口径 |
| G3 | 通过 | E3 | 通过“实现变更 -> 独立 pytest/单请求复现/short 压测”实现降级分离验证 |
| G4 | 通过 | E4 | 已执行真实 `pytest`、真实 HTTP 单请求复现、真实 `write short` |
| G5 | 通过 | E5 | `task_log` 与本验证日志能串起触发、修复、重试与收口 |
| G6 | 通过 | E6 | 降级原因、替代工具、影响范围已记录 |
| G7 | 通过 | E7 | 无迁移，直接替换 |

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `/root/code/ZYKJ_MES/.venv/bin/python -m pytest` | `start_backend.py` perf/dev 启动口径 | `backend/tests/test_start_backend_script_unit.py -q` | `3 passed` | 通过 |
| `/root/code/ZYKJ_MES/.venv/bin/python -m pytest` | perf 宿主 + 连接池 + message + write 相关回归 | `backend/tests/test_start_backend_script_unit.py backend/tests/test_db_session_config_unit.py backend/tests/test_backend_capacity_gate_unit.py backend/tests/test_message_service_unit.py -q` | `34 passed` | 通过 |
| `/root/code/ZYKJ_MES/.venv/bin/python -m pytest` | runtime handler / gate / seed / scenario / integration | `backend/tests/test_backend_capacity_gate_unit.py backend/tests/test_write_gate_sample_runtime_unit.py backend/tests/test_perf_sample_seed_service_unit.py backend/tests/test_production_craft_scenarios_unit.py backend/tests/test_write_gate_integration.py -q` | `28 passed` | 通过 |
| `/root/code/ZYKJ_MES/.venv/bin/python -m pytest` | 连接池配置 + message service + write 相关回归 | `backend/tests/test_backend_capacity_gate_unit.py backend/tests/test_db_session_config_unit.py backend/tests/test_message_service_unit.py backend/tests/test_write_gate_sample_runtime_unit.py backend/tests/test_perf_sample_seed_service_unit.py backend/tests/test_production_craft_scenarios_unit.py backend/tests/test_write_gate_integration.py -q` | `46 passed` | 通过 |
| 单请求复现脚本 | `production-order-first-article` | 运行时样本预热 + 真实 HTTP 请求 | `200` | 通过 |
| 单请求复现脚本 | `production-order-end-production` | 运行时样本预热 + 真实 HTTP 请求 | `200` | 通过 |
| 单请求复现脚本 | `production-assist-authorization-create` | 运行时样本预热 + 真实 HTTP 请求 | `201` | 通过 |
| 单请求复现脚本 | `craft-process-create` | 真实 HTTP 请求 | `201` | 通过 |
| `backend/scripts/init_perf_production_craft_samples.py` | 样本上下文文件 | `--mode ensure --output-json .tmp_runtime/production_craft_samples.json` | 成功生成/刷新 | 通过 |
| `backend-capacity-gate` | `production + craft write short` | 复跑 `.tmp_runtime/production_craft_write_short_20260417_220825.json` | `success_rate=98.98%`, `error_rate=1.02%`, `p95_ms=5832.31` | 功能性大幅收敛，但性能未达标 |
| 轻量对照压测脚本 | `/health` @ `8000` 安全池预算单 worker | `40` 并发 `8s` 对照 | `p95=432.12ms` | 通过，证明连接池预算明显影响基线 |
| `backend-capacity-gate` | `production + craft write short` @ `8000` 安全池预算单 worker | 复跑 `.tmp_runtime/production_craft_write_short_20260417_223657.json` | `success_rate=100%`, `error_rate=0`, `p95_ms=655.64` | 功能通过，性能仍略高于门槛 |
| `backend-capacity-gate` | `production + craft write short` @ `18081` gunicorn 4 workers | 复跑 `.tmp_runtime/production_craft_write_short_18081_20260417_223941.json` | `success_rate=99.59%`, `error_rate=0.41%`, `p95_ms=494.03`, `gate_passed=true` | 通过 |
| `start_backend.py --mode perf --no-reload --workers 4` + `backend-capacity-gate` | `combined_40` @ perf 宿主 | 复跑 `.tmp_runtime/backend_40_e2e_combined_perf_20260418_005717.json` | `success_rate=37.25%`, `error_rate=62.75%`, `p95_ms=1049.47` | 未通过，暴露全链路样本/权限/预置缺口 |
| `/root/code/ZYKJ_MES/.venv/bin/python start_backend.py --no-reload` | 默认 dev 启动口径 | 启动后 `curl http://127.0.0.1:8000/health` | `200` | 通过 |
| `/root/code/ZYKJ_MES/.venv/bin/python -m pytest` | combined 第一批清洗的场景契约回归 | `backend/tests/test_production_craft_scenarios_unit.py -q` | `6 passed` | 通过 |
| 单次逐场景验证脚本 | combined 第一批清洗场景 | 逐条请求 `quality-supplier-detail-1`、`products-detail-1*`、`production-order-first-article-*`、`production-order-update`、`production-order-first-article`、`production-order-end-production`、`production-assist-authorization-create`、`craft-process-create`、`craft-template-*` | 全部 `200/201` | 通过 |
| `start_backend.py --mode perf --no-reload --workers 4` + `backend-capacity-gate` | `combined_40` 第二轮 @ perf 宿主 | 复跑 `.tmp_runtime/backend_40_e2e_combined_perf_20260418_071825.json` | `success_rate=45.47%`, `error_rate=54.53%`, `p95_ms=1139.68` | 未通过，但第一批清洗有效 |
| `/root/code/ZYKJ_MES/.venv/bin/python -m pytest` | 第二批 401 池隔离与 stale process 清理回归 | `backend/tests/test_perf_user_seed_service_unit.py backend/tests/test_combined_auth_scenarios_unit.py backend/tests/test_perf_sample_seed_service_unit.py backend/tests/test_production_craft_scenarios_unit.py -q` | `18 passed` | 通过 |
| `backend-capacity-gate` | 认证/消息子集定向复跑 | 复跑 `.tmp_runtime/combined_auth_focus_20260418_074427.json` | `401` 基本收敛到 `auth-logout`、`me-password-update` 两项 | 通过 |
| `start_backend.py --mode perf --no-reload --workers 4` + `backend-capacity-gate` | `combined_40` 第三轮 @ perf 宿主 | 复跑 `.tmp_runtime/backend_40_e2e_combined_perf_20260418_075503.json` | `401=2`, `403=66`, `404=140`, `422=85`, `EXC=52` | 未通过，但第二批清洗有效 |
| `/root/code/ZYKJ_MES/.venv/bin/python -m pytest` | 第三批 403/422 第一层清洗回归 | `backend/tests/test_backend_capacity_gate_unit.py backend/tests/test_combined_management_scenarios_unit.py backend/tests/test_perf_capacity_permission_service_unit.py backend/tests/test_perf_user_seed_service_unit.py backend/tests/test_perf_sample_seed_service_unit.py backend/tests/test_production_craft_scenarios_unit.py -q` | 全部通过 | 通过 |
| 代表场景单次验证脚本 | 第三批 user-admin/authz/messages payload 修正 | 逐条请求 `authz-role-permission-matrix-update`、`authz-hierarchy-preview`、`authz-role-permissions-role-update`、`authz-hierarchy-role-config-update`、`authz-capability-packs-role-config-update`、`messages-announcements` | `200/410` | 通过 |
| `start_backend.py --mode perf --no-reload --workers 4` + `backend-capacity-gate` | `combined_40` 第四轮 @ perf 宿主 | 复跑 `.tmp_runtime/backend_40_e2e_combined_perf_20260418_084033.json` | `success_rate=52.57%`, `403=47`, `422=62`, `EXC=32` | 未通过，但第三批清洗有效 |
| `/root/code/ZYKJ_MES/.venv/bin/python -m pytest` | 第四批 products 场景路径回归 | `backend/tests/test_combined_products_scenarios_unit.py -q` | `2 passed` | 通过 |
| 单次 products 子集验证脚本 | `products` 固定 ID 主簇 | 在 `18081` perf 宿主下逐条请求 `products-detail-v2`、`products-effective-parameters`、`products-impact-analysis`、`products-parameter-history`、`products-parameters`、`products-versions-compare`、`products-version-export`、`products-version-parameter-history` 等 | 读路径全部 `200`；写路径转为真实业务约束 `400/422` | 通过，说明固定 ID 404 已基本剥离 |
| `/root/code/ZYKJ_MES/.venv/bin/python -m pytest` | products/equipment/quality/auth-register 连续收敛回归 | `backend/tests/test_write_gate_sample_runtime_unit.py backend/tests/test_combined_products_scenarios_unit.py backend/tests/test_combined_equipment_scenarios_unit.py backend/tests/test_combined_quality_scenarios_unit.py backend/tests/test_combined_auth_scenarios_unit.py backend/tests/test_backend_capacity_gate_unit.py backend/tests/test_perf_user_seed_service_unit.py -q` | 全部通过 | 通过 |
| 单次逐场景验证脚本 | `products` 写簇 runtime 版本样本 | `products-versions-create`、`products-rollback`、`products-version-activate`、`products-version-copy`、`products-version-disable`、`products-version-note`、`products-version-delete`、`products-version-parameters` | 全部 `200/201` | 通过 |
| 单次逐场景验证脚本 | `equipment` 主失败簇 | 台账 / 项目 / 计划 / 规则 / 运行参数 / 工单 / detail 相关场景 | 全部 `200/201`；`plan-create` 经 cleanup 修复后复检通过 | 通过 |
| `backend/scripts/init_perf_capacity_users.py` + 数据库抽检脚本 | perf 账号阶段绑定 | 重建并核对 `ltmnt*` / `ltopr*` 的 `stage/process` | `ltmnt*=product_testing`，`ltopr*=PERF-STAGE-STD-01` | 通过 |
| 单次逐场景验证脚本 | `quality` 主失败簇 | `quality-supplier-update/delete`、`quality-first-article-*`、`quality-repair-order-*`、`quality-scrap-statistics-detail` | 全部 `200` | 通过 |
| 单次逐场景验证脚本 | `auth-register` 子簇 | `auth-register`、`auth-register-request-create`、`auth-register-requests-detail`、`auth-register-request-approve/reject` | 当前契约下全部 `200/202` | 通过 |
| `start_backend.py --mode perf --no-reload --workers 4` + `backend-capacity-gate` | `combined_40` products/equipment/quality/auth-register 回灌 | 复跑 `.tmp_runtime/backend_40_e2e_combined_perf_20260418_150433.json` 与 `.tmp_runtime/backend_40_e2e_combined_perf_20260418_151421.json` | `success_rate` 由 `52.57%` 提升到 `76.05%` 再提升到 `78.85%` | 未通过，但阶段性收敛显著 |
| 单次逐场景验证脚本 | `authz` 旧写场景 | `authz-permission-update`、`authz-role-permission-update`、`authz-hierarchy-config-update`、`authz-capability-pack-create/update`、`authz-capability-pack-role-config-update`、`authz-capability-packs-batch-apply` | 全部返回 `200/410` | 通过 |
| `start_backend.py --mode perf --no-reload --workers 4` + `backend-capacity-gate` | `combined_40` authz 收口后回灌 | 复跑 `.tmp_runtime/backend_40_e2e_combined_perf_20260418_154920.json` | `success_rate=75.0%`，`404=6`，`405=1`，`422=5` | 未通过，但 authz 旧路由类失败明显缩减 |

## 5. 失败重试

| 轮次 | 失败阶段 | 失败现象 | 根因判断 | 修复动作 | 复检工具 | 复检结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 单测 | registry 缺少 runtime handlers；gate 在请求前完成 restore | 运行时样本链路未真正接通 | 补 handler、局部上下文、请求后 restore | `pytest` | 通过 |
| 2 | 短跑 | `Sub-order assignment not found for current user` | `in-progress` 预热错误使用管理员而非已分配操作者 | 预热改用实际子工单操作者 | 集成测试 + 单请求复现 | 通过 |
| 3 | 集成/单请求 | `First article template not found`、验证码类型错误、`effective_operator_user_id` 缺失 | `first-article` 契约字段错误 | 补稳定首件模板/验证码、修正场景占位符 | 单请求复现 | 通过 |
| 4 | 短跑 | 并发下 runtime 样本被互删 | handler 内部 `seed_production_craft_samples()` 仍执行清理历史 PERF 资产 | 增加 `cleanup_stale_perf_artifacts=False` 开关并在 handler 关闭 | `pytest` + short | 通过 |
| 5 | 短跑 | `craft-process-create` 全量 `400` | 工序编码不满足 `01-99` 序号规则 | 新增 `craft:process-create-ready` 自动分配合法且未占用序号 | 单请求复现 + short | 通过 |
| 6 | 定向压测/对照压测 | PostgreSQL `remaining connection slots` / `too many clients already`，以及 `QueuePool limit of size 6 overflow 4 reached` | 当前工作区默认池预算曾被抬到 `48/32`；同时 runtime handlers 与应用共享 `QueuePool`，在安全池预算下先把压测工具自己卡死 | 回退默认池预算到 `6/4/5`，本地 `.env` 补同口径，runtime handlers 改用独立 `NullPool` 会话工厂 | `pytest` + 轻量对照 + short | 通过 |
| 7 | 写压测 | `production-order-create/update/pipeline` 仍显著高于其余接口 | 同步入口在消息落库后仍阻塞执行首次消息投递 | `message_service` 改为同步入口只落库、不阻塞首轮推送，交由后续维护链路补偿 | `pytest` + short | 通过 |
| 8 | `combined_40` 首轮复跑 | `failed to acquire any token from login flow` | `combined_40` 仍有 `default` 池场景，但命令未显式覆盖默认账号前缀，回落到了不存在的 `loadtest_` 用户 | 复跑命令显式补 `--login-user-prefix ltadm --token-count 2`，并同步更新命令模板 | `combined_40` 复跑 | 通过（能执行，但总体验收未通过） |
| 9 | `combined_40` 第二轮清洗 | `production + craft` 子集在 combined 中仍出现旧 runtime 合同与固定 ID 404 | `combined_40_scan.json` 未同步最新 `production_craft_write_40_scan.json` 与稳定样本占位符 | 同步 production/craft 写合同、产品/供应商/模板版本路径占位符，并复跑定向场景与全量 combined | 场景单测 + 单次逐场景验证 + combined 复跑 | 通过 |
| 10 | `combined_40` 第三轮清洗 | auth/messages 默认池与 pool-admin 共享账号，`auth-logout` / `me-password-update` 污染共享会话；同时历史 perf 工序未清理导致 `craft-process-create` 编码耗尽 | 场景池隔离不足；样本清理仅覆盖 `templates/orders` 未覆盖 `stages/processes` | 新增 `pool-readonly`、`pool-auth-logout`、`pool-auth-password`；调整 combined 场景 token_pool；扩展 stale perf 清理到 `stages/processes` | 场景单测 + auth 子集复跑 + combined 复跑 | 通过 |
| 11 | `combined_40` 第四轮清洗 | `user-admin` / `authz` / `messages` 仍残留大量旧 payload、旧路径字面量与权限缓存伪 403 | 场景契约仍沿用旧 schema；权限 rollout 默认模块与真实目录不匹配；rollout 无增量时未强制清缓存 | 修正 combined payload 与路径；新增 `{RANDOM_SHORT}`；将权限 rollout 对齐到 `user/system/message` 并始终失效缓存；账号初始化脚本自动带 rollout | 场景单测 + 代表场景验证 + combined 复跑 | 通过 |
| 12 | 第五批起步（products 固定 ID 404） | `/products/1/...` 相关场景大簇 404 | combined 场景仍使用历史产品 ID/版本路径 | 将 products 扩展 detail/version/mutation 场景统一收口到 `{sample:product_id}` | 场景单测 | 通过；在线回灌受环境阻塞 |
| 13 | 第五批续做（products runtime 版本样本） | `products` 写场景进入版本状态前置条件错误 | 缺少 draft / effective / version-create 三类 runtime 样本 | 补 products runtime handler、修事务边界、修 `items` schema，并完成在线逐条验证 | `pytest` + `18081` 宿主逐条验证 | 通过 |
| 14 | 第六批（equipment） | `equipment` 出现固定 ID `404`、旧 schema `422`、执行可见范围缺失 | 缺少设备 runtime 样本；`pool-equipment` 无 stage 绑定；cleanup 无法带走请求内新建计划 | 补设备 runtime handler、重建 perf 账号阶段绑定、修 cleanup 级联删除，并完成在线逐条验证 | `pytest` + `18081` 宿主逐条验证 | 通过 |
| 15 | 第七批（quality） | `quality` detail / disposition / repair / scrap 依赖固定 ID 与状态样本 | 缺少 supplier / first article / repair / scrap runtime 样本 | 补质量 runtime handler、修 combined 质量场景，并完成在线逐条验证 | `pytest` + `18081` 宿主逐条验证 | 通过 |
| 16 | 第八批（auth-register） | `register` / `register-request*` 使用旧 body、旧路径与缺 request 样本 | `account` 字段长度口径变化；审批链缺 runtime registration request | 补 auth runtime handler，修 combined 注册审批场景并完成在线验证 | `pytest` + `18081` 宿主逐条验证 | 通过 |
| 17 | 第九批（authz） | `authz` 剩余旧写场景仍指向已废弃路由或旧 payload | 旧场景未对齐到当前 `role-permissions` / `hierarchy role-config` / `capability role-config` / `batch-apply` 写入口 | 统一修正 combined authz 场景，并完成在线逐条验证 | `pytest` + `18081` 宿主逐条验证 | 通过 |

## 6. 降级/阻塞/代记

- 前置说明是否已披露默认工具缺失与影响：是
- 工具降级：shell 缺 `rg` 与系统 `python`
- 阻塞记录：无硬阻塞；当前仅剩性能未达标
- evidence 代记：无

## 7. 通过判定

- 是否完成闭环：是
- 是否满足门禁：是
- 是否存在残余风险：有
- 最终判定：通过（功能性 write runtime chain 已收敛，性能目标仍未通过）

## 8. 残余风险

- `.tmp_runtime/production_craft_write_short_18081_20260417_223941.json` 已表明：
  - 在 `gunicorn 4 workers + 安全池预算` 口径下，`production + craft write short` 已通过当前门禁
  - `overall.p95_ms=494.03`
  - `overall.error_rate=0.0041`
- `.tmp_runtime/backend_40_e2e_combined_perf_20260418_005717.json` 进一步表明：
  - `combined_40` 当前主要阻塞已变成全链路历史样本、权限、预置数据与写入契约缺口
  - 即使宿主口径已切到 perf，整体仍是 `401/403/404/422` 主导，而不是纯 `P95` 主导
- `.tmp_runtime/backend_40_e2e_combined_perf_20260418_071825.json` 表明：
  - 第一批固定 ID / production-craft 旧合同清洗已把整体成功率从 `37.25%` 拉到 `45.47%`
  - 下一轮最优先的清洗对象已经清晰收敛为：
    - `401`：messages / me / auth request 等默认池与认证语义场景
    - `403`：`pool-user-admin` 与部分 authz/user 管理权限场景
    - `404/422`：equipment / products / quality 模块的固定 ID 与不合法 payload
- `.tmp_runtime/backend_40_e2e_combined_perf_20260418_075503.json` 表明：
  - 第二批 `401` 池隔离已基本达标：`401` 从 `56` 压到 `2`
  - 同时带动 `404/422` 明显下降，但新的主噪声变成 `403` 与 `EXC`
- `.tmp_runtime/backend_40_e2e_combined_perf_20260418_084033.json` 表明：
  - 第三批清洗后整体成功率已提升到 `52.57%`
  - `403` 从 `66` 降到 `47`
  - `422` 从 `85` 降到 `62`
  - `EXC` 从 `52` 降到 `32`
- 第四批起步已完成场景层修正，但由于环境层不稳定，尚未形成新的全量 `combined_40` 对照文件
- `products` 子集在线验证已表明：
  - 这一簇中最纯的固定 ID `404` 已被清掉
  - 剩余 `products` 写场景需要版本状态 runtime 样本，而不是继续改固定路径
- 当前残余风险主要有两类：
  - 单 worker 本地默认启动口径仍在 `~655ms`
  - `combined_40` 仍有大量跨模块脏样本与权限缺口，继续扩大压测范围前需要先做全链路样本/权限清洗
- 当前额外阻塞：
  - 本地 `8000/5432` 曾出现不稳定；现已确认 `docker`、`docker-compose`、`pg_ctl` 可用，且 Docker daemon 已可手动拉起
- 下一轮建议：
  - 先为 `products` 写场景补版本状态 runtime 样本
  - 再转到 `equipment / quality / auth-register-request` 的 404 主簇

## 9. 迁移说明

- 无迁移，直接替换

## 10. 当前会话追加验证（点名尾部功能收口）

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `/root/code/ZYKJ_MES/.venv/bin/python -m pytest` | 尾部场景契约与 registry 回归 | `backend/tests/test_combined_auth_scenarios_unit.py backend/tests/test_combined_management_scenarios_unit.py backend/tests/test_combined_products_scenarios_unit.py backend/tests/test_backend_capacity_gate_unit.py backend/tests/test_authz_service_unit.py -q` | 通过 | 通过 |
| `/root/code/ZYKJ_MES/.venv/bin/python -m pytest` | `normalize_users_to_single_role` 保留 perf 账号 stage/process 绑定 | `backend/tests/test_equipment_module_integration.py -k 'normalize_users_to_single_role_keeps_equipment_perf_stage_scope or get_user_for_auth_loads_processes_for_stage_scoped_equipment_user' -q` | `2 passed` | 通过 |
| `backend-capacity-gate` | 点名尾部场景批量 smoke | `users/roles/sessions/messages/processes/craft` 定向复跑 | `.tmp_runtime/focus_tail_fixed_batch_part2.json` 全绿 | 通过 |
| `backend-capacity-gate` | 新失败名单二次回归 | `quality-trend / production-data-manual-export / authz-capability-pack-update / auth-bootstrap-admin / messages-announcements / equipment-record-detail` | `.tmp_runtime/focus_combined_failure_list_round4.json` 全绿 | 通过 |
| `backend-capacity-gate` | `products-lifecycle` 当前契约 + runtime 样本 | `products-lifecycle` 单场景复跑 | `.tmp_runtime/focus_products_lifecycle_after_runtime_fix.json` 全绿 | 通过 |
| `backend-capacity-gate` | 修复后的稳定全量基线 | `combined_40` @ `18081`, `4 workers`, `40` 并发 | `.tmp_runtime/backend_40_e2e_combined_perf_20260418_1932stable.json`：`success_rate=98.24%`，`error_rate=1.76%`，`p95_ms=8436.03` | 功能基本收口，性能仍严重超标 |

## 11. 当前会话追加验证（残余功能失败第二轮收口）

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `/root/code/ZYKJ_MES/.venv/bin/python -m pytest` | `products-template-references-1` / `craft-stage-delete` / `products-parameter-update` 场景契约回归 | `backend/tests/test_combined_products_scenarios_unit.py backend/tests/test_production_craft_scenarios_unit.py backend/tests/test_backend_capacity_gate_unit.py -q` | `23 passed` | 通过 |
| `backend-capacity-gate` | `products-template-references-1` | 单场景复跑 | `.tmp_runtime/focus_products_template_references_1_fixed.json` => `200` | 通过 |
| `backend-capacity-gate` | `craft-stage-delete` | 单场景复跑 | `.tmp_runtime/focus_craft_stage_delete_fixed.json` => `200` | 通过 |
| `backend-capacity-gate` | `products-parameter-update` | 单场景复跑 | `.tmp_runtime/focus_products_parameter_update_fixed.json` => `200` | 通过 |
| `backend-capacity-gate` | 三场景组合 smoke | `products-template-references-1,craft-stage-delete,products-parameter-update` | `.tmp_runtime/focus_three_residuals_fixed_batch.json`：`success_rate=100%`、`error_rate=0` | 通过 |

## 12. 当前会话追加验证（4 workers 稳定基线复跑）

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `curl` + `ss` | `18081` perf 宿主 | 健康检查并确认 `4 workers` 监听 | 健康 `200`，`gunicorn + 4 workers` | 通过 |
| `backend/scripts/init_perf_capacity_users.py` | perf 账号状态 | 重建/刷新 perf 账号、权限与工段绑定 | 执行成功 | 通过 |
| `backend/scripts/init_perf_production_craft_samples.py` | `production/craft` 样本上下文 | `--mode ensure --output-json .tmp_runtime/production_craft_samples.json` | 执行成功 | 通过 |
| `backend-capacity-gate` | `combined_40` 稳定基线 | `40` 并发、`4 workers`、`20s + 5s warmup` 全量复跑 | `.tmp_runtime/backend_40_e2e_combined_perf_20260418_1942baseline.json`：`success_rate=97.14%`、`error_rate=2.86%`、`p95_ms=7019.64` | 未通过 |

## 13. 当前会话追加验证（六个失败场景完全收口）

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `/root/code/ZYKJ_MES/.venv/bin/python -m pytest` | `products-product-delete` / `products-parameter-version-create` 场景契约回归 | `backend/tests/test_combined_products_scenarios_unit.py -q` | 通过 | 通过 |
| `backend-capacity-gate` | `production-order-update-pipeline-mode` | 单场景复跑 | `.tmp_runtime/focus_production_order_update_pipeline_mode_now.json` => `200` | 通过 |
| `backend-capacity-gate` | `craft-kanban-process-metrics-export` | 单场景复跑 | `.tmp_runtime/focus_craft_kanban_process_metrics_export_now.json` => `200` | 通过 |
| `backend-capacity-gate` | `craft-template-references` | 单场景复跑 | `.tmp_runtime/focus_craft_template_references_now.json` => `200` | 通过 |
| `backend-capacity-gate` | `products-product-delete` | 单场景复跑 | `.tmp_runtime/focus_products_product_delete_fixed.json` => `200` | 通过 |
| `backend-capacity-gate` | `products-parameter-version-create` | 单场景复跑 | `.tmp_runtime/focus_products_parameter_version_create_fixed.json` => `201` | 通过 |
| `backend-capacity-gate` | `auth-register-requests-detail` | 单场景复跑 | `.tmp_runtime/focus_auth_register_requests_detail_after_rollout.json` => `200` | 通过 |
| `backend-capacity-gate` | 修复后稳定基线 | `combined_40` @ `18081`, `4 workers`, `40` 并发 | `.tmp_runtime/backend_40_e2e_combined_perf_20260418_2000postfix.json`：这 6 条场景全部退出失败名单 | 通过 |

## 14. 当前会话追加验证（五个失败场景完全收口）

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `/root/code/ZYKJ_MES/.venv/bin/python -m pytest` | `products-product-update` / `users-export-task-create` 场景契约回归 | `backend/tests/test_combined_products_scenarios_unit.py backend/tests/test_combined_management_scenarios_unit.py -q` | `4 passed` | 通过 |
| `backend-capacity-gate` | `products-product-update` | 单场景复跑 | `.tmp_runtime/focus_products_product_update_fixed.json` => `200` | 通过 |
| `backend-capacity-gate` | `users-user-disable` | 单场景复跑 | `.tmp_runtime/focus_users_user_disable_after_rollout.json` => `200` | 通过 |
| `backend-capacity-gate` | `users-user-reset-password` | 单场景复跑 | `.tmp_runtime/focus_users_user_reset_password_after_rollout.json` => `200` | 通过 |
| `backend-capacity-gate` | `users-export-task-create` | 单场景复跑 | `.tmp_runtime/focus_users_export_task_create_fixed.json` => `200` | 通过 |
| `backend-capacity-gate` | `roles-role-delete` | 单场景复跑 | `.tmp_runtime/focus_roles_role_delete_after_rollout.json` => `200` | 通过 |
| `backend-capacity-gate` | 修复后稳定基线 | `combined_40` @ `18081`, `4 workers`, `40` 并发 | `.tmp_runtime/backend_40_e2e_combined_perf_20260418_2013fivefixed.json`：`success_rate=100%`、`error_rate=0`、`measured window failures=NONE` | 通过 |

## 15. 当前会话追加验证（4 workers 稳定基线二次复跑）

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `curl` + `ss` | `18081` perf 宿主 | 健康检查并确认 `4 workers` 监听 | 健康 `200`，`gunicorn + 4 workers` | 通过 |
| `backend/scripts/init_perf_capacity_users.py` | perf 账号状态 | 刷新 perf 账号与权限 | 执行成功 | 通过 |
| `backend/scripts/init_perf_production_craft_samples.py` | `production/craft` 样本上下文 | `--mode ensure --output-json .tmp_runtime/production_craft_samples.json` | 执行成功 | 通过 |
| `backend-capacity-gate` | `combined_40` 稳定基线复跑 | `40` 并发、`4 workers`、`20s + 5s warmup` | `.tmp_runtime/backend_40_e2e_combined_perf_20260418_2019rerun.json`：`success_rate=98.63%`、`error_rate=1.37%` | 未通过 |

## 16. 当前会话追加验证（两个残余失败场景根因调查）

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `backend-capacity-gate` | `quality-stats-operators` | 单场景复跑 | `.tmp_runtime/investigate_quality_stats_operators.json`：`95/95` 成功，`p95_ms=59.65` | 接口逻辑单跑稳定，不是固定合同错误 |
| `backend-capacity-gate` | `products-versions-compare` | 单场景复跑 | `.tmp_runtime/investigate_products_versions_compare.json`：`61/61` 成功，`p95_ms=76.65` | 接口逻辑单跑稳定，不是固定合同错误 |
| 代码审读 | `quality-stats-operators` | 检查 `quality.py` 与 `quality_service.py` 实现 | 首件明细 + 缺陷/报废/维修三路聚合 + Python 归并 | 更像高压下资源争用导致偶发 `EXC` |
| 代码审读 | `products-versions-compare` | 检查 `products.py` 与 `product_service.py` 实现 | 两个版本快照读出后在内存做 diff | 更像高压下排队/超时，而非 compare 逻辑错误 |

## 17. 当前会话追加验证（合并前最小验证）

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| `/root/code/ZYKJ_MES/.venv/bin/python -m pytest` | 当前未提交改动直接相关测试集 | `backend/tests/test_backend_capacity_gate_unit.py backend/tests/test_combined_management_scenarios_unit.py backend/tests/test_combined_products_scenarios_unit.py backend/tests/test_production_craft_scenarios_unit.py -q` | `25 passed` | 通过 |
| `git fetch --all --prune` + `git rev-parse` | 主仓库 `main` 与远端对齐状态 | 对比 `origin/main` 与本地 `main` | 两者同为 `8977a8f` | 通过 |
