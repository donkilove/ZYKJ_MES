# 设备模块完整收口实施计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 按三批方式完成设备模块完整收口，统一总页壳层、抽取模块级 widget、覆盖模块级 integration 测试。

**架构：** 参照生产模块完整收口模式，创建 `EquipmentPageShell` 和 `EquipmentPageHeader`，将 `EquipmentPage` 从旧式 `TabBar + TabBarView` 迁移到统一壳层。

**技术栈：** Flutter + Dart、`mes_crud_page_scaffold`、`CrudListTableSection`、`UnifiedListTableHeaderStyle`

---

## 第1批：总页壳层 + 设备台账

### 任务 1：创建 EquipmentPageShell

**文件：**
- 创建：`frontend/lib/features/equipment/presentation/widgets/equipment_page_shell.dart`
- 参考：`frontend/lib/features/production/presentation/widgets/production_page_shell.dart`

- [ ] **创建文件**

```dart
import 'package:flutter/material.dart';

class EquipmentPageShell extends StatelessWidget {
  const EquipmentPageShell({
    super.key,
    required this.tabBar,
    required this.tabBarView,
  });

  final Widget tabBar;
  final Widget tabBarView;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('equipment-page-shell'),
      child: Column(
        children: [
          KeyedSubtree(
            key: const ValueKey('equipment-page-tab-bar'),
            child: tabBar,
          ),
          Expanded(child: tabBarView),
        ],
      ),
    );
  }
}
```

- [ ] **运行分析验证**

```bash
cd frontend && flutter analyze lib/features/equipment/presentation/widgets/equipment_page_shell.dart
```

- [ ] **Commit**

---

### 任务 2：创建 EquipmentPageHeader

**文件：**
- 创建：`frontend/lib/features/equipment/presentation/widgets/equipment_page_header.dart`
- 参考：`frontend/lib/features/production/presentation/widgets/production_page_header.dart`

- [ ] **创建文件**

```dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class EquipmentPageHeader extends StatelessWidget {
  const EquipmentPageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: ValueKey('equipment-page-header'),
      child: MesPageHeader(
        title: '设备管理',
        subtitle: '统一装配设备模块全部页签。',
      ),
    );
  }
}
```

- [ ] **运行分析验证**

```bash
cd frontend && flutter analyze lib/features/equipment/presentation/widgets/equipment_page_header.dart
```

- [ ] **Commit**

---

### 任务 3：修改 EquipmentPage 使用新壳层

**文件：**
- 修改：`frontend/lib/features/equipment/presentation/equipment_page.dart`

- [ ] **添加 import**

```dart
import 'package:mes_client/features/equipment/presentation/widgets/equipment_page_shell.dart';
```

- [ ] **替换 build 方法中的 Column 为 EquipmentPageShell**

- [ ] **运行分析验证**

```bash
cd frontend && flutter analyze lib/features/equipment/presentation/equipment_page.dart
```

- [ ] **Commit**

---

## 第2批：保养项目 + 保养计划

### 任务 4：验证保养项目页

- [ ] **运行分析验证**

```bash
cd frontend && flutter analyze lib/features/equipment/presentation/maintenance_item_page.dart
```

- [ ] **Commit**

---

### 任务 5：验证保养计划页

- [ ] **运行分析验证**

```bash
cd frontend && flutter analyze lib/features/equipment/presentation/maintenance_plan_page.dart
```

- [ ] **Commit**

---

## 第3批：保养执行 + 保养记录 + 规则参数

### 任务 6：验证保养执行页

- [ ] **运行分析验证**

```bash
cd frontend && flutter analyze lib/features/equipment/presentation/maintenance_execution_page.dart
```

---

### 任务 7：验证保养记录页

- [ ] **运行分析验证**

```bash
cd frontend && flutter analyze lib/features/equipment/presentation/maintenance_record_page.dart
```

---

### 任务 8：验证规则参数页

- [ ] **运行分析验证**

```bash
cd frontend && flutter analyze lib/features/equipment/presentation/equipment_rule_parameter_page.dart
```

---

### 任务 9：创建模块级回归测试

**文件：**
- 创建：`frontend/test/widgets/equipment_module_full_convergence_test.dart`

- [ ] **创建测试文件**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/equipment/presentation/widgets/equipment_page_shell.dart';
import 'package:mes_client/features/equipment/presentation/widgets/equipment_page_header.dart';

void main() {
  group('EquipmentModuleFullConvergence', () {
    testWidgets('EquipmentPageShell renders correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DefaultTabController(
              length: 2,
              child: EquipmentPageShell(
                tabBar: const TabBar(tabs: [
                  Tab(text: '设备台账'),
                  Tab(text: '保养项目'),
                ]),
                tabBarView: const TabBarView(children: [
                  Center(child: Text('设备台账')),
                  Center(child: Text('保养项目')),
                ]),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(EquipmentPageShell), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(TabBarView), findsOneWidget);
    });

    testWidgets('EquipmentPageHeader renders correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EquipmentPageHeader()),
        ),
      );

      expect(find.byType(EquipmentPageHeader), findsOneWidget);
    });
  });
}
```

- [ ] **运行测试验证**

```bash
cd frontend && flutter test test/widgets/equipment_module_full_convergence_test.dart
```

---

## 验收检查清单

### 第1批完成检查

- [ ] `EquipmentPageShell` 已创建
- [ ] `EquipmentPageHeader` 已创建
- [ ] `EquipmentPage` 使用新壳层
- [ ] 代码分析通过

### 第2批完成检查

- [ ] 保养项目页代码分析通过
- [ ] 保养计划页代码分析通过

### 第3批完成检查

- [ ] 保养执行页代码分析通过
- [ ] 保养记录页代码分析通过
- [ ] 规则参数页代码分析通过
- [ ] 模块级回归测试通过
