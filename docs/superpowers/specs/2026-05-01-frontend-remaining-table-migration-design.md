# 前端剩余表格公共基线迁移设计

**目标**

一次性完成前端剩余 12 个未接入公共表格基线的表格迁移，使其统一接入公共表格组件，并同步具备固定表头、统一空态、统一加载态与统一表头样式能力。

**范围**

本次范围只覆盖当前未接入公共表格基线的 12 个表格实例，不扩展到已完成迁移的页面，也不顺带改写无关交互逻辑、权限逻辑或业务文案。

涉及文件分布如下：

1. `frontend/lib/features/product/presentation/widgets/product_version_table_section.dart`
2. `frontend/lib/features/product/presentation/widgets/product_detail_drawer.dart`
3. `frontend/lib/features/product/presentation/widgets/product_parameter_query_dialog.dart`
4. `frontend/lib/features/craft/presentation/craft_kanban_page.dart`
5. `frontend/lib/features/production/presentation/production_order_detail_page.dart`
6. `frontend/lib/features/production/presentation/production_order_query_detail_page.dart`
7. `frontend/lib/features/production/presentation/widgets/production_first_article_parameters_dialog.dart`
8. `frontend/lib/features/production/presentation/widgets/production_assist_record_detail_dialog.dart`

其中：

1. `production_order_detail_page.dart` 含 3 张 `DataTable`
2. `production_order_query_detail_page.dart` 含 3 张 `DataTable`
3. `production_assist_record_detail_dialog.dart` 含 1 张原生 `Table`

**非目标**

1. 不修改表格对应的数据来源、接口契约、筛选逻辑或动作菜单语义。
2. 不把详情键值展示强行改造成列表语义的表格。
3. 不对已接入 `CrudListTableSection` 的页面做二次风格重设计。
4. 不在本轮同时处理批量导入、Token 续期、单会话并发控制等其他规划项。

**现状判断**

当前表格基线已经具备以下公共能力：

1. `CrudListTableSection`：统一卡片骨架、加载态、空态、内容区承载。
2. `AdaptiveTableContainer`：统一横向/纵向滚动容器，并已具备 `DataTable` 固定表头支持。
3. `UnifiedListTableHeaderStyle`：统一表头样式与操作按钮风格。

剩余 12 个未迁移点的差异主要有三类：

1. 裸 `DataTable` 直接嵌在 `SingleChildScrollView` 中，缺少公共骨架。
2. 弹窗、抽屉、侧栏等受限容器内使用 `DataTable`，需要兼顾高度与滚动区域。
3. 使用原生 `Table` 展示键值详情，需要判断是否适合迁入公共表格基线。

**迁移策略**

本次虽然按“一次性交付”推进，但实现顺序按风险由低到高执行，目的是在单次开发中优先消化标准单表，再处理多表与受限容器。

### 一、低风险单表

优先迁移以下场景：

1. `product_parameter_query_dialog.dart`
2. `production_first_article_parameters_dialog.dart`
3. `product_version_table_section.dart`
4. `craft_kanban_page.dart`

这些文件的共同点是：

1. 基本是一张独立 `DataTable`
2. 当前逻辑主要是表格展示与动作入口
3. 外层容器简单，容易直接切到公共表格骨架

预期迁移方式：

1. 用 `CrudListTableSection` 承载表格主体
2. 用 `AdaptiveTableContainer` 提供滚动与固定表头
3. 将表头与操作按钮统一到 `UnifiedListTableHeaderStyle`
4. 保留原有业务列、排序方式、菜单动作与文案

### 二、中风险详情容器

第二阶段处理：

1. `product_detail_drawer.dart`
2. `production_assist_record_detail_dialog.dart`

设计原则：

1. `product_detail_drawer.dart` 中参数表仍属于列表型参数快照，适合接入公共表格基线。
2. `production_assist_record_detail_dialog.dart` 当前是典型键值详情结构，不应该强行迁为 `DataTable`。推荐改为统一详情信息行组件风格，而不是纳入列表表格基线。

因此本轮对这两个文件的处理会区分语义：

1. `product_detail_drawer.dart`：迁移到公共表格基线。
2. `production_assist_record_detail_dialog.dart`：不改造成 `DataTable`，但纳入统一详情展示风格收口，并从“未接入公共表格”清单中剔除为“非列表语义、无需接入”。

### 三、高风险多表详情页

最后处理：

1. `production_order_detail_page.dart`
2. `production_order_query_detail_page.dart`

这两个页面各有 3 张表，并且绑定在 `TabBarView` / 详情视图内。

核心设计约束：

1. 不把整个详情页抽成一个巨型公共表格壳。
2. 每张表单独按公共表格基线迁移。
3. 保持现有 Tab 结构、详情页整体布局与信息头部不变。
4. 固定表头只作用于各自表格区域，不影响页头与页签切换。

**最终排序**

按建议执行顺序如下：

1. `product_parameter_query_dialog.dart`
2. `production_first_article_parameters_dialog.dart`
3. `product_version_table_section.dart`
4. `craft_kanban_page.dart`
5. `product_detail_drawer.dart`
6. `production_assist_record_detail_dialog.dart`
7. `production_order_detail_page.dart`
8. `production_order_query_detail_page.dart`

**组件使用约定**

本轮统一遵循以下口径：

1. 列表语义表格优先接入 `CrudListTableSection`
2. 统一通过 `AdaptiveTableContainer` 承载滚动与固定表头
3. 统一启用 `enableUnifiedHeaderStyle`
4. 保留现有 `DataTable` 列结构、数据行结构与菜单行为
5. 对于受限空间弹窗/抽屉，优先保留现有宽高约束，只替换表格承载层

**异常与边界处理**

1. 若某表格没有显式加载态，但存在真实异步加载，应补接统一加载态。
2. 若某表格存在空列表显示，应统一接到 `MesEmptyState`。
3. 若某详情容器本质不是“列表”，不强行接入 `CrudListTableSection`，避免语义错位。
4. 若多表页面因为固定表头引入双 `DataTable` 组件树，需要同步更新测试断言口径。

**测试策略**

### 公共基线回归

1. `frontend/test/widgets/adaptive_table_container_test.dart`
2. `frontend/test/widgets/crud_list_table_section_test.dart`

### 页面级回归

1. `frontend/test/widgets/product_version_management_page_test.dart`
2. `frontend/test/widgets/product_management_page_test.dart`
3. `frontend/test/widgets/product_module_issue_regression_test.dart`
4. `frontend/test/widgets/product_parameter_query_page_test.dart`
5. `frontend/test/widgets/craft_kanban_page_test.dart`
6. `frontend/test/widgets/production_first_article_page_test.dart`
7. `frontend/test/widgets/production_assist_records_page_test.dart`
8. `frontend/test/widgets/production_order_detail_page_test.dart`
9. `frontend/test/widgets/production_order_query_detail_page_test.dart`

### 必要时补充

如果某个未迁移点当前没有足够测试覆盖，需要补最小 widget test，重点验证：

1. 公共骨架是否接入
2. 固定表头是否生效
3. 关键表格文案或动作入口是否仍存在
4. 弹窗/抽屉在受限宽高下不会布局溢出

**风险**

1. 多表详情页迁移后，测试中 `find.byType(DataTable)` 的数量可能翻倍，需要改为按语义查找。
2. 弹窗与抽屉内部固定表头如果高度约束不稳，可能触发溢出或滚动冲突。
3. 历史原生 `Table` 若被误判为列表表格，可能导致 UI 语义退化。

**建议实施方式**

虽然对外是一轮交付，但实现应按以下节奏推进：

1. 先做低风险单表并跑局部测试
2. 再做抽屉/弹窗并跑对应页面测试
3. 最后做多表详情页并跑详情页测试与公共测试
4. 最终统一跑公共表格测试与受影响页面测试矩阵

**验收标准**

1. 剩余列表语义表格全部接入公共表格基线
2. 固定表头在受支持的 `DataTable` 场景下可用
3. 统一空态、加载态与表头样式全部收口
4. 现有业务交互、菜单动作、数据文案不回退
5. 相关 widget test 全部通过

**开放问题**

1. `production_assist_record_detail_dialog.dart` 是否允许按“详情结构不迁表格基线、只做详情样式统一”处理

当前推荐答案：允许。因为它不是列表型表格，强迁到 `DataTable` 的收益低、语义成本高。
