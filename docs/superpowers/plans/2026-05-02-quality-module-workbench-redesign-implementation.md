# 质量模块统一工作台改版 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改变质量模块接口契约、筛选语义和导出逻辑的前提下，先完成第一批 `质量数据 + 质量趋势` 的统一工作台改版，让两页共享同一套控制台、结论带和主体区节奏。

**Architecture:** 以 `features/quality/presentation/widgets/` 下的新共享工作台 widgets 作为第一批承载层，把 `QualityDataPage` 和 `QualityTrendPage` 的控制台、摘要卡和状态区统一到相同骨架，再分别保留汇总型页和分析型页的主体差异。测试上以 `quality_pages_test.dart`、`quality_trend_page_test.dart`、`quality_module_regression_test.dart` 锁定统一骨架、交互回归和首屏层级。

**Tech Stack:** Flutter、Dart、Material 3、`fl_chart`、`MesRefreshPageHeader`、`MesFilterBar`、`MesMetricCard`、`MesSectionCard`、`MesEmptyState`、`MesErrorState`、`flutter_test`

---

> Flutter 命令默认在 `frontend/` 目录执行；`git` 命令默认在仓库根目录执行。  
> 本计划遵循“无迁移，直接替换”，且所有提交信息必须使用中文。

## 文件结构与职责

### 新增文件

- `frontend/lib/features/quality/presentation/widgets/quality_workbench_filter_panel.dart`
  - 责任：承载质量模块第一页批共享的顶部控制台容器，统一标题、筛选区、右侧动作区与紧凑间距。
- `frontend/lib/features/quality/presentation/widgets/quality_workbench_summary_grid.dart`
  - 责任：承载摘要卡栅格，统一卡片排布与窄桌面换行。

### 修改文件

- `frontend/lib/features/quality/presentation/quality_data_page.dart`
  - 责任：接入统一控制台、摘要结论带和主体区层级，保持分页、导出、路由载荷与统计并发逻辑不变。
- `frontend/lib/features/quality/presentation/quality_trend_page.dart`
  - 责任：接入统一控制台、摘要结论带和分析主体区层级，保持趋势查询、导出和维度对比逻辑不变。
- `frontend/test/pages/quality_pages_test.dart`
  - 责任：锁定 `质量数据` 第一批改版后的统一骨架、摘要区和交互不回退。
- `frontend/test/widgets/quality_trend_page_test.dart`
  - 责任：锁定 `质量趋势` 第一批改版后的统一骨架、摘要区和图表主体不回退。
- `frontend/test/widgets/quality_module_regression_test.dart`
  - 责任：锁定质量模块页签接线与第一页批改版后的页头/骨架回归。

### 复用文件

- `frontend/lib/core/ui/patterns/mes_refresh_page_header.dart`
- `frontend/lib/core/ui/patterns/mes_filter_bar.dart`
- `frontend/lib/core/ui/patterns/mes_metric_card.dart`
- `frontend/lib/core/ui/patterns/mes_section_card.dart`
- `frontend/lib/core/ui/patterns/mes_empty_state.dart`
- `frontend/lib/core/ui/patterns/mes_error_state.dart`
- `frontend/lib/core/widgets/crud_list_table_section.dart`
- `frontend/lib/core/widgets/adaptive_table_container.dart`

---

### Task 1: 先用失败测试锁定第一批统一工作台骨架

**Files:**
- Modify: `frontend/test/pages/quality_pages_test.dart`
- Modify: `frontend/test/widgets/quality_trend_page_test.dart`
- Modify: `frontend/test/widgets/quality_module_regression_test.dart`
- Test: `frontend/test/pages/quality_pages_test.dart`
- Test: `frontend/test/widgets/quality_trend_page_test.dart`
- Test: `frontend/test/widgets/quality_module_regression_test.dart`

- [ ] **Step 1: 在 `quality_pages_test.dart` 先补 `质量数据` 的失败测试**

在 `frontend/test/pages/quality_pages_test.dart` 增加以下导入与新用例：

```dart
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_metric_card.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
```

```dart
testWidgets('质量数据页首屏使用统一工作台骨架', (tester) async {
  final service = _FakeQualityService(
    overviewResult: QualityStatsOverview(
      firstArticleTotal: 31,
      passedTotal: 30,
      failedTotal: 1,
      passRatePercent: 96.77,
      defectTotal: 5,
      scrapTotal: 2,
      repairTotal: 1,
      coveredOrderCount: 3,
      coveredProcessCount: 3,
      coveredOperatorCount: 3,
      latestFirstArticleAt: DateTime(2026, 3, 5, 8),
    ),
    processItems: _buildProcessItems(3),
    operatorItems: _buildOperatorItems(3),
    productItems: _buildProductItems(3),
    trendItems: _buildTrendItems(3),
  );
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    wrapBody(
      QualityDataPage(session: session, onLogout: () {}, service: service),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byType(MesFilterBar), findsOneWidget);
  expect(find.byType(MesMetricCard), findsAtLeastNWidgets(4));
  expect(find.text('筛选控制台'), findsOneWidget);
  expect(find.text('质量总览'), findsOneWidget);
  expect(find.byType(MesSectionCard), findsAtLeastNWidgets(3));
});
```

- [ ] **Step 2: 在 `quality_trend_page_test.dart` 先补 `质量趋势` 的失败测试**

在 `frontend/test/widgets/quality_trend_page_test.dart` 增加以下用例：

```dart
testWidgets('质量趋势页首屏使用统一工作台骨架并突出趋势主体', (tester) async {
  final service = _FakeQualityTrendService();

  await pumpPage(tester, service);

  expect(find.byType(MesFilterBar), findsOneWidget);
  expect(find.byType(MesMetricCard), findsAtLeastNWidgets(4));
  expect(find.text('筛选控制台'), findsOneWidget);
  expect(find.text('质量总览'), findsOneWidget);
  expect(find.text('趋势概览'), findsOneWidget);
  expect(find.byType(MesSectionCard), findsAtLeastNWidgets(4));
});
```

```dart
testWidgets('质量趋势页首屏先展示趋势主体再展示维度对比', (tester) async {
  final service = _FakeQualityTrendService();

  await pumpPage(tester, service);

  final trendTitle = find.text('趋势概览');
  final productTitle = find.text('按产品对比');
  expect(trendTitle, findsOneWidget);
  expect(productTitle, findsOneWidget);
  expect(
    tester.getTopLeft(trendTitle).dy,
    lessThan(tester.getTopLeft(productTitle).dy),
  );
});
```

- [ ] **Step 3: 在 `quality_module_regression_test.dart` 锁定页签入口仍然不回退**

在 `frontend/test/widgets/quality_module_regression_test.dart` 新增以下断言：

```dart
testWidgets('质量数据页第一页批改版后仍接入统一页头和工作台骨架', (tester) async {
  await tester.pumpWidget(
    _wrapBody(
      QualityDataPage(session: session, onLogout: () {}, service: _FakeQualityService()),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byType(MesRefreshPageHeader), findsOneWidget);
  expect(find.byType(MesFilterBar), findsOneWidget);
});
```

```dart
testWidgets('质量趋势页第一页批改版后仍接入统一页头和工作台骨架', (tester) async {
  await tester.pumpWidget(
    _wrapBody(
      QualityTrendPage(session: session, onLogout: () {}, service: _FakeQualityService()),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('quality-trend-page-header')), findsOneWidget);
  expect(find.byType(MesFilterBar), findsOneWidget);
});
```

- [ ] **Step 4: 运行测试，确认第一页批骨架断言先红灯**

Run:

```bash
flutter test test/pages/quality_pages_test.dart --plain-name "质量数据页首屏使用统一工作台骨架" -r expanded
```

Expected: FAIL，至少因为 `MesFilterBar`、`MesMetricCard` 或 `筛选控制台` 未出现而失败。

Run:

```bash
flutter test test/widgets/quality_trend_page_test.dart --plain-name "质量趋势页首屏使用统一工作台骨架并突出趋势主体" -r expanded
```

Expected: FAIL，至少因为 `MesFilterBar` 或 `趋势概览` 未出现而失败。

- [ ] **Step 5: Commit**

```bash
git add frontend/test/pages/quality_pages_test.dart frontend/test/widgets/quality_trend_page_test.dart frontend/test/widgets/quality_module_regression_test.dart
git commit -m "补充质量模块统一工作台改版失败测试"
```

---

### Task 2: 先落共享工作台骨架，再接入质量数据页

**Files:**
- Create: `frontend/lib/features/quality/presentation/widgets/quality_workbench_filter_panel.dart`
- Create: `frontend/lib/features/quality/presentation/widgets/quality_workbench_summary_grid.dart`
- Modify: `frontend/lib/features/quality/presentation/quality_data_page.dart`
- Test: `frontend/test/pages/quality_pages_test.dart`
- Test: `frontend/test/widgets/quality_module_regression_test.dart`

- [ ] **Step 1: 新增共享控制台容器组件**

创建 `frontend/lib/features/quality/presentation/widgets/quality_workbench_filter_panel.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';

class QualityWorkbenchFilterPanel extends StatelessWidget {
  const QualityWorkbenchFilterPanel({
    super.key,
    required this.child,
    this.title = '筛选控制台',
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MesFilterBar(
      title: title,
      child: child,
    );
  }
}
```

- [ ] **Step 2: 新增共享摘要卡栅格组件**

创建 `frontend/lib/features/quality/presentation/widgets/quality_workbench_summary_grid.dart`：

```dart
import 'package:flutter/material.dart';

class QualityWorkbenchSummaryGrid extends StatelessWidget {
  const QualityWorkbenchSummaryGrid({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: children,
    );
  }
}
```

- [ ] **Step 3: 先把 `quality_data_page.dart` 改成统一工作台骨架**

在文件顶部补充导入：

```dart
import 'package:mes_client/core/ui/patterns/mes_empty_state.dart';
import 'package:mes_client/core/ui/patterns/mes_error_state.dart';
import 'package:mes_client/core/ui/patterns/mes_metric_card.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/features/quality/presentation/widgets/quality_workbench_filter_panel.dart';
import 'package:mes_client/features/quality/presentation/widgets/quality_workbench_summary_grid.dart';
```

把当前 `build()` 内的筛选和总览区改为：

```dart
Widget _buildFilterPanel(ThemeData theme) {
  return QualityWorkbenchFilterPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () => _pickDate(
                        current: _startDate,
                        helpText: '选择开始日期',
                        onChanged: (value) => setState(() => _startDate = value),
                      ),
              icon: const Icon(Icons.event),
              label: Text('开始：${_formatDate(_startDate)}'),
            ),
            OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () => _pickDate(
                        current: _endDate,
                        helpText: '选择结束日期',
                        onChanged: (value) => setState(() => _endDate = value),
                      ),
              icon: const Icon(Icons.event_available),
              label: Text('结束：${_formatDate(_endDate)}'),
            ),
            FilledButton.icon(
              onPressed: _loading ? null : _loadStats,
              icon: const Icon(Icons.search),
              label: const Text('查询'),
            ),
            if (widget.canExport)
              OutlinedButton.icon(
                onPressed: (_loading || _exporting) ? null : _exportCsv,
                icon: const Icon(Icons.download),
                label: const Text('导出'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                controller: _productNameController,
                decoration: const InputDecoration(
                  labelText: '产品名称',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _loadStats(),
              ),
            ),
            SizedBox(
              width: 220,
              child: TextField(
                controller: _processCodeController,
                decoration: const InputDecoration(
                  labelText: '工序编码',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _loadStats(),
              ),
            ),
            SizedBox(
              width: 220,
              child: TextField(
                controller: _operatorUsernameController,
                decoration: const InputDecoration(
                  labelText: '操作员',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _loadStats(),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String?>(
                initialValue: _resultFilter,
                decoration: const InputDecoration(
                  labelText: '结果筛选',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('全部结果')),
                  DropdownMenuItem(value: 'passed', child: Text('合格')),
                  DropdownMenuItem(value: 'failed', child: Text('不合格')),
                ],
                onChanged: _loading
                    ? null
                    : (value) => setState(() => _resultFilter = value),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
```

```dart
Widget _buildOverviewSection(ThemeData theme) {
  return MesSectionCard(
    title: '质量总览',
    child: QualityWorkbenchSummaryGrid(
      children: [
        _buildOverviewCard(title: '首件总数', value: '${_overview.firstArticleTotal}', theme: theme),
        _buildOverviewCard(title: '通过数', value: '${_overview.passedTotal}', theme: theme),
        _buildOverviewCard(title: '不通过数', value: '${_overview.failedTotal}', theme: theme),
        _buildOverviewCard(title: '不良总数', value: '${_overview.defectTotal}', theme: theme),
        _buildOverviewCard(title: '报废总数', value: '${_overview.scrapTotal}', theme: theme),
        _buildOverviewCard(title: '维修总数', value: '${_overview.repairTotal}', theme: theme),
      ],
    ),
  );
}
```

并在 `build()` 中将主内容顺序改为：

```dart
content: ListView(
  children: [
    if (_message.isNotEmpty)
      Text(
        _message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    _buildFilterPanel(theme),
    const SizedBox(height: 12),
    _buildOverviewSection(theme),
    const SizedBox(height: 12),
    MesSectionCard(
      title: '趋势概览',
      child: _buildTrendSection(),
    ),
    const SizedBox(height: 12),
    // 保留原有 TabBar 与 TabBarView
  ],
),
```

- [ ] **Step 4: 让 `质量数据` 的空态与错误态接入统一语义**

保持 `_loadStats()` 和 `_exportCsv()` 不变，只把展示层的空态/错误态收口：

```dart
if (_message.isNotEmpty) {
  return MesErrorState(
    message: _message,
    onRetry: _loadStats,
  );
}
```

趋势区和各 tab 表格区在 `rows.isEmpty` 时继续使用既有 `emptyText`，但最上层不再出现“空空如也”的首屏。

- [ ] **Step 5: 运行 `质量数据` 的测试，确认骨架断言转绿且原功能不回退**

Run:

```bash
flutter test test/pages/quality_pages_test.dart --plain-name "质量数据页首屏使用统一工作台骨架" -r expanded
```

Expected: PASS

Run:

```bash
flutter test test/widgets/quality_module_regression_test.dart --plain-name "质量数据页第一页批改版后仍接入统一页头和工作台骨架" -r expanded
```

Expected: PASS

Run:

```bash
flutter test test/widgets/quality_module_regression_test.dart --plain-name "质量数据页支持查询筛选分页与导出" -r expanded
```

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add frontend/lib/features/quality/presentation/widgets/quality_workbench_filter_panel.dart frontend/lib/features/quality/presentation/widgets/quality_workbench_summary_grid.dart frontend/lib/features/quality/presentation/quality_data_page.dart frontend/test/pages/quality_pages_test.dart frontend/test/widgets/quality_module_regression_test.dart
git commit -m "实现质量数据页统一工作台骨架"
```

---

### Task 3: 接入质量趋势页并完成第一批共享收口

**Files:**
- Modify: `frontend/lib/features/quality/presentation/quality_trend_page.dart`
- Modify: `frontend/test/widgets/quality_trend_page_test.dart`
- Modify: `frontend/test/widgets/quality_module_regression_test.dart`
- Test: `frontend/test/widgets/quality_trend_page_test.dart`
- Test: `frontend/test/widgets/quality_module_regression_test.dart`

- [ ] **Step 1: 先把 `质量趋势` 控制台改成统一面板**

在 `quality_trend_page.dart` 顶部补充导入：

```dart
import 'package:mes_client/core/ui/patterns/mes_metric_card.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/features/quality/presentation/widgets/quality_workbench_filter_panel.dart';
import 'package:mes_client/features/quality/presentation/widgets/quality_workbench_summary_grid.dart';
```

把当前 `_buildFilterBar()` 重写为：

```dart
Widget _buildFilterBar() {
  return QualityWorkbenchFilterPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () => _pickDate(
                        current: _startDate,
                        helpText: '选择开始日期',
                        onChanged: (v) => setState(() => _startDate = v),
                      ),
              icon: const Icon(Icons.event),
              label: Text('开始：${_formatDate(_startDate)}'),
            ),
            OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () => _pickDate(
                        current: _endDate,
                        helpText: '选择结束日期',
                        onChanged: (v) => setState(() => _endDate = v),
                      ),
              icon: const Icon(Icons.event_available),
              label: Text('结束：${_formatDate(_endDate)}'),
            ),
            FilledButton.icon(
              onPressed: _loading ? null : _loadTrend,
              icon: const Icon(Icons.search),
              label: const Text('查询'),
            ),
            if (widget.canExport)
              OutlinedButton.icon(
                onPressed: (_loading || _exporting) ? null : _exportTrend,
                icon: const Icon(Icons.download),
                label: const Text('导出'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                controller: _productController,
                decoration: const InputDecoration(
                  labelText: '产品名称',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _loadTrend(),
              ),
            ),
            SizedBox(
              width: 220,
              child: TextField(
                controller: _processController,
                decoration: const InputDecoration(
                  labelText: '工序编码',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _loadTrend(),
              ),
            ),
            SizedBox(
              width: 220,
              child: TextField(
                controller: _operatorController,
                decoration: const InputDecoration(
                  labelText: '操作员',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _loadTrend(),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
```

- [ ] **Step 2: 新增 `质量趋势` 的质量总览卡与趋势主体区**

在同文件中增加：

```dart
Widget _buildSummarySection() {
  final overview = _overview;
  if (overview == null) {
    return const SizedBox.shrink();
  }
  final scrapRate = overview.firstArticleTotal <= 0
      ? 0
      : (overview.scrapTotal / overview.firstArticleTotal) * 100;
  final repairRate = overview.firstArticleTotal <= 0
      ? 0
      : (overview.repairTotal / overview.firstArticleTotal) * 100;
  return MesSectionCard(
    title: '质量总览',
    child: QualityWorkbenchSummaryGrid(
      children: [
        MesMetricCard(label: '整体通过率', value: '${overview.passRatePercent.toStringAsFixed(1)}%'),
        MesMetricCard(label: '不良总数', value: '${overview.defectTotal}'),
        MesMetricCard(label: '报废率', value: '${scrapRate.toStringAsFixed(1)}%'),
        MesMetricCard(label: '维修占比', value: '${repairRate.toStringAsFixed(1)}%'),
      ],
    ),
  );
}
```

```dart
Widget _buildTrendOverviewSection() {
  return MesSectionCard(
    title: '趋势概览',
    child: SizedBox(
      height: 320,
      child: _loading
          ? const MesLoadingState(label: '质量趋势加载中...')
          : _buildTrendChart(),
    ),
  );
}
```

并将 `build()` 主顺序调整为：

```dart
content: ListView(
  children: [
    _buildFilterBar(),
    const SizedBox(height: 12),
    _buildSummarySection(),
    const SizedBox(height: 12),
    _buildTrendOverviewSection(),
    const SizedBox(height: 12),
    _buildDimensionComparisonSection(),
  ],
),
```

其中 `_buildDimensionComparisonSection()` 负责继续承载 “按产品 / 按工序 / 按人员” 三块对比区。

- [ ] **Step 3: 让维度对比区进入统一 section 容器**

把当前产品、工序、人员三个维度区各自包进 `MesSectionCard`：

```dart
Widget _buildDimensionComparisonSection() {
  return Column(
    children: [
      MesSectionCard(title: '按产品对比', child: _buildProductSection()),
      const SizedBox(height: 12),
      MesSectionCard(title: '按工序对比', child: _buildProcessSection()),
      const SizedBox(height: 12),
      MesSectionCard(title: '按人员对比', child: _buildOperatorSection()),
    ],
  );
}
```

要求：

1. 趋势概览始终在维度对比之前。
2. 现有图表、表格和空态文案不改业务语义。

- [ ] **Step 4: 运行 `质量趋势` 测试，确认第一页批统一骨架转绿**

Run:

```bash
flutter test test/widgets/quality_trend_page_test.dart -r expanded
```

Expected: PASS

Run:

```bash
flutter test test/widgets/quality_module_regression_test.dart --plain-name "质量趋势页第一页批改版后仍接入统一页头和工作台骨架" -r expanded
```

Expected: PASS

- [ ] **Step 5: 运行第一页批汇总验证**

Run:

```bash
flutter test test/pages/quality_pages_test.dart test/widgets/quality_trend_page_test.dart test/widgets/quality_module_regression_test.dart -r expanded
```

Expected: PASS

Run:

```bash
flutter analyze lib/features/quality/presentation/quality_data_page.dart lib/features/quality/presentation/quality_trend_page.dart lib/features/quality/presentation/widgets/quality_workbench_filter_panel.dart lib/features/quality/presentation/widgets/quality_workbench_summary_grid.dart test/pages/quality_pages_test.dart test/widgets/quality_trend_page_test.dart test/widgets/quality_module_regression_test.dart
```

Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add frontend/lib/features/quality/presentation/quality_trend_page.dart frontend/lib/features/quality/presentation/widgets/quality_workbench_filter_panel.dart frontend/lib/features/quality/presentation/widgets/quality_workbench_summary_grid.dart frontend/test/widgets/quality_trend_page_test.dart frontend/test/widgets/quality_module_regression_test.dart frontend/test/pages/quality_pages_test.dart
git commit -m "完成质量模块统一工作台第一批改版"
```

---

## 计划自检结论

### Spec 覆盖

本计划已覆盖 spec 中以下要求：

1. 第一批只做 `质量数据 + 质量趋势`
2. 统一工作台骨架中的控制台、结论带和主体区
3. 数据汇总型与分析看板型两类代表页
4. 不改接口契约、导出逻辑与权限语义
5. 通过现有测试体系锁定回归与页签接线

### 占位词扫描

本计划未使用 `TODO`、`TBD`、`待定`、`implement later` 等占位词。

### 一致性检查

本计划统一使用以下命名：

1. `QualityWorkbenchFilterPanel`
2. `QualityWorkbenchSummaryGrid`
3. `质量总览`
4. `趋势概览`
5. `筛选控制台`

测试断言、实现步骤与验证命令均围绕这一组命名展开，没有前后漂移。
