# 前端剩余表格公共基线迁移 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 一次性完成前端剩余列表语义表格的公共基线迁移，并对非列表语义详情表做一致性收口。

**Architecture:** 以现有 `CrudListTableSection`、`AdaptiveTableContainer`、`UnifiedListTableHeaderStyle` 为统一承载层，按低风险单表、受限容器表格、多表详情页三个层级推进。对列表语义表格统一接入公共骨架与固定表头；对键值详情结构仅收口展示样式，不强行改造成 `DataTable`。

**Tech Stack:** Flutter、Dart、DataTable、CrudListTableSection、AdaptiveTableContainer、Widget Test

---

## 文件结构与职责

**公共承载层**
- Modify: `frontend/lib/core/widgets/adaptive_table_container.dart`
  责任：统一普通内容与 `DataTable` 内容的滚动承载、固定表头逻辑、公共表头样式挂接。
- Modify: `frontend/lib/core/widgets/crud_list_table_section.dart`
  责任：统一卡片骨架、加载态、空态、内容承载层接线。

**低风险单表**
- Modify: `frontend/lib/features/product/presentation/widgets/product_version_table_section.dart`
- Modify: `frontend/lib/features/product/presentation/widgets/product_parameter_query_dialog.dart`
- Modify: `frontend/lib/features/craft/presentation/craft_kanban_page.dart`
- Modify: `frontend/lib/features/production/presentation/widgets/production_first_article_parameters_dialog.dart`

**中风险受限容器**
- Modify: `frontend/lib/features/product/presentation/widgets/product_detail_drawer.dart`
- Modify: `frontend/lib/features/production/presentation/widgets/production_assist_record_detail_dialog.dart`

**高风险多表详情页**
- Modify: `frontend/lib/features/production/presentation/production_order_detail_page.dart`
- Modify: `frontend/lib/features/production/presentation/production_order_query_detail_page.dart`

**页面级与公共测试**
- Modify: `frontend/test/widgets/crud_list_table_section_test.dart`
- Modify: `frontend/test/widgets/adaptive_table_container_test.dart`
- Modify: `frontend/test/widgets/product_version_management_page_test.dart`
- Modify: `frontend/test/widgets/product_management_page_test.dart`
- Modify: `frontend/test/widgets/product_module_issue_regression_test.dart`
- Modify: `frontend/test/widgets/product_parameter_query_page_test.dart`
- Modify: `frontend/test/widgets/craft_kanban_page_test.dart`
- Modify: `frontend/test/widgets/production_first_article_page_test.dart`
- Modify: `frontend/test/widgets/production_assist_records_page_test.dart`
- Modify: `frontend/test/widgets/production_order_detail_page_test.dart`
- Modify: `frontend/test/widgets/production_order_query_detail_page_test.dart`

---

### Task 1: 公共承载层稳定化

**Files:**
- Modify: `frontend/lib/core/widgets/adaptive_table_container.dart`
- Modify: `frontend/lib/core/widgets/crud_list_table_section.dart`
- Test: `frontend/test/widgets/adaptive_table_container_test.dart`
- Test: `frontend/test/widgets/crud_list_table_section_test.dart`

- [ ] **Step 1: 写失败测试，固定 `CrudListTableSection` 在 `DataTable` 内容态进入固定表头布局**

在 `frontend/test/widgets/crud_list_table_section_test.dart` 增加一个用例，断言：

```dart
testWidgets('列表主体组件在 DataTable 内容态启用固定表头布局', (tester) async {
  await tester.pumpWidget(_buildSubject(loading: false, isEmpty: false));
  await tester.pumpAndSettle();

  expect(find.byType(CustomScrollView), findsOneWidget);
  expect(find.byType(DataTable), findsNWidgets(2));
  expect(find.text('张三'), findsOneWidget);
});
```

- [ ] **Step 2: 运行测试，确认它在修改前失败**

Run:

```bash
cd frontend && flutter test test/widgets/crud_list_table_section_test.dart -r compact
```

Expected: 失败，原因是内容态未进入 `CustomScrollView` 或 `DataTable` 数量不符合固定表头预期。

- [ ] **Step 3: 修改 `AdaptiveTableContainer`，让其直接识别原始 `DataTable`，并在固定表头分支复制表体表格**

关键要求：

```dart
class AdaptiveTableContainer extends StatefulWidget {
  const AdaptiveTableContainer({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.enableUnifiedHeaderStyle = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool enableUnifiedHeaderStyle;
}
```

```dart
@override
Widget build(BuildContext context) {
  final dataTable = widget.child is DataTable
      ? widget.child as DataTable
      : null;
  if (dataTable != null) {
    return _buildStickyHeaderLayout(dataTable);
  }
  final content = _wrapContent(context, widget.child);
  return _buildNormalLayout(content);
}
```

```dart
DataTable _buildBodyOnlyDataTable(DataTable dataTable) {
  return DataTable(
    columns: dataTable.columns,
    rows: dataTable.rows,
    sortColumnIndex: dataTable.sortColumnIndex,
    sortAscending: dataTable.sortAscending,
    onSelectAll: dataTable.onSelectAll,
    decoration: dataTable.decoration,
    dataRowColor: dataTable.dataRowColor,
    dataRowMinHeight: dataTable.dataRowMinHeight,
    dataRowMaxHeight: dataTable.dataRowMaxHeight,
    dataTextStyle: dataTable.dataTextStyle,
    headingRowColor: dataTable.headingRowColor,
    headingRowHeight: 0,
    headingTextStyle: dataTable.headingTextStyle,
    horizontalMargin: dataTable.horizontalMargin,
    columnSpacing: dataTable.columnSpacing,
    showCheckboxColumn: dataTable.showCheckboxColumn,
    showBottomBorder: dataTable.showBottomBorder,
    dividerThickness: dataTable.dividerThickness,
    checkboxHorizontalMargin: dataTable.checkboxHorizontalMargin,
    border: dataTable.border,
    clipBehavior: dataTable.clipBehavior,
  );
}
```

同时要把普通滚动分支的纵向控制器改回成员字段，避免在 `build` 中临时新建控制器。

- [ ] **Step 4: 修改 `CrudListTableSection`，把统一表头样式的接线下沉到 `AdaptiveTableContainer`**

目标是避免 `DataTable` 先被 `wrap()` 包一层后丢失识别机会：

```dart
body = AdaptiveTableContainer(
  padding: contentPadding,
  enableUnifiedHeaderStyle: enableUnifiedHeaderStyle,
  child: child,
);
```

- [ ] **Step 5: 运行公共测试，确认公共承载层转绿**

Run:

```bash
cd frontend && flutter test test/widgets/adaptive_table_container_test.dart test/widgets/crud_list_table_section_test.dart -r compact
```

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add frontend/lib/core/widgets/adaptive_table_container.dart frontend/lib/core/widgets/crud_list_table_section.dart frontend/test/widgets/adaptive_table_container_test.dart frontend/test/widgets/crud_list_table_section_test.dart
git commit -m "稳定公共表格固定表头承载层"
```

---

### Task 2: 低风险单表统一迁移

**Files:**
- Modify: `frontend/lib/features/product/presentation/widgets/product_parameter_query_dialog.dart`
- Modify: `frontend/lib/features/production/presentation/widgets/production_first_article_parameters_dialog.dart`
- Modify: `frontend/lib/features/product/presentation/widgets/product_version_table_section.dart`
- Modify: `frontend/lib/features/craft/presentation/craft_kanban_page.dart`
- Test: `frontend/test/widgets/product_parameter_query_page_test.dart`
- Test: `frontend/test/widgets/production_first_article_page_test.dart`
- Test: `frontend/test/widgets/product_version_management_page_test.dart`
- Test: `frontend/test/widgets/craft_kanban_page_test.dart`

- [ ] **Step 1: 写失败测试，固定 `product_version_table_section.dart` 接入公共列表骨架**

在 `frontend/test/widgets/product_version_management_page_test.dart` 增加或调整断言，验证：

```dart
expect(find.byType(CrudListTableSection), findsWidgets);
expect(find.byType(CustomScrollView), findsWidgets);
```

并验证版本列表仍能打开原有动作菜单。

- [ ] **Step 2: 运行产品版本页测试，确认修改前失败或至少缺少公共骨架断言**

Run:

```bash
cd frontend && flutter test test/widgets/product_version_management_page_test.dart -r compact
```

Expected: 若新增断言正确，旧实现失败。

- [ ] **Step 3: 迁移 `product_version_table_section.dart`**

将当前 `MesSectionCard + 双层 SingleChildScrollView + DataTable` 切换为：

1. 外层仍保留 `MesSectionCard` 的标题/副标题语义
2. 表格主体改用 `CrudListTableSection`
3. 通过 `enableUnifiedHeaderStyle: true` 启用公共表头样式
4. 保留原有版本状态、版本动作菜单与选择逻辑

- [ ] **Step 4: 迁移 `product_parameter_query_dialog.dart` 与 `production_first_article_parameters_dialog.dart`**

原则：

1. 保留现有弹窗标题、宽度和上方摘要信息
2. 表格部分接入 `CrudListTableSection` 或最小公共承载组合
3. 弹窗内保持 `AdaptiveTableContainer` 滚动与固定表头
4. 空列表统一展示 `MesEmptyState` 或现有空文案，不能丢失

- [ ] **Step 5: 迁移 `craft_kanban_page.dart` 中未接入公共基线的表格区域**

要求：

1. 只收口裸表格区域
2. 不改看板切换、卡片逻辑与工艺业务动作
3. 保持原有数据列和业务状态展示

- [ ] **Step 6: 运行低风险单表测试**

Run:

```bash
cd frontend && flutter test test/widgets/product_parameter_query_page_test.dart test/widgets/production_first_article_page_test.dart test/widgets/product_version_management_page_test.dart test/widgets/craft_kanban_page_test.dart -r compact
```

Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add frontend/lib/features/product/presentation/widgets/product_parameter_query_dialog.dart frontend/lib/features/production/presentation/widgets/production_first_article_parameters_dialog.dart frontend/lib/features/product/presentation/widgets/product_version_table_section.dart frontend/lib/features/craft/presentation/craft_kanban_page.dart frontend/test/widgets/product_parameter_query_page_test.dart frontend/test/widgets/production_first_article_page_test.dart frontend/test/widgets/product_version_management_page_test.dart frontend/test/widgets/craft_kanban_page_test.dart
git commit -m "迁移低风险单表到公共表格基线"
```

---

### Task 3: 中风险详情容器收口

**Files:**
- Modify: `frontend/lib/features/product/presentation/widgets/product_detail_drawer.dart`
- Modify: `frontend/lib/features/production/presentation/widgets/production_assist_record_detail_dialog.dart`
- Test: `frontend/test/widgets/product_management_page_test.dart`
- Test: `frontend/test/widgets/product_module_issue_regression_test.dart`
- Test: `frontend/test/widgets/production_assist_records_page_test.dart`

- [ ] **Step 1: 写失败测试，固定产品详情侧栏的参数表进入公共承载**

在 `frontend/test/widgets/product_management_page_test.dart` 或 `frontend/test/widgets/product_module_issue_regression_test.dart` 中增加断言：

```dart
expect(find.byType(CrudListTableSection), findsWidgets);
expect(find.byType(CustomScrollView), findsWidgets);
```

注意只对参数表区域断言，不要把整个详情侧栏误判成列表页。

- [ ] **Step 2: 运行产品详情相关测试，确认新增断言先失败**

Run:

```bash
cd frontend && flutter test test/widgets/product_management_page_test.dart test/widgets/product_module_issue_regression_test.dart -r compact
```

- [ ] **Step 3: 迁移 `product_detail_drawer.dart` 的参数表**

要求：

1. 保留详情侧栏整体结构与“基本信息/关联信息/历史时间线”布局
2. 仅将参数快照表收口到公共表格基线
3. 保留搜索框、参数快照标题、列定义与截断行为

- [ ] **Step 4: 收口 `production_assist_record_detail_dialog.dart`**

该文件不强行迁为 `DataTable`，按详情展示语义处理：

1. 保留 `MesDialog`
2. 将原生 `Table` 调整到统一详情行展示风格
3. 保持标题、字段和值不变

如果已有更合适的通用详情行组件，可接入通用详情行组件；若无，则保持当前语义并只做最小一致性优化。

- [ ] **Step 5: 运行中风险详情容器测试**

Run:

```bash
cd frontend && flutter test test/widgets/product_management_page_test.dart test/widgets/product_module_issue_regression_test.dart test/widgets/production_assist_records_page_test.dart -r compact
```

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add frontend/lib/features/product/presentation/widgets/product_detail_drawer.dart frontend/lib/features/production/presentation/widgets/production_assist_record_detail_dialog.dart frontend/test/widgets/product_management_page_test.dart frontend/test/widgets/product_module_issue_regression_test.dart frontend/test/widgets/production_assist_records_page_test.dart
git commit -m "收口详情容器中的剩余表格展示"
```

---

### Task 4: 高风险多表详情页迁移

**Files:**
- Modify: `frontend/lib/features/production/presentation/production_order_detail_page.dart`
- Modify: `frontend/lib/features/production/presentation/production_order_query_detail_page.dart`
- Test: `frontend/test/widgets/production_order_detail_page_test.dart`
- Test: `frontend/test/widgets/production_order_query_detail_page_test.dart`

- [ ] **Step 1: 写失败测试，固定详情页多表区域接入公共表格基线**

在两个测试文件中分别补充断言：

```dart
expect(find.byType(CrudListTableSection), findsWidgets);
expect(find.byType(CustomScrollView), findsWidgets);
```

并同步把旧的“一张 `DataTable`”口径调整成“固定表头场景会出现两张 `DataTable` 组件树”的新口径。

- [ ] **Step 2: 运行两个详情页测试，确认新增断言在修改前失败**

Run:

```bash
cd frontend && flutter test test/widgets/production_order_detail_page_test.dart test/widgets/production_order_query_detail_page_test.dart -r compact
```

- [ ] **Step 3: 迁移 `production_order_detail_page.dart` 的 3 张表**

迁移目标：

1. 工序表
2. 子订单表
3. 记录表

要求：

1. 每张表各自接入公共表格基线
2. 保持现有 TabBar、事件列表与动作栏不变
3. 不把整个详情页改造成单一表格壳

- [ ] **Step 4: 迁移 `production_order_query_detail_page.dart` 的 3 张表**

迁移目标：

1. 工序表
2. 子订单表
3. 记录表

要求与上一个页面一致，同时保留“我的工单视角”“只读回退”“发起代班/手工送修”等既有交互。

- [ ] **Step 5: 运行多表详情页测试**

Run:

```bash
cd frontend && flutter test test/widgets/production_order_detail_page_test.dart test/widgets/production_order_query_detail_page_test.dart -r compact
```

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add frontend/lib/features/production/presentation/production_order_detail_page.dart frontend/lib/features/production/presentation/production_order_query_detail_page.dart frontend/test/widgets/production_order_detail_page_test.dart frontend/test/widgets/production_order_query_detail_page_test.dart
git commit -m "迁移生产详情页多表到公共表格基线"
```

---

### Task 5: 总体验证与清单复核

**Files:**
- Review: `frontend/lib/features/product/presentation/widgets/product_version_table_section.dart`
- Review: `frontend/lib/features/product/presentation/widgets/product_detail_drawer.dart`
- Review: `frontend/lib/features/product/presentation/widgets/product_parameter_query_dialog.dart`
- Review: `frontend/lib/features/craft/presentation/craft_kanban_page.dart`
- Review: `frontend/lib/features/production/presentation/production_order_detail_page.dart`
- Review: `frontend/lib/features/production/presentation/production_order_query_detail_page.dart`
- Review: `frontend/lib/features/production/presentation/widgets/production_first_article_parameters_dialog.dart`
- Review: `frontend/lib/features/production/presentation/widgets/production_assist_record_detail_dialog.dart`

- [ ] **Step 1: 运行公共与页面级测试矩阵**

Run:

```bash
cd frontend && flutter test test/widgets/adaptive_table_container_test.dart test/widgets/crud_list_table_section_test.dart test/widgets/product_version_management_page_test.dart test/widgets/product_management_page_test.dart test/widgets/product_module_issue_regression_test.dart test/widgets/product_parameter_query_page_test.dart test/widgets/craft_kanban_page_test.dart test/widgets/production_first_article_page_test.dart test/widgets/production_assist_records_page_test.dart test/widgets/production_order_detail_page_test.dart test/widgets/production_order_query_detail_page_test.dart -r compact
```

Expected: PASS

- [ ] **Step 2: 复核源码清单，确认剩余列表语义表格已全部接入公共基线**

Run:

```bash
cd frontend && rg -n "\b(DataTable|Table)\s*\(" lib/features
```

人工复核标准：

1. 本次设计覆盖的列表语义表格都已接入 `CrudListTableSection` 或公共承载层
2. `production_assist_record_detail_dialog.dart` 被明确标注为详情结构，不再计入待迁移列表

- [ ] **Step 3: 提交前检查**

Run:

```bash
cd .. && git status --short --untracked-files=all && git diff --check
```

Expected: 无 diff 格式错误；提交范围仅包含本轮迁移相关文件。

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "统一前端剩余表格公共基线"
```
