# 独立验证记录（创建订单页重复小工序报错改中文）

日期：2026-04-03
角色：独立验证子 agent

## 前置说明
- 仅执行验证，不修改实现代码。
- 当前环境未提供 `Sequential Thinking` 与计划工具，本次采用显式书面检查 + 命令验证降级执行。

## 验证范围
- `backend/app/schemas/production.py`
- `frontend/lib/services/production_service.dart`
- `frontend/lib/pages/production_order_form_page.dart`
- `frontend/test/services/production_service_test.dart`
- `frontend/test/widgets/production_order_form_page_test.dart`

## 验证结论
- 结论：PASS。
- 当前问题根因可确认是重复选择了相同小工序，且本次修复同时覆盖了前端提交前拦截与后端 422 中文化兜底。

## 关键证据
- 证据#V-1：`git diff -- backend/app/schemas/production.py ...`
  结论：后端 `process_codes` 重复校验文案由英文 `Process codes cannot contain duplicates` 改为中文 `工序路线中不能重复选择相同的小工序。`，与本次问题描述一致。
- 证据#V-2：`backend/app/schemas/production.py:31-38,67-74,208-215`
  结论：`OrderCreate`、`OrderUpdate`、`OrderPipelineModeUpdateRequest` 都会对 `process_codes` 去空白、去重比对；一旦长度不一致即抛出重复小工序错误，根因确认为重复选择相同小工序。
- 证据#V-3：`frontend/lib/pages/production_order_form_page.dart:202-208,538-581`
  结论：表单提交前会汇总当前路线的 `processCodes`，调用 `_hasDuplicateProcessCodes` 检查重复；命中后直接弹出中文提示 `工序路线中不能重复选择相同的小工序。` 并 `return`，不会继续调用 `createOrder/updateOrder`。
- 证据#V-4：`frontend/test/widgets/production_order_form_page_test.dart:446-509`
  结论：widget 测试通过“新增步骤但不改默认工序”的方式构造重复小工序，断言出现中文提示，且 `createOrderCallCount == 0`，证明前端提交前拦截真实生效。
- 证据#V-5：`frontend/lib/services/production_service.dart:1219-1304`
  结论：422 错误解析会优先读取 `detail`，对 `msg` 做 `_normalizeValidationMessage` 清理 `Value error, ` 英文前缀，并把 `process_codes` 字段标签映射为中文 `工序路线`，不再返回 `Process Codes: Value error, ...`。
- 证据#V-6：`frontend/test/services/production_service_test.dart:1109-1144`
  结论：service 测试显式模拟后端 422 `msg = Value error, 工序路线中不能重复选择相同的小工序。`，最终断言异常消息为 `工序路线: 工序路线中不能重复选择相同的小工序。`，验证了后端兜底中文整理链路。

## 运行命令
- `git diff -- backend/app/schemas/production.py frontend/lib/services/production_service.dart frontend/lib/pages/production_order_form_page.dart frontend/test/services/production_service_test.dart frontend/test/widgets/production_order_form_page_test.dart`
  结果：显示本次修复确实将后端重复校验文案、前端提交前拦截、422 中文映射及对应测试补齐。
- `flutter test test/services/production_service_test.dart`
  结果：PASS，4 个测试全部通过，包含重复工序中文 422 用例。
- `flutter test test/widgets/production_order_form_page_test.dart`
  结果：PASS，4 个测试全部通过，包含重复小工序前端拦截用例。
- `flutter analyze`
  结果：PASS，输出 `No issues found!`。
- `python -m py_compile "backend/app/schemas/production.py"`
  结果：PASS，命令退出成功，无语法错误输出。

## 发现的问题
- 未发现阻塞本次修复验收的问题。

## 是否可直接回复用户
- 可以。可直接回复“当前原因确认为重复选择相同小工序；前端已在提交前中文拦截；即使后端返回 422 也会整理成中文；目标测试与静态校验均已通过”。
