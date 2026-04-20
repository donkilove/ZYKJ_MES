# 用户模块 UI 第二波迁移 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 Flutter 前端中完成“用户管理 + 注册审批”两页的第二波 UI 迁移，补齐 CRUD 骨架模式件、收敛页面状态流，并同步补齐 widget / integration / evidence 闭环。

**Architecture:** 先在 `core/ui/patterns/` 内补齐适合 CRUD 页面装配的 `MesCrudPageScaffold / MesInlineBanner / MesTableSectionHeader`，再在 `features/user/presentation/widgets/shared/` 中建立用户模块共用展示层。页面迁移按“用户管理 -> 注册审批”的顺序推进，页面主文件只保留状态编排与动作入口，筛选区、反馈区、列表区拆到独立组件中，现有业务弹窗与权限语义保持不变。

**Tech Stack:** Flutter、Dart、Material 3、`flutter_test`、`integration_test`

---

> 本计划遵循“无迁移，直接替换”。  
> 用户已明确要求在当前 `main` 分支内直接执行，不使用 worktree，本计划按该口径编写。  
> 当前工作区已有一处与本计划无关的改动：`evidence/2026-04-20_前端UI基础件体系实施.md`。执行本计划时不要误将该文件一并提交。

## 文件结构

### 新增文件

- `frontend/lib/core/ui/patterns/mes_inline_banner.dart`
  - 统一页内反馈条，承接 info / warning / error / success 四种语义
- `frontend/lib/core/ui/patterns/mes_table_section_header.dart`
  - 统一表格区标题、说明和右侧动作位
- `frontend/lib/core/ui/patterns/mes_crud_page_scaffold.dart`
  - 统一 CRUD 页的 `header / filters / banner / content / pagination`
- `frontend/lib/features/user/presentation/widgets/shared/user_module_feedback_banner.dart`
  - 用户模块页内反馈薄包装，稳定 key 与 tone 映射
- `frontend/lib/features/user/presentation/widgets/shared/user_module_status_chip.dart`
  - 用户模块状态语义统一件，覆盖在线、离线、启用、停用、已删除、待审批、已通过、已驳回
- `frontend/lib/features/user/presentation/widgets/shared/user_module_filter_panel.dart`
  - 用户模块筛选区容器薄包装
- `frontend/lib/features/user/presentation/widgets/shared/user_module_table_shell.dart`
  - 用户模块列表区容器薄包装，统一标题、key 和空态布局
- `frontend/lib/features/user/presentation/widgets/user_management_page_header.dart`
  - 用户管理页头
- `frontend/lib/features/user/presentation/widgets/user_management_action_bar.dart`
  - 用户管理主操作区
- `frontend/lib/features/user/presentation/widgets/user_management_filter_section.dart`
  - 用户管理筛选区装配
- `frontend/lib/features/user/presentation/widgets/user_management_feedback_banner.dart`
  - 用户管理反馈区装配
- `frontend/lib/features/user/presentation/widgets/user_management_table_section.dart`
  - 用户管理表格区装配
- `frontend/lib/features/user/presentation/widgets/registration_approval_page_header.dart`
  - 注册审批页头
- `frontend/lib/features/user/presentation/widgets/registration_approval_filter_section.dart`
  - 注册审批筛选区装配
- `frontend/lib/features/user/presentation/widgets/registration_approval_feedback_banner.dart`
  - 注册审批反馈区装配
- `frontend/lib/features/user/presentation/widgets/registration_approval_table_section.dart`
  - 注册审批表格区装配
- `frontend/test/widgets/user_module_shared_widgets_test.dart`
  - 覆盖用户模块共享展示层
- `frontend/integration_test/user_module_flow_test.dart`
  - 覆盖用户管理与注册审批的统一锚点与最小流程
- `evidence/2026-04-20_用户模块UI第二波迁移实施.md`
  - 本轮实施 evidence 主日志

### 修改文件

- `frontend/test/widgets/ui/mes_patterns_test.dart`
  - 补齐 CRUD 模式件失败测试与回归断言
- `frontend/lib/features/user/presentation/user_management_page.dart`
  - 收敛状态入口、接入 `MesCrudPageScaffold`
- `frontend/lib/features/user/presentation/widgets/user_data_table.dart`
  - 接入 `UserModuleStatusChip` 和 `UserModuleTableShell`
- `frontend/test/widgets/user_management_page_test.dart`
  - 覆盖统一骨架、页码回退、权限显隐与页内反馈
- `frontend/lib/features/user/presentation/registration_approval_page.dart`
  - 收敛状态入口、接入 `MesCrudPageScaffold`
- `frontend/test/widgets/registration_approval_page_test.dart`
  - 覆盖统一骨架、状态筛选、route payload 提示与页内反馈
- `frontend/test/widgets/user_page_test.dart`
  - 保持最小回归，确认 tab 装配未被破坏

## 任务 1：补齐 CRUD 模式骨架层

**Files:**
- Create: `frontend/lib/core/ui/patterns/mes_inline_banner.dart`
- Create: `frontend/lib/core/ui/patterns/mes_table_section_header.dart`
- Create: `frontend/lib/core/ui/patterns/mes_crud_page_scaffold.dart`
- Modify: `frontend/test/widgets/ui/mes_patterns_test.dart`

- [ ] **Step 1: 先写失败测试，固定 CRUD 骨架插槽与页内反馈能力**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_inline_banner.dart';
import 'package:mes_client/core/ui/patterns/mes_table_section_header.dart';

void main() {
  testWidgets('MesCrudPageScaffold 按固定顺序装配 header filters banner content pagination', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: Scaffold(
          body: MesCrudPageScaffold(
            header: const Text('header-slot'),
            filters: const Text('filters-slot'),
            banner: const MesInlineBanner.info(message: '页内提示'),
            content: const Placeholder(),
            pagination: const Text('pagination-slot'),
          ),
        ),
      ),
    );

    expect(find.text('header-slot'), findsOneWidget);
    expect(find.text('filters-slot'), findsOneWidget);
    expect(find.text('页内提示'), findsOneWidget);
    expect(find.text('pagination-slot'), findsOneWidget);
    expect(find.byType(MesInlineBanner), findsOneWidget);
  });

  testWidgets('MesTableSectionHeader 支持标题、副标题和右侧动作', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: const Scaffold(
          body: MesTableSectionHeader(
            title: '列表区',
            subtitle: '统一表格说明',
            trailing: Text('仅右侧动作'),
          ),
        ),
      ),
    );

    expect(find.text('列表区'), findsOneWidget);
    expect(find.text('统一表格说明'), findsOneWidget);
    expect(find.text('仅右侧动作'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行模式件测试，确认新增骨架尚未存在**

Run: `flutter test test/widgets/ui/mes_patterns_test.dart`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Undefined class 'MesCrudPageScaffold'`

- [ ] **Step 3: 实现 CRUD 模式骨架文件**

```dart
// frontend/lib/core/ui/patterns/mes_inline_banner.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';
import 'package:mes_client/core/ui/primitives/mes_surface.dart';

enum MesInlineBannerTone { info, warning, error, success }

class MesInlineBanner extends StatelessWidget {
  const MesInlineBanner._({
    super.key,
    required this.message,
    required this.tone,
  });

  const MesInlineBanner.info({Key? key, required String message})
    : this._(key: key, message: message, tone: MesInlineBannerTone.info);

  const MesInlineBanner.warning({Key? key, required String message})
    : this._(key: key, message: message, tone: MesInlineBannerTone.warning);

  const MesInlineBanner.error({Key? key, required String message})
    : this._(key: key, message: message, tone: MesInlineBannerTone.error);

  const MesInlineBanner.success({Key? key, required String message})
    : this._(key: key, message: message, tone: MesInlineBannerTone.success);

  final String message;
  final MesInlineBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<MesTokens>();
    final color = switch (tone) {
      MesInlineBannerTone.info => tokens?.colors.info ?? theme.colorScheme.primary,
      MesInlineBannerTone.warning => tokens?.colors.warning ?? const Color(0xFFB97100),
      MesInlineBannerTone.error => tokens?.colors.danger ?? theme.colorScheme.error,
      MesInlineBannerTone.success => tokens?.colors.success ?? const Color(0xFF1B8A5A),
    };
    final icon = switch (tone) {
      MesInlineBannerTone.info => Icons.info_outline_rounded,
      MesInlineBannerTone.warning => Icons.warning_amber_rounded,
      MesInlineBannerTone.error => Icons.error_outline_rounded,
      MesInlineBannerTone.success => Icons.check_circle_outline_rounded,
    };
    return MesSurface(
      tone: MesSurfaceTone.subtle,
      padding: EdgeInsets.symmetric(
        horizontal: tokens?.spacing.md ?? 16,
        vertical: tokens?.spacing.sm ?? 12,
      ),
      border: BorderSide(color: color.withValues(alpha: 0.35)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          SizedBox(width: tokens?.spacing.sm ?? 12),
          Expanded(
            child: Text(
              message,
              style: (tokens?.typography.body ?? theme.textTheme.bodyMedium)?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/core/ui/patterns/mes_table_section_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';
import 'package:mes_client/core/ui/primitives/mes_gap.dart';

class MesTableSectionHeader extends StatelessWidget {
  const MesTableSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<MesTokens>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: tokens?.typography.sectionTitle ??
                    theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (subtitle != null) ...[
                MesGap.vertical(tokens?.spacing.xs ?? 8),
                Text(
                  subtitle!,
                  style: tokens?.typography.body ??
                      theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          MesGap.horizontal(tokens?.spacing.md ?? 16),
          trailing!,
        ],
      ],
    );
  }
}
```

```dart
// frontend/lib/core/ui/patterns/mes_crud_page_scaffold.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';
import 'package:mes_client/core/ui/primitives/mes_gap.dart';

class MesCrudPageScaffold extends StatelessWidget {
  const MesCrudPageScaffold({
    super.key,
    required this.header,
    required this.content,
    this.filters,
    this.banner,
    this.pagination,
    this.padding,
  });

  final Widget header;
  final Widget? filters;
  final Widget? banner;
  final Widget content;
  final Widget? pagination;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<MesTokens>()?.spacing.md ?? 16.0;
    return Padding(
      padding: padding ?? EdgeInsets.all(spacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          if (filters != null) ...[
            MesGap.vertical(spacing),
            filters!,
          ],
          if (banner != null) ...[
            MesGap.vertical(spacing),
            banner!,
          ],
          MesGap.vertical(spacing),
          Expanded(child: content),
          if (pagination != null) ...[
            MesGap.vertical(spacing),
            pagination!,
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 重新运行模式件测试，确认 CRUD 骨架可用**

Run: `flutter test test/widgets/ui/mes_patterns_test.dart`

Expected: PASS，显示 `All tests passed`

- [ ] **Step 5: 提交 CRUD 模式骨架层**

```bash
git add frontend/lib/core/ui/patterns/mes_inline_banner.dart frontend/lib/core/ui/patterns/mes_table_section_header.dart frontend/lib/core/ui/patterns/mes_crud_page_scaffold.dart frontend/test/widgets/ui/mes_patterns_test.dart
git commit -m "补齐用户模块CRUD骨架模式件"
```

## 任务 2：建立用户模块共享展示层

**Files:**
- Create: `frontend/lib/features/user/presentation/widgets/shared/user_module_feedback_banner.dart`
- Create: `frontend/lib/features/user/presentation/widgets/shared/user_module_status_chip.dart`
- Create: `frontend/lib/features/user/presentation/widgets/shared/user_module_filter_panel.dart`
- Create: `frontend/lib/features/user/presentation/widgets/shared/user_module_table_shell.dart`
- Create: `frontend/test/widgets/user_module_shared_widgets_test.dart`

- [ ] **Step 1: 先写失败测试，固定共享反馈条、状态标签和列表壳层**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_feedback_banner.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_filter_panel.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_status_chip.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_table_shell.dart';

void main() {
  testWidgets('用户模块共享件提供稳定反馈、筛选和表格壳层', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: const Scaffold(
          body: Column(
            children: [
              UserModuleFeedbackBanner.error(message: '权限不足'),
              UserModuleFilterPanel(
                sectionKey: ValueKey('filter-shell'),
                child: Text('筛选内容'),
              ),
              Expanded(
                child: UserModuleTableShell(
                  sectionKey: ValueKey('table-shell'),
                  title: '用户列表',
                  child: Center(
                    child: UserModuleStatusChip(
                      tone: UserModuleStatusTone.online,
                      label: '在线',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('权限不足'), findsOneWidget);
    expect(find.byKey(const ValueKey('filter-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('table-shell')), findsOneWidget);
    expect(find.text('在线'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行共享件测试，确认用户模块共享层尚未存在**

Run: `flutter test test/widgets/user_module_shared_widgets_test.dart`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Undefined class 'UserModuleFeedbackBanner'`

- [ ] **Step 3: 实现共享展示层文件**

```dart
// frontend/lib/features/user/presentation/widgets/shared/user_module_feedback_banner.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_inline_banner.dart';

class UserModuleFeedbackBanner extends StatelessWidget {
  const UserModuleFeedbackBanner._({
    super.key,
    required this.message,
    required this.builder,
  });

  const UserModuleFeedbackBanner.info({Key? key, required String message})
    : this._(key: key, message: message, builder: MesInlineBanner.info);

  const UserModuleFeedbackBanner.warning({Key? key, required String message})
    : this._(key: key, message: message, builder: MesInlineBanner.warning);

  const UserModuleFeedbackBanner.error({Key? key, required String message})
    : this._(key: key, message: message, builder: MesInlineBanner.error);

  const UserModuleFeedbackBanner.success({Key? key, required String message})
    : this._(key: key, message: message, builder: MesInlineBanner.success);

  final String message;
  final Widget Function({Key? key, required String message}) builder;

  @override
  Widget build(BuildContext context) {
    return builder(
      key: const ValueKey('user-module-feedback-banner'),
      message: message,
    );
  }
}
```

```dart
// frontend/lib/features/user/presentation/widgets/shared/user_module_status_chip.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/primitives/mes_status_chip.dart';

enum UserModuleStatusTone {
  online,
  offline,
  active,
  inactive,
  deleted,
  pending,
  approved,
  rejected,
}

class UserModuleStatusChip extends StatelessWidget {
  const UserModuleStatusChip({
    super.key,
    required this.tone,
    required this.label,
  });

  final UserModuleStatusTone tone;
  final String label;

  @override
  Widget build(BuildContext context) {
    return switch (tone) {
      UserModuleStatusTone.online => MesStatusChip.success(label: label),
      UserModuleStatusTone.active => MesStatusChip.success(label: label),
      UserModuleStatusTone.approved => MesStatusChip.success(label: label),
      UserModuleStatusTone.pending => MesStatusChip.warning(label: label),
      UserModuleStatusTone.offline => MesStatusChip.warning(label: label),
      UserModuleStatusTone.inactive => MesStatusChip.warning(label: label),
      UserModuleStatusTone.deleted => MesStatusChip.warning(label: label),
      UserModuleStatusTone.rejected => MesStatusChip.warning(label: label),
    };
  }
}
```

```dart
// frontend/lib/features/user/presentation/widgets/shared/user_module_filter_panel.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';

class UserModuleFilterPanel extends StatelessWidget {
  const UserModuleFilterPanel({
    super.key,
    required this.child,
    this.sectionKey,
  });

  final Widget child;
  final Key? sectionKey;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: sectionKey,
      child: MesFilterBar(child: child),
    );
  }
}
```

```dart
// frontend/lib/features/user/presentation/widgets/shared/user_module_table_shell.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';
import 'package:mes_client/core/ui/patterns/mes_table_section_header.dart';

class UserModuleTableShell extends StatelessWidget {
  const UserModuleTableShell({
    super.key,
    required this.title,
    required this.child,
    this.sectionKey,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Key? sectionKey;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<MesTokens>()?.spacing.md ?? 16.0;
    return KeyedSubtree(
      key: sectionKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MesTableSectionHeader(
            title: title,
            subtitle: subtitle,
            trailing: trailing,
          ),
          SizedBox(height: spacing),
          Expanded(child: child),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 重新运行共享件测试，确认用户模块共享展示层可用**

Run: `flutter test test/widgets/user_module_shared_widgets_test.dart`

Expected: PASS

- [ ] **Step 5: 提交共享展示层**

```bash
git add frontend/lib/features/user/presentation/widgets/shared/user_module_feedback_banner.dart frontend/lib/features/user/presentation/widgets/shared/user_module_status_chip.dart frontend/lib/features/user/presentation/widgets/shared/user_module_filter_panel.dart frontend/lib/features/user/presentation/widgets/shared/user_module_table_shell.dart frontend/test/widgets/user_module_shared_widgets_test.dart
git commit -m "新增用户模块共享展示层"
```

## 任务 3：迁移用户管理页到统一 CRUD 骨架

**Files:**
- Create: `frontend/lib/features/user/presentation/widgets/user_management_page_header.dart`
- Create: `frontend/lib/features/user/presentation/widgets/user_management_action_bar.dart`
- Create: `frontend/lib/features/user/presentation/widgets/user_management_filter_section.dart`
- Create: `frontend/lib/features/user/presentation/widgets/user_management_feedback_banner.dart`
- Create: `frontend/lib/features/user/presentation/widgets/user_management_table_section.dart`
- Modify: `frontend/lib/features/user/presentation/user_management_page.dart`
- Modify: `frontend/lib/features/user/presentation/widgets/user_data_table.dart`
- Modify: `frontend/test/widgets/user_management_page_test.dart`

- [ ] **Step 1: 先写失败测试，固定统一骨架、筛选区与页码回退行为**

```dart
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';

testWidgets('用户管理页接入 CRUD 骨架并在筛选变化后回到第一页', (tester) async {
  final userService = _FakeUserService(
    initialUsers: List<UserItem>.generate(
      12,
      (index) => _buildUser(
        id: index + 1,
        username: 'user_${index + 1}',
        roleCode: index.isEven ? 'operator' : 'production_admin',
        roleName: index.isEven ? '操作员' : '生产管理员',
        isActive: true,
      ),
    ),
  );
  final craftService = _FakeCraftService();

  await _pumpPage(
    tester,
    userService: userService,
    craftService: craftService,
  );

  expect(find.byType(MesCrudPageScaffold), findsOneWidget);
  expect(find.byKey(const ValueKey('user-management-filter-section')), findsOneWidget);
  expect(find.byKey(const ValueKey('user-management-table-section')), findsOneWidget);
  expect(find.byType(MesPaginationBar), findsOneWidget);

  await tester.tap(find.text('下一页'));
  await tester.pumpAndSettle();
  expect(find.text('第 2 / 2 页'), findsOneWidget);

  await tester.tap(find.byKey(const ValueKey('userToolbarStatusFilter')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('停用').last);
  await tester.pumpAndSettle();

  expect(find.text('第 1 / 1 页'), findsOneWidget);
});
```

- [ ] **Step 2: 运行用户管理页测试，确认新骨架断言尚未满足**

Run: `flutter test test/widgets/user_management_page_test.dart`

Expected: FAIL，断言里找不到 `MesCrudPageScaffold` 或 `user-management-filter-section`

- [ ] **Step 3: 实现用户管理页拆分与状态流收敛**

```dart
// frontend/lib/features/user/presentation/widgets/user_management_page_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/widgets/crud_page_header.dart';

class UserManagementPageHeader extends StatelessWidget {
  const UserManagementPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
  });

  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return CrudPageHeader(
      title: '用户管理',
      onRefresh: loading ? null : onRefresh,
    );
  }
}
```

```dart
// frontend/lib/features/user/presentation/widgets/user_management_action_bar.dart
import 'package:flutter/material.dart';

class UserManagementActionBar extends StatelessWidget {
  const UserManagementActionBar({
    super.key,
    required this.actions,
  });

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: actions,
    );
  }
}
```

```dart
// frontend/lib/features/user/presentation/widgets/user_management_filter_section.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_filter_panel.dart';
import 'package:mes_client/features/user/presentation/widgets/user_management_action_bar.dart';
import 'package:mes_client/features/user/presentation/widgets/user_filter_toolbar.dart';

class UserManagementFilterSection extends StatelessWidget {
  const UserManagementFilterSection({
    super.key,
    required this.keywordController,
    required this.filterRoleCode,
    required this.filterIsActive,
    required this.deletedScope,
    required this.roles,
    required this.onFilterRoleCodeChanged,
    required this.onFilterIsActiveChanged,
    required this.onFilterDeletedScopeChanged,
    required this.onSearch,
    required this.actions,
  });

  final TextEditingController keywordController;
  final String? filterRoleCode;
  final bool? filterIsActive;
  final String deletedScope;
  final List<RoleItem> roles;
  final ValueChanged<String?> onFilterRoleCodeChanged;
  final ValueChanged<bool?> onFilterIsActiveChanged;
  final ValueChanged<String> onFilterDeletedScopeChanged;
  final VoidCallback onSearch;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return UserModuleFilterPanel(
      sectionKey: const ValueKey('user-management-filter-section'),
      child: Column(
        children: [
          UserFilterToolbar(
            keywordController: keywordController,
            filterRoleCode: filterRoleCode,
            filterIsActive: filterIsActive,
            deletedScope: deletedScope,
            roles: roles,
            onFilterRoleCodeChanged: onFilterRoleCodeChanged,
            onFilterIsActiveChanged: onFilterIsActiveChanged,
            onFilterDeletedScopeChanged: onFilterDeletedScopeChanged,
            onSearch: onSearch,
            actions: const [],
          ),
          const SizedBox(height: 12),
          UserManagementActionBar(actions: actions),
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/features/user/presentation/widgets/user_management_feedback_banner.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_feedback_banner.dart';

class UserManagementFeedbackBanner extends StatelessWidget {
  const UserManagementFeedbackBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) {
      return const SizedBox.shrink();
    }
    return KeyedSubtree(
      key: const ValueKey('user-management-feedback-banner'),
      child: UserModuleFeedbackBanner.error(message: message),
    );
  }
}
```

```dart
// frontend/lib/features/user/presentation/widgets/user_management_table_section.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_table_shell.dart';
import 'package:mes_client/features/user/presentation/widgets/user_data_table.dart';

class UserManagementTableSection extends StatelessWidget {
  const UserManagementTableSection({
    super.key,
    required this.users,
    required this.loading,
    required this.emptyText,
    required this.canEditUser,
    required this.canToggleUser,
    required this.canResetPassword,
    required this.canDeleteUser,
    required this.canRestoreUser,
    required this.myUserId,
    required this.onAction,
  });

  final List<UserItem> users;
  final bool loading;
  final String emptyText;
  final bool canEditUser;
  final bool canToggleUser;
  final bool canResetPassword;
  final bool canDeleteUser;
  final bool canRestoreUser;
  final int? myUserId;
  final void Function(UserTableAction action, UserItem user) onAction;

  @override
  Widget build(BuildContext context) {
    return UserModuleTableShell(
      sectionKey: const ValueKey('user-management-table-section'),
      title: '用户列表',
      child: UserDataTable(
        users: users,
        loading: loading,
        emptyText: emptyText,
        canEditUser: canEditUser,
        canToggleUser: canToggleUser,
        canResetPassword: canResetPassword,
        canDeleteUser: canDeleteUser,
        canRestoreUser: canRestoreUser,
        myUserId: myUserId,
        onAction: onAction,
      ),
    );
  }
}
```

```dart
// frontend/lib/features/user/presentation/user_management_page.dart
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/widgets/simple_pagination_bar.dart';
import 'package:mes_client/features/user/presentation/widgets/user_management_action_bar.dart';
import 'package:mes_client/features/user/presentation/widgets/user_management_feedback_banner.dart';
import 'package:mes_client/features/user/presentation/widgets/user_management_filter_section.dart';
import 'package:mes_client/features/user/presentation/widgets/user_management_page_header.dart';
import 'package:mes_client/features/user/presentation/widgets/user_management_table_section.dart';

Future<void> _reloadCurrentPage() => _loadUsers(page: _userPage);

Future<void> _applyFiltersAndReload() => _loadUsers(page: 1);

Future<void> _handleActionSuccess() => _loadUsers(silent: true, page: _userPage);

Future<void> _confirmDeleteUser(UserItem user) async {
  await showConfirmDeleteUserDialog(
    context: context,
    userService: _userService,
    user: user,
    roleLabel: _roleLabelForUser(user.roleCode, user.roleName),
    stageLabel: _stageLabelForUser(user.stageId, user.stageName),
    onError: (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
      } else if (mounted) {
        setState(() => _message = '删除用户失败：${_errorMessage(error)}');
      }
    },
    onSuccess: (result) async {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatDeleteSuccessMessage(result))),
        );
      }
      await _handleActionSuccess();
    },
  );
}

@override
Widget build(BuildContext context) {
  return MesCrudPageScaffold(
    header: UserManagementPageHeader(
      loading: _loading,
      onRefresh: _refreshUsersFromHeader,
    ),
    filters: UserManagementFilterSection(
      keywordController: _keywordController,
      filterRoleCode: _filterRoleCode,
      filterIsActive: _filterIsActive,
      deletedScope: _deletedScope,
      roles: _roles,
      onFilterRoleCodeChanged: (value) {
        setState(() => _filterRoleCode = value);
        _applyFiltersAndReload();
      },
      onFilterIsActiveChanged: (value) {
        setState(() => _filterIsActive = value);
        _applyFiltersAndReload();
      },
      onFilterDeletedScopeChanged: (value) {
        setState(() => _deletedScope = value);
        _applyFiltersAndReload();
      },
      onSearch: _applyFiltersAndReload,
      actions: _buildToolbarButtons(),
    ),
    banner: _message.isEmpty ? null : UserManagementFeedbackBanner(message: _message),
    content: UserManagementTableSection(
      users: _users,
      loading: _loading,
      emptyText: _emptyListMessage,
      canEditUser: widget.canEditUser,
      canToggleUser: widget.canToggleUser,
      canResetPassword: widget.canResetPassword,
      canDeleteUser: widget.canDeleteUser,
      canRestoreUser: widget.canRestoreUser,
      myUserId: _myUserId,
      onAction: _handleUserAction,
    ),
    pagination: SimplePaginationBar(
      page: _userPage,
      totalPages: _userTotalPages,
      total: _total,
      loading: _loading,
      showTotal: false,
      onPrevious: () => _loadUsers(page: _userPage - 1),
      onNext: () => _loadUsers(page: _userPage + 1),
    ),
  );
}
```

```dart
// frontend/lib/features/user/presentation/widgets/user_data_table.dart
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_status_chip.dart';

DataCell(
  UserModuleStatusChip(
    tone: user.isOnline ? UserModuleStatusTone.online : UserModuleStatusTone.offline,
    label: user.isOnline ? '在线' : '离线',
  ),
),
DataCell(
  UserModuleStatusChip(
    tone: user.isDeleted
        ? UserModuleStatusTone.deleted
        : user.isActive
            ? UserModuleStatusTone.active
            : UserModuleStatusTone.inactive,
    label: user.isDeleted
        ? '已删除'
        : user.isActive
            ? '启用'
            : '停用',
  ),
),
```

- [ ] **Step 4: 重新运行用户管理页测试，确认骨架迁移与行为未回归**

Run: `flutter test test/widgets/user_management_page_test.dart`

Expected: PASS

- [ ] **Step 5: 提交用户管理页迁移**

```bash
git add frontend/lib/features/user/presentation/user_management_page.dart frontend/lib/features/user/presentation/widgets/user_management_page_header.dart frontend/lib/features/user/presentation/widgets/user_management_action_bar.dart frontend/lib/features/user/presentation/widgets/user_management_filter_section.dart frontend/lib/features/user/presentation/widgets/user_management_feedback_banner.dart frontend/lib/features/user/presentation/widgets/user_management_table_section.dart frontend/lib/features/user/presentation/widgets/user_data_table.dart frontend/test/widgets/user_management_page_test.dart
git commit -m "迁移用户管理页到统一CRUD骨架"
```

## 任务 4：迁移注册审批页到统一 CRUD 骨架

**Files:**
- Create: `frontend/lib/features/user/presentation/widgets/registration_approval_page_header.dart`
- Create: `frontend/lib/features/user/presentation/widgets/registration_approval_filter_section.dart`
- Create: `frontend/lib/features/user/presentation/widgets/registration_approval_feedback_banner.dart`
- Create: `frontend/lib/features/user/presentation/widgets/registration_approval_table_section.dart`
- Modify: `frontend/lib/features/user/presentation/registration_approval_page.dart`
- Modify: `frontend/test/widgets/registration_approval_page_test.dart`
- Modify: `frontend/test/widgets/user_page_test.dart`

- [ ] **Step 1: 先写失败测试，固定注册审批统一骨架和 route payload 提示**

```dart
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';

testWidgets('注册审批页接入 CRUD 骨架并保留 route payload 定位提示', (tester) async {
  final userService = _FakeApprovalUserService()
    ..listResponses = [
      [
        RegistrationRequestItem(
          id: 572,
          account: 'pending_572',
          status: 'pending',
          rejectedReason: null,
          reviewedByUserId: null,
          reviewedAt: null,
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
    ];
  final craftService = _FakeApprovalCraftService();

  tester.view.physicalSize = const Size(1920, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RegistrationApprovalPage(
          session: AppSession(baseUrl: 'http://test', accessToken: 'token'),
          onLogout: () {},
          canApprove: true,
          canReject: true,
          routePayloadJson: '{"request_id":572}',
          userService: userService,
          craftService: craftService,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byType(MesCrudPageScaffold), findsOneWidget);
  expect(find.byKey(const ValueKey('registration-approval-filter-section')), findsOneWidget);
  expect(find.byKey(const ValueKey('registration-approval-table-section')), findsOneWidget);
  expect(find.byType(MesPaginationBar), findsOneWidget);
  expect(find.textContaining('已定位注册申请 #572'), findsOneWidget);
});
```

- [ ] **Step 2: 运行注册审批页测试，确认统一骨架断言尚未满足**

Run: `flutter test test/widgets/registration_approval_page_test.dart`

Expected: FAIL，断言里找不到 `MesCrudPageScaffold` 或 `registration-approval-filter-section`

- [ ] **Step 3: 实现注册审批页拆分与状态流收敛**

```dart
// frontend/lib/features/user/presentation/widgets/registration_approval_page_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/widgets/crud_page_header.dart';

class RegistrationApprovalPageHeader extends StatelessWidget {
  const RegistrationApprovalPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
  });

  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return CrudPageHeader(
      title: '注册审批',
      onRefresh: loading ? null : onRefresh,
    );
  }
}
```

```dart
// frontend/lib/features/user/presentation/widgets/registration_approval_filter_section.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_filter_panel.dart';

class RegistrationApprovalFilterSection extends StatelessWidget {
  const RegistrationApprovalFilterSection({
    super.key,
    required this.statusFilter,
    required this.onChanged,
  });

  final String? statusFilter;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return UserModuleFilterPanel(
      sectionKey: const ValueKey('registration-approval-filter-section'),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<String?>(
              initialValue: statusFilter,
              decoration: const InputDecoration(
                labelText: '申请状态',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('全部')),
                DropdownMenuItem<String?>(value: 'pending', child: Text('待审批')),
                DropdownMenuItem<String?>(value: 'approved', child: Text('已通过')),
                DropdownMenuItem<String?>(value: 'rejected', child: Text('已驳回')),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/features/user/presentation/widgets/registration_approval_feedback_banner.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_feedback_banner.dart';

class RegistrationApprovalFeedbackBanner extends StatelessWidget {
  const RegistrationApprovalFeedbackBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) {
      return const SizedBox.shrink();
    }
    return KeyedSubtree(
      key: const ValueKey('registration-approval-feedback-banner'),
      child: UserModuleFeedbackBanner.info(message: message),
    );
  }
}
```

```dart
// frontend/lib/features/user/presentation/widgets/registration_approval_table_section.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_status_chip.dart';
import 'package:mes_client/features/user/presentation/widgets/shared/user_module_table_shell.dart';

class RegistrationApprovalTableSection extends StatelessWidget {
  const RegistrationApprovalTableSection({
    super.key,
    required this.items,
    required this.loading,
    required this.emptyText,
    required this.canApprove,
    required this.canReject,
    required this.onApprove,
    required this.onReject,
    required this.formatTime,
  });

  final List<RegistrationRequestItem> items;
  final bool loading;
  final String emptyText;
  final bool canApprove;
  final bool canReject;
  final void Function(RegistrationRequestItem item) onApprove;
  final void Function(RegistrationRequestItem item) onReject;
  final String Function(DateTime value) formatTime;

  @override
  Widget build(BuildContext context) {
    return UserModuleTableShell(
      sectionKey: const ValueKey('registration-approval-table-section'),
      title: '申请列表',
      child: CrudListTableSection(
        loading: loading,
        isEmpty: items.isEmpty,
        emptyText: emptyText,
        enableUnifiedHeaderStyle: true,
        child: DataTable(
          columnSpacing: 16,
          columns: [
            UnifiedListTableHeaderStyle.column(context, '用户名'),
            UnifiedListTableHeaderStyle.column(context, '申请时间'),
            UnifiedListTableHeaderStyle.column(context, '申请状态'),
            UnifiedListTableHeaderStyle.column(context, '驳回原因'),
            UnifiedListTableHeaderStyle.column(context, '操作'),
          ],
          rows: items.map((item) {
            return DataRow(
              cells: [
                DataCell(Text(item.account)),
                DataCell(Text(formatTime(item.createdAt))),
                DataCell(
                  UserModuleStatusChip(
                    tone: switch (item.status) {
                      'approved' => UserModuleStatusTone.approved,
                      'rejected' => UserModuleStatusTone.rejected,
                      _ => UserModuleStatusTone.pending,
                    },
                    label: switch (item.status) {
                      'approved' => '已通过',
                      'rejected' => '已驳回',
                      _ => '待审批',
                    },
                  ),
                ),
                DataCell(Text(item.rejectedReason ?? '-')),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.status == 'pending' && canApprove)
                        TextButton(onPressed: () => onApprove(item), child: const Text('通过')),
                      if (item.status == 'pending' && canReject)
                        TextButton(onPressed: () => onReject(item), child: const Text('驳回')),
                      if (item.status != 'pending' || (!canApprove && !canReject))
                        const Text('-'),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
```

```dart
// frontend/lib/features/user/presentation/registration_approval_page.dart
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/widgets/simple_pagination_bar.dart';
import 'package:mes_client/features/user/presentation/widgets/registration_approval_feedback_banner.dart';
import 'package:mes_client/features/user/presentation/widgets/registration_approval_filter_section.dart';
import 'package:mes_client/features/user/presentation/widgets/registration_approval_page_header.dart';
import 'package:mes_client/features/user/presentation/widgets/registration_approval_table_section.dart';

Future<void> _reloadCurrentPage() => _loadRequests(page: _requestPage);

Future<void> _applyStatusFilterAndReload(String? value) async {
  setState(() => _statusFilter = value);
  await _loadRequests(page: 1);
}

Future<void> _handleActionSuccess() => _reloadCurrentPage();

void _consumeRoutePayload(String? rawJson) {
  final normalized = (rawJson ?? '').trim();
  if (normalized.isEmpty || normalized == _lastHandledRoutePayloadJson) {
    return;
  }
  _lastHandledRoutePayloadJson = normalized;
  try {
    final payload = jsonDecode(normalized);
    if (payload is! Map<String, dynamic>) {
      return;
    }
    final requestId = _parsePositiveInt(payload['request_id']);
    if (requestId == null) {
      return;
    }
    setState(() {
      _jumpRequestId = requestId;
      _message = '已收到目标注册申请 #$requestId 的跳转请求，正在定位。';
    });
    final shouldReloadAllStatuses = _statusFilter != null;
    if (shouldReloadAllStatuses) {
      _applyStatusFilterAndReload(null);
      return;
    }
    _applyJumpTargetHint();
  } catch (_) {
    return;
  }
}

Future<bool> _approveRequest({
  required RegistrationRequestItem item,
  required String account,
  required String roleCode,
  String? password,
  int? stageId,
}) async {
  try {
    await _userService.approveRegistrationRequest(
      requestId: item.id,
      account: account,
      roleCode: roleCode,
      password: password,
      stageId: stageId,
    );
    if (!mounted) {
      return false;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已通过账号 $account 的注册申请。')),
    );
    await _handleActionSuccess();
    return true;
  } catch (error) {
    if (!mounted) {
      return false;
    }
    if (_isUnauthorized(error)) {
      widget.onLogout();
      return false;
    }
    setState(() => _message = '审批通过失败：${_errorMessage(error)}');
    return false;
  }
}

Future<void> _rejectRequest(RegistrationRequestItem item, {String? reason}) async {
  try {
    await _userService.rejectRegistrationRequest(
      requestId: item.id,
      reason: reason,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已驳回账号 ${item.account} 的注册申请。')),
    );
    await _handleActionSuccess();
  } catch (error) {
    if (!mounted) {
      return;
    }
    if (_isUnauthorized(error)) {
      widget.onLogout();
      return;
    }
    setState(() => _message = '驳回申请失败：${_errorMessage(error)}');
  }
}

@override
Widget build(BuildContext context) {
  return MesCrudPageScaffold(
    header: RegistrationApprovalPageHeader(
      loading: _loading,
      onRefresh: () => _loadInitialData(page: _requestPage),
    ),
    filters: RegistrationApprovalFilterSection(
      statusFilter: _statusFilter,
      onChanged: (value) {
        _applyStatusFilterAndReload(value);
      },
    ),
    banner: _message.isEmpty ? null : RegistrationApprovalFeedbackBanner(message: _message),
    content: RegistrationApprovalTableSection(
      items: _items,
      loading: _loading,
      emptyText: _statusFilter == null ? '暂无注册申请记录' : '当前状态下暂无注册申请记录',
      canApprove: widget.canApprove,
      canReject: widget.canReject,
      onApprove: _openApproveDialog,
      onReject: _confirmReject,
      formatTime: _formatTime,
    ),
    pagination: SimplePaginationBar(
      page: _requestPage,
      totalPages: _requestTotalPages,
      total: _total,
      loading: _loading,
      onPrevious: () => _loadRequests(page: _requestPage - 1),
      onNext: () => _loadRequests(page: _requestPage + 1),
    ),
  );
}
```

```dart
// frontend/test/widgets/user_page_test.dart
testWidgets('用户页在第二波迁移后仍保持用户管理与注册审批页签装配', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: UserPage(
          session: AppSession(baseUrl: 'http://test', accessToken: 'token'),
          onLogout: () {},
          visibleTabCodes: const ['user_management', 'registration_approval'],
          capabilityCodes: const <String>{},
          preferredTabCode: 'user_management',
          tabChildBuilder: (tabCode) => Center(child: Text('tab:$tabCode')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('用户管理'), findsOneWidget);
  expect(find.text('注册审批'), findsOneWidget);
  expect(find.text('tab:user_management'), findsOneWidget);
});
```

- [ ] **Step 4: 重新运行注册审批与用户页回归测试**

Run: `flutter test test/widgets/registration_approval_page_test.dart test/widgets/user_page_test.dart`

Expected: PASS

- [ ] **Step 5: 提交注册审批页迁移**

```bash
git add frontend/lib/features/user/presentation/registration_approval_page.dart frontend/lib/features/user/presentation/widgets/registration_approval_page_header.dart frontend/lib/features/user/presentation/widgets/registration_approval_filter_section.dart frontend/lib/features/user/presentation/widgets/registration_approval_feedback_banner.dart frontend/lib/features/user/presentation/widgets/registration_approval_table_section.dart frontend/test/widgets/registration_approval_page_test.dart frontend/test/widgets/user_page_test.dart
git commit -m "迁移注册审批页到统一CRUD骨架"
```

## 任务 5：补齐 integration、evidence 与最终收口

**Files:**
- Create: `frontend/integration_test/user_module_flow_test.dart`
- Create: `evidence/2026-04-20_用户模块UI第二波迁移实施.md`

- [ ] **Step 1: 先写失败的 integration 观察点，固定用户模块统一锚点**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/features/user/presentation/registration_approval_page.dart';
import 'package:mes_client/features/user/presentation/user_management_page.dart';
import 'package:mes_client/features/user/services/user_service.dart';

class _IntegrationUserService extends UserService {
  _IntegrationUserService() : super(AppSession(baseUrl: '', accessToken: 'token'));

  @override
  Future<UserListResult> listUsers({
    required int page,
    required int pageSize,
    String? keyword,
    String? roleCode,
    int? stageId,
    bool? isOnline,
    bool? isActive,
    String deletedScope = 'active',
    bool includeDeleted = false,
  }) async {
    return UserListResult(
      total: 1,
      items: [
        UserItem(
          id: 1,
          username: 'integration_user',
          fullName: 'integration_user',
          remark: null,
          isOnline: true,
          isActive: true,
          isDeleted: false,
          mustChangePassword: false,
          lastSeenAt: null,
          stageId: null,
          stageName: null,
          roleCode: 'production_admin',
          roleName: '生产管理员',
          lastLoginAt: null,
          lastLoginIp: null,
          passwordChangedAt: null,
          createdAt: DateTime.parse('2026-04-20T08:00:00Z'),
          updatedAt: DateTime.parse('2026-04-20T08:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<RoleListResult> listAllRoles({String? keyword}) async {
    return RoleListResult(
      total: 1,
      items: [
        RoleItem(
          id: 1,
          code: 'production_admin',
          name: '生产管理员',
          description: null,
          roleType: 'builtin',
          isBuiltin: true,
          isEnabled: true,
          userCount: 1,
          createdAt: DateTime.parse('2026-04-20T08:00:00Z'),
          updatedAt: DateTime.parse('2026-04-20T08:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<ProfileResult> getMyProfile() async {
    return ProfileResult(
      id: 99,
      username: 'admin',
      fullName: '管理员',
      roleCode: 'system_admin',
      roleName: '系统管理员',
      stageId: null,
      stageName: null,
      isActive: true,
      createdAt: DateTime.parse('2026-04-20T08:00:00Z'),
      lastLoginAt: null,
      lastLoginIp: null,
      passwordChangedAt: null,
    );
  }

  @override
  Future<Set<int>> listOnlineUserIds({required List<int> userIds}) async {
    return {1};
  }

  @override
  Future<RegistrationRequestListResult> listRegistrationRequests({
    required int page,
    required int pageSize,
    String? keyword,
    String? status,
  }) async {
    return RegistrationRequestListResult(
      total: 1,
      items: [
        RegistrationRequestItem(
          id: 572,
          account: 'pending_572',
          status: 'pending',
          rejectedReason: null,
          reviewedByUserId: null,
          reviewedAt: null,
          createdAt: DateTime.parse('2026-04-20T08:00:00Z'),
        ),
      ],
    );
  }
}

class _IntegrationCraftService extends CraftService {
  _IntegrationCraftService() : super(AppSession(baseUrl: '', accessToken: 'token'));

  @override
  Future<CraftStageListResult> listStages({
    int page = 1,
    int pageSize = 10,
    String? keyword,
    bool? enabled,
  }) async {
    return CraftStageListResult(total: 1, items: const []);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('用户管理页展示统一页头、筛选区与列表区锚点', (tester) async {
    final userService = _IntegrationUserService();
    final craftService = _IntegrationCraftService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LegacyLegacyUserManagementPage(
            session: AppSession(baseUrl: '', accessToken: 'token'),
            onLogout: () {},
            canCreateUser: true,
            canEditUser: true,
            canToggleUser: true,
            canResetPassword: true,
            canDeleteUser: true,
            canExport: true,
            userService: userService,
            craftService: craftService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('用户管理'), findsOneWidget);
    expect(find.byKey(const ValueKey('user-management-filter-section')), findsOneWidget);
    expect(find.byKey(const ValueKey('user-management-table-section')), findsOneWidget);
  });

  testWidgets('注册审批页展示统一页头、筛选区和 route payload 提示', (tester) async {
    final userService = _IntegrationUserService();
    final craftService = _IntegrationCraftService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RegistrationApprovalPage(
            session: AppSession(baseUrl: '', accessToken: 'token'),
            onLogout: () {},
            canApprove: true,
            canReject: true,
            routePayloadJson: '{"request_id":572}',
            userService: userService,
            craftService: craftService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('注册审批'), findsOneWidget);
    expect(find.byKey(const ValueKey('registration-approval-filter-section')), findsOneWidget);
    expect(find.byKey(const ValueKey('registration-approval-table-section')), findsOneWidget);
    expect(find.textContaining('已定位注册申请 #572'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行 analyze、widget、integration 和既有用户模块回归**

Run: `flutter analyze`

Expected: `No issues found!`

Run: `flutter test test/widgets/ui/mes_patterns_test.dart test/widgets/user_module_shared_widgets_test.dart test/widgets/user_management_page_test.dart test/widgets/registration_approval_page_test.dart test/widgets/user_page_test.dart`

Expected: PASS

Run: `flutter test -d windows integration_test/user_module_flow_test.dart`

Expected: PASS

Run: `flutter test -d windows integration_test/login_flow_test.dart --plain-name "登录后进入用户管理并通过启停弹窗停用在线用户"`

Expected: PASS

Run: `flutter test -d windows integration_test/home_shell_flow_test.dart --plain-name "登录后进入主壳首页并可从工作台快速跳转到用户模块"`

Expected: PASS

- [ ] **Step 3: 更新实施 evidence，记录拆分、验证命令与结果**

```md
# 任务日志：用户模块 UI 第二波迁移实施

- 日期：2026-04-20
- 执行人：Codex
- 当前状态：已完成

## 1. 输入来源
- 用户指令：按已批准 spec 为用户模块第二波 UI 迁移编写计划并执行
- 设计规格：`docs/superpowers/specs/2026-04-20-user-module-ui-second-wave-design.md`
- 实施计划：`docs/superpowers/plans/2026-04-20-user-module-ui-second-wave-implementation.md`

## 2. 实施分段
- 任务 1：补齐 CRUD 模式骨架层
- 任务 2：建立用户模块共享展示层
- 任务 3：迁移用户管理页
- 任务 4：迁移注册审批页
- 任务 5：补齐 integration、evidence 与最终收口

## 3. 验证结果
- flutter analyze：通过
- widget tests：通过
- integration_test/user_module_flow_test.dart：通过
- integration_test/login_flow_test.dart --plain-name "登录后进入用户管理并通过启停弹窗停用在线用户"：通过
- integration_test/home_shell_flow_test.dart --plain-name "登录后进入主壳首页并可从工作台快速跳转到用户模块"：通过

## 4. 迁移说明
- 无迁移，直接替换
```

- [ ] **Step 4: 提交最终验证与留痕**

```bash
git add frontend/integration_test/user_module_flow_test.dart evidence/2026-04-20_用户模块UI第二波迁移实施.md
git commit -m "补齐用户模块第二波迁移验证"
```
