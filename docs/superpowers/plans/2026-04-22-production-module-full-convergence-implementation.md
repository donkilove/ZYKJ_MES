# 生产模块完整收口实施计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 按三层分批方式完成生产模块完整收口，统一总页壳层、主业务页签使用 `mes_crud_page_scaffold`、抽取模块级 widget、覆盖模块级 integration 测试。

**架构：** 参照质量模块完整收口模式，创建 `ProductionPageShell` 和 `ProductionPageHeader`，将 `ProductionPage` 从旧式 `TabBar + TabBarView` 迁移到统一壳层；主业务页签使用 `MesCrudPageScaffold` 重构；抽取模块级 widget 如 `ProductionOrderStatusChip`。

**技术栈：** Flutter + Dart、`mes_crud_page_scaffold`、`CrudListTableSection`、`UnifiedListTableHeaderStyle`、`SimplePaginationBar`

---

## 文件结构

### 新增文件

| 文件 | 职责 |
|-----|------|
| `frontend/lib/features/production/presentation/widgets/production_page_shell.dart` | 总页壳层，替代 Column + TabBar |
| `frontend/lib/features/production/presentation/widgets/production_page_header.dart` | 统一页头 |
| `frontend/lib/features/production/presentation/widgets/production_order_status_chip.dart` | 订单状态 Chip |
| `frontend/lib/features/production/presentation/widgets/production_data_section_chip.dart` | 数据统计 Section 切换 Chip |
| `frontend/lib/features/production/presentation/widgets/production_module_feedback_banner.dart` | Feedback Banner |
| `frontend/test/widgets/production_module_full_convergence_test.dart` | 模块级完整回归测试 |

### 修改文件

| 文件 | 改造内容 |
|-----|---------|
| `frontend/lib/features/production/presentation/production_page.dart` | 使用 `ProductionPageShell` |
| `frontend/lib/features/production/presentation/production_order_management_page.dart` | 使用 `mes_crud_page_scaffold` |
| `frontend/lib/features/production/presentation/production_order_query_page.dart` | 使用 `mes_crud_page_scaffold` |
| `frontend/lib/features/production/presentation/production_data_page.dart` | 使用 `mes_crud_page_scaffold`，抽取 Section Chip |
| `frontend/lib/features/production/presentation/production_scrap_statistics_page.dart` | 使用 `mes_crud_page_scaffold` |
| `frontend/lib/features/production/presentation/production_pipeline_instances_page.dart` | 使用 `mes_crud_page_scaffold` |
| `frontend/lib/features/production/presentation/production_assist_records_page.dart` | 使用 `mes_crud_page_scaffold` |
| `frontend/lib/features/production/presentation/production_repair_orders_page.dart` | 使用 `mes_crud_page_scaffold` |

---

## 第1批：总页壳层 + 主业务页签

### 任务 1：创建 ProductionPageShell

**文件：**
- 创建：`frontend/lib/features/production/presentation/widgets/production_page_shell.dart`
- 参考：`frontend/lib/features/quality/presentation/widgets/quality_page_shell.dart`

- [ ] **步骤 1：创建 ProductionPageShell 文件**

```dart
import 'package:flutter/material.dart';

class ProductionPageShell extends StatelessWidget {
  const ProductionPageShell({
    super.key,
    required this.tabBar,
    required this.tabBarView,
  });

  final Widget tabBar;
  final Widget tabBarView;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('production-page-shell'),
      child: Column(
        children: [
          KeyedSubtree(
            key: const ValueKey('production-page-tab-bar'),
            child: tabBar,
          ),
          Expanded(child: tabBarView),
        ],
      ),
    );
  }
}
```

- [ ] **步骤 2：Commit**

```bash
git add frontend/lib/features/production/presentation/widgets/production_page_shell.dart
git commit -m "feat(production): add ProductionPageShell"
```

---

### 任务 2：创建 ProductionPageHeader

**文件：**
- 创建：`frontend/lib/features/production/presentation/widgets/production_page_header.dart`
- 参考：`frontend/lib/features/quality/presentation/widgets/quality_page_header.dart`

- [ ] **步骤 1：创建 ProductionPageHeader 文件**

```dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class ProductionPageHeader extends StatelessWidget {
  const ProductionPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: ValueKey('production-page-header'),
      child: MesPageHeader(
        title: '生产管理',
        subtitle: '统一装配生产模块全部页签。',
      ),
    );
  }
}
```

- [ ] **步骤 2：Commit**

```bash
git add frontend/lib/features/production/presentation/widgets/production_page_header.dart
git commit -m "feat(production): add ProductionPageHeader"
```

---

### 任务 3：创建 ProductionOrderStatusChip

**文件：**
- 创建：`frontend/lib/features/production/presentation/widgets/production_order_status_chip.dart`
- 参考：`frontend/lib/features/product/presentation/widgets/product_management_status_chip.dart`

- [ ] **步骤 1：创建 ProductionOrderStatusChip 文件**

```dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/primitives/mes_status_chip.dart';
import 'package:mes_client/features/production/models/production_models.dart';

class ProductionOrderStatusChip extends StatelessWidget {
  const ProductionOrderStatusChip({
    super.key,
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    return MesStatusChip(
      label: productionOrderStatusLabel(status),
      color: _statusColor(status),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
```

- [ ] **步骤 2：Commit**

```bash
git add frontend/lib/features/production/presentation/widgets/production_order_status_chip.dart
git commit -m "feat(production): add ProductionOrderStatusChip"
```

---

### 任务 4：修改 ProductionPage 使用新壳层

**文件：**
- 修改：`frontend/lib/features/production/presentation/production_page.dart:1-302`

- [ ] **步骤 1：在文件头部添加 import**

```dart
import 'package:mes_client/features/production/presentation/widgets/production_page_shell.dart';
```

- [ ] **步骤 2：替换 build 方法中的 Column 为 ProductionPageShell**

原始代码（第 282-300 行）：
```dart
return Column(
  children: [
    Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: TabBar(
        controller: _tabController,
        tabs: _orderedVisibleTabCodes
            .map((code) => Tab(text: _tabTitle(code)))
            .toList(),
      ),
    ),
    Expanded(
      child: TabBarView(
        controller: _tabController,
        children: _orderedVisibleTabCodes.map(_buildTabContent).toList(),
      ),
    ),
  ],
);
```

替换为：
```dart
return ProductionPageShell(
  tabBar: Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: TabBar(
      controller: _tabController,
      tabs: _orderedVisibleTabCodes
          .map((code) => Tab(text: _tabTitle(code)))
          .toList(),
    ),
  ),
  tabBarView: TabBarView(
    controller: _tabController,
    children: _orderedVisibleTabCodes.map(_buildTabContent).toList(),
  ),
);
```

- [ ] **步骤 3：运行分析验证**

```bash
cd frontend && flutter analyze lib/features/production/presentation/production_page.dart
```

预期：无错误

- [ ] **步骤 4：Commit**

```bash
git add frontend/lib/features/production/presentation/production_page.dart
git commit -m "refactor(production): use ProductionPageShell in ProductionPage"
```

---

### 任务 5：修改 ProductionOrderManagementPage 使用统一组件

**文件：**
- 修改：`frontend/lib/features/production/presentation/production_order_management_page.dart`
- 参考：`frontend/lib/features/product/presentation/product_management_page.dart`

**说明：** 此任务涉及较多文件改造，建议分子步骤完成。具体改造内容：
1. 使用 `MesCrudPageScaffold` 包裹页面结构
2. 确认 `CrudListTableSection` + `UnifiedListTableHeaderStyle` 兼容性
3. 使用 `ProductionOrderStatusChip` 替换硬编码状态 Text

- [ ] **步骤 1：添加 import**

```dart
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/features/production/presentation/widgets/production_order_status_chip.dart';
```

- [ ] **步骤 2：用 MesCrudPageScaffold 包裹 build 方法内容**

将 `build` 方法中的 `Padding` -> `Column` 结构替换为 `MesCrudPageScaffold`

- [ ] **步骤 3：替换订单状态为 ProductionOrderStatusChip**

原始代码（约第 750 行）：
```dart
DataCell(Text(productionOrderStatusLabel(item.status))),
```

替换为：
```dart
DataCell(ProductionOrderStatusChip(status: item.status)),
```

- [ ] **步骤 4：运行分析验证**

```bash
cd frontend && flutter analyze lib/features/production/presentation/production_order_management_page.dart
```

预期：无错误

- [ ] **步骤 5：运行单元测试验证**

```bash
cd frontend && flutter test test/widgets/production_order_management_page_test.dart
```

预期：测试通过

- [ ] **步骤 6：Commit**

```bash
git add frontend/lib/features/production/presentation/production_order_management_page.dart
git commit -m "refactor(production): use mes_crud_page_scaffold in ProductionOrderManagementPage"
```

---

### 任务 6：修改 ProductionOrderQueryPage 使用统一组件

**文件：**
- 修改：`frontend/lib/features/production/presentation/production_order_query_page.dart`

- [ ] **步骤 1：添加 import**

```dart
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
```

- [ ] **步骤 2：检查并重构页面结构**

检查 `production_order_query_page.dart` 的 build 方法，参照 `production_order_management_page.dart` 的改造方式

- [ ] **步骤 3：运行分析验证**

```bash
cd frontend && flutter analyze lib/features/production/presentation/production_order_query_page.dart
```

预期：无错误

- [ ] **步骤 4：运行单元测试验证**

```bash
cd frontend && flutter test test/widgets/production_order_query_page_test.dart
```

预期：测试通过

- [ ] **步骤 5：Commit**

```bash
git add frontend/lib/features/production/presentation/production_order_query_page.dart
git commit -m "refactor(production): use mes_crud_page_scaffold in ProductionOrderQueryPage"
```

---

### 任务 7：运行第1批集成验证

**文件：**
- 测试：`frontend/test/widgets/production_page_test.dart`

- [ ] **步骤 1：运行总页测试**

```bash
cd frontend && flutter test test/widgets/production_page_test.dart
```

预期：测试通过

- [ ] **步骤 2：运行模块级回归测试**

```bash
cd frontend && flutter test test/widgets/production_module_full_convergence_test.dart 2>/dev/null || echo "Test file may not exist yet"
```

预期：测试通过或文件不存在（将在第3批创建）

- [ ] **步骤 3：Commit 第1批完成**

```bash
git add -A
git commit -m "feat(production): complete batch 1 - shell and main business tabs"
```

---

## 第2批：数据统计类页签

### 任务 8：创建 ProductionDataSectionChip

**文件：**
- 创建：`frontend/lib/features/production/presentation/widgets/production_data_section_chip.dart`

- [ ] **步骤 1：创建 ProductionDataSectionChip 文件**

```dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/production/models/production_models.dart';

class ProductionDataSectionChip extends StatelessWidget {
  const ProductionDataSectionChip({
    super.key,
    required this.selectedSection,
    required this.onSectionChanged,
  });

  final ProductionDataSection selectedSection;
  final ValueChanged<ProductionDataSection> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ProductionDataSection>(
      segments: const [
        ButtonSegment(
          value: ProductionDataSection.processStats,
          label: Text('工序统计'),
        ),
        ButtonSegment(
          value: ProductionDataSection.todayRealtime,
          label: Text('今日实时产量'),
        ),
        ButtonSegment(
          value: ProductionDataSection.operatorStats,
          label: Text('人员统计'),
        ),
      ],
      selected: {selectedSection},
      onSelectionChanged: (selection) {
        onSectionChanged(selection.first);
      },
    );
  }
}
```

- [ ] **步骤 2：Commit**

```bash
git add frontend/lib/features/production/presentation/widgets/production_data_section_chip.dart
git commit -m "feat(production): add ProductionDataSectionChip"
```

---

### 任务 9：修改 ProductionDataPage 使用统一组件

**文件：**
- 修改：`frontend/lib/features/production/presentation/production_data_page.dart`

- [ ] **步骤 1：添加 import**

```dart
import 'package:mes_client/features/production/presentation/widgets/production_data_section_chip.dart';
```

- [ ] **步骤 2：使用 ProductionDataSectionChip 替换现有 Section 切换逻辑**

- [ ] **步骤 3：运行分析验证**

```bash
cd frontend && flutter analyze lib/features/production/presentation/production_data_page.dart
```

预期：无错误

- [ ] **步骤 4：Commit**

```bash
git add frontend/lib/features/production/presentation/production_data_page.dart
git commit -m "refactor(production): use ProductionDataSectionChip in ProductionDataPage"
```

---

### 任务 10：修改其他数据统计类页签

**文件：**
- 修改：`frontend/lib/features/production/presentation/production_scrap_statistics_page.dart`
- 修改：`frontend/lib/features/production/presentation/production_pipeline_instances_page.dart`

- [ ] **步骤 1：检查并重构页面结构**

参照 `production_order_management_page.dart` 的改造方式

- [ ] **步骤 2：运行分析验证**

```bash
cd frontend && flutter analyze lib/features/production/presentation/production_scrap_statistics_page.dart lib/features/production/presentation/production_pipeline_instances_page.dart
```

预期：无错误

- [ ] **步骤 3：Commit**

```bash
git add frontend/lib/features/production/presentation/production_scrap_statistics_page.dart frontend/lib/features/production/presentation/production_pipeline_instances_page.dart
git commit -m "refactor(production): use mes_crud_page_scaffold in scrap and pipeline pages"
```

---

### 任务 11：运行第2批集成验证

- [ ] **步骤 1：运行相关测试**

```bash
cd frontend && flutter test test/widgets/production_data_page_test.dart test/widgets/production_repair_scrap_pages_test.dart
```

预期：测试通过

- [ ] **步骤 2：Commit 第2批完成**

```bash
git add -A
git commit -m "feat(production): complete batch 2 - data statistics tabs"
```

---

## 第3批：辅助类页签

### 任务 12：修改辅助类页签

**文件：**
- 修改：`frontend/lib/features/production/presentation/production_assist_records_page.dart`
- 修改：`frontend/lib/features/production/presentation/production_repair_orders_page.dart`

- [ ] **步骤 1：检查并重构页面结构**

参照 `production_order_management_page.dart` 的改造方式

- [ ] **步骤 2：运行分析验证**

```bash
cd frontend && flutter analyze lib/features/production/presentation/production_assist_records_page.dart lib/features/production/presentation/production_repair_orders_page.dart
```

预期：无错误

- [ ] **步骤 3：Commit**

```bash
git add frontend/lib/features/production/presentation/production_assist_records_page.dart frontend/lib/features/production/presentation/production_repair_orders_page.dart
git commit -m "refactor(production): use mes_crud_page_scaffold in assist and repair pages"
```

---

### 任务 13：创建模块级回归测试

**文件：**
- 创建：`frontend/test/widgets/production_module_full_convergence_test.dart`
- 参考：`frontend/test/widgets/quality_module_full_convergence_test.dart`

- [ ] **步骤 1：创建测试文件**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/production/presentation/widgets/production_page_shell.dart';
import 'package:mes_client/features/production/presentation/widgets/production_page_header.dart';
import 'package:flutter/material.dart';

void main() {
  group('ProductionModuleFullConvergence', () {
    testWidgets('ProductionPageShell renders correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProductionPageShell(
            tabBar: const TabBar(tabs: []),
            tabBarView: const TabBarView(children: []),
          ),
        ),
      );

      expect(find.byType(ProductionPageShell), findsOneWidget);
    });

    testWidgets('ProductionPageHeader renders correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ProductionPageHeader()),
        ),
      );

      expect(find.byType(ProductionPageHeader), findsOneWidget);
    });
  });
}
```

- [ ] **步骤 2：运行测试验证**

```bash
cd frontend && flutter test test/widgets/production_module_full_convergence_test.dart
```

预期：测试通过

- [ ] **步骤 3：Commit**

```bash
git add frontend/test/widgets/production_module_full_convergence_test.dart
git commit -m "test(production): add module full convergence test"
```

---

### 任务 14：最终验收

- [ ] **步骤 1：运行完整模块测试**

```bash
cd frontend && flutter test test/widgets/production_module_full_convergence_test.dart test/widgets/production_page_test.dart
```

预期：所有测试通过

- [ ] **步骤 2：运行分析检查**

```bash
cd frontend && flutter analyze lib/features/production/
```

预期：无错误

- [ ] **步骤 3：Commit 收尾**

```bash
git add -A
git commit -m "feat(production): complete full convergence"
```

---

## 验收检查清单

### 第1批完成检查

- [ ] `ProductionPageShell` 已创建且被 `ProductionPage` 使用
- [ ] `ProductionPageHeader` 已创建
- [ ] `ProductionOrderStatusChip` 已创建
- [ ] `ProductionPage` 使用新壳层
- [ ] 订单管理页使用 `mes_crud_page_scaffold`
- [ ] 订单查询页使用 `mes_crud_page_scaffold`
- [ ] 单元测试通过
- [ ] Integration 测试通过

### 第2批完成检查

- [ ] `ProductionDataSectionChip` 已创建
- [ ] 数据统计页使用新 Chip
- [ ] 报废统计页使用统一组件
- [ ] 并行实例追踪页使用统一组件
- [ ] 单元测试通过
- [ ] Integration 测试通过

### 第3批完成检查

- [ ] 代班记录页使用统一组件
- [ ] 维修订单页使用统一组件
- [ ] 模块级 integration 测试覆盖
- [ ] 模块级回归测试通过
- [ ] 旧组件已清理
