# Quality 模块高优先级页面迁移实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将 QualityTrendPage 和 QualityScrapStatisticsPage 迁移到 MesCrudPageScaffold，实现页面布局统一化

**架构：** 重构两个质量模块页面使用 MesCrudPageScaffold 作为根布局组件，复用现有 Header 组件，保持业务逻辑不变

**技术栈：** Flutter, MesCrudPageScaffold, Widget Testing

---

## 文件清单

| 文件 | 职责 |
|------|------|
| `frontend/lib/features/quality/presentation/quality_trend_page.dart` | 质量趋势页面主文件 - 重构为使用 MesCrudPageScaffold |
| `frontend/lib/features/quality/presentation/quality_scrap_statistics_page.dart` | 质量报废统计页面 - 重构为使用 MesCrudPageScaffold |
| `frontend/test/widgets/quality_trend_page_test.dart` | 质量趋势页面测试 - 新增 MesCrudPageScaffold 验证 |
| `frontend/test/widgets/quality_scrap_statistics_page_test.dart` | 质量报废统计页面测试 - 新增 MesCrudPageScaffold 验证 |

---

## 任务 1：QualityScrapStatisticsPage 迁移

**文件：** `frontend/lib/features/quality/presentation/quality_scrap_statistics_page.dart`

- [ ] **步骤 1：阅读当前实现**

确认文件结构和现有组件使用情况

- [ ] **步骤 2：重构为使用 MesCrudPageScaffold**

```dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/quality/presentation/widgets/quality_scrap_statistics_page_header.dart';
import 'package:mes_client/features/quality/services/quality_service.dart';
import 'package:mes_client/features/production/presentation/production_scrap_statistics_page.dart';

class QualityScrapStatisticsPage extends StatelessWidget {
  const QualityScrapStatisticsPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canExport,
    this.jumpPayloadJson,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canExport;
  final String? jumpPayloadJson;
  final QualityService? service;

  @override
  Widget build(BuildContext context) {
    return MesCrudPageScaffold(
      header: const QualityScrapStatisticsPageHeader(),
      content: ProductionScrapStatisticsPage(
        session: session,
        onLogout: onLogout,
        canExport: canExport,
        jumpPayloadJson: jumpPayloadJson,
        service: service ?? QualityService(session),
      ),
    );
  }
}
```

- [ ] **步骤 3：运行测试验证**

运行：`cd frontend && flutter test test/widgets/quality_scrap_statistics_page_test.dart`
预期：测试通过（如果测试文件存在且覆盖正确）

---

## 任务 2：QualityTrendPage 迁移

**文件：** `frontend/lib/features/quality/presentation/quality_trend_page.dart`

- [ ] **步骤 1：阅读当前实现**

确认文件结构，特别注意 `_buildSummaryCards`, `_buildChart`, `_buildPassRateChart`, `_buildDimensionSection`, `_buildTrendTable` 方法

- [ ] **步骤 2：添加 MesCrudPageScaffold import**

在 import 列表中添加：
```dart
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
```

- [ ] **步骤 3：提取 FilterBar 方法**

将 build 方法中的 filter Wrap 提取为 `_buildFilterBar()` 方法：
```dart
Widget _buildFilterBar(ThemeData theme) {
  return Wrap(
    spacing: 12,
    runSpacing: 8,
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
      SizedBox(
        width: 130,
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
        width: 120,
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
        width: 120,
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
      DropdownButton<String?>(
        value: _resultFilter,
        hint: const Text('全部结果'),
        items: const [
          DropdownMenuItem(value: null, child: Text('全部结果')),
          DropdownMenuItem(value: 'passed', child: Text('合格')),
          DropdownMenuItem(value: 'failed', child: Text('不合格')),
        ],
        onChanged: _loading
            ? null
            : (v) => setState(() => _resultFilter = v),
      ),
      FilledButton.icon(
        onPressed: _loading ? null : _loadTrend,
        icon: const Icon(Icons.search),
        label: const Text('查询'),
      ),
    ],
  );
}
```

- [ ] **步骤 4：提取 MainContent 方法**

将 build 方法中的 Expanded(ListView) 提取为 `_buildMainContent()` 方法：
```dart
Widget _buildMainContent(ThemeData theme) {
  return ListView(
    children: [
      if (_items.length >= 2) ...[
        _buildChart(),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _legendDot(Colors.green, '通过'),
            _legendDot(Colors.red, '不通过'),
            _legendDot(Colors.deepOrange, '不良'),
            _legendDot(Colors.orange, '报废'),
            _legendDot(Colors.purple, '维修'),
          ],
        ),
        const SizedBox(height: 12),
        _buildPassRateChart(),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          children: [_legendDot(Colors.blue, '通过率趋势')],
        ),
        const SizedBox(height: 12),
      ],
      _buildDimensionSection(),
      const SizedBox(height: 12),
      _buildTrendTable(),
    ],
  );
}
```

- [ ] **步骤 5：重构 build 方法**

将整个 build 方法重构为使用 MesCrudPageScaffold：
```dart
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  return MesCrudPageScaffold(
    header: QualityTrendPageHeader(
      loading: _loading,
      canExport: widget.canExport,
      exporting: _exporting,
      onRefresh: _loadTrend,
      onExport: _exportTrend,
    ),
    filters: _buildFilterBar(theme),
    banner: _buildSummaryCards(context),
    content: _loading
        ? const Center(child: CircularProgressIndicator())
        : _buildMainContent(theme),
  );
}
```

- [ ] **步骤 6：删除不再需要的代码**

移除：
- 原来的 `Padding(16)` 包装
- `Column` 包装
- 内部的错误消息 Text（需要将 `_message` 显示改为 SnackBar 或其他方式）

- [ ] **步骤 7：运行测试验证**

运行：`cd frontend && flutter test test/widgets/quality_trend_page_test.dart`
预期：测试通过

---

## 任务 3：编写/更新测试

**文件：** `frontend/test/widgets/quality_scrap_statistics_page_test.dart`, `frontend/test/widgets/quality_trend_page_test.dart`

- [ ] **步骤 1：检查现有测试文件**

查看测试文件是否已存在

- [ ] **步骤 2：为 QualityScrapStatisticsPage 添加 MesCrudPageScaffold 验证测试**

如果测试文件存在，添加：
```dart
testWidgets('QualityScrapStatisticsPage 使用 MesCrudPageScaffold', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: QualityScrapStatisticsPage(
      session: fakeSession,
      onLogout: () {},
      canExport: false,
      service: fakeService,
    ),
  ));
  expect(find.byType(MesCrudPageScaffold), findsOneWidget);
});
```

- [ ] **步骤 3：为 QualityTrendPage 添加 MesCrudPageScaffold 验证测试**

如果测试文件存在，添加：
```dart
testWidgets('QualityTrendPage 使用 MesCrudPageScaffold', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: QualityTrendPage(
      session: fakeSession,
      onLogout: () {},
      service: fakeService,
    ),
  ));
  expect(find.byType(MesCrudPageScaffold), findsOneWidget);
});
```

- [ ] **步骤 4：运行所有测试**

运行：`cd frontend && flutter test test/widgets/quality_trend_page_test.dart test/widgets/quality_scrap_statistics_page_test.dart`
预期：所有测试通过

---

## 任务 4：Git 提交

- [ ] **步骤 1：检查 git 状态**

运行：`git status`

- [ ] **步骤 2：添加并提交更改**

```bash
git add frontend/lib/features/quality/presentation/quality_trend_page.dart
git add frontend/lib/features/quality/presentation/quality_scrap_statistics_page.dart
git add frontend/test/widgets/quality_trend_page_test.dart
git add frontend/test/widgets/quality_scrap_statistics_page_test.dart
git commit -m "feat(quality): 迁移高优先级页面到 MesCrudPageScaffold

- QualityScrapStatisticsPage 使用 MesCrudPageScaffold 统一布局
- QualityTrendPage 使用 MesCrudPageScaffold 统一布局
- 提取 filterBar 和 mainContent 方法提高可维护性"
```

---

## 验收检查清单

- [ ] QualityScrapStatisticsPage 使用 MesCrudPageScaffold
- [ ] QualityTrendPage 使用 MesCrudPageScaffold
- [ ] 页面功能与迁移前保持一致
- [ ] 所有相关测试通过
- [ ] 提交到 git
