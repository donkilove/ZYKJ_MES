# 产品版本管理页第二波迁移 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 Flutter 前端中完成产品版本管理页第二波 UI 迁移，新增主从页面骨架 `MesListDetailShell`，拆分产品版本页展示层，并补齐 widget / integration / evidence 闭环。

**Architecture:** 先在 `core/ui/patterns/` 新增主从页骨架 `MesListDetailShell`，用独立模式件测试固定宽屏双栏与窄屏纵向退化行为。随后在 `features/product/presentation/widgets/` 建立产品版本页的 5 个展示组件，主页面只保留状态、数据加载、`jump command`、动作入口与弹窗调用。测试按“模式件 -> 页面拆分 -> 页面主文件 -> 页面级回归 -> integration -> evidence”顺序推进，现有业务动作语义保持不变。

**Tech Stack:** Flutter、Dart、Material 3、`flutter_test`、`integration_test`

---

> Flutter 命令默认在 `frontend/` 目录执行；`git`、`evidence` 与计划文档操作默认在仓库根目录执行。  
> 本计划遵循“无迁移，直接替换”。  
> 用户已明确要求在当前 `main` 分支内直接执行，不派发子 AGENT。  
> 当前工作区已有一处与本计划无关的改动：`evidence/2026-04-20_前端UI基础件体系实施.md`。执行本计划时不要误将该文件一并提交。

## 文件结构

### 新增文件

- `frontend/lib/core/ui/patterns/mes_list_detail_shell.dart`
  - 统一“左侧列表 / 右侧工作区”的主从页骨架，负责双栏与窄宽度退化
- `frontend/lib/features/product/presentation/widgets/product_version_page_header.dart`
  - 产品版本管理页头，只负责页面标题与刷新入口
- `frontend/lib/features/product/presentation/widgets/product_selector_panel.dart`
  - 左侧产品选择区，承接搜索、列表、选中态与分页
- `frontend/lib/features/product/presentation/widgets/product_version_feedback_banner.dart`
  - 右侧页内反馈区，统一“草稿存在 / 最近生效结果 / 当前无生效版本 / 页面级错误”
- `frontend/lib/features/product/presentation/widgets/product_version_toolbar.dart`
  - 右侧版本工作区顶部动作带，统一产品标题、当前选中版本提示和主操作入口
- `frontend/lib/features/product/presentation/widgets/product_version_table_section.dart`
  - 右侧版本表格区，统一状态展示、空态、加载态和行级菜单
- `frontend/test/widgets/product_version_management_page_test.dart`
  - 产品版本管理页的页面级 widget test，覆盖接入新骨架后的装配与关键锚点
- `frontend/integration_test/product_version_flow_test.dart`
  - 产品版本管理页的桌面主路径 integration test
- `evidence/2026-04-20_产品版本管理页第二波迁移实施.md`
  - 本轮实施 evidence 主日志

### 修改文件

- `frontend/test/widgets/ui/mes_patterns_test.dart`
  - 补齐 `MesListDetailShell` 的失败测试与回归断言
- `frontend/lib/features/product/presentation/product_version_management_page.dart`
  - 收敛主页面职责，接入 `MesListDetailShell` 与拆分后的 widgets
- `frontend/test/widgets/product_module_issue_regression_test.dart`
  - 保留既有产品模块行为回归，并补充新锚点断言

## 任务 1：新增主从页面骨架 `MesListDetailShell`

**Files:**
- Create: `frontend/lib/core/ui/patterns/mes_list_detail_shell.dart`
- Modify: `frontend/test/widgets/ui/mes_patterns_test.dart`

- [ ] **Step 1: 先写失败测试，固定主从骨架的横向 / 纵向布局与 banner 插槽**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_inline_banner.dart';
import 'package:mes_client/core/ui/patterns/mes_list_detail_shell.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/core/ui/patterns/mes_table_section_header.dart';

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
            actions: [FilledButton(onPressed: () {}, child: const Text('新增'))],
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

  testWidgets(
    'MesCrudPageScaffold 按固定顺序装配 header filters banner content pagination',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMesTheme(
            brightness: Brightness.light,
            visualDensity: VisualDensity.standard,
          ),
          home: const Scaffold(
            body: MesCrudPageScaffold(
              header: Text('header-slot'),
              filters: Text('filters-slot'),
              banner: MesInlineBanner.info(message: '页内提示'),
              content: Placeholder(),
              pagination: Text('pagination-slot'),
            ),
          ),
        ),
      );

      expect(find.text('header-slot'), findsOneWidget);
      expect(find.text('filters-slot'), findsOneWidget);
      expect(find.text('页内提示'), findsOneWidget);
      expect(find.text('pagination-slot'), findsOneWidget);
      expect(find.byType(MesInlineBanner), findsOneWidget);
    },
  );

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

  testWidgets('MesListDetailShell 在宽屏双栏、窄屏纵向堆叠并支持 banner', (tester) async {
    Future<void> pumpShell(double width) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMesTheme(
            brightness: Brightness.light,
            visualDensity: VisualDensity.standard,
          ),
          home: Scaffold(
            body: SizedBox(
              width: width,
              height: 720,
              child: const MesListDetailShell(
                banner: MesInlineBanner.info(message: '顶部提示'),
                sidebar: ColoredBox(
                  key: ValueKey('sidebar-child'),
                  color: Colors.blue,
                  child: SizedBox.expand(),
                ),
                content: ColoredBox(
                  key: ValueKey('content-child'),
                  color: Colors.green,
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpShell(1280);
    expect(find.text('顶部提示'), findsOneWidget);

    final wideSidebar = tester.getRect(
      find.byKey(const ValueKey('mes-list-detail-shell-sidebar')),
    );
    final wideContent = tester.getRect(
      find.byKey(const ValueKey('mes-list-detail-shell-content')),
    );
    expect(wideSidebar.left, lessThan(wideContent.left));
    expect(wideSidebar.top, equals(wideContent.top));

    await pumpShell(720);

    final narrowSidebar = tester.getRect(
      find.byKey(const ValueKey('mes-list-detail-shell-sidebar')),
    );
    final narrowContent = tester.getRect(
      find.byKey(const ValueKey('mes-list-detail-shell-content')),
    );
    expect(narrowSidebar.top, lessThan(narrowContent.top));
    expect(narrowSidebar.left, equals(narrowContent.left));
  });
}
```

- [ ] **Step 2: 运行模式件测试，确认新骨架尚未存在**

Run: `flutter test test/widgets/ui/mes_patterns_test.dart`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Undefined class 'MesListDetailShell'`

- [ ] **Step 3: 新增 `MesListDetailShell`，只支持第一版主从结构核心插槽**

```dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';
import 'package:mes_client/core/ui/primitives/mes_gap.dart';

class MesListDetailShell extends StatelessWidget {
  const MesListDetailShell({
    super.key,
    required this.sidebar,
    required this.content,
    this.header,
    this.banner,
    this.sidebarWidth = 280,
    this.breakpoint = 960,
  });

  final Widget sidebar;
  final Widget content;
  final Widget? header;
  final Widget? banner;
  final double sidebarWidth;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    final spacing = Theme.of(context).extension<MesTokens>()?.spacing.md ?? 16.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < breakpoint;

        final body = stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KeyedSubtree(
                    key: const ValueKey('mes-list-detail-shell-sidebar'),
                    child: sidebar,
                  ),
                  MesGap.vertical(spacing),
                  Expanded(
                    child: KeyedSubtree(
                      key: const ValueKey('mes-list-detail-shell-content'),
                      child: content,
                    ),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: sidebarWidth,
                    child: KeyedSubtree(
                      key: const ValueKey('mes-list-detail-shell-sidebar'),
                      child: sidebar,
                    ),
                  ),
                  MesGap.horizontal(spacing),
                  Expanded(
                    child: KeyedSubtree(
                      key: const ValueKey('mes-list-detail-shell-content'),
                      child: content,
                    ),
                  ),
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) ...[
              header!,
              MesGap.vertical(spacing),
            ],
            if (banner != null) ...[
              banner!,
              MesGap.vertical(spacing),
            ],
            Expanded(child: body),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 4: 重新运行模式件测试，确认新骨架通过**

Run: `flutter test test/widgets/ui/mes_patterns_test.dart`

Expected: PASS，显示 `All tests passed`

- [ ] **Step 5: 提交主从骨架模式件**

```bash
git add frontend/lib/core/ui/patterns/mes_list_detail_shell.dart frontend/test/widgets/ui/mes_patterns_test.dart
git commit -m "新增主从页面骨架模式件"
```

## 任务 2：建立产品版本页展示层 widgets

**Files:**
- Create: `frontend/lib/features/product/presentation/widgets/product_version_page_header.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_selector_panel.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_version_feedback_banner.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_version_toolbar.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_version_table_section.dart`
- Create: `frontend/test/widgets/product_version_management_page_test.dart`

- [ ] **Step 1: 先写失败测试，固定拆分组件的稳定锚点和主要文案**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_selector_panel.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_feedback_banner.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_page_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_table_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_toolbar.dart';

final DateTime _fixedDate = DateTime.parse('2026-04-20T00:00:00Z');

ProductItem _buildProduct({
  required int id,
  required String name,
  String lifecycleStatus = 'active',
  int effectiveVersion = 1,
  String? inactiveReason,
}) {
  return ProductItem(
    id: id,
    name: name,
    category: '贴片',
    remark: '',
    lifecycleStatus: lifecycleStatus,
    currentVersion: 2,
    currentVersionLabel: 'V1.1',
    effectiveVersion: effectiveVersion,
    effectiveVersionLabel: effectiveVersion > 0 ? 'V1.0' : null,
    effectiveAt: _fixedDate,
    inactiveReason: inactiveReason,
    lastParameterSummary: null,
    createdAt: _fixedDate,
    updatedAt: _fixedDate,
  );
}

ProductVersionItem _buildVersion({
  required int version,
  required String label,
  required String lifecycleStatus,
  String? note,
}) {
  return ProductVersionItem(
    version: version,
    versionLabel: label,
    lifecycleStatus: lifecycleStatus,
    action: 'create',
    note: note,
    effectiveAt: lifecycleStatus == 'effective' ? _fixedDate : null,
    sourceVersion: null,
    sourceVersionLabel: null,
    createdByUserId: 1,
    createdByUsername: 'admin',
    createdAt: _fixedDate,
  );
}

void main() {
  testWidgets('产品版本页拆分组件提供稳定页头 反馈 工具栏与表格锚点', (tester) async {
    final searchController = TextEditingController(text: '产品101');
    addTearDown(searchController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: Scaffold(
          body: Column(
            children: [
              ProductVersionPageHeader(
                loading: false,
                onRefresh: () {},
              ),
              ProductVersionFeedbackBanner(
                hasDraft: true,
                product: _buildProduct(
                  id: 101,
                  name: '产品101',
                  lifecycleStatus: 'inactive',
                  effectiveVersion: 0,
                  inactiveReason: '当前无生效版本，请先将目标版本设为生效后再恢复启用。',
                ),
                effectiveVersion: _buildVersion(
                  version: 1,
                  label: 'V1.0',
                  lifecycleStatus: 'effective',
                ),
                formatDate: (value) => '2026-04-20 08:00',
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: ProductSelectorPanel(
                        searchController: searchController,
                        loading: false,
                        products: [
                          _buildProduct(id: 101, name: '产品101'),
                          _buildProduct(
                            id: 102,
                            name: '产品102',
                            lifecycleStatus: 'inactive',
                            effectiveVersion: 0,
                          ),
                        ],
                        selectedProductId: 101,
                        page: 1,
                        totalPages: 3,
                        total: 120,
                        onSearchSubmitted: (_) {},
                        onRefresh: () {},
                        onSelectProduct: (_) {},
                        onPreviousPage: () {},
                        onNextPage: () {},
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          ProductVersionToolbar(
                            product: _buildProduct(id: 101, name: '产品101'),
                            selectedVersion: _buildVersion(
                              version: 2,
                              label: 'V1.1',
                              lifecycleStatus: 'draft',
                            ),
                            hasDraft: true,
                            canManageVersions: true,
                            canActivateVersions: true,
                            canExportVersionParameters: true,
                            onCreateVersion: () {},
                            onCopyVersion: () {},
                            onEditVersionNote: () {},
                            onExportParameters: () {},
                            onActivateVersion: () {},
                            onRefresh: () {},
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ProductVersionTableSection(
                              versions: [
                                _buildVersion(
                                  version: 2,
                                  label: 'V1.1',
                                  lifecycleStatus: 'draft',
                                  note: '草稿版本',
                                ),
                              ],
                              loading: false,
                              selectedVersionNumber: 2,
                              canManageVersions: true,
                              canActivateVersions: true,
                              canExportVersionParameters: true,
                              onSelectVersion: (_) {},
                              onShowDetail: (_) {},
                              onActivate: (_) {},
                              onCopy: (_) {},
                              onEditNote: (_) {},
                              onEditParameters: (_) {},
                              onExport: (_) {},
                              onDisable: (_) {},
                              onDelete: (_) {},
                              formatDate: (_) => '2026-04-20 08:00',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('版本管理'), findsOneWidget);
    expect(find.byKey(const ValueKey('product-version-feedback-banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-selector-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-version-toolbar')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-version-table-section')), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '复制版本'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '立即生效'), findsOneWidget);
  });

  testWidgets('版本表格区保留行级操作菜单文案', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 600,
            child: ProductVersionTableSection(
              versions: [
                _buildVersion(
                  version: 2,
                  label: 'V1.1',
                  lifecycleStatus: 'draft',
                  note: '草稿版本',
                ),
              ],
              loading: false,
              selectedVersionNumber: 2,
              canManageVersions: true,
              canActivateVersions: true,
              canExportVersionParameters: true,
              onSelectVersion: (_) {},
              onShowDetail: (_) {},
              onActivate: (_) {},
              onCopy: (_) {},
              onEditNote: (_) {},
              onEditParameters: (_) {},
              onExport: (_) {},
              onDisable: (_) {},
              onDelete: (_) {},
              formatDate: (_) => '2026-04-20 08:00',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('查看详情'), findsOneWidget);
    expect(find.text('立即生效'), findsOneWidget);
    expect(find.text('复制版本'), findsOneWidget);
    expect(find.text('编辑版本说明'), findsOneWidget);
    expect(find.text('维护参数'), findsOneWidget);
    expect(find.text('导出版本参数'), findsOneWidget);
    expect(find.text('删除版本'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行拆分组件测试，确认页面 widgets 尚未存在**

Run: `flutter test test/widgets/product_version_management_page_test.dart`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Undefined class 'ProductVersionToolbar'`

- [ ] **Step 3: 新增产品版本页展示 widgets**

```dart
// frontend/lib/features/product/presentation/widgets/product_version_page_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class ProductVersionPageHeader extends StatelessWidget {
  const ProductVersionPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
  });

  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return MesPageHeader(
      title: '版本管理',
      subtitle: '左侧选择产品，右侧查看版本工作区与参数动作。',
      actions: [
        FilledButton.tonalIcon(
          onPressed: loading ? null : onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('刷新页面'),
        ),
      ],
    );
  }
}
```

```dart
// frontend/lib/features/product/presentation/widgets/product_selector_panel.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_empty_state.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/core/ui/primitives/mes_status_chip.dart';
import 'package:mes_client/features/product/models/product_models.dart';

class ProductSelectorPanel extends StatelessWidget {
  const ProductSelectorPanel({
    super.key,
    required this.searchController,
    required this.loading,
    required this.products,
    required this.selectedProductId,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.onSearchSubmitted,
    required this.onRefresh,
    required this.onSelectProduct,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final TextEditingController searchController;
  final bool loading;
  final List<ProductItem> products;
  final int? selectedProductId;
  final int page;
  final int totalPages;
  final int total;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onRefresh;
  final ValueChanged<ProductItem> onSelectProduct;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-selector-panel'),
      child: MesSectionCard(
        title: '产品列表',
        subtitle: '先定位产品，再进入右侧版本工作区。',
        expandChild: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: '搜索产品名称',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: onSearchSubmitted,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: loading ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (loading)
              const LinearProgressIndicator()
            else if (products.isEmpty)
              const Expanded(
                child: MesEmptyState(
                  title: '暂无产品',
                  description: '可尝试修改关键词后重新查询。',
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final selected = product.id == selectedProductId;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: ListTile(
                        selected: selected,
                        title: Text(
                          product.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          product.category.isEmpty ? '无分类' : product.category,
                        ),
                        trailing: product.lifecycleStatus == 'inactive'
                            ? MesStatusChip.warning(label: '停用')
                            : null,
                        onTap: () => onSelectProduct(product),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            MesPaginationBar(
              page: page,
              totalPages: totalPages,
              total: total,
              loading: loading,
              onPrevious: onPreviousPage,
              onNext: onNextPage,
            ),
          ],
        ),
      ),
    );
  }
}
```

```dart
// frontend/lib/features/product/presentation/widgets/product_version_feedback_banner.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_inline_banner.dart';
import 'package:mes_client/features/product/models/product_models.dart';

class ProductVersionFeedbackBanner extends StatelessWidget {
  const ProductVersionFeedbackBanner({
    super.key,
    required this.hasDraft,
    required this.product,
    required this.effectiveVersion,
    required this.formatDate,
    this.message,
  });

  final bool hasDraft;
  final ProductItem? product;
  final ProductVersionItem? effectiveVersion;
  final String Function(DateTime value) formatDate;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    final trimmedMessage = message?.trim() ?? '';
    if (trimmedMessage.isNotEmpty) {
      items.add(MesInlineBanner.error(message: trimmedMessage));
    }
    if (hasDraft) {
      items.add(
        const MesInlineBanner.warning(
          message: '已存在草稿版本，请先完成或删除当前草稿后再新建版本。',
        ),
      );
    }
    if (effectiveVersion != null) {
      final effective = effectiveVersion!;
      final timeText = effective.effectiveAt == null
          ? ''
          : '（${formatDate(effective.effectiveAt!)}）';
      items.add(
        MesInlineBanner.success(
          message: '最近一次生效结果：${effective.versionLabel} 已生效$timeText',
        ),
      );
    }
    if (product != null &&
        product!.lifecycleStatus == 'inactive' &&
        effectiveVersion == null) {
      items.add(
        MesInlineBanner.info(
          message:
              product!.inactiveReason?.trim().isNotEmpty == true
                  ? product!.inactiveReason!
                  : '当前无生效版本，请先将目标版本设为生效后再恢复启用。',
        ),
      );
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return KeyedSubtree(
      key: const ValueKey('product-version-feedback-banner'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            items[index],
          ],
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/features/product/presentation/widgets/product_version_toolbar.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_table_section_header.dart';
import 'package:mes_client/core/ui/patterns/mes_toolbar.dart';
import 'package:mes_client/features/product/models/product_models.dart';

class ProductVersionToolbar extends StatelessWidget {
  const ProductVersionToolbar({
    super.key,
    required this.product,
    required this.selectedVersion,
    required this.hasDraft,
    required this.canManageVersions,
    required this.canActivateVersions,
    required this.canExportVersionParameters,
    required this.onCreateVersion,
    required this.onCopyVersion,
    required this.onEditVersionNote,
    required this.onExportParameters,
    required this.onActivateVersion,
    required this.onRefresh,
  });

  final ProductItem? product;
  final ProductVersionItem? selectedVersion;
  final bool hasDraft;
  final bool canManageVersions;
  final bool canActivateVersions;
  final bool canExportVersionParameters;
  final VoidCallback onCreateVersion;
  final VoidCallback onCopyVersion;
  final VoidCallback onEditVersionNote;
  final VoidCallback onExportParameters;
  final VoidCallback onActivateVersion;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final selected = selectedVersion;
    final productTitle = product?.name ?? '请先选择产品';
    final subtitle = selected == null
        ? '当前未选中版本'
        : '当前选中：${selected.versionLabel} / ${_statusLabel(selected.lifecycleStatus)}';

    return KeyedSubtree(
      key: const ValueKey('product-version-toolbar'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MesTableSectionHeader(
            title: productTitle,
            subtitle: subtitle,
            trailing: IconButton(
              tooltip: '刷新版本列表',
              onPressed: product == null ? null : onRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ),
          const SizedBox(height: 12),
          MesToolbar(
            leading: Text(
              product == null
                  ? '选择左侧产品后才能执行版本动作。'
                  : hasDraft
                  ? '当前产品已存在草稿版本，不能重复新建。'
                  : '当前产品可继续新建版本或对选中版本执行后续动作。',
            ),
            trailing: [
              if (canManageVersions)
                OutlinedButton.icon(
                  onPressed: product == null || hasDraft ? null : onCreateVersion,
                  icon: const Icon(Icons.add),
                  label: const Text('新建版本'),
                ),
              if (canManageVersions)
                OutlinedButton.icon(
                  onPressed: selected == null ? null : onCopyVersion,
                  icon: const Icon(Icons.copy),
                  label: const Text('复制版本'),
                ),
              if (canManageVersions)
                OutlinedButton.icon(
                  onPressed: selected == null ? null : onEditVersionNote,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('编辑版本说明'),
                ),
              if (canExportVersionParameters)
                OutlinedButton.icon(
                  onPressed: selected == null ? null : onExportParameters,
                  icon: const Icon(Icons.download),
                  label: const Text('导出参数'),
                ),
              if (canActivateVersions)
                FilledButton.icon(
                  onPressed: selected == null || selected.lifecycleStatus != 'draft'
                      ? null
                      : onActivateVersion,
                  icon: const Icon(Icons.task_alt),
                  label: const Text('立即生效'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'draft':
      return '草稿';
    case 'effective':
      return '已生效';
    case 'obsolete':
    case 'inactive':
      return '已失效';
    case 'disabled':
      return '已停用';
    default:
      return status;
  }
}
```

```dart
// frontend/lib/features/product/presentation/widgets/product_version_table_section.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_empty_state.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/core/ui/primitives/mes_status_chip.dart';
import 'package:mes_client/features/product/models/product_models.dart';

class ProductVersionTableSection extends StatelessWidget {
  const ProductVersionTableSection({
    super.key,
    required this.versions,
    required this.loading,
    required this.selectedVersionNumber,
    required this.canManageVersions,
    required this.canActivateVersions,
    required this.canExportVersionParameters,
    required this.onSelectVersion,
    required this.onShowDetail,
    required this.onActivate,
    required this.onCopy,
    required this.onEditNote,
    required this.onEditParameters,
    required this.onExport,
    required this.onDisable,
    required this.onDelete,
    required this.formatDate,
  });

  final List<ProductVersionItem> versions;
  final bool loading;
  final int? selectedVersionNumber;
  final bool canManageVersions;
  final bool canActivateVersions;
  final bool canExportVersionParameters;
  final ValueChanged<int> onSelectVersion;
  final ValueChanged<ProductVersionItem> onShowDetail;
  final ValueChanged<ProductVersionItem> onActivate;
  final ValueChanged<ProductVersionItem> onCopy;
  final ValueChanged<ProductVersionItem> onEditNote;
  final ValueChanged<ProductVersionItem> onEditParameters;
  final ValueChanged<ProductVersionItem> onExport;
  final ValueChanged<ProductVersionItem> onDisable;
  final ValueChanged<ProductVersionItem> onDelete;
  final String Function(DateTime value) formatDate;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-version-table-section'),
      child: MesSectionCard(
        title: '版本列表',
        subtitle: '版本状态、备注、来源版本和动作入口保持既有业务语义。',
        expandChild: true,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : versions.isEmpty
            ? const MesEmptyState(
                title: '暂无版本记录',
                description: '请先创建新版本或复制既有版本。',
              )
            : SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 12,
                  columns: const [
                    DataColumn(label: Text('版本号')),
                    DataColumn(label: Text('状态')),
                    DataColumn(label: Text('变更摘要')),
                    DataColumn(label: Text('来源版本')),
                    DataColumn(label: Text('创建人')),
                    DataColumn(label: Text('创建时间')),
                    DataColumn(label: Text('生效时间')),
                    DataColumn(label: Text('操作')),
                  ],
                  rows: versions.map((version) {
                    final isDraft = version.lifecycleStatus == 'draft';
                    final isEffective = version.lifecycleStatus == 'effective';
                    final isObsolete = version.lifecycleStatus == 'obsolete';
                    return DataRow(
                      selected: selectedVersionNumber == version.version,
                      onSelectChanged: (_) => onSelectVersion(version.version),
                      cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                version.versionLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (isEffective) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: Color(0xFF1B8A5A),
                                ),
                              ],
                            ],
                          ),
                        ),
                        DataCell(_buildStatusChip(version.lifecycleStatus)),
                        DataCell(
                          Text(
                            version.note?.trim().isNotEmpty == true
                                ? version.note!
                                : '-',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DataCell(Text(version.sourceVersionLabel ?? '-')),
                        DataCell(Text(version.createdByUsername ?? '-')),
                        DataCell(Text(formatDate(version.createdAt))),
                        DataCell(
                          Text(
                            version.effectiveAt == null
                                ? '-'
                                : formatDate(version.effectiveAt!),
                          ),
                        ),
                        DataCell(
                          (canManageVersions ||
                                  canActivateVersions ||
                                  canExportVersionParameters)
                              ? PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 18),
                                  onSelected: (action) {
                                    switch (action) {
                                      case 'detail':
                                        onShowDetail(version);
                                        return;
                                      case 'activate':
                                        onActivate(version);
                                        return;
                                      case 'copy':
                                        onCopy(version);
                                        return;
                                      case 'editNote':
                                        onEditNote(version);
                                        return;
                                      case 'editParams':
                                        onEditParameters(version);
                                        return;
                                      case 'export':
                                        onExport(version);
                                        return;
                                      case 'disable':
                                        onDisable(version);
                                        return;
                                      case 'delete':
                                        onDelete(version);
                                        return;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'detail',
                                      child: Text('查看详情'),
                                    ),
                                    if (canActivateVersions && isDraft)
                                      const PopupMenuItem(
                                        value: 'activate',
                                        child: Text('立即生效'),
                                      ),
                                    if (canManageVersions &&
                                        (isDraft ||
                                            isEffective ||
                                            isObsolete ||
                                            version.lifecycleStatus == 'disabled'))
                                      const PopupMenuItem(
                                        value: 'copy',
                                        child: Text('复制版本'),
                                      ),
                                    if (canManageVersions)
                                      const PopupMenuItem(
                                        value: 'editNote',
                                        child: Text('编辑版本说明'),
                                      ),
                                    PopupMenuItem(
                                      value: 'editParams',
                                      child: Text(isDraft ? '维护参数' : '查看参数'),
                                    ),
                                    if (canExportVersionParameters)
                                      const PopupMenuItem(
                                        value: 'export',
                                        child: Text('导出版本参数'),
                                      ),
                                    if (canManageVersions && (isEffective || isObsolete))
                                      const PopupMenuItem(
                                        value: 'disable',
                                        child: Text('停用版本'),
                                      ),
                                    if (canManageVersions && isDraft)
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text(
                                          '删除版本',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    switch (status) {
      case 'effective':
        return MesStatusChip.success(label: '已生效');
      case 'draft':
        return MesStatusChip.warning(label: '草稿');
      case 'obsolete':
      case 'inactive':
        return MesStatusChip.warning(label: '已失效');
      case 'disabled':
        return MesStatusChip.warning(label: '已停用');
      default:
        return MesStatusChip.warning(label: status);
    }
  }
}
```

- [ ] **Step 4: 重新运行拆分组件测试，确认 widgets 可独立工作**

Run: `flutter test test/widgets/product_version_management_page_test.dart`

Expected: PASS

- [ ] **Step 5: 提交产品版本页展示层**

```bash
git add frontend/lib/features/product/presentation/widgets/product_version_page_header.dart frontend/lib/features/product/presentation/widgets/product_selector_panel.dart frontend/lib/features/product/presentation/widgets/product_version_feedback_banner.dart frontend/lib/features/product/presentation/widgets/product_version_toolbar.dart frontend/lib/features/product/presentation/widgets/product_version_table_section.dart frontend/test/widgets/product_version_management_page_test.dart
git commit -m "拆分产品版本页展示组件"
```

## 任务 3：迁移 `ProductVersionManagementPage` 到主从骨架

**Files:**
- Modify: `frontend/lib/features/product/presentation/product_version_management_page.dart`

- [ ] **Step 1: 先写失败测试，固定页面接入新骨架后的结构锚点**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/ui/patterns/mes_list_detail_shell.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/product_page.dart';
import 'package:mes_client/features/product/presentation/product_version_management_page.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_page_header.dart';
import 'package:mes_client/features/product/services/product_service.dart';

final DateTime _fixedDate = DateTime.parse('2026-04-20T00:00:00Z');

class _PageStructureService extends ProductService {
  _PageStructureService()
    : super(AppSession(baseUrl: '', accessToken: 'token'));

  @override
  Future<ProductListResult> listProducts({
    required int page,
    required int pageSize,
    String? keyword,
    String? category,
    String? lifecycleStatus,
    bool? hasEffectiveVersion,
    DateTime? updatedAfter,
    DateTime? updatedBefore,
    String? currentVersionKeyword,
    String? currentParamNameKeyword,
    String? currentParamCategoryKeyword,
  }) async {
    return ProductListResult(
      total: 2,
      items: [
        ProductItem(
          id: 101,
          name: '产品101',
          category: '贴片',
          remark: '',
          lifecycleStatus: 'active',
          currentVersion: 2,
          currentVersionLabel: 'V1.1',
          effectiveVersion: 1,
          effectiveVersionLabel: 'V1.0',
          effectiveAt: _fixedDate,
          inactiveReason: null,
          lastParameterSummary: null,
          createdAt: _fixedDate,
          updatedAt: _fixedDate,
        ),
        ProductItem(
          id: 102,
          name: '产品102',
          category: '贴片',
          remark: '',
          lifecycleStatus: 'inactive',
          currentVersion: 1,
          currentVersionLabel: 'V1.0',
          effectiveVersion: 0,
          effectiveVersionLabel: null,
          effectiveAt: null,
          inactiveReason: '当前无生效版本，请先将目标版本设为生效后再恢复启用。',
          lastParameterSummary: null,
          createdAt: _fixedDate,
          updatedAt: _fixedDate,
        ),
      ],
    );
  }

  @override
  Future<ProductVersionListResult> listProductVersions({
    required int productId,
  }) async {
    return ProductVersionListResult(
      total: 2,
      items: [
        ProductVersionItem(
          version: 2,
          versionLabel: 'V1.1',
          lifecycleStatus: 'draft',
          action: 'create',
          note: '草稿版本',
          effectiveAt: null,
          sourceVersion: 1,
          sourceVersionLabel: 'V1.0',
          createdByUserId: 1,
          createdByUsername: 'admin',
          createdAt: _fixedDate,
        ),
        ProductVersionItem(
          version: 1,
          versionLabel: 'V1.0',
          lifecycleStatus: 'effective',
          action: 'create',
          note: '当前生效',
          effectiveAt: _fixedDate,
          sourceVersion: null,
          sourceVersionLabel: null,
          createdByUserId: 1,
          createdByUsername: 'admin',
          createdAt: _fixedDate,
        ),
      ],
    );
  }
}

void main() {
  testWidgets('ProductVersionManagementPage 接入主从骨架并装配拆分组件', (tester) async {
    final service = _PageStructureService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1440,
            height: 900,
            child: ProductVersionManagementPage(
              session: AppSession(baseUrl: '', accessToken: 'token'),
              onLogout: () {},
              tabCode: productVersionManagementTabCode,
              canManageVersions: true,
              canActivateVersions: true,
              canExportVersionParameters: true,
              service: service,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('产品101'));
    await tester.pumpAndSettle();

    expect(find.byType(ProductVersionPageHeader), findsOneWidget);
    expect(find.byType(MesListDetailShell), findsOneWidget);
    expect(find.byKey(const ValueKey('product-selector-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-version-toolbar')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-version-table-section')), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行页面结构测试，确认主文件仍未迁移**

Run: `flutter test test/widgets/product_version_management_page_test.dart --plain-name "ProductVersionManagementPage 接入主从骨架并装配拆分组件"`

Expected: FAIL，断言找不到 `MesListDetailShell` 或 `ProductVersionPageHeader`

- [ ] **Step 3: 收敛主页面职责，接入 `MesListDetailShell` 和拆分组件**

```dart
// frontend/lib/features/product/presentation/product_version_management_page.dart
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_list_detail_shell.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_selector_panel.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_feedback_banner.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_page_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_table_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_toolbar.dart';
import 'package:mes_client/features/product/services/product_service.dart';

class ProductVersionManagementPage extends StatefulWidget {
  const ProductVersionManagementPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.tabCode,
    this.jumpCommand,
    this.onJumpHandled,
    this.onEditVersionParameters,
    required this.canManageVersions,
    this.canActivateVersions = false,
    this.canExportVersionParameters = false,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final String tabCode;
  final ProductJumpCommand? jumpCommand;
  final void Function(int seq)? onJumpHandled;
  final void Function(ProductItem product, ProductVersionItem version)?
  onEditVersionParameters;
  final bool canManageVersions;
  final bool canActivateVersions;
  final bool canExportVersionParameters;
  final ProductService? service;

  @override
  State<ProductVersionManagementPage> createState() =>
      _ProductVersionManagementPageState();
}

class _ProductVersionManagementPageState
    extends State<ProductVersionManagementPage> {
  late final ProductService _service;

  List<ProductItem> _products = [];
  int _productTotal = 0;
  int _productPage = 1;
  static const int _productPageSize = 50;
  bool _loadingProducts = false;
  String _productKeyword = '';
  String _pageMessage = '';
  final TextEditingController _searchController = TextEditingController();

  ProductItem? _selectedProduct;
  List<ProductVersionItem> _versions = [];
  bool _loadingVersions = false;
  int? _selectedVersionNumber;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProductService(widget.session);
    _loadProducts();
  }

  @override
  void didUpdateWidget(covariant ProductVersionManagementPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cmd = widget.jumpCommand;
    if (cmd != null &&
        cmd.targetTabCode == widget.tabCode &&
        cmd.seq != oldWidget.jumpCommand?.seq) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.jumpCommand?.seq != cmd.seq) {
          return;
        }
        _handleJump(cmd);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleJump(ProductJumpCommand cmd) {
    widget.onJumpHandled?.call(cmd.seq);
    _selectProductById(cmd.productId);
  }

  Future<void> _selectProductById(int productId) async {
    try {
      final product = await _service.getProduct(productId: productId);
      setState(() {
        _selectedProduct = product;
      });
      await _loadVersions(product);
    } catch (_) {}
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _pageMessage = '';
    });
    try {
      final result = await _service.listProducts(
        page: _productPage,
        pageSize: _productPageSize,
        keyword: _productKeyword.isEmpty ? null : _productKeyword,
      );
      setState(() {
        _products = result.items;
        _productTotal = result.total;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pageMessage = '加载产品列表失败：$error';
      });
      _showError('加载产品列表失败: $error');
    } finally {
      if (mounted) {
        setState(() => _loadingProducts = false);
      }
    }
  }

  Future<void> _loadVersions(
    ProductItem product, {
    int? preferredVersionNumber,
  }) async {
    setState(() {
      _selectedProduct = product;
      _loadingVersions = true;
      _versions = [];
      _selectedVersionNumber = null;
      _pageMessage = '';
    });
    try {
      final result = await _service.listProductVersions(productId: product.id);
      setState(() {
        _versions = result.items;
        int? matchedVersionNumber;
        if (preferredVersionNumber != null) {
          for (final item in result.items) {
            if (item.version == preferredVersionNumber) {
              matchedVersionNumber = item.version;
              break;
            }
          }
        }
        _selectedVersionNumber =
            matchedVersionNumber ??
            (result.items.isEmpty ? null : result.items.first.version);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pageMessage = '加载版本列表失败：$error';
      });
      _showError('加载版本列表失败: $error');
    } finally {
      if (mounted) {
        setState(() => _loadingVersions = false);
      }
    }
  }

  ProductVersionItem? get _selectedVersion {
    final selectedVersionNumber = _selectedVersionNumber;
    if (selectedVersionNumber == null) {
      return null;
    }
    for (final item in _versions) {
      if (item.version == selectedVersionNumber) {
        return item;
      }
    }
    return _versions.isEmpty ? null : _versions.first;
  }

  ProductVersionItem? get _effectiveVersion {
    for (final item in _versions) {
      if (item.lifecycleStatus == 'effective') {
        return item;
      }
    }
    return null;
  }

  bool get _hasDraftVersion {
    for (final item in _versions) {
      if (item.lifecycleStatus == 'draft') {
        return true;
      }
    }
    return false;
  }

  int get _productTotalPages {
    if (_productTotal <= 0) {
      return 1;
    }
    return ((_productTotal - 1) ~/ _productPageSize) + 1;
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  Future<void> _createVersion() async {
    final product = _selectedProduct;
    if (product == null) return;
    try {
      await _service.createProductVersion(productId: product.id);
      _showSuccess('新建版本成功');
      await _reloadSelectedProductAndVersions(product.id);
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('新建版本失败: $error');
    }
  }

  Future<void> _copyVersion(ProductVersionItem source) async {
    final product = _selectedProduct;
    if (product == null) return;
    try {
      await _service.copyProductVersion(
        productId: product.id,
        sourceVersion: source.version,
      );
      _showSuccess('复制版本成功（来源：${source.versionLabel}）');
      await _reloadSelectedProductAndVersions(product.id);
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('复制版本失败: $error');
    }
  }

  Future<void> _activateVersion(ProductVersionItem revision) async {
    final product = _selectedProduct;
    if (product == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认生效'),
        content: Text(
          '确认将版本 ${revision.versionLabel} 设为生效版本？\n生效后，当前生效版本将自动变为已失效。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认生效'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.activateProductVersion(
        productId: product.id,
        version: revision.version,
        confirmed: true,
        expectedEffectiveVersion: product.effectiveVersion,
      );
      await _reloadSelectedProductAndVersions(product.id);
      _showSuccess('版本 ${revision.versionLabel} 已生效');
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('生效失败: $error');
    }
  }

  Future<void> _disableVersion(ProductVersionItem revision) async {
    final product = _selectedProduct;
    if (product == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认停用'),
        content: Text(
          '确认停用版本 ${revision.versionLabel}？停用后不可直接恢复，如需再次使用请复制出新草稿。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认停用'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.disableProductVersion(
        productId: product.id,
        version: revision.version,
      );
      final refreshedProduct = await _reloadSelectedProductAndVersions(product.id);
      _showSuccess(
        refreshedProduct != null &&
                refreshedProduct.lifecycleStatus == 'inactive'
            ? '版本 ${revision.versionLabel} 已停用，产品因无生效版本已同步停用'
            : '版本 ${revision.versionLabel} 已停用',
      );
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('停用失败: $error');
    }
  }

  Future<void> _deleteVersion(ProductVersionItem revision) async {
    final product = _selectedProduct;
    if (product == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确认删除草稿版本 ${revision.versionLabel}？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteProductVersion(
        productId: product.id,
        version: revision.version,
      );
      _showSuccess('版本 ${revision.versionLabel} 已删除');
      await _reloadSelectedProductAndVersions(product.id);
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('删除失败: $error');
    }
  }

  Future<void> _showVersionDetail(ProductVersionItem revision) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('版本详情 - ${revision.versionLabel}'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow('版本号', revision.versionLabel),
                _detailRow(
                  '状态',
                  _statusLabel(revision.lifecycleStatus),
                ),
                _detailRow('变更摘要', revision.note ?? '-'),
                _detailRow('来源版本', revision.sourceVersionLabel ?? '-'),
                _detailRow('创建人', revision.createdByUsername ?? '-'),
                _detailRow('创建时间', _formatDate(revision.createdAt)),
                if (revision.updatedAt != null)
                  _detailRow('最后更新', _formatDate(revision.updatedAt!)),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  Future<void> _editVersionNote(ProductVersionItem revision) async {
    final product = _selectedProduct;
    if (product == null) return;
    final controller = TextEditingController(text: revision.note ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('编辑备注 - ${revision.versionLabel}'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            maxLength: 256,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '版本备注',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    if (result == null) return;
    try {
      await _service.updateProductVersionNote(
        productId: product.id,
        version: revision.version,
        note: result,
      );
      _showSuccess('备注已更新');
      await _loadVersions(product);
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('更新备注失败: $error');
    }
  }

  void _navigateToEditParams(ProductVersionItem revision) {
    final product = _selectedProduct;
    if (product == null) return;
    widget.onEditVersionParameters?.call(product, revision);
  }

  Future<ProductItem?> _reloadSelectedProductAndVersions(int productId) async {
    try {
      final product = await _service.getProduct(productId: productId);
      if (!mounted) return null;
      await _loadVersions(
        product,
        preferredVersionNumber: _selectedVersionNumber,
      );
      return product;
    } catch (error) {
      if (mounted) {
        setState(() {
          _pageMessage = '刷新产品状态失败：$error';
        });
        _showError('刷新产品状态失败: $error');
      }
      return null;
    }
  }

  Future<void> _refreshPage() async {
    final selectedProductId = _selectedProduct?.id;
    await _loadProducts();
    if (!mounted || selectedProductId == null) {
      return;
    }
    await _reloadSelectedProductAndVersions(selectedProductId);
  }

  Future<void> _exportVersionParams(ProductVersionItem revision) async {
    final product = _selectedProduct;
    if (product == null) return;
    try {
      final bytes = await _service.exportProductVersionParameters(
        productId: product.id,
        version: revision.version,
      );
      final fileName = '${product.name}_${revision.versionLabel}_参数.csv';
      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: [
          const XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (location == null) return;
      final file = XFile.fromData(
        Uint8List.fromList(bytes),
        mimeType: 'text/csv',
        name: fileName,
      );
      await file.saveTo(location.path);
      _showSuccess('导出成功');
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('导出失败: $error');
    }
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final selectedProduct = _selectedProduct;
    final selectedVersion = _selectedVersion;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductVersionPageHeader(
            loading: _loadingProducts || _loadingVersions,
            onRefresh: _refreshPage,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: MesListDetailShell(
              banner: ProductVersionFeedbackBanner(
                message: _pageMessage,
                hasDraft: _hasDraftVersion,
                product: selectedProduct,
                effectiveVersion: _effectiveVersion,
                formatDate: _formatDate,
              ),
              sidebar: ProductSelectorPanel(
                searchController: _searchController,
                loading: _loadingProducts,
                products: _products,
                selectedProductId: selectedProduct?.id,
                page: _productPage,
                totalPages: _productTotalPages,
                total: _productTotal,
                onSearchSubmitted: (value) {
                  _productKeyword = value.trim();
                  _productPage = 1;
                  _loadProducts();
                },
                onRefresh: _loadProducts,
                onSelectProduct: (product) => _loadVersions(product),
                onPreviousPage: _productPage > 1
                    ? () {
                        _productPage -= 1;
                        _loadProducts();
                      }
                    : null,
                onNextPage: _productPage < _productTotalPages
                    ? () {
                        _productPage += 1;
                        _loadProducts();
                      }
                    : null,
              ),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProductVersionToolbar(
                    product: selectedProduct,
                    selectedVersion: selectedVersion,
                    hasDraft: _hasDraftVersion,
                    canManageVersions: widget.canManageVersions,
                    canActivateVersions: widget.canActivateVersions,
                    canExportVersionParameters:
                        widget.canExportVersionParameters,
                    onCreateVersion: _createVersion,
                    onCopyVersion: () {
                      if (selectedVersion != null) {
                        _copyVersion(selectedVersion);
                      }
                    },
                    onEditVersionNote: () {
                      if (selectedVersion != null) {
                        _editVersionNote(selectedVersion);
                      }
                    },
                    onExportParameters: () {
                      if (selectedVersion != null) {
                        _exportVersionParams(selectedVersion);
                      }
                    },
                    onActivateVersion: () {
                      if (selectedVersion != null) {
                        _activateVersion(selectedVersion);
                      }
                    },
                    onRefresh: () {
                      if (selectedProduct != null) {
                        _loadVersions(selectedProduct);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: selectedProduct == null
                        ? const Center(child: Text('请在左侧选择产品'))
                        : ProductVersionTableSection(
                            versions: _versions,
                            loading: _loadingVersions,
                            selectedVersionNumber: _selectedVersionNumber,
                            canManageVersions: widget.canManageVersions,
                            canActivateVersions: widget.canActivateVersions,
                            canExportVersionParameters:
                                widget.canExportVersionParameters,
                            onSelectVersion: (versionNumber) {
                              setState(() {
                                _selectedVersionNumber = versionNumber;
                              });
                            },
                            onShowDetail: _showVersionDetail,
                            onActivate: _activateVersion,
                            onCopy: _copyVersion,
                            onEditNote: _editVersionNote,
                            onEditParameters: _navigateToEditParams,
                            onExport: _exportVersionParams,
                            onDisable: _disableVersion,
                            onDelete: _deleteVersion,
                            formatDate: _formatDate,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 重新运行页面结构测试，确认主页面迁移完成**

Run: `flutter test test/widgets/product_version_management_page_test.dart --plain-name "ProductVersionManagementPage 接入主从骨架并装配拆分组件"`

Expected: PASS

- [ ] **Step 5: 提交页面主文件迁移**

```bash
git add frontend/lib/features/product/presentation/product_version_management_page.dart
git commit -m "迁移产品版本管理页到主从骨架"
```

## 任务 4：补齐页面级 widget test，并扩展产品模块回归断言

**Files:**
- Modify: `frontend/test/widgets/product_version_management_page_test.dart`
- Modify: `frontend/test/widgets/product_module_issue_regression_test.dart`

- [ ] **Step 1: 先写失败测试，固定新骨架锚点与既有行为回归共同成立**

```dart
// frontend/test/widgets/product_version_management_page_test.dart
testWidgets('ProductVersionManagementPage 窄宽度下仍保留产品区与版本工作区', (tester) async {
  final service = _PageStructureService();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 760,
          height: 900,
          child: ProductVersionManagementPage(
            session: AppSession(baseUrl: '', accessToken: 'token'),
            onLogout: () {},
            tabCode: productVersionManagementTabCode,
            canManageVersions: true,
            canActivateVersions: true,
            canExportVersionParameters: true,
            service: service,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('产品101'));
  await tester.pumpAndSettle();

  final sidebarRect = tester.getRect(
    find.byKey(const ValueKey('mes-list-detail-shell-sidebar')),
  );
  final contentRect = tester.getRect(
    find.byKey(const ValueKey('mes-list-detail-shell-content')),
  );

  expect(sidebarRect.top, lessThan(contentRect.top));
  expect(find.byKey(const ValueKey('product-version-toolbar')), findsOneWidget);
  expect(find.byKey(const ValueKey('product-version-table-section')), findsOneWidget);
});
```

```dart
// frontend/test/widgets/product_module_issue_regression_test.dart
testWidgets('版本管理页应提示停用产品需先生效版本', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final service = _VersionListService(
    products: [
      _buildProduct(
        id: 1,
        currentVersion: 1,
        effectiveVersion: 0,
        lifecycleStatus: 'inactive',
        inactiveReason: '当前无生效版本，请前往版本管理生效版本后恢复启用',
      ),
    ],
    versions: const [],
  );

  await tester.pumpWidget(
    _host(
      ProductVersionManagementPage(
        session: _session(),
        onLogout: () {},
        tabCode: productVersionManagementTabCode,
        canManageVersions: true,
        canActivateVersions: true,
        canExportVersionParameters: true,
        service: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('产品1'));
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('product-version-feedback-banner')), findsOneWidget);
  expect(find.text('当前无生效版本，请前往版本管理生效版本后恢复启用'), findsOneWidget);
});

testWidgets('版本管理页顶部应显式展示复制版本和导出参数入口', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final service = _VersionListService(
    products: [
      _buildProduct(id: 61, currentVersion: 2, effectiveVersion: 1),
    ],
    versions: [
      _buildVersion(version: 2, versionLabel: 'V1.1', lifecycleStatus: 'draft'),
      _buildVersion(version: 1, versionLabel: 'V1.0', lifecycleStatus: 'effective'),
    ],
  );

  await tester.pumpWidget(
    _host(
      ProductVersionManagementPage(
        session: _session(),
        onLogout: () {},
        tabCode: productVersionManagementTabCode,
        canManageVersions: true,
        canActivateVersions: true,
        canExportVersionParameters: true,
        service: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('产品61'));
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('product-version-toolbar')), findsOneWidget);
  expect(find.widgetWithText(OutlinedButton, '复制版本'), findsOneWidget);
  expect(find.widgetWithText(OutlinedButton, '导出参数'), findsOneWidget);
  expect(find.widgetWithText(OutlinedButton, '编辑版本说明'), findsOneWidget);
  expect(find.widgetWithText(FilledButton, '立即生效'), findsOneWidget);
});
```

- [ ] **Step 2: 运行页面级测试和既有产品模块回归，确认新锚点尚未补齐**

Run: `flutter test test/widgets/product_version_management_page_test.dart test/widgets/product_module_issue_regression_test.dart`

Expected: FAIL，至少包含：
- 页面级测试找不到窄宽度锚点或 `MesListDetailShell`
- 产品模块回归找不到 `product-version-feedback-banner` 或 `product-version-toolbar`

- [ ] **Step 3: 扩展页面级测试与回归断言**

```dart
// frontend/test/widgets/product_version_management_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/ui/patterns/mes_list_detail_shell.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/product_page.dart';
import 'package:mes_client/features/product/presentation/product_version_management_page.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_page_header.dart';
import 'package:mes_client/features/product/services/product_service.dart';

final DateTime _fixedDate = DateTime.parse('2026-04-20T00:00:00Z');

class _PageStructureService extends ProductService {
  _PageStructureService()
    : super(AppSession(baseUrl: '', accessToken: 'token'));

  @override
  Future<ProductListResult> listProducts({
    required int page,
    required int pageSize,
    String? keyword,
    String? category,
    String? lifecycleStatus,
    bool? hasEffectiveVersion,
    DateTime? updatedAfter,
    DateTime? updatedBefore,
    String? currentVersionKeyword,
    String? currentParamNameKeyword,
    String? currentParamCategoryKeyword,
  }) async {
    return ProductListResult(
      total: 2,
      items: [
        ProductItem(
          id: 101,
          name: '产品101',
          category: '贴片',
          remark: '',
          lifecycleStatus: 'active',
          currentVersion: 2,
          currentVersionLabel: 'V1.1',
          effectiveVersion: 1,
          effectiveVersionLabel: 'V1.0',
          effectiveAt: _fixedDate,
          inactiveReason: null,
          lastParameterSummary: null,
          createdAt: _fixedDate,
          updatedAt: _fixedDate,
        ),
        ProductItem(
          id: 102,
          name: '产品102',
          category: '贴片',
          remark: '',
          lifecycleStatus: 'inactive',
          currentVersion: 1,
          currentVersionLabel: 'V1.0',
          effectiveVersion: 0,
          effectiveVersionLabel: null,
          effectiveAt: null,
          inactiveReason: '当前无生效版本，请先将目标版本设为生效后再恢复启用。',
          lastParameterSummary: null,
          createdAt: _fixedDate,
          updatedAt: _fixedDate,
        ),
      ],
    );
  }

  @override
  Future<ProductVersionListResult> listProductVersions({
    required int productId,
  }) async {
    return ProductVersionListResult(
      total: 2,
      items: [
        ProductVersionItem(
          version: 2,
          versionLabel: 'V1.1',
          lifecycleStatus: 'draft',
          action: 'create',
          note: '草稿版本',
          effectiveAt: null,
          sourceVersion: 1,
          sourceVersionLabel: 'V1.0',
          createdByUserId: 1,
          createdByUsername: 'admin',
          createdAt: _fixedDate,
        ),
        ProductVersionItem(
          version: 1,
          versionLabel: 'V1.0',
          lifecycleStatus: 'effective',
          action: 'create',
          note: '当前生效',
          effectiveAt: _fixedDate,
          sourceVersion: null,
          sourceVersionLabel: null,
          createdByUserId: 1,
          createdByUsername: 'admin',
          createdAt: _fixedDate,
        ),
      ],
    );
  }

  @override
  Future<ProductItem> getProduct({required int productId}) async {
    return ProductItem(
      id: productId,
      name: '产品$productId',
      category: '贴片',
      remark: '',
      lifecycleStatus: productId == 102 ? 'inactive' : 'active',
      currentVersion: 2,
      currentVersionLabel: 'V1.1',
      effectiveVersion: productId == 102 ? 0 : 1,
      effectiveVersionLabel: productId == 102 ? null : 'V1.0',
      effectiveAt: productId == 102 ? null : _fixedDate,
      inactiveReason: productId == 102
          ? '当前无生效版本，请先将目标版本设为生效后再恢复启用。'
          : null,
      lastParameterSummary: null,
      createdAt: _fixedDate,
      updatedAt: _fixedDate,
    );
  }
}

Future<void> _pumpPage(WidgetTester tester, double width) async {
  final service = _PageStructureService();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 900,
          child: ProductVersionManagementPage(
            session: AppSession(baseUrl: '', accessToken: 'token'),
            onLogout: () {},
            tabCode: productVersionManagementTabCode,
            canManageVersions: true,
            canActivateVersions: true,
            canExportVersionParameters: true,
            service: service,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ProductVersionManagementPage 接入主从骨架并装配拆分组件', (tester) async {
    await _pumpPage(tester, 1440);
    await tester.tap(find.text('产品101'));
    await tester.pumpAndSettle();

    expect(find.byType(ProductVersionPageHeader), findsOneWidget);
    expect(find.byType(MesListDetailShell), findsOneWidget);
    expect(find.byKey(const ValueKey('product-selector-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-version-toolbar')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-version-table-section')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-version-feedback-banner')), findsOneWidget);
  });

  testWidgets('ProductVersionManagementPage 窄宽度下仍保留产品区与版本工作区', (tester) async {
    await _pumpPage(tester, 760);
    await tester.tap(find.text('产品101'));
    await tester.pumpAndSettle();

    final sidebarRect = tester.getRect(
      find.byKey(const ValueKey('mes-list-detail-shell-sidebar')),
    );
    final contentRect = tester.getRect(
      find.byKey(const ValueKey('mes-list-detail-shell-content')),
    );

    expect(sidebarRect.top, lessThan(contentRect.top));
    expect(find.byKey(const ValueKey('product-version-toolbar')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-version-table-section')), findsOneWidget);
  });
}
```

```dart
// frontend/test/widgets/product_module_issue_regression_test.dart
testWidgets('版本管理页应提示停用产品需先生效版本', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final service = _VersionListService(
    products: [
      _buildProduct(
        id: 1,
        currentVersion: 1,
        effectiveVersion: 0,
        lifecycleStatus: 'inactive',
        inactiveReason: '当前无生效版本，请前往版本管理生效版本后恢复启用',
      ),
    ],
    versions: const [],
  );

  await tester.pumpWidget(
    _host(
      ProductVersionManagementPage(
        session: _session(),
        onLogout: () {},
        tabCode: productVersionManagementTabCode,
        canManageVersions: true,
        canActivateVersions: true,
        canExportVersionParameters: true,
        service: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('产品1'));
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('product-version-feedback-banner')), findsOneWidget);
  expect(find.text('当前无生效版本，请前往版本管理生效版本后恢复启用'), findsOneWidget);
});

testWidgets('版本管理页顶部应显式展示复制版本和导出参数入口', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final service = _VersionListService(
    products: [
      _buildProduct(id: 61, currentVersion: 2, effectiveVersion: 1),
    ],
    versions: [
      _buildVersion(version: 2, versionLabel: 'V1.1', lifecycleStatus: 'draft'),
      _buildVersion(version: 1, versionLabel: 'V1.0', lifecycleStatus: 'effective'),
    ],
  );

  await tester.pumpWidget(
    _host(
      ProductVersionManagementPage(
        session: _session(),
        onLogout: () {},
        tabCode: productVersionManagementTabCode,
        canManageVersions: true,
        canActivateVersions: true,
        canExportVersionParameters: true,
        service: service,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('产品61'));
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('product-version-toolbar')), findsOneWidget);
  expect(find.widgetWithText(OutlinedButton, '复制版本'), findsOneWidget);
  expect(find.widgetWithText(OutlinedButton, '导出参数'), findsOneWidget);
  expect(find.widgetWithText(OutlinedButton, '编辑版本说明'), findsOneWidget);
  expect(find.widgetWithText(FilledButton, '立即生效'), findsOneWidget);
});
```

- [ ] **Step 4: 重新运行页面级与产品模块回归测试**

Run: `flutter test test/widgets/product_version_management_page_test.dart test/widgets/product_module_issue_regression_test.dart`

Expected: PASS

- [ ] **Step 5: 提交页面级回归补强**

```bash
git add frontend/test/widgets/product_version_management_page_test.dart frontend/test/widgets/product_module_issue_regression_test.dart
git commit -m "补齐产品版本页页面级回归"
```

## 任务 5：补齐产品版本管理页 integration 主路径

**Files:**
- Create: `frontend/integration_test/product_version_flow_test.dart`

- [ ] **Step 1: 先写失败的 integration test，固定产品选择到右侧工作区的主路径**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/product_page.dart';
import 'package:mes_client/features/product/presentation/product_version_management_page.dart';
import 'package:mes_client/features/product/services/product_service.dart';

final DateTime _fixedDate = DateTime.parse('2026-04-20T00:00:00Z');

class _IntegrationProductService extends ProductService {
  _IntegrationProductService()
    : super(AppSession(baseUrl: '', accessToken: 'token'));

  @override
  Future<ProductListResult> listProducts({
    required int page,
    required int pageSize,
    String? keyword,
    String? category,
    String? lifecycleStatus,
    bool? hasEffectiveVersion,
    DateTime? updatedAfter,
    DateTime? updatedBefore,
    String? currentVersionKeyword,
    String? currentParamNameKeyword,
    String? currentParamCategoryKeyword,
  }) async {
    return ProductListResult(
      total: 2,
      items: [
        ProductItem(
          id: 101,
          name: '产品101',
          category: '贴片',
          remark: '',
          lifecycleStatus: 'active',
          currentVersion: 2,
          currentVersionLabel: 'V1.1',
          effectiveVersion: 1,
          effectiveVersionLabel: 'V1.0',
          effectiveAt: _fixedDate,
          inactiveReason: null,
          lastParameterSummary: null,
          createdAt: _fixedDate,
          updatedAt: _fixedDate,
        ),
        ProductItem(
          id: 102,
          name: '产品102',
          category: '贴片',
          remark: '',
          lifecycleStatus: 'inactive',
          currentVersion: 1,
          currentVersionLabel: 'V1.0',
          effectiveVersion: 0,
          effectiveVersionLabel: null,
          effectiveAt: null,
          inactiveReason: '当前无生效版本，请先将目标版本设为生效后再恢复启用。',
          lastParameterSummary: null,
          createdAt: _fixedDate,
          updatedAt: _fixedDate,
        ),
      ],
    );
  }

  @override
  Future<ProductVersionListResult> listProductVersions({
    required int productId,
  }) async {
    return ProductVersionListResult(
      total: 2,
      items: [
        ProductVersionItem(
          version: 2,
          versionLabel: 'V1.1',
          lifecycleStatus: 'draft',
          action: 'create',
          note: '草稿版本',
          effectiveAt: null,
          sourceVersion: 1,
          sourceVersionLabel: 'V1.0',
          createdByUserId: 1,
          createdByUsername: 'admin',
          createdAt: _fixedDate,
        ),
        ProductVersionItem(
          version: 1,
          versionLabel: 'V1.0',
          lifecycleStatus: 'effective',
          action: 'create',
          note: '当前生效',
          effectiveAt: _fixedDate,
          sourceVersion: null,
          sourceVersionLabel: null,
          createdByUserId: 1,
          createdByUsername: 'admin',
          createdAt: _fixedDate,
        ),
      ],
    );
  }

  @override
  Future<ProductItem> getProduct({required int productId}) async {
    return ProductItem(
      id: productId,
      name: '产品$productId',
      category: '贴片',
      remark: '',
      lifecycleStatus: productId == 102 ? 'inactive' : 'active',
      currentVersion: 2,
      currentVersionLabel: 'V1.1',
      effectiveVersion: productId == 102 ? 0 : 1,
      effectiveVersionLabel: productId == 102 ? null : 'V1.0',
      effectiveAt: productId == 102 ? null : _fixedDate,
      inactiveReason: productId == 102
          ? '当前无生效版本，请先将目标版本设为生效后再恢复启用。'
          : null,
      lastParameterSummary: null,
      createdAt: _fixedDate,
      updatedAt: _fixedDate,
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('产品版本管理页主路径展示产品区与版本工作区', (tester) async {
    final service = _IntegrationProductService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1440,
            height: 900,
            child: ProductVersionManagementPage(
              session: AppSession(baseUrl: '', accessToken: 'token'),
              onLogout: () {},
              tabCode: productVersionManagementTabCode,
              canManageVersions: true,
              canActivateVersions: true,
              canExportVersionParameters: true,
              service: service,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('版本管理'), findsOneWidget);
    expect(find.byKey(const ValueKey('product-selector-panel')), findsOneWidget);

    await tester.tap(find.text('产品101'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('product-version-toolbar')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-version-table-section')), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '复制版本'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行 integration test，确认主路径观察点尚未建立**

Run: `flutter test -d windows integration_test/product_version_flow_test.dart`

Expected: FAIL，报错包含 `No such file or directory` 或断言找不到新锚点

- [ ] **Step 3: 新增产品版本管理页 integration 主路径**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/product_page.dart';
import 'package:mes_client/features/product/presentation/product_version_management_page.dart';
import 'package:mes_client/features/product/services/product_service.dart';

final DateTime _fixedDate = DateTime.parse('2026-04-20T00:00:00Z');

class _IntegrationProductService extends ProductService {
  _IntegrationProductService()
    : super(AppSession(baseUrl: '', accessToken: 'token'));

  @override
  Future<ProductListResult> listProducts({
    required int page,
    required int pageSize,
    String? keyword,
    String? category,
    String? lifecycleStatus,
    bool? hasEffectiveVersion,
    DateTime? updatedAfter,
    DateTime? updatedBefore,
    String? currentVersionKeyword,
    String? currentParamNameKeyword,
    String? currentParamCategoryKeyword,
  }) async {
    return ProductListResult(
      total: 2,
      items: [
        ProductItem(
          id: 101,
          name: '产品101',
          category: '贴片',
          remark: '',
          lifecycleStatus: 'active',
          currentVersion: 2,
          currentVersionLabel: 'V1.1',
          effectiveVersion: 1,
          effectiveVersionLabel: 'V1.0',
          effectiveAt: _fixedDate,
          inactiveReason: null,
          lastParameterSummary: null,
          createdAt: _fixedDate,
          updatedAt: _fixedDate,
        ),
        ProductItem(
          id: 102,
          name: '产品102',
          category: '贴片',
          remark: '',
          lifecycleStatus: 'inactive',
          currentVersion: 1,
          currentVersionLabel: 'V1.0',
          effectiveVersion: 0,
          effectiveVersionLabel: null,
          effectiveAt: null,
          inactiveReason: '当前无生效版本，请先将目标版本设为生效后再恢复启用。',
          lastParameterSummary: null,
          createdAt: _fixedDate,
          updatedAt: _fixedDate,
        ),
      ],
    );
  }

  @override
  Future<ProductVersionListResult> listProductVersions({
    required int productId,
  }) async {
    return ProductVersionListResult(
      total: 2,
      items: [
        ProductVersionItem(
          version: 2,
          versionLabel: 'V1.1',
          lifecycleStatus: 'draft',
          action: 'create',
          note: '草稿版本',
          effectiveAt: null,
          sourceVersion: 1,
          sourceVersionLabel: 'V1.0',
          createdByUserId: 1,
          createdByUsername: 'admin',
          createdAt: _fixedDate,
        ),
        ProductVersionItem(
          version: 1,
          versionLabel: 'V1.0',
          lifecycleStatus: 'effective',
          action: 'create',
          note: '当前生效',
          effectiveAt: _fixedDate,
          sourceVersion: null,
          sourceVersionLabel: null,
          createdByUserId: 1,
          createdByUsername: 'admin',
          createdAt: _fixedDate,
        ),
      ],
    );
  }

  @override
  Future<ProductItem> getProduct({required int productId}) async {
    return ProductItem(
      id: productId,
      name: '产品$productId',
      category: '贴片',
      remark: '',
      lifecycleStatus: productId == 102 ? 'inactive' : 'active',
      currentVersion: 2,
      currentVersionLabel: 'V1.1',
      effectiveVersion: productId == 102 ? 0 : 1,
      effectiveVersionLabel: productId == 102 ? null : 'V1.0',
      effectiveAt: productId == 102 ? null : _fixedDate,
      inactiveReason: productId == 102
          ? '当前无生效版本，请先将目标版本设为生效后再恢复启用。'
          : null,
      lastParameterSummary: null,
      createdAt: _fixedDate,
      updatedAt: _fixedDate,
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('产品版本管理页主路径展示产品区与版本工作区', (tester) async {
    final service = _IntegrationProductService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1440,
            height: 900,
            child: ProductVersionManagementPage(
              session: AppSession(baseUrl: '', accessToken: 'token'),
              onLogout: () {},
              tabCode: productVersionManagementTabCode,
              canManageVersions: true,
              canActivateVersions: true,
              canExportVersionParameters: true,
              service: service,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('版本管理'), findsOneWidget);
    expect(find.byKey(const ValueKey('product-selector-panel')), findsOneWidget);

    await tester.tap(find.text('产品101'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('product-version-toolbar')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-version-table-section')), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '复制版本'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '导出参数'), findsOneWidget);
  });
}
```

- [ ] **Step 4: 重新运行 integration test**

Run: `flutter test -d windows integration_test/product_version_flow_test.dart`

Expected: PASS

- [ ] **Step 5: 提交产品版本管理页 integration 观察点**

```bash
git add frontend/integration_test/product_version_flow_test.dart
git commit -m "新增产品版本页集成观察点"
```

## 任务 6：补齐 evidence、静态检查与最终验证闭环

**Files:**
- Create: `evidence/2026-04-20_产品版本管理页第二波迁移实施.md`

- [ ] **Step 1: 先写实施 evidence 模板，固定任务拆分、验证命令和迁移口径**

```md
# 任务日志：产品版本管理页第二波迁移实施

- 日期：2026-04-20
- 执行人：Codex
- 当前状态：已完成

## 1. 输入来源
- 用户指令：按已批准设计继续实施产品版本管理页第二波迁移
- 设计规格：`docs/superpowers/specs/2026-04-20-product-version-management-page-second-wave-design.md`
- 实施计划：`docs/superpowers/plans/2026-04-20-product-version-management-page-second-wave-implementation.md`

## 2. 实施分段
- 任务 1：新增主从页面骨架 `MesListDetailShell`
- 任务 2：建立产品版本页展示层 widgets
- 任务 3：迁移 `ProductVersionManagementPage` 到主从骨架
- 任务 4：补齐页面级 widget test，并扩展产品模块回归断言
- 任务 5：补齐产品版本管理页 integration 主路径
- 任务 6：补齐 evidence、静态检查与最终验证闭环

## 3. 验证结果
- flutter analyze：通过
- flutter test test/widgets/ui/mes_patterns_test.dart：通过
- flutter test test/widgets/product_version_management_page_test.dart test/widgets/product_module_issue_regression_test.dart：通过
- flutter test -d windows integration_test/product_version_flow_test.dart：通过

## 4. 风险与补偿
- 当前 integration 仅覆盖桌面主路径，不扩展到完整业务弹窗链路；复杂动作链路继续由 `product_module_issue_regression_test.dart` 兜底

## 5. 迁移说明
- 无迁移，直接替换
```

- [ ] **Step 2: 运行 analyze、widget、integration，确认第二波迁移完整通过**

Run: `flutter analyze`

Expected: `No issues found!`

Run: `flutter test test/widgets/ui/mes_patterns_test.dart test/widgets/product_version_management_page_test.dart test/widgets/product_module_issue_regression_test.dart`

Expected: PASS

Run: `flutter test -d windows integration_test/product_version_flow_test.dart`

Expected: PASS

- [ ] **Step 3: 创建实施 evidence 并记录真实结果**

```md
# 任务日志：产品版本管理页第二波迁移实施

- 日期：2026-04-20
- 执行人：Codex
- 当前状态：已完成

## 1. 输入来源
- 用户指令：按已批准设计继续实施产品版本管理页第二波迁移
- 设计规格：`docs/superpowers/specs/2026-04-20-product-version-management-page-second-wave-design.md`
- 实施计划：`docs/superpowers/plans/2026-04-20-product-version-management-page-second-wave-implementation.md`

## 2. 实施分段
- 任务 1：新增主从页面骨架 `MesListDetailShell`
- 任务 2：建立产品版本页展示层 widgets
- 任务 3：迁移 `ProductVersionManagementPage` 到主从骨架
- 任务 4：补齐页面级 widget test，并扩展产品模块回归断言
- 任务 5：补齐产品版本管理页 integration 主路径
- 任务 6：补齐 evidence、静态检查与最终验证闭环

## 3. 验证结果
- flutter analyze：通过
- flutter test test/widgets/ui/mes_patterns_test.dart：通过
- flutter test test/widgets/product_version_management_page_test.dart test/widgets/product_module_issue_regression_test.dart：通过
- flutter test -d windows integration_test/product_version_flow_test.dart：通过

## 4. 风险与补偿
- 当前 integration 仅覆盖桌面主路径，不扩展到完整业务弹窗链路；复杂动作链路继续由 `product_module_issue_regression_test.dart` 兜底

## 5. 迁移说明
- 无迁移，直接替换
```

- [ ] **Step 4: 提交验证与 evidence**

```bash
git add evidence/2026-04-20_产品版本管理页第二波迁移实施.md
git commit -m "补齐产品版本页迁移验证留痕"
```
