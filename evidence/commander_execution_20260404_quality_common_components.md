# 指挥官任务日志：质量模块公共页面与公共列表分页统一

## 1. 任务信息

- 任务名称：质量模块页面统一接入公共页面组件与公共列表/公共翻页
- 任务时间：2026-04-04
- 用户原始需求：这些页面都要使用公共页面组件，页面内有列表的就要使用公共列表+公共翻页组件，每页30条数据。
- 目标：将截图涉及的质量模块页面统一到现有公共页面体系；凡包含列表数据的页面统一复用公共列表与公共翻页，并将分页尺寸固定为每页 30 条。
- 非目标：不改动后端接口、不新增业务字段、不重做非列表型可视化组件。
- 成功标准：
  - 目标页面使用公共页面容器。
  - 含列表的页面使用公共列表与公共翻页组件。
  - 列表分页大小统一为 30。
  - 页面不再出现明显布局溢出问题。

## 2. 输入来源

- 证据#QCC-001：用户提供的 6 张质量模块页面截图，适用结论：目标范围包含每日首件、质量数据、报废统计、维修订单、质量趋势、不良分析、供应商管理页。
- 证据#QCC-002：`AGENTS.md`，访问时间：2026-04-04，适用结论：需中文沟通、先做 Sequential Thinking、维护 evidence、仓库存在 `指挥官工作流程.md` 时默认按指挥官模式执行。
- 证据#QCC-003：`指挥官工作流程.md`，访问时间：2026-04-04，适用结论：主 agent 负责拆解/派发/汇总，不直接承担实现与最终验证；每个原子任务需执行与验证闭环。

## 3. 指挥决策

- 原子任务 A：调研公共页面、公共列表、公共翻页组件与目标页面当前实现，形成改造映射。
- 原子任务 B：执行前端改造，将目标页面切换为公共组件并统一列表分页为 30。
- 原子任务 C：独立验证改造结果，检查组件引用、分页常量、布局与构建状态。

## 4. 子 agent 输出摘要

- 原子任务 A（调研子 agent）结论：
  - 公共页面组件：`frontend/lib/widgets/crud_page_header.dart`
  - 公共列表组件：`frontend/lib/widgets/crud_list_table_section.dart`
  - 公共翻页组件：`frontend/lib/widgets/simple_pagination_bar.dart`
  - 真实目标页：`daily_first_article_page.dart`、`quality_data_page.dart`、`quality_trend_page.dart`、`quality_defect_analysis_page.dart`、`quality_supplier_management_page.dart`，以及质量页壳复用的 `production_scrap_statistics_page.dart`、`production_repair_orders_page.dart`。
  - 现状差异：
    - 每日首件未接入公共页面、公共列表、公共翻页，`_pageSize = 20`。
    - 报废统计、维修订单已接入公共三件套，但 `pageSize = 500`。
    - 供应商管理已接入公共页面+公共列表，缺公共翻页，服务端无分页参数，需前端本地分页。
    - 质量数据、质量趋势、不良分析存在 `DataTable`/列表展示，但未接入公共页面与公共列表，也无统一分页。
  - 风险点：表格区横向滚动、列表空态一致性、筛选后页码重置、质量页壳实际复用生产实现文件。
- 原子任务 B（执行子 agent）结论：
  - 已修改文件：`frontend/lib/pages/daily_first_article_page.dart`、`quality_data_page.dart`、`quality_trend_page.dart`、`quality_defect_analysis_page.dart`、`quality_supplier_management_page.dart`、`production_scrap_statistics_page.dart`、`production_repair_orders_page.dart`。
  - 已完成内容：
    - 每日首件切换到 `CrudPageHeader + CrudListTableSection + SimplePaginationBar`，分页改为 30。
    - 供应商管理补齐前端本地分页并接入 `SimplePaginationBar`。
    - 质量数据、质量趋势、不良分析的表格区域切换为公共列表，并为各表补齐本地分页，分页尺寸 30。
    - 报废统计、维修订单真实实现页的分页常量由 500 改为 30。
  - 执行子 agent 验证：`flutter analyze frontend/lib/pages/daily_first_article_page.dart frontend/lib/pages/quality_data_page.dart frontend/lib/pages/quality_trend_page.dart frontend/lib/pages/quality_defect_analysis_page.dart frontend/lib/pages/quality_supplier_management_page.dart frontend/lib/pages/production_scrap_statistics_page.dart frontend/lib/pages/production_repair_orders_page.dart`，结果为通过。

## 5. 实际改动

- 已完成改造文件：
  - `frontend/lib/pages/daily_first_article_page.dart`
  - `frontend/lib/pages/quality_data_page.dart`
  - `frontend/lib/pages/quality_trend_page.dart`
  - `frontend/lib/pages/quality_defect_analysis_page.dart`
  - `frontend/lib/pages/quality_supplier_management_page.dart`
  - `frontend/lib/pages/production_scrap_statistics_page.dart`
  - `frontend/lib/pages/production_repair_orders_page.dart`
- 改造摘要：
  - 所有目标页面已接入 `CrudPageHeader` 或保持既有公共页头实现。
  - 所有含列表/表格数据展示的页面已统一接入 `CrudListTableSection`。
  - 所有列表页已统一接入 `SimplePaginationBar`。
  - 后端分页页将 `pageSize` 统一为 30；无后端分页能力的页面改为前端本地分页，页长同样为 30。
  - 质量数据、质量趋势、不良分析等统计页增加分页与滚动约束，降低底部溢出风险。

## 6. 验证结果

- 原子任务 C（验证子 agent）结论：通过。
- 验证方式：
  - 对 7 个目标页面执行源码检索，确认 `CrudPageHeader`、`CrudListTableSection`、`SimplePaginationBar` 与 `_pageSize = 30`/本地分页逻辑均已落地。
  - 执行命令：`flutter analyze lib/pages/daily_first_article_page.dart lib/pages/quality_data_page.dart lib/pages/quality_trend_page.dart lib/pages/quality_defect_analysis_page.dart lib/pages/quality_supplier_management_page.dart lib/pages/production_scrap_statistics_page.dart lib/pages/production_repair_orders_page.dart`（在 `frontend/` 目录）。
  - 结果：`No issues found!`
- 验证留痕：`evidence/verification_20260404_quality_common_components_pagination.md`

## 7. 限制与阻塞

- 无硬阻塞。
- 剩余风险：本次以源码复核与静态检查为主，未做运行态视觉回归；若后续需要，可补充 Flutter 桌面端实机浏览验证。

## 8. 迁移说明

- 无迁移，直接替换。
