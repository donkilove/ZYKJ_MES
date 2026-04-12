# 工具化验证日志：后端 40 并发 P95 纯性能优化

- 执行日期：2026-04-12
- 对应主日志：`evidence/task_log_20260412_backend_p95_40_performance_optimization.md`
- 当前状态：已通过

## 1. 任务分类
| 主分类 | 次分类 | 分类依据 | 对应门禁 |
| --- | --- | --- | --- |
| CAT-05 | 后端容量热点优化 | 本轮目标是在真实 Docker 后端下对 `91` 场景正式门禁剩余性能瓶颈做收敛 | G1、G2、G4、G5、G6、G7 |

## 2. 工具触发记录
| 序号 | 阶段 | 工具 | 触发类型 | 触发原因 | 预期产出 | 记录时间 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 启动 | `MCP_DOCKER Sequential Thinking` | 默认 `MCP_DOCKER` | 拆解本轮热点定位顺序与共享瓶颈假设 | 拆解结论 | 2026-04-12 |
| 2 | 启动 | `update_plan` | 补充 | 维护当前计划与状态 | 当前计划 | 2026-04-12 |
| 3 | 启动 | PowerShell | 降级 | `rg` 不可用时补充读取日志与产物 | 当前基线证据 | 2026-04-12 |
| 4 | 启动 | `MCP_DOCKER ast-grep` | 默认 `MCP_DOCKER` | 定位热点接口与服务实现 | 代码定位结果 | 2026-04-12 |
| 5 | 验证 | `pytest` | 补充 | 验证红绿测试与关键回归 | 测试结果 | 2026-04-12 |
| 6 | 验证 | Docker / Python | 补充 | 单链路 smoke 与正式压测复测 | 结果 JSON 与抽样时延 | 2026-04-12 |

## 3. 执行留痕
| 序号 | 工具 | 操作对象 | 实际动作 | 结果摘要 | 输出物 |
| --- | --- | --- | --- | --- | --- |
| 1 | `MCP_DOCKER Sequential Thinking` | 当前性能优化任务 | 进行四步拆解 | 已完成热点优先级判断 | E2 |
| 2 | PowerShell | 既有 evidence、结果产物、规则文档 | 读取并确认当前阶段 | 已确认剩余问题为纯性能瓶颈 | E1 |
| 3 | `pytest` | `test_api_deps_unit.py`、`test_list_query_optimization_unit.py` | 先跑红灯、后跑绿灯 | 已确认并修复共享缓存/总数子查询问题 | E4、E5 |
| 4 | `pytest` | `craft/production/quality/me/session` 关键测试 | 回归验证 | `25 passed` | E6 |
| 5 | Docker / Python | `backend-web` 容器与热点接口 | 同步代码、重启服务、执行 smoke | 热点单链路时延明显下降 | E7 |
| 6 | `backend-capacity-gate` | `91` 场景 `40` 并发正式门禁 | 连续两轮正式复测 | 首轮定位回归，二次全绿通过 | E8、E9 |

## 4. 验证留痕
| 门禁 | 检查结果 | 证据编号 | 备注 |
| --- | --- | --- | --- |
| G1 | 通过 | E1 | 已判定为 CAT-05 性能热点优化 |
| G2 | 通过 | E2 | 已记录默认工具与降级原因 |
| G3 | 不适用 | E2 | 本轮采用主 agent 直接执行与独立验证补偿 |
| G4 | 通过 | E5、E6、E7、E9 | 已完成红绿测试、关键回归与全量正式复测 |
| G5 | 通过 | 本文件 | evidence 已完成闭环 |
| G6 | 通过 | E2 | 已记录 `rg` 降级 |
| G7 | 通过 | 主日志 | 已明确“无迁移，直接替换” |

| 验证工具 | 验证对象 | 验证动作 | 结果 | 结论 |
| --- | --- | --- | --- | --- |
| PowerShell | `.tmp_runtime/p95_40_real_pools_fullclear_20260412_202128.json` | 读取现有正式门禁结果 | 通过 | 当前问题只剩 `p95_ms=637.9` |
| `pytest` | `backend/tests/test_api_deps_unit.py backend/tests/test_list_query_optimization_unit.py` | 红绿测试 | 通过 | `10 passed` |
| `pytest` | `backend/tests/test_api_deps_unit.py backend/tests/test_list_query_optimization_unit.py backend/tests/test_me_endpoint_unit.py backend/tests/test_session_service_unit.py` | 最终单元验证 | 通过 | `32 passed` |
| `pytest` | `backend/tests/test_craft_module_integration.py::CraftModuleIntegrationTest::test_detail_queries_and_reference_code_fields backend/tests/test_production_module_integration.py::ProductionModuleIntegrationTest::test_first_article_rich_submission_and_queries_work backend/tests/test_quality_module_integration.py::QualityModuleIntegrationTest::test_quality_suppliers_crud_and_filter_contracts_are_available backend/tests/test_me_endpoint_unit.py backend/tests/test_session_service_unit.py` | 关键接口回归 | 通过 | `25 passed` |
| Python | 热点接口抽样 | 顺序请求多次计时 | 通过 | `craft/processes/supplier/assist/first-article` 单链路时延显著下降 |
| `backend-capacity-gate` | `.tmp_runtime/p95_40_real_pools_perfopt_20260412_205005.json` | 首轮正式复测 | 通过 | 整体门禁已过，但暴露 `production/my-orders*` 偶发 `400` |
| `backend-capacity-gate` | `.tmp_runtime/p95_40_real_pools_perfopt_final_20260412_205547.json` | 二次正式复测 | 通过 | `success_rate=100%`、`error_rate=0`、`p95_ms=200.09`、`gate_passed=true` |

## 5. 失败重试
| 轮次 | 失败阶段 | 失败现象 | 根因判断 | 修复动作 | 复检工具 | 复检结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 检索准备 | `rg.exe` 无法启动 | 环境限制 | 改用 PowerShell 与 `MCP_DOCKER ast-grep` | PowerShell | 已可继续 |
| 2 | 正式复测 | `production/my-orders*` 偶发 `400` | GET 用户缓存扩面与 `current_user.processes` 相关链路兼容性风险 | 将 `production/my-orders*` 从缓存白名单剔除 | `backend-capacity-gate` | 二次复测 `error_rate=0` |

## 6. 降级/阻塞/代记
- 前置说明是否已披露默认 `MCP_DOCKER` 缺失与影响：是
- 工具降级：`rg` 不可用，改为 PowerShell
- 阻塞记录：无
- evidence 代记：否

## 7. 通过判定
- 是否完成闭环：是
- 是否满足门禁：是
- 是否存在残余风险：有
- 最终判定：通过

## 8. 迁移说明
- 无迁移，直接替换。
