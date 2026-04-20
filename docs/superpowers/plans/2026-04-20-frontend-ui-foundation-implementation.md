# 前端 UI 基础件体系 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 Flutter 前端中落地“design tokens + 页面骨架组件 + 业务组件组装”体系，先建立 `core/ui` 基础层，再把设置页、首页、消息中心迁移为统一 UI 试点页面。

**Architecture:** 先把主题、颜色语义、间距、圆角、文本层级收敛到 `core/ui/foundation/`，再在 `core/ui/primitives/` 和 `core/ui/patterns/` 建立页面通用骨架。现有 `core/widgets` 里的 CRUD 统一件不直接删除，而是改造成对新模式件的薄包装；试点页面按“设置页 -> 首页 -> 消息中心”顺序迁移，其中消息中心同时完成页面拆分，避免继续膨胀单文件。

**Tech Stack:** Flutter、Dart、Material 3、`ThemeExtension`、`flutter_test`、`integration_test`

---

> Flutter 命令默认在 `frontend/` 目录执行；`git`、`evidence` 与计划文档操作默认在仓库根目录执行。  
> 本计划遵循“无迁移，直接替换”，但仍保留现有 `core/widgets` 文件作为新基础件的薄包装，避免试点迁移阶段出现双套样式系统并存。

## 文件结构

### 新增文件

- `frontend/lib/core/ui/foundation/mes_colors.dart`
  - 定义颜色语义 token
- `frontend/lib/core/ui/foundation/mes_spacing.dart`
  - 定义统一间距档位
- `frontend/lib/core/ui/foundation/mes_radius.dart`
  - 定义统一圆角档位
- `frontend/lib/core/ui/foundation/mes_typography.dart`
  - 定义页面标题、区块标题、正文、指标值等文本层级
- `frontend/lib/core/ui/foundation/mes_tokens.dart`
  - 汇总 `MesColors / MesSpacing / MesRadius / MesTypography`
- `frontend/lib/core/ui/foundation/mes_theme.dart`
  - 暴露 `buildMesTheme()`，把 token 接入 Material theme
- `frontend/lib/core/ui/primitives/mes_surface.dart`
  - 统一卡片、容器和表面层级
- `frontend/lib/core/ui/primitives/mes_gap.dart`
  - 统一垂直和水平间距节点
- `frontend/lib/core/ui/primitives/mes_status_chip.dart`
  - 统一状态小标签
- `frontend/lib/core/ui/primitives/mes_info_row.dart`
  - 统一信息行
- `frontend/lib/core/ui/patterns/mes_page_header.dart`
  - 统一页面头部
- `frontend/lib/core/ui/patterns/mes_section_card.dart`
  - 统一区块容器
- `frontend/lib/core/ui/patterns/mes_toolbar.dart`
  - 统一操作条
- `frontend/lib/core/ui/patterns/mes_filter_bar.dart`
  - 统一筛选区域
- `frontend/lib/core/ui/patterns/mes_empty_state.dart`
  - 统一空态
- `frontend/lib/core/ui/patterns/mes_error_state.dart`
  - 统一错态
- `frontend/lib/core/ui/patterns/mes_pagination_bar.dart`
  - 统一分页区
- `frontend/lib/core/ui/patterns/mes_metric_card.dart`
  - 统一指标卡
- `frontend/lib/core/ui/patterns/mes_detail_panel.dart`
  - 统一详情侧栏 / 说明区
- `frontend/lib/features/settings/presentation/widgets/software_settings_page_header.dart`
  - 设置页专用页头
- `frontend/lib/features/settings/presentation/widgets/software_settings_content_sections.dart`
  - 设置页“外观 / 布局偏好”两块业务 section
- `frontend/lib/features/message/presentation/widgets/message_center_header.dart`
  - 消息中心页头与主操作区
- `frontend/lib/features/message/presentation/widgets/message_center_overview_section.dart`
  - 消息概览指标区
- `frontend/lib/features/message/presentation/widgets/message_center_filter_section.dart`
  - 消息中心筛选区
- `frontend/lib/features/message/presentation/widgets/message_center_list_section.dart`
  - 消息列表区与分页区
- `frontend/lib/features/message/presentation/widgets/message_center_preview_panel.dart`
  - 消息详情预览区
- `frontend/test/widgets/ui/mes_theme_test.dart`
  - 覆盖主题 token 注入与基础样式映射
- `frontend/test/widgets/ui/mes_primitives_test.dart`
  - 覆盖 primitives 的视觉约束
- `frontend/test/widgets/ui/mes_patterns_test.dart`
  - 覆盖 patterns 的骨架能力
- `frontend/integration_test/message_center_flow_test.dart`
  - 覆盖消息中心试点页的桌面主流程
- `evidence/2026-04-20_前端UI基础件体系实施.md`
  - 实施阶段 evidence 主日志

### 修改文件

- `frontend/lib/main.dart`
  - 使用 `buildMesTheme()` 替换内联主题构造
- `frontend/lib/core/widgets/crud_page_header.dart`
  - 改为 `MesPageHeader` 薄包装
- `frontend/lib/core/widgets/crud_list_table_section.dart`
  - 改为 `MesSectionCard + MesEmptyState / MesErrorState` 风格薄包装
- `frontend/lib/core/widgets/simple_pagination_bar.dart`
  - 改为 `MesPaginationBar` 薄包装
- `frontend/lib/features/settings/presentation/software_settings_page.dart`
  - 使用新基础件与拆分后的 section widgets
- `frontend/lib/features/settings/presentation/widgets/software_settings_preview_card.dart`
  - 使用 `MesSurface` 和 token
- `frontend/lib/features/settings/presentation/widgets/software_time_sync_section.dart`
  - 使用 `MesSectionCard`、`MesStatusChip`
- `frontend/lib/features/shell/presentation/home_page.dart`
  - 使用统一页面外间距与 section 组合
- `frontend/lib/features/shell/presentation/widgets/home_dashboard_header.dart`
  - 改为 `MesPageHeader`
- `frontend/lib/features/shell/presentation/widgets/home_dashboard_todo_card.dart`
  - 改为 `MesSectionCard`
- `frontend/lib/features/shell/presentation/widgets/home_dashboard_risk_card.dart`
  - 改为 `MesSectionCard + MesMetricCard`
- `frontend/lib/features/shell/presentation/widgets/home_dashboard_kpi_card.dart`
  - 改为 `MesSectionCard + MesMetricCard`
- `frontend/lib/features/message/presentation/message_center_page.dart`
  - 只负责状态和事件编排，UI 拆到模块 widgets
- `frontend/test/widgets/crud_page_header_test.dart`
  - 继续验证旧入口行为不回归
- `frontend/test/widgets/crud_list_table_section_test.dart`
  - 继续验证旧入口行为不回归
- `frontend/test/widgets/simple_pagination_bar_test.dart`
  - 继续验证旧入口行为不回归
- `frontend/test/widgets/software_settings_page_test.dart`
  - 验证设置页已使用新骨架
- `frontend/test/widgets/home_page_test.dart`
  - 验证首页试点页的新骨架
- `frontend/test/widgets/message_center_page_test.dart`
  - 验证消息中心拆分后行为不回归
- `frontend/integration_test/software_settings_flow_test.dart`
  - 验证设置页试点在桌面流中可用
- `frontend/integration_test/home_dashboard_flow_test.dart`
  - 验证首页试点在桌面流中可用
- `frontend/integration_test/home_shell_flow_test.dart`
  - 验证壳层进入设置页和首页后无回归

## 任务 1：建立 foundation 主题层

**Files:**
- Create: `frontend/lib/core/ui/foundation/mes_colors.dart`
- Create: `frontend/lib/core/ui/foundation/mes_spacing.dart`
- Create: `frontend/lib/core/ui/foundation/mes_radius.dart`
- Create: `frontend/lib/core/ui/foundation/mes_typography.dart`
- Create: `frontend/lib/core/ui/foundation/mes_tokens.dart`
- Create: `frontend/lib/core/ui/foundation/mes_theme.dart`
- Modify: `frontend/lib/main.dart`
- Test: `frontend/test/widgets/ui/mes_theme_test.dart`

- [ ] **Step 1: 先写失败测试，固定 theme token 注入和语义样式映射**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';

class _ThemeProbe extends StatelessWidget {
  const _ThemeProbe();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MesTokens>()!;
    return Column(
      children: [
        Text(
          'spacing:${tokens.spacing.md}',
          style: tokens.typography.body,
        ),
        Card(
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.md),
            child: Text(
              'surface',
              style: tokens.typography.cardTitle,
            ),
          ),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('buildMesTheme 注入 MesTokens 并统一卡片外观', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: const Scaffold(body: _ThemeProbe()),
      ),
    );

    final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
    final tokens = theme.extension<MesTokens>();
    expect(tokens, isNotNull);
    expect(tokens!.spacing.md, 16);
    expect(tokens.radius.md, 16);

    final card = tester.widget<Card>(find.byType(Card));
    expect(card.margin, EdgeInsets.zero);
    expect(find.text('spacing:16.0'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行 theme 测试，确认 token 层尚未落地**

Run: `flutter test test/widgets/ui/mes_theme_test.dart`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Undefined name 'buildMesTheme'`

- [ ] **Step 3: 新增 foundation 文件并接入 `main.dart`**

```dart
// frontend/lib/core/ui/foundation/mes_spacing.dart
import 'package:flutter/widgets.dart';

@immutable
class MesSpacing {
  const MesSpacing({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;

  static const MesSpacing comfortable = MesSpacing(
    xs: 8,
    sm: 12,
    md: 16,
    lg: 20,
    xl: 24,
  );
}
```

```dart
// frontend/lib/core/ui/foundation/mes_radius.dart
import 'package:flutter/widgets.dart';

@immutable
class MesRadius {
  const MesRadius({
    required this.sm,
    required this.md,
    required this.lg,
  });

  final BorderRadius sm;
  final BorderRadius md;
  final BorderRadius lg;

  static const MesRadius standard = MesRadius(
    sm: BorderRadius.all(Radius.circular(10)),
    md: BorderRadius.all(Radius.circular(16)),
    lg: BorderRadius.all(Radius.circular(24)),
  );
}
```

```dart
// frontend/lib/core/ui/foundation/mes_colors.dart
import 'package:flutter/material.dart';

@immutable
class MesColors {
  const MesColors({
    required this.background,
    required this.surface,
    required this.surfaceSubtle,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  final Color background;
  final Color surface;
  final Color surfaceSubtle;
  final Color surfaceRaised;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  factory MesColors.fromScheme(ColorScheme scheme) {
    return MesColors(
      background: scheme.surface,
      surface: scheme.surfaceContainerLow,
      surfaceSubtle: scheme.surfaceContainerLowest,
      surfaceRaised: scheme.surfaceContainerHigh,
      border: scheme.outlineVariant,
      borderStrong: scheme.outline,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      success: const Color(0xFF1B8A5A),
      warning: const Color(0xFFB97100),
      danger: scheme.error,
      info: scheme.primary,
    );
  }
}
```

```dart
// frontend/lib/core/ui/foundation/mes_typography.dart
import 'package:flutter/material.dart';

@immutable
class MesTypography {
  const MesTypography({
    required this.pageTitle,
    required this.sectionTitle,
    required this.cardTitle,
    required this.body,
    required this.bodyStrong,
    required this.caption,
    required this.metric,
  });

  final TextStyle pageTitle;
  final TextStyle sectionTitle;
  final TextStyle cardTitle;
  final TextStyle body;
  final TextStyle bodyStrong;
  final TextStyle caption;
  final TextStyle metric;

  factory MesTypography.fromTextTheme(TextTheme textTheme) {
    return MesTypography(
      pageTitle: textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w700),
      sectionTitle: textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w700),
      cardTitle: textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600),
      body: textTheme.bodyMedium!,
      bodyStrong: textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
      caption: textTheme.bodySmall!,
      metric: textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
```

```dart
// frontend/lib/core/ui/foundation/mes_tokens.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_colors.dart';
import 'package:mes_client/core/ui/foundation/mes_radius.dart';
import 'package:mes_client/core/ui/foundation/mes_spacing.dart';
import 'package:mes_client/core/ui/foundation/mes_typography.dart';

@immutable
class MesTokens extends ThemeExtension<MesTokens> {
  const MesTokens({
    required this.colors,
    required this.spacing,
    required this.radius,
    required this.typography,
  });

  final MesColors colors;
  final MesSpacing spacing;
  final MesRadius radius;
  final MesTypography typography;

  factory MesTokens.fromTheme(ThemeData theme) {
    return MesTokens(
      colors: MesColors.fromScheme(theme.colorScheme),
      spacing: MesSpacing.comfortable,
      radius: MesRadius.standard,
      typography: MesTypography.fromTextTheme(theme.textTheme),
    );
  }

  @override
  MesTokens copyWith({
    MesColors? colors,
    MesSpacing? spacing,
    MesRadius? radius,
    MesTypography? typography,
  }) {
    return MesTokens(
      colors: colors ?? this.colors,
      spacing: spacing ?? this.spacing,
      radius: radius ?? this.radius,
      typography: typography ?? this.typography,
    );
  }

  @override
  MesTokens lerp(ThemeExtension<MesTokens>? other, double t) {
    return t < 0.5 || other == null ? this : other;
  }
}
```

```dart
// frontend/lib/core/ui/foundation/mes_theme.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';

ThemeData buildMesTheme({
  required Brightness brightness,
  required VisualDensity visualDensity,
}) {
  final base = ThemeData(
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF006A67),
      brightness: brightness,
    ),
    useMaterial3: true,
    visualDensity: visualDensity,
    fontFamily: 'Microsoft YaHei',
    fontFamilyFallback: const [
      '微软雅黑',
      'Microsoft YaHei',
      'PingFang SC',
      'Noto Sans CJK SC',
      'sans-serif',
    ],
  );
  final tokens = MesTokens.fromTheme(base);
  return base.copyWith(
    extensions: <ThemeExtension<dynamic>>[tokens],
    scaffoldBackgroundColor: tokens.colors.background,
    cardTheme: CardThemeData(
      margin: EdgeInsets.zero,
      color: tokens.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: tokens.radius.md),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.colors.surfaceSubtle,
      border: OutlineInputBorder(
        borderRadius: tokens.radius.sm,
        borderSide: BorderSide(color: tokens.colors.border),
      ),
    ),
  );
}
```

```dart
// frontend/lib/main.dart
import 'package:mes_client/core/ui/foundation/mes_theme.dart';

theme: buildMesTheme(
  brightness: Brightness.light,
  visualDensity: softwareSettingsController.visualDensity,
),
darkTheme: buildMesTheme(
  brightness: Brightness.dark,
  visualDensity: softwareSettingsController.visualDensity,
),
```

- [ ] **Step 4: 重新运行 theme 测试，确认 foundation 已接入**

Run: `flutter test test/widgets/ui/mes_theme_test.dart`

Expected: PASS，显示 `1 passed`

- [ ] **Step 5: 提交 foundation 主题层**

```bash
git add frontend/lib/core/ui/foundation frontend/lib/main.dart frontend/test/widgets/ui/mes_theme_test.dart
git commit -m "建立前端UI主题基础层"
```

## 任务 2：建立 primitives 基础件层

**Files:**
- Create: `frontend/lib/core/ui/primitives/mes_surface.dart`
- Create: `frontend/lib/core/ui/primitives/mes_gap.dart`
- Create: `frontend/lib/core/ui/primitives/mes_status_chip.dart`
- Create: `frontend/lib/core/ui/primitives/mes_info_row.dart`
- Test: `frontend/test/widgets/ui/mes_primitives_test.dart`

- [ ] **Step 1: 先写失败测试，固定 surface、gap 和状态 chip 的视觉约束**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/core/ui/primitives/mes_gap.dart';
import 'package:mes_client/core/ui/primitives/mes_status_chip.dart';
import 'package:mes_client/core/ui/primitives/mes_surface.dart';

void main() {
  testWidgets('MesSurface 使用统一圆角与内边距', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: const Scaffold(
          body: MesSurface(
            padding: EdgeInsets.all(16),
            child: Text('surface-body'),
          ),
        ),
      ),
    );

    expect(find.text('surface-body'), findsOneWidget);
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(MesSurface),
        matching: find.byType(Container),
      ).first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(16));
  });

  testWidgets('MesStatusChip 渲染状态文案', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: const Scaffold(
          body: Row(
            children: [
              MesStatusChip.success(label: '已启用'),
              MesGap.horizontal(12),
              MesStatusChip.warning(label: '待确认'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('已启用'), findsOneWidget);
    expect(find.text('待确认'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行 primitives 测试，确认基础件尚不存在**

Run: `flutter test test/widgets/ui/mes_primitives_test.dart`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Undefined class 'MesSurface'`

- [ ] **Step 3: 实现 primitives 文件**

```dart
// frontend/lib/core/ui/primitives/mes_surface.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';

enum MesSurfaceTone { normal, subtle, raised }

class MesSurface extends StatelessWidget {
  const MesSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.tone = MesSurfaceTone.normal,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final MesSurfaceTone tone;
  final BorderSide? border;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MesTokens>()!;
    final background = switch (tone) {
      MesSurfaceTone.normal => tokens.colors.surface,
      MesSurfaceTone.subtle => tokens.colors.surfaceSubtle,
      MesSurfaceTone.raised => tokens.colors.surfaceRaised,
    };
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: tokens.radius.md,
        border: Border.fromBorderSide(
          border ?? BorderSide(color: tokens.colors.border),
        ),
      ),
      child: child,
    );
  }
}
```

```dart
// frontend/lib/core/ui/primitives/mes_gap.dart
import 'package:flutter/widgets.dart';

class MesGap extends SizedBox {
  const MesGap.vertical(double value, {super.key}) : super(height: value);
  const MesGap.horizontal(double value, {super.key}) : super(width: value);
}
```

```dart
// frontend/lib/core/ui/primitives/mes_status_chip.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';

class MesStatusChip extends StatelessWidget {
  const MesStatusChip._({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  factory MesStatusChip.success({Key? key, required String label}) {
    return MesStatusChip._(
      key: key,
      label: label,
      backgroundColor: const Color(0xFFE4F5EC),
      foregroundColor: const Color(0xFF1B8A5A),
    );
  }

  factory MesStatusChip.warning({Key? key, required String label}) {
    return MesStatusChip._(
      key: key,
      label: label,
      backgroundColor: const Color(0xFFFFF1D6),
      foregroundColor: const Color(0xFFB97100),
    );
  }

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MesTokens>()!;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.sm,
        vertical: tokens.spacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: tokens.radius.lg,
      ),
      child: Text(
        label,
        style: tokens.typography.caption.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
```

```dart
// frontend/lib/core/ui/primitives/mes_info_row.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';

class MesInfoRow extends StatelessWidget {
  const MesInfoRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MesTokens>()!;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: tokens.typography.caption.copyWith(
                color: tokens.colors.textSecondary,
              ),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 重新运行 primitives 测试，确认基础件可用**

Run: `flutter test test/widgets/ui/mes_primitives_test.dart`

Expected: PASS，显示 `2 passed`

- [ ] **Step 5: 提交 primitives 基础件层**

```bash
git add frontend/lib/core/ui/primitives frontend/test/widgets/ui/mes_primitives_test.dart
git commit -m "新增前端UI基础件层"
```

## 任务 3：建立 patterns 页面骨架层，并改造旧 shared widgets 为薄包装

**Files:**
- Create: `frontend/lib/core/ui/patterns/mes_page_header.dart`
- Create: `frontend/lib/core/ui/patterns/mes_section_card.dart`
- Create: `frontend/lib/core/ui/patterns/mes_toolbar.dart`
- Create: `frontend/lib/core/ui/patterns/mes_filter_bar.dart`
- Create: `frontend/lib/core/ui/patterns/mes_empty_state.dart`
- Create: `frontend/lib/core/ui/patterns/mes_error_state.dart`
- Create: `frontend/lib/core/ui/patterns/mes_pagination_bar.dart`
- Create: `frontend/lib/core/ui/patterns/mes_metric_card.dart`
- Create: `frontend/lib/core/ui/patterns/mes_detail_panel.dart`
- Modify: `frontend/lib/core/widgets/crud_page_header.dart`
- Modify: `frontend/lib/core/widgets/crud_list_table_section.dart`
- Modify: `frontend/lib/core/widgets/simple_pagination_bar.dart`
- Test: `frontend/test/widgets/ui/mes_patterns_test.dart`
- Test: `frontend/test/widgets/crud_page_header_test.dart`
- Test: `frontend/test/widgets/crud_list_table_section_test.dart`
- Test: `frontend/test/widgets/simple_pagination_bar_test.dart`

- [ ] **Step 1: 先写失败测试，固定 pattern 级骨架能力**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';

void main() {
  testWidgets('MesPageHeader 展示标题、副标题和操作区', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: Scaffold(
          body: MesPageHeader(
            title: '页面标题',
            subtitle: '页面说明',
            actions: [
              FilledButton(
                onPressed: () {},
                child: const Text('新增'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('页面标题'), findsOneWidget);
    expect(find.text('页面说明'), findsOneWidget);
    expect(find.text('新增'), findsOneWidget);
  });

  testWidgets('MesSectionCard 与 MesPaginationBar 可组合使用', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: Scaffold(
          body: MesSectionCard(
            title: '列表区',
            child: MesPaginationBar(
              page: 1,
              totalPages: 3,
              total: 56,
              loading: false,
              onPrevious: () {},
              onNext: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('列表区'), findsOneWidget);
    expect(find.text('第 1 / 3 页'), findsOneWidget);
    expect(find.text('总数：56'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行 pattern 测试和旧 shared widget 测试，确认新骨架层尚未落地**

Run: `flutter test test/widgets/ui/mes_patterns_test.dart test/widgets/crud_page_header_test.dart test/widgets/crud_list_table_section_test.dart test/widgets/simple_pagination_bar_test.dart`

Expected: FAIL，`mes_patterns_test.dart` 报找不到 pattern 组件

- [ ] **Step 3: 实现 patterns，并让旧 shared widgets 改为薄包装**

```dart
// frontend/lib/core/ui/patterns/mes_page_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';
import 'package:mes_client/core/ui/primitives/mes_gap.dart';

class MesPageHeader extends StatelessWidget {
  const MesPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MesTokens>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: tokens.typography.pageTitle),
              if (subtitle != null) ...[
                MesGap.vertical(tokens.spacing.xs),
                Text(
                  subtitle!,
                  style: tokens.typography.body.copyWith(
                    color: tokens.colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          MesGap.horizontal(tokens.spacing.md),
          Wrap(spacing: tokens.spacing.sm, runSpacing: tokens.spacing.sm, children: actions),
        ],
      ],
    );
  }
}
```

```dart
// frontend/lib/core/ui/patterns/mes_section_card.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';
import 'package:mes_client/core/ui/primitives/mes_gap.dart';
import 'package:mes_client/core/ui/primitives/mes_surface.dart';

class MesSectionCard extends StatelessWidget {
  const MesSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MesTokens>()!;
    return MesSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: tokens.typography.sectionTitle),
                    if (subtitle != null) ...[
                      MesGap.vertical(tokens.spacing.xs),
                      Text(
                        subtitle!,
                        style: tokens.typography.body.copyWith(
                          color: tokens.colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          MesGap.vertical(tokens.spacing.md),
          child,
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/core/ui/patterns/mes_toolbar.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/primitives/mes_surface.dart';

class MesToolbar extends StatelessWidget {
  const MesToolbar({
    super.key,
    required this.leading,
    this.trailing = const <Widget>[],
  });

  final Widget leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return MesSurface(
      tone: MesSurfaceTone.subtle,
      child: Row(
        children: [
          Expanded(child: leading),
          Wrap(spacing: 12, runSpacing: 12, children: trailing),
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/core/ui/patterns/mes_filter_bar.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';

class MesFilterBar extends StatelessWidget {
  const MesFilterBar({
    super.key,
    required this.child,
    this.title = '筛选条件',
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MesSectionCard(title: title, child: child);
  }
}
```

```dart
// frontend/lib/core/ui/patterns/mes_empty_state.dart
import 'package:flutter/material.dart';

class MesEmptyState extends StatelessWidget {
  const MesEmptyState({
    super.key,
    required this.title,
    this.description,
  });

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 32),
          const SizedBox(height: 12),
          Text(title),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(description!),
          ],
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/core/ui/patterns/mes_error_state.dart
import 'package:flutter/material.dart';

class MesErrorState extends StatelessWidget {
  const MesErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 32),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/core/ui/patterns/mes_pagination_bar.dart
import 'package:flutter/material.dart';

class MesPaginationBar extends StatelessWidget {
  const MesPaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.loading,
    this.showTotal = true,
    this.onPrevious,
    this.onNext,
  });

  final int page;
  final int totalPages;
  final int total;
  final bool loading;
  final bool showTotal;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('第 $page / $totalPages 页'),
        if (showTotal) ...[const SizedBox(width: 12), Text('总数：$total')],
        const Spacer(),
        OutlinedButton.icon(
          onPressed: loading || page <= 1 ? null : onPrevious,
          icon: const Icon(Icons.chevron_left),
          label: const Text('上一页'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: loading || page >= totalPages ? null : onNext,
          icon: const Icon(Icons.chevron_right),
          label: const Text('下一页'),
        ),
      ],
    );
  }
}
```

```dart
// frontend/lib/core/ui/patterns/mes_metric_card.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';
import 'package:mes_client/core/ui/primitives/mes_surface.dart';

class MesMetricCard extends StatelessWidget {
  const MesMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.hint,
  });

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MesTokens>()!;
    return MesSurface(
      tone: MesSurfaceTone.raised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: tokens.typography.caption),
          const SizedBox(height: 8),
          Text(value, style: tokens.typography.metric),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(hint!, style: tokens.typography.caption),
          ],
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/core/ui/patterns/mes_detail_panel.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';

class MesDetailPanel extends StatelessWidget {
  const MesDetailPanel({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MesSectionCard(title: title, child: child);
  }
}
```

```dart
// frontend/lib/core/widgets/crud_page_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class CrudPageHeader extends StatelessWidget {
  const CrudPageHeader({super.key, required this.title, this.onRefresh});

  final String title;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return MesPageHeader(
      title: title,
      actions: [
        Tooltip(
          message: '刷新',
          child: IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ),
      ],
    );
  }
}
```

```dart
// frontend/lib/core/widgets/crud_list_table_section.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_empty_state.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';

class CrudListTableSection extends StatelessWidget {
  const CrudListTableSection({
    super.key,
    required this.loading,
    required this.isEmpty,
    required this.child,
    this.emptyText = '暂无数据',
    this.cardKey,
    this.loadingWidget,
    this.emptyWidget,
    this.contentPadding = EdgeInsets.zero,
    this.enableUnifiedHeaderStyle = false,
    this.shape = const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    this.clipBehavior = Clip.hardEdge,
  });

  final bool loading;
  final bool isEmpty;
  final Widget child;
  final String emptyText;
  final Key? cardKey;
  final Widget? loadingWidget;
  final Widget? emptyWidget;
  final EdgeInsetsGeometry contentPadding;
  final bool enableUnifiedHeaderStyle;
  final ShapeBorder shape;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final body = loading
        ? loadingWidget ?? const Center(child: CircularProgressIndicator())
        : isEmpty
        ? emptyWidget ?? MesEmptyState(title: emptyText)
        : Padding(padding: contentPadding, child: child);
    return KeyedSubtree(
      key: cardKey,
      child: MesSectionCard(title: '列表内容', child: SizedBox.expand(child: body)),
    );
  }
}
```

```dart
// frontend/lib/core/widgets/simple_pagination_bar.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';

class SimplePaginationBar extends StatelessWidget {
  const SimplePaginationBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.loading,
    this.showTotal = true,
    this.onPrevious,
    this.onNext,
  });

  final int page;
  final int totalPages;
  final int total;
  final bool loading;
  final bool showTotal;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return MesPaginationBar(
      page: page,
      totalPages: totalPages,
      total: total,
      loading: loading,
      showTotal: showTotal,
      onPrevious: onPrevious,
      onNext: onNext,
    );
  }
}
```

- [ ] **Step 4: 重新运行 pattern 与 shared widget 测试，确认旧入口不回归**

Run: `flutter test test/widgets/ui/mes_patterns_test.dart test/widgets/crud_page_header_test.dart test/widgets/crud_list_table_section_test.dart test/widgets/simple_pagination_bar_test.dart`

Expected: PASS，旧 shared widget 测试与新 pattern 测试同时通过

- [ ] **Step 5: 提交 patterns 与 shared widget 薄包装**

```bash
git add frontend/lib/core/ui/patterns frontend/lib/core/widgets/crud_page_header.dart frontend/lib/core/widgets/crud_list_table_section.dart frontend/lib/core/widgets/simple_pagination_bar.dart frontend/test/widgets/ui/mes_patterns_test.dart frontend/test/widgets/crud_page_header_test.dart frontend/test/widgets/crud_list_table_section_test.dart frontend/test/widgets/simple_pagination_bar_test.dart
git commit -m "建立前端UI页面骨架层"
```

## 任务 4：迁移设置页试点，落地统一页头与 section card

**Files:**
- Create: `frontend/lib/features/settings/presentation/widgets/software_settings_page_header.dart`
- Create: `frontend/lib/features/settings/presentation/widgets/software_settings_content_sections.dart`
- Modify: `frontend/lib/features/settings/presentation/software_settings_page.dart`
- Modify: `frontend/lib/features/settings/presentation/widgets/software_settings_preview_card.dart`
- Modify: `frontend/lib/features/settings/presentation/widgets/software_time_sync_section.dart`
- Test: `frontend/test/widgets/software_settings_page_test.dart`

- [ ] **Step 1: 先写失败测试，固定设置页试点应使用新骨架**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';

testWidgets('SoftwareSettingsPage 使用统一页头与区块卡片', (tester) async {
  final controller = SoftwareSettingsController.memory();

  await pumpPage(tester, controller);

  expect(find.byType(MesPageHeader), findsOneWidget);
  expect(find.byType(MesSectionCard), findsAtLeastNWidgets(2));
  expect(find.text('软件设置'), findsOneWidget);
});
```

- [ ] **Step 2: 运行设置页测试，确认试点页尚未迁移**

Run: `flutter test test/widgets/software_settings_page_test.dart`

Expected: FAIL，断言里找不到 `MesPageHeader` 或 `MesSectionCard`

- [ ] **Step 3: 拆设置页 UI 并接入 patterns**

```dart
// frontend/lib/features/settings/presentation/widgets/software_settings_page_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';
import 'package:mes_client/core/ui/primitives/mes_status_chip.dart';

class SoftwareSettingsPageHeader extends StatelessWidget {
  const SoftwareSettingsPageHeader({
    super.key,
    required this.saveMessage,
    required this.saveFailed,
    required this.onRestoreDefaults,
  });

  final String? saveMessage;
  final bool saveFailed;
  final VoidCallback onRestoreDefaults;

  @override
  Widget build(BuildContext context) {
    final status = saveMessage;
    return MesPageHeader(
      title: '软件设置',
      subtitle: '控制本机软件的外观、布局和时间同步偏好。',
      actions: [
        if (status != null)
          saveFailed
              ? MesStatusChip.warning(label: status)
              : MesStatusChip.success(label: status),
        OutlinedButton.icon(
          onPressed: onRestoreDefaults,
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('恢复默认'),
        ),
      ],
    );
  }
}
```

```dart
// frontend/lib/features/settings/presentation/widgets/software_settings_content_sections.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/features/settings/models/software_settings_models.dart';
import 'package:mes_client/features/settings/presentation/software_settings_controller.dart';
import 'package:mes_client/features/settings/presentation/widgets/software_settings_preview_card.dart';

class SoftwareSettingsAppearanceSection extends StatelessWidget {
  const SoftwareSettingsAppearanceSection({
    super.key,
    required this.settings,
    required this.controller,
  });

  final SoftwareSettings settings;
  final SoftwareSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MesSectionCard(
          title: '外观',
          child: Column(
            children: [
              RadioGroup<AppThemePreference>(
                groupValue: settings.themePreference,
                onChanged: (value) {
                  if (value != null) {
                    unawaited(controller.updateThemePreference(value));
                  }
                },
                child: const Column(
                  children: [
                    RadioListTile<AppThemePreference>(
                      title: Text('跟随系统'),
                      value: AppThemePreference.system,
                    ),
                    RadioListTile<AppThemePreference>(
                      title: Text('浅色'),
                      value: AppThemePreference.light,
                    ),
                    RadioListTile<AppThemePreference>(
                      title: Text('深色'),
                      value: AppThemePreference.dark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SoftwareSettingsPreviewCard(
          themePreference: settings.themePreference,
          densityPreference: settings.densityPreference,
        ),
      ],
    );
  }
}

class SoftwareSettingsLayoutSection extends StatelessWidget {
  const SoftwareSettingsLayoutSection({
    super.key,
    required this.settings,
    required this.controller,
  });

  final SoftwareSettings settings;
  final SoftwareSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return MesSectionCard(
      title: '布局偏好',
      child: Column(
        children: [
          RadioGroup<AppLaunchTargetPreference>(
            groupValue: settings.launchTargetPreference,
            onChanged: (value) {
              if (value != null) {
                unawaited(controller.updateLaunchTargetPreference(value));
              }
            },
            child: const Column(
              children: [
                RadioListTile<AppLaunchTargetPreference>(
                  title: Text('首页'),
                  value: AppLaunchTargetPreference.home,
                ),
                RadioListTile<AppLaunchTargetPreference>(
                  title: Text('上次停留模块'),
                  value: AppLaunchTargetPreference.lastVisitedModule,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/features/settings/presentation/widgets/software_settings_preview_card.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';

class SoftwareSettingsPreviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MesSectionCard(
      title: '预览',
      subtitle: '预览当前主题和密度偏好',
      child: _buildPreviewBody(context),
    );
  }
}
```

```dart
// frontend/lib/features/settings/presentation/widgets/software_time_sync_section.dart
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';

return Column(
  children: [
    MesSectionCard(
      title: '时间同步',
      subtitle: '服务器对时、系统改时与软件内校准',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: const Text('启用时间同步'),
            value: settings.timeSyncEnabled,
            onChanged: (value) {
              unawaited(softwareSettingsController.updateTimeSyncEnabled(value));
            },
          ),
          const SizedBox(height: 12),
          _buildStatusBlock(),
        ],
      ),
    ),
  ],
);
```

```dart
// frontend/lib/features/settings/presentation/software_settings_page.dart
import 'package:mes_client/features/settings/presentation/widgets/software_settings_content_sections.dart';
import 'package:mes_client/features/settings/presentation/widgets/software_settings_page_header.dart';

children: [
  SoftwareSettingsPageHeader(
    saveMessage: widget.controller.saveMessage,
    saveFailed: widget.controller.saveFailed,
    onRestoreDefaults: () {
      unawaited(widget.controller.restoreDefaults());
    },
  ),
  const SizedBox(height: 16),
  // 其余导航结构保留，内容区改为使用新 section widgets
]

case _SettingsSectionType.appearance:
  return SoftwareSettingsAppearanceSection(
    settings: settings,
    controller: widget.controller,
  );
case _SettingsSectionType.layout:
  return SoftwareSettingsLayoutSection(
    settings: settings,
    controller: widget.controller,
  );
```

- [ ] **Step 4: 重新运行设置页测试，确认试点页迁移完成**

Run: `flutter test test/widgets/software_settings_page_test.dart`

Expected: PASS，设置页继续通过原有行为断言，并新增通过 `MesPageHeader` / `MesSectionCard` 断言

- [ ] **Step 5: 提交设置页试点迁移**

```bash
git add frontend/lib/features/settings/presentation/software_settings_page.dart frontend/lib/features/settings/presentation/widgets/software_settings_page_header.dart frontend/lib/features/settings/presentation/widgets/software_settings_content_sections.dart frontend/lib/features/settings/presentation/widgets/software_settings_preview_card.dart frontend/lib/features/settings/presentation/widgets/software_time_sync_section.dart frontend/test/widgets/software_settings_page_test.dart
git commit -m "统一软件设置页基础件结构"
```

## 任务 5：迁移首页试点，统一概览区、指标卡和头部

**Files:**
- Modify: `frontend/lib/features/shell/presentation/home_page.dart`
- Modify: `frontend/lib/features/shell/presentation/widgets/home_dashboard_header.dart`
- Modify: `frontend/lib/features/shell/presentation/widgets/home_dashboard_todo_card.dart`
- Modify: `frontend/lib/features/shell/presentation/widgets/home_dashboard_risk_card.dart`
- Modify: `frontend/lib/features/shell/presentation/widgets/home_dashboard_kpi_card.dart`
- Test: `frontend/test/widgets/home_page_test.dart`

- [ ] **Step 1: 先写失败测试，固定首页试点应使用统一 header 和 metric card**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/ui/patterns/mes_metric_card.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';

testWidgets('HomePage 使用统一页头与指标卡骨架', (tester) async {
  await pumpHomePage(
    tester,
    currentUser: buildUser(),
    shortcuts: const [],
    onNavigateToPage: (_, {tabCode, routePayloadJson}) {},
    onRefresh: () async {},
  );

  expect(find.byType(MesPageHeader), findsOneWidget);
  expect(find.byType(MesSectionCard), findsAtLeastNWidgets(2));
  expect(find.byType(MesMetricCard), findsAtLeastNWidgets(2));
});
```

- [ ] **Step 2: 运行首页测试，确认首页试点尚未迁移**

Run: `flutter test test/widgets/home_page_test.dart`

Expected: FAIL，断言里找不到 `MesPageHeader` 或 `MesMetricCard`

- [ ] **Step 3: 改造首页与 dashboard widgets**

```dart
// frontend/lib/features/shell/presentation/widgets/home_dashboard_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class HomeDashboardHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MesPageHeader(
      title: '工作台',
      subtitle: refreshStatusText ?? '集中查看待办、风险和关键指标',
      actions: [
        FilledButton.tonalIcon(
          onPressed: refreshing ? null : onRefresh,
          icon: Icon(refreshing ? Icons.sync : Icons.refresh),
          label: Text(refreshing ? '刷新中' : '刷新业务数据'),
        ),
      ],
    );
  }
}
```

```dart
// frontend/lib/features/shell/presentation/widgets/home_dashboard_risk_card.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_metric_card.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';

class HomeDashboardRiskCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MesSectionCard(
      title: '风险提醒',
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: riskItems
            .map(
              (item) => MesMetricCard(
                label: item.label,
                value: item.value,
              ),
            )
            .toList(),
      ),
    );
  }
}
```

```dart
// frontend/lib/features/shell/presentation/widgets/home_dashboard_kpi_card.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_metric_card.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';

class HomeDashboardKpiCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MesSectionCard(
      title: '关键指标',
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: kpiItems
            .map(
              (item) => MesMetricCard(
                label: item.label,
                value: item.value,
              ),
            )
            .toList(),
      ),
    );
  }
}
```

```dart
// frontend/lib/features/shell/presentation/widgets/home_dashboard_todo_card.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';

class HomeDashboardTodoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MesSectionCard(
      title: '我的待办队列',
      subtitle: '查看全部待办并快速进入目标模块',
      child: _buildTodoBody(context),
    );
  }
}
```

```dart
// frontend/lib/features/shell/presentation/home_page.dart
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';

@override
Widget build(BuildContext context) {
  final tokens = Theme.of(context).extension<MesTokens>()!;
  final data = widget.dashboardData ?? _buildFallbackData();
  return Padding(
    padding: EdgeInsets.all(tokens.spacing.md),
    child: LayoutBuilder(
      builder: (context, constraints) {
        if (_isDesktopLayout(constraints)) {
          return _buildDesktopLayout(data);
        }
        return _buildMobileLayout(data);
      },
    ),
  );
}
```

- [ ] **Step 4: 重新运行首页 widget 和 integration tests**

Run: `flutter test test/widgets/home_page_test.dart`

Expected: PASS

Run: `flutter test -d windows integration_test/home_dashboard_flow_test.dart`

Expected: PASS

- [ ] **Step 5: 提交首页试点迁移**

```bash
git add frontend/lib/features/shell/presentation/home_page.dart frontend/lib/features/shell/presentation/widgets/home_dashboard_header.dart frontend/lib/features/shell/presentation/widgets/home_dashboard_todo_card.dart frontend/lib/features/shell/presentation/widgets/home_dashboard_risk_card.dart frontend/lib/features/shell/presentation/widgets/home_dashboard_kpi_card.dart frontend/test/widgets/home_page_test.dart frontend/integration_test/home_dashboard_flow_test.dart
git commit -m "统一首页骨架与指标卡"
```

## 任务 6：拆分并迁移消息中心试点

**Files:**
- Create: `frontend/lib/features/message/presentation/widgets/message_center_header.dart`
- Create: `frontend/lib/features/message/presentation/widgets/message_center_overview_section.dart`
- Create: `frontend/lib/features/message/presentation/widgets/message_center_filter_section.dart`
- Create: `frontend/lib/features/message/presentation/widgets/message_center_list_section.dart`
- Create: `frontend/lib/features/message/presentation/widgets/message_center_preview_panel.dart`
- Modify: `frontend/lib/features/message/presentation/message_center_page.dart`
- Test: `frontend/test/widgets/message_center_page_test.dart`

- [ ] **Step 1: 先写失败测试，固定消息中心的统一骨架与拆分结果**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/ui/patterns/mes_detail_panel.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';

testWidgets('message center 使用统一骨架组件', (tester) async {
  final service = _FakeMessageService();

  await _pumpMessageCenterPage(tester, service: service);

  expect(find.byType(MesPageHeader), findsOneWidget);
  expect(find.byType(MesFilterBar), findsOneWidget);
  expect(find.byType(MesSectionCard), findsAtLeastNWidgets(2));
  expect(find.byType(MesDetailPanel), findsOneWidget);
  expect(find.byType(MesPaginationBar), findsOneWidget);
});
```

- [ ] **Step 2: 运行消息中心测试，确认试点页尚未迁移**

Run: `flutter test test/widgets/message_center_page_test.dart`

Expected: FAIL，断言里找不到 `MesPageHeader` 或 `MesDetailPanel`

- [ ] **Step 3: 新建 feature widgets，缩减 `message_center_page.dart` 为状态编排文件**

```dart
// frontend/lib/features/message/presentation/widgets/message_center_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_toolbar.dart';

class MessageCenterHeader extends StatelessWidget {
  const MessageCenterHeader({
    super.key,
    required this.nowText,
    required this.errorText,
    required this.loading,
    required this.canPublishAnnouncement,
    required this.onReset,
    required this.onRefresh,
    required this.onMaintenance,
    required this.onPublishAnnouncement,
    required this.onMarkAllRead,
    required this.onMarkBatchRead,
    required this.batchReadCount,
  });

  final String nowText;
  final String errorText;
  final bool loading;
  final bool canPublishAnnouncement;
  final VoidCallback onReset;
  final VoidCallback onRefresh;
  final VoidCallback onMaintenance;
  final VoidCallback onPublishAnnouncement;
  final VoidCallback onMarkAllRead;
  final VoidCallback onMarkBatchRead;
  final int batchReadCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MesPageHeader(
          title: '消息中心',
          subtitle: nowText,
        ),
        const SizedBox(height: 12),
        MesToolbar(
          leading: errorText.isEmpty ? const SizedBox.shrink() : Text(errorText),
          trailing: [
            OutlinedButton.icon(
              onPressed: loading ? null : onReset,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('重置'),
            ),
            OutlinedButton.icon(
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新'),
            ),
            if (canPublishAnnouncement)
              OutlinedButton.icon(
                onPressed: loading ? null : onMaintenance,
                icon: const Icon(Icons.build_circle_outlined),
                label: const Text('执行维护'),
              ),
            if (canPublishAnnouncement)
              FilledButton.icon(
                onPressed: loading ? null : onPublishAnnouncement,
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('发布公告'),
              ),
            FilledButton.icon(
              onPressed: loading ? null : onMarkAllRead,
              icon: const Icon(Icons.done_all),
              label: const Text('全部已读'),
            ),
            FilledButton.tonalIcon(
              onPressed: loading || batchReadCount == 0 ? null : onMarkBatchRead,
              icon: const Icon(Icons.playlist_add_check),
              label: Text('批量已读${batchReadCount == 0 ? '' : '($batchReadCount)'}'),
            ),
          ],
        ),
      ],
    );
  }
}
```

```dart
// frontend/lib/features/message/presentation/widgets/message_center_overview_section.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_metric_card.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';

class MessageCenterOverviewSection extends StatelessWidget {
  const MessageCenterOverviewSection({
    super.key,
    required this.unreadCount,
    required this.todoCount,
    required this.urgentCount,
    required this.allCount,
  });

  final int unreadCount;
  final int todoCount;
  final int urgentCount;
  final int allCount;

  @override
  Widget build(BuildContext context) {
    return MesSectionCard(
      title: '消息概览',
      child: Row(
        children: [
          Expanded(child: MesMetricCard(label: '未读消息', value: '$unreadCount')),
          const SizedBox(width: 12),
          Expanded(child: MesMetricCard(label: '待处理', value: '$todoCount')),
          const SizedBox(width: 12),
          Expanded(child: MesMetricCard(label: '紧急', value: '$urgentCount')),
          const SizedBox(width: 12),
          Expanded(child: MesMetricCard(label: '全部消息', value: '$allCount')),
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/features/message/presentation/widgets/message_center_filter_section.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';

class MessageCenterFilterSection extends StatelessWidget {
  const MessageCenterFilterSection({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MesFilterBar(child: child);
  }
}
```

```dart
// frontend/lib/features/message/presentation/widgets/message_center_list_section.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_empty_state.dart';
import 'package:mes_client/core/ui/patterns/mes_error_state.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';

class MessageCenterListSection extends StatelessWidget {
  const MessageCenterListSection({
    super.key,
    required this.loading,
    required this.error,
    required this.isEmpty,
    required this.body,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.onRetry,
    required this.onPrevious,
    required this.onNext,
  });

  final bool loading;
  final String error;
  final bool isEmpty;
  final Widget body;
  final int page;
  final int totalPages;
  final int total;
  final VoidCallback onRetry;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final content = loading
        ? const Center(child: CircularProgressIndicator())
        : error.isNotEmpty
        ? MesErrorState(message: error, onRetry: onRetry)
        : isEmpty
        ? const MesEmptyState(title: '当前没有消息')
        : body;
    return MesSectionCard(
      title: '消息列表',
      child: Column(
        children: [
          Expanded(child: content),
          const SizedBox(height: 12),
          MesPaginationBar(
            page: page,
            totalPages: totalPages,
            total: total,
            loading: loading,
            onPrevious: onPrevious,
            onNext: onNext,
          ),
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/features/message/presentation/widgets/message_center_preview_panel.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_detail_panel.dart';

class MessageCenterPreviewPanel extends StatelessWidget {
  const MessageCenterPreviewPanel({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MesDetailPanel(title: '消息详情预览', child: child);
  }
}
```

```dart
// frontend/lib/features/message/presentation/message_center_page.dart
import 'package:mes_client/features/message/presentation/widgets/message_center_filter_section.dart';
import 'package:mes_client/features/message/presentation/widgets/message_center_header.dart';
import 'package:mes_client/features/message/presentation/widgets/message_center_list_section.dart';
import 'package:mes_client/features/message/presentation/widgets/message_center_overview_section.dart';
import 'package:mes_client/features/message/presentation/widgets/message_center_preview_panel.dart';

@override
Widget build(BuildContext context) {
  final totalPages = (_total / _pageSize).ceil().clamp(1, 1 << 20);
  final effectiveNow = widget.nowProvider();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MessageCenterHeader(
        nowText: _formatDateTime(effectiveNow),
        errorText: _error,
        loading: _loading,
        canPublishAnnouncement: widget.canPublishAnnouncement,
        onReset: _resetFilters,
        onRefresh: () => _load(),
        onMaintenance: _runMaintenance,
        onPublishAnnouncement: _publishAnnouncement,
        onMarkAllRead: _markAllRead,
        onMarkBatchRead: _markBatchRead,
        batchReadCount: _selectedIds.length,
      ),
      const SizedBox(height: 12),
      MessageCenterOverviewSection(
        unreadCount: _unreadCount,
        todoCount: _todoCount,
        urgentCount: _urgentCount,
        allCount: _allMessageCount,
      ),
      const SizedBox(height: 12),
      MessageCenterFilterSection(child: _buildFilterBar(Theme.of(context))),
      const SizedBox(height: 12),
      Expanded(
        child: Row(
          children: [
            Expanded(
              flex: 16,
              child: MessageCenterListSection(
                loading: _loading,
                error: _error,
                isEmpty: _items.isEmpty,
                body: _buildMessageList(Theme.of(context)),
                page: _page,
                totalPages: totalPages,
                total: _total,
                onRetry: () => _load(),
                onPrevious: () {
                  setState(() => _page -= 1);
                  _load(reset: false);
                },
                onNext: () {
                  setState(() => _page += 1);
                  _load(reset: false);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 9,
              child: MessageCenterPreviewPanel(
                child: _buildPreviewPane(Theme.of(context)),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
```

- [ ] **Step 4: 重新运行消息中心 widget tests**

Run: `flutter test test/widgets/message_center_page_test.dart`

Expected: PASS

- [ ] **Step 5: 提交消息中心拆分与试点迁移**

```bash
git add frontend/lib/features/message/presentation/message_center_page.dart frontend/lib/features/message/presentation/widgets/message_center_header.dart frontend/lib/features/message/presentation/widgets/message_center_overview_section.dart frontend/lib/features/message/presentation/widgets/message_center_filter_section.dart frontend/lib/features/message/presentation/widgets/message_center_list_section.dart frontend/lib/features/message/presentation/widgets/message_center_preview_panel.dart frontend/test/widgets/message_center_page_test.dart
git commit -m "拆分消息中心并接入统一基础件"
```

## 任务 7：补齐 integration 回归、evidence 和最终收口

**Files:**
- Create: `frontend/integration_test/message_center_flow_test.dart`
- Create: `evidence/2026-04-20_前端UI基础件体系实施.md`
- Modify: `frontend/integration_test/software_settings_flow_test.dart`
- Modify: `frontend/integration_test/home_dashboard_flow_test.dart`
- Modify: `frontend/integration_test/home_shell_flow_test.dart`

- [ ] **Step 1: 先补失败的 integration assertions，固定试点页在桌面流中的新骨架**

```dart
// frontend/integration_test/software_settings_flow_test.dart
testWidgets('软件设置页可切换到时间同步并展示统一页头', (tester) async {
  final controller = SoftwareSettingsController(
    service: await SoftwareSettingsService.create(),
  );
  await controller.load();
  await _pumpMainShellPage(tester, controller: controller);

  await tester.tap(find.text('软件设置'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('时间同步').first);
  await tester.pumpAndSettle();

  expect(find.text('软件设置'), findsOneWidget);
  expect(find.text('启用时间同步'), findsOneWidget);
  expect(find.text('立即检查并同步'), findsOneWidget);
});
```

```dart
// frontend/integration_test/home_dashboard_flow_test.dart
testWidgets('首页工作台显示统一头部和指标卡', (tester) async {
  final messageService = _FakeMessageService();
  await _pumpHomeDashboardShell(tester, messageService: messageService);

  expect(find.text('工作台'), findsOneWidget);
  expect(find.text('风险提醒'), findsOneWidget);
  expect(find.text('关键指标'), findsOneWidget);
});
```

```dart
// frontend/integration_test/home_shell_flow_test.dart
testWidgets('主壳层切换到设置页与首页后不出现布局回归', (tester) async {
  await _pumpHomeShellApp(
    tester,
    authService: _IntegrationAuthService(),
    messageService: _IntegrationMessageService(items: const []),
  );

  await tester.tap(find.byKey(const ValueKey('main-shell-entry-software-settings')));
  await tester.pumpAndSettle();
  expect(find.text('软件设置'), findsOneWidget);

  await tester.tap(find.byKey(const ValueKey('main-shell-menu-home')));
  await tester.pumpAndSettle();
  expect(find.text('工作台'), findsOneWidget);
});
```

```dart
// frontend/integration_test/message_center_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/message/models/message_models.dart';
import 'package:mes_client/features/message/presentation/message_center_page.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/user/services/user_service.dart';

class _IntegrationMessageService extends MessageService {
  _IntegrationMessageService() : super(AppSession(baseUrl: '', accessToken: ''));

  @override
  Future<MessageSummaryResult> getSummary() async {
    return const MessageSummaryResult(
      totalCount: 1,
      unreadCount: 1,
      todoUnreadCount: 1,
      urgentUnreadCount: 0,
    );
  }

  @override
  Future<MessageListResult> listMessages({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? status,
    String? messageType,
    String? priority,
    String? sourceModule,
    DateTime? startTime,
    DateTime? endTime,
    bool todoOnly = false,
    bool activeOnly = true,
  }) async {
    return MessageListResult(
      items: [
        MessageItem.fromJson({
          'id': 1,
          'message_type': 'todo',
          'priority': 'urgent',
          'title': '待办消息',
          'summary': '请尽快处理',
          'status': 'active',
          'published_at': '2026-04-20T08:00:00Z',
          'is_read': false,
          'delivery_status': 'delivered',
          'delivery_attempt_count': 1,
        }),
      ],
      total: 1,
      page: 1,
      pageSize: 20,
    );
  }
}

class _IntegrationUserService extends UserService {
  _IntegrationUserService() : super(AppSession(baseUrl: '', accessToken: ''));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('消息中心桌面流展示统一页头、筛选区和详情预览', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1280,
            child: MessageCenterPage(
              session: AppSession(baseUrl: '', accessToken: ''),
              onLogout: () {},
              canPublishAnnouncement: false,
              canViewDetail: true,
              canUseJump: false,
              service: _IntegrationMessageService(),
              userService: _IntegrationUserService(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('消息中心'), findsOneWidget);
    expect(find.text('消息概览'), findsOneWidget);
    expect(find.text('筛选条件'), findsOneWidget);
    expect(find.text('消息详情预览'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行回归命令，确认桌面主流程全部通过**

Run: `flutter analyze`

Expected: `No issues found!`

Run: `flutter test test/widgets/ui/mes_theme_test.dart test/widgets/ui/mes_primitives_test.dart test/widgets/ui/mes_patterns_test.dart test/widgets/software_settings_page_test.dart test/widgets/home_page_test.dart test/widgets/message_center_page_test.dart test/widgets/crud_page_header_test.dart test/widgets/crud_list_table_section_test.dart test/widgets/simple_pagination_bar_test.dart`

Expected: PASS

Run: `flutter test -d windows integration_test/software_settings_flow_test.dart`

Expected: PASS

Run: `flutter test -d windows integration_test/home_dashboard_flow_test.dart`

Expected: PASS

Run: `flutter test -d windows integration_test/home_shell_flow_test.dart`

Expected: PASS

Run: `flutter test -d windows integration_test/message_center_flow_test.dart`

Expected: PASS

- [ ] **Step 3: 更新实施 evidence，记录任务拆分、验证命令与结果**

```md
# 任务日志：前端UI基础件体系实施

- 日期：2026-04-20
- 执行人：Codex
- 当前状态：已完成

## 1. 输入来源
- 用户指令：按路线 B 落地前端 UI 基础件体系
- 设计规格：docs/superpowers/specs/2026-04-20-frontend-ui-foundation-design.md

## 2. 实施分段
- 任务 1：foundation 主题层
- 任务 2：primitives 基础件层
- 任务 3：patterns 页面骨架层与 shared widgets 薄包装
- 任务 4：设置页试点迁移
- 任务 5：首页试点迁移
- 任务 6：消息中心拆分与试点迁移

## 3. 验证结果
- flutter analyze：通过
- widget tests：通过
- integration_test/software_settings_flow_test.dart：通过
- integration_test/home_dashboard_flow_test.dart：通过
- integration_test/home_shell_flow_test.dart：通过
- integration_test/message_center_flow_test.dart：通过

## 4. 迁移说明
- 无迁移，直接替换
```

- [ ] **Step 4: 提交最终验证与留痕**

```bash
git add frontend/integration_test/software_settings_flow_test.dart frontend/integration_test/home_dashboard_flow_test.dart frontend/integration_test/home_shell_flow_test.dart frontend/integration_test/message_center_flow_test.dart evidence/2026-04-20_前端UI基础件体系实施.md
git commit -m "补齐前端UI基础件体系验证"
```
