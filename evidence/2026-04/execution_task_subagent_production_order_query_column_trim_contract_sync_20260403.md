# 订单查询页列裁剪与契约同步

## 任务信息
- 任务类型：执行子 agent 原子任务
- 开始时间：2026-04-03
- 目标：将 `生产订单查询` 页列表裁成用户指定的 9 列，并补齐前后端 `MyOrderItem` 契约字段 `supplier_name`、`due_date`、`remark`。
- 范围：`backend/app/schemas/production.py`、`backend/app/services/production_order_service.py`、`frontend/lib/models/production_models.dart`、`frontend/lib/pages/production_order_query_page.dart` 及最小测试。

## 前置说明
- 本次环境未提供 `Sequential Thinking`、`TodoWrite`，按书面拆解替代。
- 降级原因：当前会话仅提供本地读写、检索、命令执行工具。
- 补偿措施：在本文件记录任务拆解、关键证据、验证命令与最终结论，保持可审计。

## 任务拆解
1. 核对前后端 `MyOrderItem` 现状与缺失字段。
2. 后端补齐 `supplier_name`、`due_date`、`remark` 输出。
3. 前端模型同步解析新增字段。
4. 订单查询页裁列为 9 列，并将业务入口收束到单一 `操作` 列。
5. 更新最小测试并执行最小验证。

## 关键证据
- 证据#1：`frontend/lib/pages/production_order_query_page.dart` 原列表存在 13 列，含 `工段`、`工序状态`、`查看视角`、`并行实例`、`更新时间` 等，未满足用户指定列顺序。
- 证据#2：`frontend/lib/models/production_models.dart` 中 `MyOrderItem` 缺少 `supplierName`、`dueDate`、`remark`。
- 证据#3：`backend/app/schemas/production.py` 中 `MyOrderItem` 缺少 `supplier_name`、`due_date`、`remark`。
- 证据#4：`backend/app/services/production_order_service.py::_build_my_order_item` 当前未返回上述 3 个字段，但 `ProductionOrder` 模型已具备对应持久化字段。

## 实施记录
- 状态：已完成
- 已完成：
  - 后端 `MyOrderItem` Schema 与 `_build_my_order_item(...)` 增加 `supplier_name`、`due_date`、`remark`。
  - 前端 `MyOrderItem` 模型同步解析上述字段。
  - `生产订单查询` 页列表裁剪为 9 列：`订单编号`、`产品型号`、`供应商`、`工序`、`数量概况`、`状态`、`交货日期`、`操作`、`备注`。
  - `操作` 列改为单一菜单入口，保留 `详情 / 首件 / 报工 / 送修 / 代班` 能力入口。
  - 空 `supplier_name`、空 `remark` 统一展示为 `-`。
  - `数量概况` 基于现有字段聚合为单列文本，不新增复杂后端计算。
  - 补充后端契约回归、前端模型与页面测试。

## 验证记录
- `python -m compileall backend/app`：通过。
- `python -m unittest backend.tests.test_production_module_integration.ProductionModuleIntegrationTest.test_my_orders_contract_includes_supplier_due_date_and_remark`：通过。
- `flutter test test/widgets/production_order_query_page_test.dart`：通过。
- `flutter test test/models/production_models_test.dart`：通过。
- `flutter test test/widgets/production_order_query_detail_page_test.dart`：通过。
- `flutter analyze`：通过。

## 最终结论
- 已完成“订单查询页列裁剪与契约同步”。
- 列顺序满足用户要求，且 `操作` 明确保留在 `备注` 之前。
- 本次为直接替换，无迁移需求。
