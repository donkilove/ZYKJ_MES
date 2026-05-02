# 工艺看板驾驶舱改版 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改变工艺看板查询、导出、筛选与图表业务语义的前提下，把页面重构为“结论先行”的工业风驾驶舱，并显著提升首屏空间利用率。

**Architecture:** 保留 `CraftKanbanPage` 现有服务依赖、状态变量与查询链路，在页面内部追加摘要聚合、控制台分区和响应式工序卡布局。优先复用现有 `MesRefreshPageHeader`、`MesMetricCard`、`MesSectionCard`、`MesFilterBar`、`MesEmptyState`、`MesErrorState`，避免把本轮改造扩散为全局 UI 基础件重构。

**Tech Stack:** Flutter、Dart、Material 3、`fl_chart`、现有 `core/ui/patterns`、`flutter_test`

---

> Flutter 命令默认在 `frontend/` 目录执行；`git` 命令默认在仓库根目录执行。  
> 本计划遵循“无迁移，直接替换”，且所有提交信息必须使用中文。

## 文件结构与职责

### 修改文件

- `frontend/lib/features/craft/presentation/craft_kanban_page.dart`
  - 责任：完成驾驶舱布局、摘要指标聚合、响应式图表卡、空态与错误态收口。
- `frontend/test/widgets/craft_kanban_page_test.dart`
  - 责任：锁定驾驶舱首屏结构、摘要指标、双栏图表卡、空态与既有交互不回退。

### 复用文件

- `frontend/lib/core/ui/patterns/mes_refresh_page_header.dart`
  - 责任：页面头部与刷新语义。
- `frontend/lib/core/ui/patterns/mes_metric_card.dart`
  - 责任：摘要指标卡承载。
- `frontend/lib/core/ui/patterns/mes_section_card.dart`
  - 责任：控制台与趋势总览区块容器。
- `frontend/lib/core/ui/patterns/mes_filter_bar.dart`
  - 责任：筛选控制台外层语义。
- `frontend/lib/core/ui/patterns/mes_empty_state.dart`
  - 责任：无产品与无结果空态。
- `frontend/lib/core/ui/patterns/mes_error_state.dart`
  - 责任：查询失败内容态。

---

### Task 1: 用失败测试锁定驾驶舱首屏结构

**Files:**
- Modify: `frontend/test/widgets/craft_kanban_page_test.dart`
- Test: `frontend/test/widgets/craft_kanban_page_test.dart`

- [ ] **Step 1: 先补一组失败测试，固定摘要卡、控制台和双栏图表卡**

在 `frontend/test/widgets/craft_kanban_page_test.dart` 增加以下导入和新用例：

```dart
import 'package:mes_client/core/ui/patterns/mes_empty_state.dart';
import 'package:mes_client/core/ui/patterns/mes_metric_card.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
```

```dart
testWidgets('工艺看板首屏展示驾驶舱摘要卡和控制台', (tester) async {
  final craftService = _FakeCraftService()
    ..metricsResult = CraftKanbanProcessMetricsResult(
      productId: 1,
      productName: '产品A',
      items: [
        CraftKanbanProcessItem(
          stageId: 1,
          stageCode: 'CUT',
          stageName: '切割段',
          processId: 11,
          processCode: 'CUT-01',
          processName: '激光切割',
          samples: [
            CraftKanbanSampleItem(
              orderProcessId: 101,
              orderId: 1001,
              orderCode: 'MO-1001',
              startAt: DateTime.parse('2026-03-01T08:00:00Z'),
              endAt: DateTime.parse('2026-03-01T09:00:00Z'),
              workMinutes: 60,
              productionQty: 120,
              capacityPerHour: 120,
            ),
            CraftKanbanSampleItem(
              orderProcessId: 102,
              orderId: 1002,
              orderCode: 'MO-1002',
              startAt: DateTime.parse('2026-03-02T08:00:00Z'),
              endAt: DateTime.parse('2026-03-02T10:10:00Z'),
              workMinutes: 130,
              productionQty: 100,
              capacityPerHour: 46.2,
            ),
          ],
        ),
      ],
    );

  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await pumpCraftKanbanPage(
    tester,
    craftService: craftService,
    productionService: _FakeProductionService(),
  );

  expect(find.byType(MesMetricCard), findsNWidgets(5));
  expect(find.text('工序数'), findsOneWidget);
  expect(find.text('样本数'), findsOneWidget);
  expect(find.text('平均工时'), findsOneWidget);
  expect(find.text('平均产能'), findsOneWidget);
  expect(find.text('异常样本'), findsOneWidget);
  expect(find.byType(MesSectionCard), findsAtLeastNWidgets(3));
  expect(find.text('筛选控制台'), findsOneWidget);
  expect(find.text('统计规则'), findsOneWidget);
});
```

```dart
testWidgets('宽桌面下工序详情卡使用左右双栏图表', (tester) async {
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await pumpCraftKanbanPage(
    tester,
    craftService: _FakeCraftService(),
    productionService: _FakeProductionService(),
  );

  final workChart = find.byKey(const ValueKey('craft-kanban-work-chart-11'));
  final capacityChart = find.byKey(const ValueKey('craft-kanban-capacity-chart-11'));
  expect(workChart, findsOneWidget);
  expect(capacityChart, findsOneWidget);

  final workLeft = tester.getTopLeft(workChart);
  final capacityLeft = tester.getTopLeft(capacityChart);
  expect(capacityLeft.dx, greaterThan(workLeft.dx + 80));
});
```

```dart
testWidgets('工艺看板无结果时展示带说明的空态卡片', (tester) async {
  final craftService = _FakeCraftService()
    ..metricsResult = CraftKanbanProcessMetricsResult(
      productId: 1,
      productName: '产品A',
      items: const [],
    );

  await pumpCraftKanbanPage(
    tester,
    craftService: craftService,
    productionService: _FakeProductionService(),
  );

  expect(find.byType(MesEmptyState), findsOneWidget);
  expect(find.text('当前筛选下暂无已完工样本'), findsOneWidget);
  expect(find.text('可尝试调整产品、工段、工序或日期范围后重试'), findsOneWidget);
});
```

- [ ] **Step 2: 运行测试，确认新断言先红灯**

Run:

```bash
flutter test test/widgets/craft_kanban_page_test.dart -r expanded
```

Expected: FAIL，至少出现 `MesMetricCard`、`筛选控制台` 或 `craft-kanban-work-chart-11` 未找到的断言失败。

- [ ] **Step 3: 调整测试夹具，让假数据能覆盖异常样本与多样本聚合**

把 `_FakeCraftService.metricsResult` 的默认值更新为两条样本，确保后续聚合结果稳定：

```dart
CraftKanbanProcessMetricsResult metricsResult =
    CraftKanbanProcessMetricsResult(
      productId: 1,
      productName: '产品A',
      items: [
        CraftKanbanProcessItem(
          stageId: 1,
          stageCode: 'CUT',
          stageName: '切割段',
          processId: 11,
          processCode: 'CUT-01',
          processName: '激光切割',
          samples: [
            CraftKanbanSampleItem(
              orderProcessId: 101,
              orderId: 1001,
              orderCode: 'MO-1001',
              startAt: DateTime.parse('2026-03-01T08:00:00Z'),
              endAt: DateTime.parse('2026-03-01T09:00:00Z'),
              workMinutes: 60,
              productionQty: 120,
              capacityPerHour: 120,
            ),
            CraftKanbanSampleItem(
              orderProcessId: 102,
              orderId: 1002,
              orderCode: 'MO-1002',
              startAt: DateTime.parse('2026-03-02T08:00:00Z'),
              endAt: DateTime.parse('2026-03-02T10:10:00Z'),
              workMinutes: 130,
              productionQty: 100,
              capacityPerHour: 46.2,
            ),
          ],
        ),
      ],
    );
```

- [ ] **Step 4: 再跑一次测试，确认失败原因仍然指向 UI 结构缺失而不是测试数据不完整**

Run:

```bash
flutter test test/widgets/craft_kanban_page_test.dart --plain-name "工艺看板首屏展示驾驶舱摘要卡和控制台" -r expanded
```

Expected: FAIL，且失败点仍然是驾驶舱结构未实现。

- [ ] **Step 5: Commit**

```bash
git add frontend/test/widgets/craft_kanban_page_test.dart
git commit -m "补充工艺看板驾驶舱改版失败测试"
```

---

### Task 2: 实现控制台、摘要卡与内容态分区

**Files:**
- Modify: `frontend/lib/features/craft/presentation/craft_kanban_page.dart`
- Test: `frontend/test/widgets/craft_kanban_page_test.dart`

- [ ] **Step 1: 在页面内新增聚合模型与摘要统计逻辑**

在 `craft_kanban_page.dart` 顶部新增一个私有摘要模型和样本聚合 getter：

```dart
class _CraftKanbanSummary {
  const _CraftKanbanSummary({
    required this.processCount,
    required this.sampleCount,
    required this.averageMinutes,
    required this.averageCapacity,
    required this.anomalyCount,
  });

  final int processCount;
  final int sampleCount;
  final double averageMinutes;
  final double averageCapacity;
  final int anomalyCount;
}
```

```dart
_CraftKanbanSummary _buildSummary(List<CraftKanbanProcessItem> items) {
  final samples = items.expand((item) => item.samples).toList();
  if (samples.isEmpty) {
    return const _CraftKanbanSummary(
      processCount: 0,
      sampleCount: 0,
      averageMinutes: 0,
      averageCapacity: 0,
      anomalyCount: 0,
    );
  }
  final totalMinutes = samples.fold<int>(
    0,
    (sum, item) => sum + item.workMinutes,
  );
  final totalCapacity = samples.fold<double>(
    0,
    (sum, item) => sum + item.capacityPerHour,
  );
  final averageMinutes = totalMinutes / samples.length;
  final anomalyThreshold = averageMinutes * 1.3;
  final anomalyCount = samples
      .where((item) => item.workMinutes.toDouble() > anomalyThreshold)
      .length;
  return _CraftKanbanSummary(
    processCount: items.where((item) => item.samples.isNotEmpty).length,
    sampleCount: samples.length,
    averageMinutes: averageMinutes,
    averageCapacity: totalCapacity / samples.length,
    anomalyCount: anomalyCount,
  );
}
```

- [ ] **Step 2: 引入现有 pattern 组件，并重写头部与控制台**

补充导入：

```dart
import 'package:mes_client/core/ui/patterns/mes_empty_state.dart';
import 'package:mes_client/core/ui/patterns/mes_error_state.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_metric_card.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
```

把 `_buildHeader()` 和 `_buildFilterBar()` 改成驾驶舱语义：

```dart
Widget _buildHeader() {
  final busy = _loadingProducts || _loadingMetrics || _exporting;
  return MesRefreshPageHeader(
    title: '工艺看板',
    subtitle: '快速识别异常工时与工序产能波动。',
    onRefresh: busy ? null : _loadProducts,
    actionsBeforeRefresh: [
      if (busy)
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
    ],
  );
}
```

```dart
Widget _buildFilterBar() {
  final busy = _loadingProducts || _loadingMetrics || _exporting;
  if (_products.isEmpty && !_loadingProducts) {
    return const MesEmptyState(
      title: '暂无产品数据',
      description: '当前无法生成工艺看板，请先补齐产品基础资料。',
    );
  }

  return MesFilterBar(
    title: '筛选控制台',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(width: 320, child: _buildProductDropdown(busy)),
            SizedBox(width: 220, child: _buildStageDropdown(busy)),
            SizedBox(width: 220, child: _buildProcessDropdown(busy)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildDateButton(isStart: true, busy: busy),
            _buildDateButton(isStart: false, busy: busy),
            if (_startDate != null || _endDate != null)
              TextButton(
                onPressed: busy ? null : _clearDateRange,
                child: const Text('清除日期'),
              ),
            FilledButton.icon(
              onPressed: busy ? null : _exportMetricsCsv,
              icon: const Icon(Icons.download),
              label: Text(_exporting ? '导出中...' : '导出数据'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Icon(Icons.rule_folder_outlined, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '统计规则：仅统计已完成工序记录；工时=首件/生产记录最早时间到最后一次生产记录时间（分钟）；产能=产出数量/工时；红色柱体表示工时超过该工序样本均值的 130%。',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
```

- [ ] **Step 3: 新增摘要卡区与内容态分发**

在同文件内追加摘要区与状态区方法：

```dart
Widget _buildSummaryCards() {
  final items = _metrics?.items ?? const <CraftKanbanProcessItem>[];
  final summary = _buildSummary(items);
  return Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      MesMetricCard(label: '工序数', value: '${summary.processCount}', hint: '当前筛选下有样本的工序'),
      MesMetricCard(label: '样本数', value: '${summary.sampleCount}', hint: '已完成工序样本总数'),
      MesMetricCard(label: '平均工时', value: '${summary.averageMinutes.toStringAsFixed(1)} 分钟'),
      MesMetricCard(label: '平均产能', value: '${summary.averageCapacity.toStringAsFixed(1)} 件/小时'),
      MesMetricCard(
        label: '异常样本',
        value: '${summary.anomalyCount}',
        hint: summary.anomalyCount == 0 ? '当前无超阈值样本' : '高于均值 130%',
      ),
    ],
  );
}
```

```dart
Widget _buildContent() {
  if (_loadingProducts || _loadingMetrics) {
    return const MesLoadingState(label: '工艺看板加载中...');
  }
  if (_products.isEmpty) {
    return const MesEmptyState(
      title: '暂无产品数据',
      description: '当前无法生成工艺看板，请先补齐产品基础资料。',
    );
  }
  if (_metrics == null) {
    return MesErrorState(
      message: '当前看板数据加载失败，请重试。',
      onRetry: _loadMetrics,
    );
  }
  if (_metrics!.items.isEmpty) {
    return const MesEmptyState(
      title: '当前筛选下暂无已完工样本',
      description: '可尝试调整产品、工段、工序或日期范围后重试',
    );
  }
  return ListView(
    children: [
      _buildSummaryCards(),
      const SizedBox(height: 12),
      _buildTrendComparison(_metrics!.items),
      ..._metrics!.items.map(_buildProcessCard),
    ],
  );
}
```

- [ ] **Step 4: 跑测试，确认摘要卡与控制台断言转绿**

Run:

```bash
flutter test test/widgets/craft_kanban_page_test.dart --plain-name "工艺看板首屏展示驾驶舱摘要卡和控制台" -r expanded
```

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/features/craft/presentation/craft_kanban_page.dart frontend/test/widgets/craft_kanban_page_test.dart
git commit -m "实现工艺看板驾驶舱控制台与摘要卡"
```

---

### Task 3: 实现双栏图表卡、窄桌面降级与最终验证

**Files:**
- Modify: `frontend/lib/features/craft/presentation/craft_kanban_page.dart`
- Modify: `frontend/test/widgets/craft_kanban_page_test.dart`

- [ ] **Step 1: 先补失败测试，锁定窄桌面降级和错误态文案**

在 `craft_kanban_page_test.dart` 增加两条测试：

```dart
testWidgets('窄桌面下工序详情卡改为上下堆叠图表', (tester) async {
  tester.view.physicalSize = const Size(920, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await pumpCraftKanbanPage(
    tester,
    craftService: _FakeCraftService(),
    productionService: _FakeProductionService(),
  );

  final workChart = find.byKey(const ValueKey('craft-kanban-work-chart-11'));
  final capacityChart = find.byKey(const ValueKey('craft-kanban-capacity-chart-11'));
  final workTop = tester.getTopLeft(workChart);
  final capacityTop = tester.getTopLeft(capacityChart);
  expect(capacityTop.dy, greaterThan(workTop.dy + 120));
});
```

```dart
testWidgets('工艺看板查询失败时内容区展示可重试错误态', (tester) async {
  final craftService = _FakeCraftService()
    ..metricsError = ApiException('统计接口异常', 500);

  await pumpCraftKanbanPage(
    tester,
    craftService: craftService,
    productionService: _FakeProductionService(),
  );

  expect(find.text('加载看板失败：统计接口异常'), findsOneWidget);
  expect(find.text('当前看板数据加载失败，请重试。'), findsOneWidget);
  expect(find.text('重试'), findsOneWidget);
});
```

- [ ] **Step 2: 运行测试，确认双栏/错误态新断言先失败**

Run:

```bash
flutter test test/widgets/craft_kanban_page_test.dart --plain-name "窄桌面下工序详情卡改为上下堆叠图表" -r expanded
```

Expected: FAIL，原因是图表尚无 key 或布局尚未按宽度降级。

- [ ] **Step 3: 重写工序详情卡为响应式双栏布局**

在 `craft_kanban_page.dart` 中新增图表面板与响应式卡片实现：

```dart
Widget _buildChartPanel({
  required String title,
  required Widget child,
  required String subtitle,
}) {
  return MesSectionCard(
    title: title,
    subtitle: subtitle,
    child: SizedBox(height: 220, child: child),
  );
}
```

```dart
Widget _buildProcessCard(CraftKanbanProcessItem processItem) {
  final samples = processItem.samples;
  if (samples.isEmpty) {
    return Card(
      child: ListTile(
        title: Text('${processItem.processCode} ${processItem.processName}'),
        subtitle: const Text('暂无可统计数据'),
      ),
    );
  }

  final stageText = [
    if ((processItem.stageCode ?? '').trim().isNotEmpty) processItem.stageCode!.trim(),
    if ((processItem.stageName ?? '').trim().isNotEmpty) processItem.stageName!.trim(),
  ].join(' ');
  final first = samples.first;
  final last = samples.last;
  final rangeLabel =
      '${first.startAt.toLocal()} ~ ${last.endAt.toLocal()}（样本 ${samples.length}）';

  return LayoutBuilder(
    builder: (context, constraints) {
      final stacked = constraints.maxWidth < 980;
      final workPanel = KeyedSubtree(
        key: ValueKey('craft-kanban-work-chart-${processItem.processId}'),
        child: _buildChartPanel(
          title: '工时分布',
          subtitle: '红柱表示高于样本均值 130%',
          child: _buildWorkMinutesChart(samples),
        ),
      );
      final capacityPanel = KeyedSubtree(
        key: ValueKey('craft-kanban-capacity-chart-${processItem.processId}'),
        child: _buildChartPanel(
          title: '产能走势',
          subtitle: '按样本记录展示件/小时变化',
          child: _buildCapacityChart(samples),
        ),
      );

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stageText.isEmpty
                    ? '${processItem.processCode} ${processItem.processName}'
                    : '$stageText  /  ${processItem.processCode} ${processItem.processName}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(rangeLabel, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              if (stacked)
                Column(
                  children: [
                    workPanel,
                    const SizedBox(height: 12),
                    capacityPanel,
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: workPanel),
                    const SizedBox(width: 12),
                    Expanded(child: capacityPanel),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
}
```

- [ ] **Step 4: 跑完整测试与分析，确认全部转绿**

Run:

```bash
flutter test test/widgets/craft_kanban_page_test.dart -r expanded
```

Expected: PASS

Run:

```bash
flutter analyze lib/features/craft/presentation/craft_kanban_page.dart test/widgets/craft_kanban_page_test.dart
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/features/craft/presentation/craft_kanban_page.dart frontend/test/widgets/craft_kanban_page_test.dart
git commit -m "完成工艺看板驾驶舱响应式改版"
```

---

## 计划自检结论

### Spec 覆盖

本计划已覆盖 spec 中以下要求：

1. 驾驶舱控制台重组
2. 摘要指标带
3. 总览区与工序详情卡双栏布局
4. 宽桌面与窄桌面响应式降级
5. 空态与错误态重构
6. 保持导出、日期、筛选与刷新行为不回退
7. `flutter test` 与 `flutter analyze` 验证

### 占位词扫描

本计划未使用 `TODO`、`TBD`、`待定`、`implement later` 等占位词。

### 一致性检查

本计划统一使用以下命名：

1. `_CraftKanbanSummary`
2. `_buildSummary`
3. `_buildSummaryCards`
4. `_buildChartPanel`
5. `craft-kanban-work-chart-<processId>`
6. `craft-kanban-capacity-chart-<processId>`

后续任务中的测试断言、实现片段与验证命令均使用同一套命名，没有前后漂移。
