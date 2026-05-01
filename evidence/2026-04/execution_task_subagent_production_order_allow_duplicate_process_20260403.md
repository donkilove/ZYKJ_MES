# 执行任务日志（生产订单允许重复小工序）

## 基本信息
- 任务：撤销生产订单工序路线中“重复小工序/重复 `process_codes`”限制，并保留其余中文化改进。
- 执行角色：执行子 agent
- 日期：2026-04-03

## 前置说明
- 按用户要求直接实施，不做 git 提交。
- 当前会话不可用 `Sequential Thinking` 与计划工具，改为在本日志中记录等效拆解、执行步骤、验证命令与结果。

## 等效拆解
1. 定位订单创建/更新链路中所有重复小工序限制，区分前端提交前拦截、后端 Schema 拒绝与服务层静默去重。
2. 仅移除与“重复小工序禁止”直接相关的限制，保留字段标签中文化、默认失败提示中文化及其余合理中文校验。
3. 补最小回归，分别证明前端可提交重复小工序、后端 create/update 允许重复 `process_codes`。
4. 运行用户指定的最小验证命令，并记录结果与残余风险。

## 关键证据
- E1：`backend/app/schemas/production.py` 中 `OrderCreate`、`OrderUpdate` 原先对 `process_codes` 去重后比对长度，重复即抛 422。
- E2：`backend/app/services/production_order_service.py` 的 `_resolve_route_steps` 在仅传 `process_codes` 时调用 `_normalize_process_codes`，会静默去重，导致即使取消 422 也无法真正保存重复工序路线。
- E3：`frontend/lib/pages/production_order_form_page.dart` 提交前调用 `_hasDuplicateProcessCodes`，命中后直接提示中文并阻止请求发出。
- E4：`frontend/lib/services/production_service.dart` 的字段标签中文化、`Value error, ` 前缀清理与默认失败提示中文化与本次规则变更无冲突，应保留。

## 本次改动文件
- `backend/app/schemas/production.py`
- `backend/app/services/production_order_service.py`
- `backend/tests/test_production_module_integration.py`
- `frontend/lib/pages/production_order_form_page.dart`
- `frontend/test/widgets/production_order_form_page_test.dart`
- `frontend/test/services/production_service_test.dart`
- `evidence/execution_task_subagent_production_order_allow_duplicate_process_20260403.md`

## 验证记录
- `python -m compileall backend/app`：通过，`backend/app` 全量编译完成。
- `pytest backend/tests/test_production_module_integration.py -k duplicate_process_codes`：环境中 `pytest` 可执行命令不可用，已降级改用 `python -m pytest backend/tests/test_production_module_integration.py -k duplicate_process_codes`，结果通过，`1 passed, 14 deselected`。
- `flutter test test/widgets/production_order_form_page_test.dart`：通过，4 个测试全部通过。
- `flutter test test/services/production_service_test.dart`：通过，4 个测试全部通过。
- `flutter analyze`：通过，输出 `No issues found!`。

## 结论
- 生产订单创建/更新链路已取消“重复小工序禁止”限制：前端不再提交前拦截，后端不再因重复 `process_codes` 返回 422，且仅传 `process_codes` 时也不会被服务层静默去重。
- 与本次规则无关的中文化改进已保留：字段标签中文化、`Value error, ` 前缀清理、默认失败提示中文化及其他原有合理校验未回退。
- 无迁移，直接替换。

## 剩余风险
- 并行模式配置 `OrderPipelineModeUpdateRequest.process_codes` 仍按“编码唯一”语义校验与存储；这不属于本次订单创建/更新链路验收范围，但若后续要求“同编码重复工序在并行模式中也要分别可选”，需要单独扩展为按工序实例或步骤序号建模。
