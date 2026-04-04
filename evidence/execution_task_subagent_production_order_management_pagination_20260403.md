# 执行证据：生产订单管理页分页接入

## 基本信息
- 任务名称：`生产订单管理` 页接入公共翻页组件 `SimplePaginationBar`
- 执行日期：2026-04-03
- 执行角色：执行子 agent
- 范围：`frontend/lib/pages/production_order_management_page.dart`、`frontend/test/widgets/production_order_management_page_test.dart`

## 前置约束与降级记录
- 约束：保持最小正确改动，不改现有业务列定义与核心功能，不做 git 提交。
- 降级项：当前会话不可用 `Sequential Thinking` 与计划类工具，改用书面等效拆解直接执行，并在本文件留痕。
- 影响范围：仅影响任务过程记录方式，不影响代码实现与验证命令。
- 补偿措施：在实现前先读取目标页面、公共分页组件、服务签名与现有测试，再执行针对性修改与验证。

## 改动摘要
- 新增页面分页状态：`_page`、`_pageSize`、`_total`、`_totalPages`。
- 将订单列表请求从固定 `page: 1, pageSize: 200` 改为按当前页真实请求。
- 查询、搜索、筛选变化统一回到第一页；刷新与常规重载保留当前页。
- 当删除、筛选或其他动作导致当前页越界时，自动回退到有效页并重新请求。
- 页面底部接入 `SimplePaginationBar`，复用仓库现有公共分页组件。
- 补充 widget 回归，覆盖初始分页请求、上一页/下一页请求、搜索回到第一页。

## 证据
- 证据#1
  - 来源：`frontend/lib/pages/production_order_management_page.dart`
  - 适用结论：页面已接入真实分页状态与公共分页组件，且保留现有列表列定义。
- 证据#2
  - 来源：`frontend/test/widgets/production_order_management_page_test.dart`
  - 适用结论：已覆盖初始加载、翻页请求、搜索回到第一页的最小前端回归。
- 证据#3
  - 来源：本地命令 `flutter test test/widgets/production_order_management_page_test.dart`
  - 适用结论：目标 widget test 通过。
- 证据#4
  - 来源：本地命令 `flutter analyze`
  - 适用结论：前端静态检查通过，无新增 analyze 问题。

## 验证命令与结果
1. `flutter test test/widgets/production_order_management_page_test.dart`
   - 结果：通过，`All tests passed!`
2. `flutter analyze`
   - 结果：通过，`No issues found!`

## 迁移说明
- 无迁移，直接替换。

## 未覆盖点
- 本次未新增针对“删除后当前页越界自动回退”的独立 widget 用例，相关行为由页面加载逻辑实现并依赖后端返回 `total` 驱动。
