# 任务日志：顺序工序按已完工数量放行下工序

## 基本信息
- 日期：2026-04-04
- 执行角色：执行子 agent
- 目标：修复顺序工序在前工序部分报工后，下工序 `visible_quantity` 未按累计完成量放行的问题，并补最小自动化测试。
- 范围：`backend/app/services/production_execution_service.py` 与最小必要测试文件。

## 前置分析
- 证据#1：用户提供数据库实况，订单 `20260403-1` 首工序 `completed_quantity=500`，第二工序 `visible_quantity=0`，子单 `assigned_quantity=0`、`is_visible=false`。
- 证据#2：`backend/app/services/production_execution_service.py:end_production` 当前逻辑仅在并行边或当前工序整单完成时提升下一工序可见量；顺序工序部分完成时沿用原值，导致不放行。
- 证据#3：`backend/app/services/production_order_service.py:ensure_sub_orders_visible_quantity` 会基于工序 `visible_quantity` 向子单分配 `assigned_quantity` 并更新 `is_visible`，因此只要顺序工序目标可见量提升，子单可见量可同步修复。

## 实施计划
- 步骤1：修改顺序工序部分报工时的下工序目标可见量口径，改为当前累计完成量且不回退。
- 步骤2：在生产模块集成测试中增加“前工序部分报工 500 -> 下工序放行 500”的最小覆盖。
- 步骤3：运行针对性测试并回填结果。

## 执行结果
- 状态：已完成
- 更新时间：2026-04-04
- 实际改动：
  - `backend/app/services/production_execution_service.py`：将顺序工序在 `end_production` 后的下工序放行口径，从“仅整单完成才放满量”改为“按当前累计完成量放行”，并继续保持 `visible_quantity` 只增不减。
  - `backend/tests/test_production_module_integration.py`：新增“前工序部分报工 500 后，下工序放行 500”集成测试，覆盖工序 `visible_quantity` 与子单 `assigned_quantity/is_visible`。

## 验证记录
- 验证命令：`python -m pytest backend/tests/test_production_module_integration.py -k "end_production_blocks_when_report_plus_defect_exceeds_visible_quantity or end_production_releases_partial_completed_quantity_to_next_process"`
- 验证结果：`2 passed, 22 deselected`

## 结论
- 证据#4：顺序工序在部分报工后，下一工序 `visible_quantity` 可提升到当前累计完成量，不再停留在 0。
- 证据#5：下工序 `ProductionSubOrder` 可同步获得对应 `assigned_quantity`，并恢复 `is_visible=true`。

## 风险与未决项
- 本次仅覆盖顺序工序的部分报工放行缺口，未扩展验证其他与本问题无关的并行实例、代班或维修路径。
