# 任务日志：后端 40 并发 P95 纯性能优化

- 日期：2026-04-12
- 执行人：Codex 主 agent
- 当前状态：已完成
- 指挥模式：主 agent 直接执行，按系统化调试与独立验证补偿推进

## 1. 输入来源
- 用户指令：继续；后端在 Docker 中，直接开始跑 40 并发 P95；按文档阶段 1 继续收敛权限后继续推进；当前进入纯性能优化阶段。
- 需求基线：
  - `docs/后端P95-40并发全链路覆盖/01-总体结论.md`
  - `docs/后端P95-40并发全链路覆盖/04-执行说明与命令模板.md`
  - `docs/后端P95-40并发全链路覆盖/08-角色-场景映射表.md`
  - `.tmp_runtime/p95_40_real_pools_fullclear_20260412_202128.json`
  - `evidence/task_log_20260412_backend_phase1_permission_convergence.md`
  - `evidence/verification_20260412_backend_phase1_permission_convergence.md`
- 代码范围：
  - `backend/app/api/v1/endpoints/`
  - `backend/app/services/`
  - `backend/tests/`
  - `.tmp_runtime/`
  - `evidence/task_log_20260412_backend_p95_40_performance_optimization.md`
  - `evidence/verification_20260412_backend_p95_40_performance_optimization.md`

## 1.1 前置说明
- 默认主线工具：`MCP_DOCKER Sequential Thinking`、`update_plan`、`MCP_DOCKER ast-grep`、Docker、PowerShell
- 缺失工具：`rg`
- 缺失/降级原因：当前环境下 `rg.exe` 不可执行
- 替代工具：PowerShell 原生命令、`MCP_DOCKER ast-grep`
- 影响范围：仅影响文本检索效率，不影响本轮定位、实现与验证

## 2. 任务目标、范围与非目标
### 任务目标
1. 在功能正确率维持稳定的前提下，将 `91` 场景 `40` 并发正式门禁的 `p95_ms` 从 `637.9` 收敛到不高于 `500`。
2. 优先定位共享瓶颈与最高热点链路，避免重复优化已收敛的权限问题。
3. 留存本轮根因、修复、验证与复测证据。

### 任务范围
1. 允许调整后端热点接口、共享服务及其测试。
2. 允许在 Docker 容器内同步代码并执行脚本或验证命令。
3. 允许新增本轮 evidence 日志与性能产物。

### 非目标
1. 不重新设计权限模型。
2. 不扩展到 `270` 场景审计套件。
3. 不做与本轮性能瓶颈无关的结构性重构。

## 3. 证据编号表
| 证据编号 | 来源 | 形成时间 | 适用结论 | 记录责任 |
| --- | --- | --- | --- | --- |
| E1 | `.tmp_runtime/p95_40_real_pools_fullclear_20260412_202128.json` | 2026-04-12 | 功能正确率已达 `100%`，剩余问题为纯性能瓶颈 | 主 agent |
| E2 | `MCP_DOCKER Sequential Thinking` 本轮拆解结论 | 2026-04-12 | 优先检查共享鉴权链与 `login / me-session / production / craft` 热点 | 主 agent |
| E3 | 热点代码与场景映射复核 | 2026-04-12 | `craft reference/detail`、`assist-user-options`、`first-article/*`、`quality supplier detail` 均为高频只读热点 | 主 agent |
| E4 | 红灯测试 `backend/tests/test_api_deps_unit.py`、`backend/tests/test_list_query_optimization_unit.py` | 2026-04-12 | 已先确认 GET 鉴权缓存口径与两处总数查询优化存在待修问题 | 主 agent |
| E5 | 绿灯测试 `backend/tests/test_api_deps_unit.py backend/tests/test_list_query_optimization_unit.py` | 2026-04-12 | 首轮共享缓存与查询优化已生效 | 主 agent |
| E6 | 回归测试 `backend/tests/test_craft_module_integration.py::CraftModuleIntegrationTest::test_detail_queries_and_reference_code_fields backend/tests/test_production_module_integration.py::ProductionModuleIntegrationTest::test_first_article_rich_submission_and_queries_work backend/tests/test_quality_module_integration.py::QualityModuleIntegrationTest::test_quality_suppliers_crud_and_filter_contracts_are_available backend/tests/test_me_endpoint_unit.py backend/tests/test_session_service_unit.py` | 2026-04-12 | 关键接口与会话链路回归通过 | 主 agent |
| E7 | 单链路 smoke 计时 | 2026-04-12 | `craft/processes/supplier/assist/first-article` 抽样已降至几十毫秒到数百毫秒 | 主 agent |
| E8 | `.tmp_runtime/p95_40_real_pools_perfopt_20260412_205005.json` | 2026-04-12 | 首轮正式复测已将整体 `p95_ms` 压到 `217.3`，但暴露 `production/my-orders` 缓存兼容性问题 | 主 agent |
| E9 | `.tmp_runtime/p95_40_real_pools_perfopt_final_20260412_205547.json` | 2026-04-12 | 二次正式复测达到 `success_rate=100%`、`error_rate=0`、`p95_ms=200.09`、`gate_passed=true` | 主 agent |

## 4. 指挥拆解结果
| 序号 | 原子任务 | 目标 | 执行子 agent | 验证子 agent | 验收标准 | 当前状态 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 基线与根因定位 | 明确共享瓶颈与接口级热点 | 主 agent | 同轮验证补偿 | 形成单一根因假设或候选列表 | 已完成 |
| 2 | 最小修复 | 在热点链路上完成最小性能修复 | 主 agent | 同轮验证补偿 | 代码与测试变更完成 | 已完成 |
| 3 | 定向验证与全量复测 | 证明修复有效且未回归功能 | 主 agent | 同轮验证补偿 | 定向验证通过，`91` 场景正式复测完成 | 已完成 |

## 5. 子 agent 输出摘要
- 调研摘要：
  - 上一轮已确认 `91` 场景功能正确率清零失败，现阶段只剩 `p95_ms=637.9` 未过门禁。
  - 场景映射与代码复核后，确认热点集中在两类问题：
    1. 高频 GET 接口每次都重复走完整当前用户加载链。
    2. `processes`、`assist-user-options` 等列表/详情接口存在不必要的总数子查询或懒加载额外成本。
- 执行摘要：
  - 扩大了 GET 鉴权用户缓存命中范围，但显式排除了 `equipment/*` 与 `production/my-orders*`，避免缺少 `processes` 关系的缓存用户对象进入相关链路。
  - 将 `processes`、`craft detail/reference`、`quality supplier detail`、`production first-article templates/participant-users`、`production assist-user-options` 切到 `require_permission_fast` 快路径。
  - 优化了 `process_service.list_processes()` 的总数查询，避免 `FROM (SELECT ...)` 子查询。
  - 优化了 `production assist-user-options` 的总数查询与角色加载，补齐 `User.is_deleted=False` 过滤并消除角色懒加载额外成本。
  - 对 `first-article templates/participant-users` 与 `processes` 列表补充了 `load_only` 轻量字段加载。
  - 代码已同步到 `zykj_mes-backend-web-1` 并重启服务。
- 验证摘要：
  - 红绿测试：`32 passed`
  - 关键接口回归：`25 passed`
  - 单链路抽样：`craft-stage-ref`、`craft-process-ref`、`assist-user-options`、`quality-supplier` 等热点已降到几十毫秒到数百毫秒量级
  - 首轮正式复测：整体 `p95_ms=217.3`，但发现 `production/my-orders*` 偶发 `400`
  - 二次正式复测：`success_rate=100%`、`error_rate=0`、`p95_ms=200.09`、`p99_ms=377.47`、`gate_passed=true`

## 6. 失败重试记录
| 轮次 | 原子任务 | 失败现象 | 根因判断 | 修复动作 | 复检结果 |
| --- | --- | --- | --- | --- | --- |
| 1 | 检索准备 | `rg.exe` 无法启动 | 环境限制 | 切换到 PowerShell 与 `MCP_DOCKER ast-grep` | 已切换 |
| 2 | 首轮正式复测 | `production-my-orders`、`production-my-order-context-18` 出现 `400` | GET 鉴权缓存扩面后，`production/my-orders*` 与 `current_user.processes` 相关链路存在兼容性风险 | 将 `production/my-orders*` 从 GET 用户缓存白名单中剔除 | 二次正式复测 `error_rate=0` |

## 7. 工具降级、硬阻塞与限制
- 默认 `MCP_DOCKER` 主线：`Sequential Thinking`、`ast-grep`
- 不可用工具：`rg`
- 降级原因：环境限制
- 替代流程：PowerShell、`MCP_DOCKER ast-grep`
- 影响范围：检索效率下降
- 补偿措施：在 evidence 中记录降级与影响
- 硬阻塞：无

## 8. 交付判断
- 已完成项：
  - 本轮 evidence 建立并回填完成
  - 热点根因定位完成
  - 共享鉴权快路径与热点查询优化完成
  - 单元/接口回归通过
  - `91` 场景 `40` 并发正式门禁复测通过
- 未完成项：
  - 无
- 是否满足任务目标：是
- 主 agent 最终结论：可交付

## 9. 迁移说明
- 无迁移，直接替换。
