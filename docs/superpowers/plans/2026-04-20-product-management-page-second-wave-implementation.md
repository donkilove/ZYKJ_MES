# 产品管理页第二波迁移 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 Flutter 前端中完成产品管理页第二波 UI 迁移，统一主页面骨架，拆分详情侧栏和版本管理弹窗展示层，并补齐 widget / integration / evidence 闭环。

**Architecture:** 先在 `features/product/presentation/widgets/` 建立产品管理页的基础展示组件，包括页头、筛选区、反馈区、表格区和状态薄包装，再将 `ProductManagementPage` 接入 `MesCrudPageScaffold`。在此基础上继续拆出 `ProductDetailDrawer` 和 `ProductVersionDialog` 展示层，保持服务调用、权限判断、动作入口和状态管理留在主页面。测试按“基础展示组件 -> 主页面统一骨架 -> 详情侧栏 -> 版本管理弹窗 -> 回归 / integration / evidence”顺序推进，现有业务语义保持不变。

**Tech Stack:** Flutter、Dart、Material 3、`flutter_test`、`integration_test`

---

> Flutter 命令默认在 `frontend/` 目录执行；`git`、`evidence` 与计划文档操作默认在仓库根目录执行。  
> 本计划遵循“无迁移，直接替换”。  
> 用户已明确要求在当前 `main` 分支内直接执行，不派发子 AGENT。  
> 当前工作区已有一处与本计划无关的改动：`evidence/2026-04-20_产品版本管理页第二波迁移实施.md`。执行本计划时不要误将该文件一并提交。

## 文件结构

### 新增文件

- `frontend/lib/features/product/presentation/widgets/product_management_page_header.dart`
  - 产品管理页头，只负责页面标题与刷新入口
- `frontend/lib/features/product/presentation/widgets/product_management_filter_section.dart`
  - 产品管理页筛选区，承接关键词、分类、状态、生效版本和顶部主动作
- `frontend/lib/features/product/presentation/widgets/product_management_feedback_banner.dart`
  - 产品管理页页内反馈区
- `frontend/lib/features/product/presentation/widgets/product_management_status_chip.dart`
  - 产品状态语义薄包装
- `frontend/lib/features/product/presentation/widgets/product_management_table_section.dart`
  - 产品列表区，承接 DataTable、状态列和操作列包装
- `frontend/lib/features/product/presentation/widgets/product_detail_drawer.dart`
  - 产品详情侧栏整体展示层
- `frontend/lib/features/product/presentation/widgets/product_related_info_section.dart`
  - 产品详情侧栏中的关联信息区块
- `frontend/lib/features/product/presentation/widgets/product_history_timeline.dart`
  - 产品详情侧栏中的变更记录区
- `frontend/lib/features/product/presentation/widgets/product_version_dialog.dart`
  - 版本管理弹窗整体展示层
- `frontend/lib/features/product/presentation/widgets/product_version_compare_panel.dart`
  - 版本管理弹窗内的版本对比结果区
- `frontend/test/widgets/product_management_page_test.dart`
  - 产品管理页第二波迁移的页面级 widget test
- `frontend/integration_test/product_management_flow_test.dart`
  - 产品管理页桌面主路径 integration test
- `evidence/2026-04-20_产品管理页第二波迁移实施.md`
  - 本轮实施 evidence 主日志

### 修改文件

- `frontend/lib/features/product/presentation/product_management_page.dart:446-1245`
  - 保留详情数据加载、版本弹窗内部状态和业务动作入口，但改为装配新展示组件
- `frontend/lib/features/product/presentation/product_management_page.dart:1696-2488`
  - 保留动作分发、数据加载和 build 入口，接入 `MesCrudPageScaffold`
- `frontend/test/widgets/product_module_issue_regression_test.dart:1157-1755`
  - 保留并扩展产品管理页相关回归断言
- `frontend/test/widgets/product_page_test.dart`
  - 保持最小回归，确认产品模块页签装配未被破坏

## 任务 1：建立产品管理页基础展示组件

**Files:**
- Create: `frontend/lib/features/product/presentation/widgets/product_management_page_header.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_management_filter_section.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_management_feedback_banner.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_management_status_chip.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_management_table_section.dart`
- Create: `frontend/test/widgets/product_management_page_test.dart`

- [ ] **Step 1: 先写失败测试，固定基础展示组件的稳定锚点和主要文案**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_feedback_banner.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_filter_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_page_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_table_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_table_section.dart'
    show ProductManagementTableAction;

final DateTime _fixedDate = DateTime.parse('2026-04-20T00:00:00Z');

ProductItem _buildProduct({
  required int id,
  String lifecycleStatus = 'active',
  int currentVersion = 2,
  int effectiveVersion = 1,
}) {
  return ProductItem(
    id: id,
    name: '产品$id',
    category: '贴片',
    remark: '',
    lifecycleStatus: lifecycleStatus,
    currentVersion: currentVersion,
    currentVersionLabel: 'V1.${currentVersion - 1}',
    effectiveVersion: effectiveVersion,
    effectiveVersionLabel: effectiveVersion > 0 ? 'V1.${effectiveVersion - 1}' : null,
    effectiveAt: effectiveVersion > 0 ? _fixedDate : null,
    inactiveReason: lifecycleStatus == 'inactive' ? '人工停用' : null,
    lastParameterSummary: null,
    createdAt: _fixedDate,
    updatedAt: _fixedDate,
  );
}

void main() {
  testWidgets('产品管理页展示组件提供稳定页头 筛选区 反馈区和列表区锚点', (tester) async {
    final keywordController = TextEditingController(text: '产品');
    addTearDown(keywordController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: Scaffold(
          body: Column(
            children: [
              ProductManagementPageHeader(
                loading: false,
                onRefresh: () {},
              ),
              ProductManagementFilterSection(
                keywordController: keywordController,
                categoryOptions: const ['贴片', 'DTU', '套件'],
                selectedCategory: '',
                selectedStatus: '',
                selectedEffectiveVersion: '',
                loading: false,
                canCreateProduct: true,
                canExportProducts: true,
                onCategoryChanged: (_) {},
                onStatusChanged: (_) {},
                onEffectiveVersionChanged: (_) {},
                onSearch: () {},
                onCreate: () {},
                onExport: () {},
              ),
              const ProductManagementFeedbackBanner(
                message: '加载失败：网络错误',
              ),
              Expanded(
                child: ProductManagementTableSection(
                  products: [
                    _buildProduct(id: 41),
                    _buildProduct(id: 42, lifecycleStatus: 'inactive', effectiveVersion: 0),
                  ],
                  loading: false,
                  emptyText: '暂无产品',
                  formatTime: (value) => '2026-04-20 08:00:00',
                  buildActionItems: (_) => const [
                    PopupMenuItem<ProductManagementTableAction>(
                      value: ProductManagementTableAction.viewDetail,
                      child: Text('查看详情'),
                    ),
                    PopupMenuItem<ProductManagementTableAction>(
                      value: ProductManagementTableAction.version,
                      child: Text('版本管理'),
                    ),
                  ],
                  onSelected: (_, __) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('产品管理'), findsOneWidget);
    expect(find.byKey(const ValueKey('product-management-filter-section')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-management-feedback-banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-management-table-section')), findsOneWidget);
    expect(find.text('搜索产品'), findsOneWidget);
    expect(find.text('添加产品'), findsOneWidget);
    expect(find.text('导出产品'), findsOneWidget);
    expect(find.text('产品41'), findsOneWidget);
    expect(find.text('产品42'), findsOneWidget);
  });

  testWidgets('产品状态薄包装按产品生命周期展示启用或停用语义', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: Scaffold(
          body: ProductManagementTableSection(
            products: [
              _buildProduct(id: 41, lifecycleStatus: 'active'),
              _buildProduct(id: 42, lifecycleStatus: 'inactive', effectiveVersion: 0),
            ],
            loading: false,
            emptyText: '暂无产品',
            formatTime: (value) => '2026-04-20 08:00:00',
            buildActionItems: (_) => const [],
            onSelected: (_, __) {},
          ),
        ),
      ),
    );

    expect(find.text('启用'), findsWidgets);
    expect(find.text('停用'), findsWidgets);
  });
}
```

- [ ] **Step 2: 运行页面级测试，确认基础展示组件尚未存在**

Run: `flutter test test/widgets/product_management_page_test.dart`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Undefined class 'ProductManagementPageHeader'`

- [ ] **Step 3: 实现产品管理页基础展示组件**

```dart
// frontend/lib/features/product/presentation/widgets/product_management_page_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class ProductManagementPageHeader extends StatelessWidget {
  const ProductManagementPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
  });

  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return MesPageHeader(
      title: '产品管理',
      subtitle: '统一管理产品筛选、列表、详情和版本工作区入口。',
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
// frontend/lib/features/product/presentation/widgets/product_management_filter_section.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';

class ProductManagementFilterSection extends StatelessWidget {
  const ProductManagementFilterSection({
    super.key,
    required this.keywordController,
    required this.categoryOptions,
    required this.selectedCategory,
    required this.selectedStatus,
    required this.selectedEffectiveVersion,
    required this.loading,
    required this.canCreateProduct,
    required this.canExportProducts,
    required this.onCategoryChanged,
    required this.onStatusChanged,
    required this.onEffectiveVersionChanged,
    required this.onSearch,
    required this.onCreate,
    required this.onExport,
  });

  final TextEditingController keywordController;
  final List<String> categoryOptions;
  final String selectedCategory;
  final String selectedStatus;
  final String selectedEffectiveVersion;
  final bool loading;
  final bool canCreateProduct;
  final bool canExportProducts;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onEffectiveVersionChanged;
  final VoidCallback onSearch;
  final VoidCallback onCreate;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-management-filter-section'),
      child: MesFilterBar(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                controller: keywordController,
                decoration: const InputDecoration(
                  labelText: '搜索产品名称',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onSearch(),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(
                  labelText: '分类筛选',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(value: '', child: Text('全部')),
                  ...categoryOptions.map(
                    (category) => DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    ),
                  ),
                ],
                onChanged: loading ? null : (value) => onCategoryChanged(value ?? ''),
              ),
            ),
            SizedBox(
              width: 140,
              child: DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                decoration: const InputDecoration(
                  labelText: '状态筛选',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<String>(value: '', child: Text('全部')),
                  DropdownMenuItem<String>(value: 'active', child: Text('启用')),
                  DropdownMenuItem<String>(value: 'inactive', child: Text('停用')),
                ],
                onChanged: loading ? null : (value) => onStatusChanged(value ?? ''),
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                initialValue: selectedEffectiveVersion,
                decoration: const InputDecoration(
                  labelText: '生效版本',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<String>(value: '', child: Text('全部')),
                  DropdownMenuItem<String>(value: 'yes', child: Text('有生效版本')),
                  DropdownMenuItem<String>(value: 'no', child: Text('无生效版本')),
                ],
                onChanged: loading
                    ? null
                    : (value) => onEffectiveVersionChanged(value ?? ''),
              ),
            ),
            FilledButton.icon(
              onPressed: loading ? null : onSearch,
              icon: const Icon(Icons.search),
              label: const Text('搜索产品'),
            ),
            FilledButton.icon(
              onPressed: loading || !canCreateProduct ? null : onCreate,
              icon: const Icon(Icons.add),
              label: const Text('添加产品'),
            ),
            OutlinedButton.icon(
              onPressed: loading || !canExportProducts ? null : onExport,
              icon: const Icon(Icons.download),
              label: const Text('导出产品'),
            ),
          ],
        ),
      ),
    );
  }
}
```

```dart
// frontend/lib/features/product/presentation/widgets/product_management_feedback_banner.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_inline_banner.dart';

class ProductManagementFeedbackBanner extends StatelessWidget {
  const ProductManagementFeedbackBanner({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return KeyedSubtree(
      key: const ValueKey('product-management-feedback-banner'),
      child: MesInlineBanner.error(message: message),
    );
  }
}
```

```dart
// frontend/lib/features/product/presentation/widgets/product_management_status_chip.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/primitives/mes_status_chip.dart';

class ProductManagementStatusChip extends StatelessWidget {
  const ProductManagementStatusChip({
    super.key,
    required this.lifecycleStatus,
  });

  final String lifecycleStatus;

  @override
  Widget build(BuildContext context) {
    switch (lifecycleStatus) {
      case 'active':
      case 'effective':
        return MesStatusChip.success(label: '启用');
      case 'inactive':
        return MesStatusChip.warning(label: '停用');
      case 'draft':
        return MesStatusChip.warning(label: '草稿');
      case 'pending_review':
        return MesStatusChip.warning(label: '待审核');
      case 'obsolete':
        return MesStatusChip.warning(label: '已废弃');
      default:
        return MesStatusChip.warning(label: lifecycleStatus);
    }
  }
}
```

```dart
// frontend/lib/features/product/presentation/widgets/product_management_table_section.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_status_chip.dart';

enum ProductManagementTableAction {
  viewDetail,
  edit,
  deactivate,
  reactivate,
  version,
  viewParams,
  editParams,
  delete,
}

class ProductManagementTableSection extends StatelessWidget {
  const ProductManagementTableSection({
    super.key,
    required this.products,
    required this.loading,
    required this.emptyText,
    required this.formatTime,
    required this.buildActionItems,
    required this.onSelected,
  });

  final List<ProductItem> products;
  final bool loading;
  final String emptyText;
  final String Function(DateTime value) formatTime;
  final List<PopupMenuEntry<ProductManagementTableAction>> Function(ProductItem product)
  buildActionItems;
  final void Function(ProductManagementTableAction action, ProductItem product)
  onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KeyedSubtree(
      key: const ValueKey('product-management-table-section'),
      child: CrudListTableSection(
        loading: loading,
        isEmpty: products.isEmpty,
        emptyText: emptyText,
        enableUnifiedHeaderStyle: true,
        child: DataTable(
          columns: [
            UnifiedListTableHeaderStyle.column(context, '产品名称'),
            UnifiedListTableHeaderStyle.column(context, '产品分类'),
            UnifiedListTableHeaderStyle.column(context, '状态'),
            UnifiedListTableHeaderStyle.column(context, '当前版本'),
            UnifiedListTableHeaderStyle.column(context, '生效版本'),
            UnifiedListTableHeaderStyle.column(context, '创建时间'),
            UnifiedListTableHeaderStyle.column(context, '更新时间'),
            UnifiedListTableHeaderStyle.column(
              context,
              '操作',
              textAlign: TextAlign.center,
            ),
          ],
          rows: products.map((product) {
            final actions = buildActionItems(product);
            return DataRow(
              cells: [
                DataCell(Text(product.name)),
                DataCell(Text(product.category)),
                DataCell(
                  ProductManagementStatusChip(
                    lifecycleStatus: product.lifecycleStatus,
                  ),
                ),
                DataCell(Text('V1.${product.currentVersion - 1}')),
                DataCell(
                  Text(
                    product.effectiveVersion > 0
                        ? 'V1.${product.effectiveVersion - 1}'
                        : '-',
                  ),
                ),
                DataCell(Text(formatTime(product.createdAt))),
                DataCell(Text(formatTime(product.updatedAt))),
                DataCell(
                  actions.isEmpty
                      ? const Text('-')
                      : UnifiedListTableHeaderStyle.actionMenuButton<
                          ProductManagementTableAction
                        >(
                          theme: theme,
                          onSelected: (action) => onSelected(action, product),
                          itemBuilder: (context) => actions,
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

- [ ] **Step 4: 重新运行页面级测试，确认基础展示组件可用**

Run: `flutter test test/widgets/product_management_page_test.dart`

Expected: PASS

- [ ] **Step 5: 提交基础展示组件**

```bash
git add frontend/lib/features/product/presentation/widgets/product_management_page_header.dart frontend/lib/features/product/presentation/widgets/product_management_filter_section.dart frontend/lib/features/product/presentation/widgets/product_management_feedback_banner.dart frontend/lib/features/product/presentation/widgets/product_management_status_chip.dart frontend/lib/features/product/presentation/widgets/product_management_table_section.dart frontend/test/widgets/product_management_page_test.dart
git commit -m "拆分产品管理页基础展示组件"
```

## 任务 2：迁移 `ProductManagementPage` 到统一 CRUD 骨架

**Files:**
- Modify: `frontend/lib/features/product/presentation/product_management_page.dart:1696-2488`
- Modify: `frontend/test/widgets/product_management_page_test.dart`

- [ ] **Step 1: 为主页面迁移补失败测试，固定统一骨架和结构锚点**

```dart
// frontend/test/widgets/product_management_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/product_management_page.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_feedback_banner.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_filter_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_page_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_table_section.dart';
import 'package:mes_client/features/product/services/product_service.dart';

final DateTime _fixedDate = DateTime.parse('2026-04-20T00:00:00Z');

class _PageStructureService extends ProductService {
  _PageStructureService() : super(AppSession(baseUrl: '', accessToken: 'token'));

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
          id: 41,
          name: '产品41',
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
          id: 42,
          name: '产品42',
          category: '套件',
          remark: '',
          lifecycleStatus: 'inactive',
          currentVersion: 1,
          currentVersionLabel: 'V1.0',
          effectiveVersion: 0,
          effectiveVersionLabel: null,
          effectiveAt: null,
          inactiveReason: '人工停用',
          lastParameterSummary: null,
          createdAt: _fixedDate,
          updatedAt: _fixedDate,
        ),
      ],
    );
  }
}

void main() {
  testWidgets('ProductManagementPage 接入 MesCrudPageScaffold 并展示统一锚点', (tester) async {
    final service = _PageStructureService();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: Scaffold(
          body: SizedBox(
            width: 1440,
            height: 900,
            child: ProductManagementPage(
              session: AppSession(baseUrl: '', accessToken: 'token'),
              onLogout: () {},
              canCreateProduct: true,
              canExportProducts: true,
              canDeleteProduct: true,
              canUpdateLifecycle: true,
              canViewVersions: true,
              canCompareVersions: true,
              canRollbackVersion: true,
              canManageVersions: true,
              canActivateVersions: true,
              canViewImpactAnalysis: true,
              canViewParameters: true,
              canEditParameters: true,
              canExportParameters: true,
              onViewParameters: (_) {},
              onEditParameters: (_) {},
              service: service,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MesCrudPageScaffold), findsOneWidget);
    expect(find.byType(ProductManagementPageHeader), findsOneWidget);
    expect(find.byType(ProductManagementFilterSection), findsOneWidget);
    expect(find.byType(ProductManagementTableSection), findsOneWidget);
    expect(find.byType(ProductManagementFeedbackBanner), findsNothing);
  });
}
```

- [ ] **Step 2: 运行主页面结构测试，确认当前页面尚未迁移**

Run: `flutter test test/widgets/product_management_page_test.dart --plain-name "ProductManagementPage 接入 MesCrudPageScaffold 并展示统一锚点"`

Expected: FAIL，断言找不到 `MesCrudPageScaffold`、`ProductManagementFilterSection` 或 `ProductManagementTableSection`

- [ ] **Step 3: 收敛主页面职责并接入 `MesCrudPageScaffold`**

```dart
// frontend/lib/features/product/presentation/product_management_page.dart
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_feedback_banner.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_filter_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_page_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_table_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_table_section.dart'
    show ProductManagementTableAction;

List<PopupMenuEntry<ProductManagementTableAction>> _buildProductActionMenuItems(
  ProductItem product,
) {
  final items = <PopupMenuEntry<ProductManagementTableAction>>[
    const PopupMenuItem(
      value: ProductManagementTableAction.viewDetail,
      child: Text('查看详情'),
    ),
  ];
  if (widget.canUpdateLifecycle) {
    switch (product.lifecycleStatus) {
      case 'active':
      case 'effective':
        items.add(
          const PopupMenuItem(
            value: ProductManagementTableAction.deactivate,
            child: Text('停用'),
          ),
        );
        break;
      case 'inactive':
        items.add(
          const PopupMenuItem(
            value: ProductManagementTableAction.reactivate,
            child: Text('启用'),
          ),
        );
        break;
    }
  }
  final utilityItems = <PopupMenuEntry<ProductManagementTableAction>>[];
  if (widget.canCreateProduct) {
    utilityItems.add(
      const PopupMenuItem(
        value: ProductManagementTableAction.edit,
        child: Text('编辑产品'),
      ),
    );
  }
  if (widget.canViewVersions) {
    utilityItems.add(
      const PopupMenuItem(
        value: ProductManagementTableAction.version,
        child: Text('版本管理'),
      ),
    );
  }
  if (widget.canViewParameters) {
    utilityItems.add(
      const PopupMenuItem(
        value: ProductManagementTableAction.viewParams,
        child: Text('查看参数'),
      ),
    );
  }
  if (widget.canEditParameters) {
    utilityItems.add(
      const PopupMenuItem(
        value: ProductManagementTableAction.editParams,
        child: Text('编辑参数'),
      ),
    );
  }
  if (widget.canDeleteProduct) {
    utilityItems.add(
      const PopupMenuItem(
        value: ProductManagementTableAction.delete,
        child: Text('删除产品'),
      ),
    );
  }
  if (items.isNotEmpty && utilityItems.isNotEmpty) {
    items.add(const PopupMenuDivider());
  }
  items.addAll(utilityItems);
  return items;
}

Future<void> _handleProductTableAction(
  ProductManagementTableAction action,
  ProductItem product,
) async {
  switch (action) {
    case ProductManagementTableAction.viewDetail:
      await _showDetailDrawer(product);
      return;
    case ProductManagementTableAction.edit:
      await _showEditProductDialog(product);
      return;
    case ProductManagementTableAction.deactivate:
      await _changeLifecycle(product, 'inactive');
      return;
    case ProductManagementTableAction.reactivate:
      await _changeLifecycle(product, 'active');
      return;
    case ProductManagementTableAction.version:
      await _showVersionDialog(product);
      return;
    case ProductManagementTableAction.viewParams:
      widget.onViewParameters(product);
      return;
    case ProductManagementTableAction.editParams:
      widget.onEditParameters(product);
      return;
    case ProductManagementTableAction.delete:
      await _deleteProduct(product);
      return;
  }
}

@override
Widget build(BuildContext context) {
  return MesCrudPageScaffold(
    header: ProductManagementPageHeader(
      loading: _loading,
      onRefresh: _loadProducts,
    ),
    filters: ProductManagementFilterSection(
      keywordController: _keywordController,
      categoryOptions: _productCategoryOptions,
      selectedCategory: _selectedCategoryFilter,
      selectedStatus: _selectedStatusFilter,
      selectedEffectiveVersion: _selectedEffectiveVersionFilter,
      loading: _loading,
      canCreateProduct: widget.canCreateProduct,
      canExportProducts: widget.canExportProducts,
      onCategoryChanged: (value) {
        setState(() => _selectedCategoryFilter = value);
        _loadProducts(page: 1);
      },
      onStatusChanged: (value) {
        setState(() => _selectedStatusFilter = value);
        _loadProducts(page: 1);
      },
      onEffectiveVersionChanged: (value) {
        setState(() => _selectedEffectiveVersionFilter = value);
        _loadProducts(page: 1);
      },
      onSearch: () => _loadProducts(page: 1),
      onCreate: _showCreateProductDialog,
      onExport: _exportProducts,
    ),
    banner: _message.isEmpty
        ? null
        : ProductManagementFeedbackBanner(message: _message),
    content: ProductManagementTableSection(
      products: _products,
      loading: _loading,
      emptyText: '暂无产品',
      formatTime: _formatTime,
      buildActionItems: _buildProductActionMenuItems,
      onSelected: _handleProductTableAction,
    ),
    pagination: SimplePaginationBar(
      page: _productPage,
      totalPages: _productTotalPages,
      total: _total,
      showTotal: false,
      loading: _loading,
      onPrevious: () => _loadProducts(page: _productPage - 1),
      onNext: () => _loadProducts(page: _productPage + 1),
    ),
  );
}
```

- [ ] **Step 4: 重新运行主页面结构测试**

Run: `flutter test test/widgets/product_management_page_test.dart --plain-name "ProductManagementPage 接入 MesCrudPageScaffold 并展示统一锚点"`

Expected: PASS

- [ ] **Step 5: 提交主页面骨架迁移**

```bash
git add frontend/lib/features/product/presentation/product_management_page.dart frontend/test/widgets/product_management_page_test.dart
git commit -m "迁移产品管理页到统一CRUD骨架"
```

## 任务 3：拆分产品详情侧栏展示层

**Files:**
- Create: `frontend/lib/features/product/presentation/widgets/product_detail_drawer.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_related_info_section.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_history_timeline.dart`
- Modify: `frontend/lib/features/product/presentation/product_management_page.dart:1809-2269`
- Modify: `frontend/test/widgets/product_management_page_test.dart`

- [ ] **Step 1: 先写失败测试，固定详情侧栏展示层锚点与主要区块**

```dart
// frontend/test/widgets/product_management_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_detail_drawer.dart';

final DateTime _fixedDate = DateTime.parse('2026-04-20T00:00:00Z');

ProductDetailResult _buildDetailResult() {
  return ProductDetailResult(
    product: ProductItem(
      id: 41,
      name: '产品41',
      category: '贴片',
      remark: '用于详情验证',
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
    detailParameters: ProductParameterListResult(
      productId: 41,
      productName: '产品41',
      parameterScope: 'version',
      version: 2,
      versionLabel: 'V1.1',
      lifecycleStatus: 'draft',
      total: 1,
      items: [
        ProductParameterItem(
          name: '产品芯片',
          category: '基础参数',
          type: 'Text',
          value: 'CHIP-X',
          description: '详情聚合',
          sortOrder: 1,
          isPreset: false,
        ),
      ],
    ),
    detailParameterMessage: '当前无生效版本，详情已回退展示当前版本参数快照。',
    latestVersionChangedAt: _fixedDate,
    versionTotal: 1,
    versions: [
      ProductVersionItem(
        version: 2,
        versionLabel: 'V1.1',
        lifecycleStatus: 'draft',
        action: 'create',
        note: '草稿版本',
        effectiveAt: null,
        sourceVersion: null,
        sourceVersionLabel: null,
        createdByUserId: 1,
        createdByUsername: 'admin',
        createdAt: _fixedDate,
      ),
    ],
    historyTotal: 1,
    historyItems: [
      ProductParameterHistoryItem(
        id: 1,
        productName: '产品41',
        productCategory: '贴片',
        version: 2,
        versionLabel: 'V1.1',
        remark: '参数调整',
        changeReason: '参数调整',
        changeType: 'edit',
        parameterName: '产品芯片',
        changedKeys: const ['产品芯片'],
        operatorUsername: 'admin',
        beforeSummary: null,
        afterSummary: null,
        beforeSnapshot: '{}',
        afterSnapshot: '{}',
        createdAt: _fixedDate,
      ),
    ],
    relatedInfoSections: [
      ProductRelatedInfoSection(
        code: 'process_templates',
        title: '关联工艺路线',
        total: 1,
        items: [
          ProductRelatedInfoItem(
            label: '贴片主线工艺',
            value: '版本 2 | 默认 | published',
          ),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets('ProductDetailDrawer 展示参数快照 关联信息和变更记录', (tester) async {
    final detail = _buildDetailResult();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductDetailDrawer(
            detail: detail,
            paramSearch: '',
            onParamSearchChanged: (_) {},
            onClose: () {},
            formatTime: (_) => '2026-04-20 08:00:00',
            lifecycleLabel: (value) => value == 'active' ? '启用' : value,
            versionLifecycleLabel: (value) => value == 'draft' ? '草稿' : value,
            formatDisplayVersion: (value) => 'V1.${value - 1}',
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('product-detail-drawer')), findsOneWidget);
    expect(find.textContaining('产品详情 - 产品41'), findsOneWidget);
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.textContaining('当前版本参数快照'), findsOneWidget);
    expect(find.text('关联工艺路线'), findsOneWidget);
    expect(find.byKey(const ValueKey('product-history-timeline')), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行详情侧栏测试，确认展示层尚未拆出**

Run: `flutter test test/widgets/product_management_page_test.dart --plain-name "ProductDetailDrawer 展示参数快照 关联信息和变更记录"`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Undefined class 'ProductDetailDrawer'`

- [ ] **Step 3: 实现详情侧栏展示层并改主页面装配**

```dart
// frontend/lib/features/product/presentation/widgets/product_related_info_section.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/product/models/product_models.dart';

class ProductRelatedInfoSectionCard extends StatelessWidget {
  const ProductRelatedInfoSectionCard({
    super.key,
    required this.section,
  });

  final ProductRelatedInfoSection section;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey('product-related-info-section-${section.code}'),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey.shade50,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    section.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${section.total}项',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (section.items.isEmpty)
              Text(
                section.emptyMessage ?? '暂无关联数据',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              )
            else
              ...section.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    item.value == null || item.value!.trim().isEmpty
                        ? item.label
                        : '${item.label}｜${item.value}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

```dart
// frontend/lib/features/product/presentation/widgets/product_history_timeline.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/product/models/product_models.dart';

class ProductHistoryTimeline extends StatelessWidget {
  const ProductHistoryTimeline({
    super.key,
    required this.items,
    required this.formatTime,
    required this.changeTypeLabel,
  });

  final List<ProductParameterHistoryItem> items;
  final String Function(DateTime value) formatTime;
  final String Function(String value) changeTypeLabel;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-history-timeline'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '变更记录',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const Divider(),
          if (items.isEmpty)
            const Text('暂无变更记录', style: TextStyle(color: Colors.grey))
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        formatTime(item.createdAt),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(
                        item.operatorUsername,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        [
                          if (item.versionLabel?.trim().isNotEmpty == true) item.versionLabel!,
                          changeTypeLabel(item.changeType),
                          item.remark,
                          if (item.changedKeys.isNotEmpty) '参数：${item.changedKeys.join(', ')}',
                        ].join('｜'),
                        style: const TextStyle(fontSize: 12),
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

```dart
// frontend/lib/features/product/presentation/widgets/product_detail_drawer.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_history_timeline.dart';
import 'package:mes_client/features/product/presentation/widgets/product_related_info_section.dart';

class ProductDetailDrawer extends StatelessWidget {
  const ProductDetailDrawer({
    super.key,
    required this.detail,
    required this.paramSearch,
    required this.onParamSearchChanged,
    required this.onClose,
    required this.formatTime,
    required this.lifecycleLabel,
    required this.versionLifecycleLabel,
    required this.formatDisplayVersion,
    required this.changeTypeLabel,
  });

  final ProductDetailResult detail;
  final String paramSearch;
  final ValueChanged<String> onParamSearchChanged;
  final VoidCallback onClose;
  final String Function(DateTime value) formatTime;
  final String Function(String value) lifecycleLabel;
  final String Function(String value) versionLifecycleLabel;
  final String Function(int value) formatDisplayVersion;
  final String Function(String value) changeTypeLabel;

  @override
  Widget build(BuildContext context) {
    final product = detail.product;
    final currentVersion = product.currentVersion > 0
        ? formatDisplayVersion(product.currentVersion)
        : '-';
    final effectiveVersion = product.effectiveVersion > 0
        ? formatDisplayVersion(product.effectiveVersion)
        : '无';
    final filteredParams = detail.detailParameters.items.where((item) {
      if (paramSearch.trim().isEmpty) {
        return true;
      }
      return item.name.toLowerCase().contains(paramSearch.toLowerCase());
    }).toList();

    return KeyedSubtree(
      key: const ValueKey('product-detail-drawer'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '产品详情 - ${product.name}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '页内侧边栏展示完整详情快照',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '基本信息',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Divider(),
                  _detailRow('产品名称', product.name),
                  _detailRow('产品分类', product.category.isEmpty ? '-' : product.category),
                  _detailRow('状态', lifecycleLabel(product.lifecycleStatus)),
                  _detailRow('当前版本', currentVersion),
                  _detailRow('生效版本', effectiveVersion),
                  _detailRow('备注', product.remark.isEmpty ? '-' : product.remark),
                  _detailRow('创建时间', formatTime(product.createdAt)),
                  _detailRow('更新时间', formatTime(product.updatedAt)),
                  const SizedBox(height: 16),
                  Text(
                    '${detail.detailParameters.parameterScope == 'effective' ? '当前生效参数快照' : '当前版本参数快照'}（${detail.detailParameters.versionLabel}）',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Divider(),
                  if ((detail.detailParameterMessage ?? '').isNotEmpty) ...[
                    Text(detail.detailParameterMessage!),
                    const SizedBox(height: 8),
                  ],
                  if (detail.detailParameters.items.isEmpty)
                    const Text('暂无参数', style: TextStyle(color: Colors.grey))
                  else ...[
                    SizedBox(
                      width: 240,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: '搜索参数名称',
                          prefixIcon: Icon(Icons.search, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: onParamSearchChanged,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DataTable(
                      columnSpacing: 16,
                      headingRowHeight: 36,
                      dataRowMinHeight: 32,
                      dataRowMaxHeight: 40,
                      columns: const [
                        DataColumn(label: Text('参数名')),
                        DataColumn(label: Text('分组')),
                        DataColumn(label: Text('类型')),
                        DataColumn(label: Text('值')),
                        DataColumn(label: Text('说明')),
                      ],
                      rows: filteredParams.map((item) {
                        return DataRow(
                          cells: [
                            DataCell(Text(item.name)),
                            DataCell(Text(item.category)),
                            DataCell(Text(item.type)),
                            DataCell(Text(item.value, overflow: TextOverflow.ellipsis)),
                            DataCell(
                              Text(
                                item.description.isEmpty ? '-' : item.description,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    '关联信息',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Divider(),
                  if (detail.relatedInfoSections.isEmpty)
                    const Text('暂无关联信息', style: TextStyle(color: Colors.grey))
                  else
                    ...detail.relatedInfoSections.map(
                      (section) => ProductRelatedInfoSectionCard(section: section),
                    ),
                  const SizedBox(height: 16),
                  ProductHistoryTimeline(
                    items: detail.historyItems,
                    formatTime: formatTime,
                    changeTypeLabel: changeTypeLabel,
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

Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
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
```

```dart
// frontend/lib/features/product/presentation/product_management_page.dart
import 'package:mes_client/features/product/presentation/widgets/product_detail_drawer.dart';

await showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: '关闭产品详情侧栏',
  barrierColor: Colors.black54,
  pageBuilder: (context, animation, secondaryAnimation) {
    return StatefulBuilder(
      builder: (context, setDialogState) {
        final screenWidth = MediaQuery.of(context).size.width;
        final drawerWidth = screenWidth < 1200 ? screenWidth * 0.92 : 720.0;
        return SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 12,
              child: SizedBox(
                width: drawerWidth,
                child: ProductDetailDrawer(
                  detail: detail,
                  paramSearch: paramSearch,
                  onParamSearchChanged: (value) {
                    setDialogState(() => paramSearch = value);
                  },
                  onClose: () => Navigator.of(context).pop(),
                  formatTime: _formatTime,
                  lifecycleLabel: _lifecycleLabel,
                  versionLifecycleLabel: _versionLifecycleLabel,
                  formatDisplayVersion: _formatDisplayVersion,
                  changeTypeLabel: _parameterHistoryTypeLabel,
                ),
              ),
            ),
          ),
        );
      },
    );
  },
  transitionBuilder: (context, animation, _, child) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    );
  },
);
```

- [ ] **Step 4: 运行详情侧栏测试和既有侧栏回归**

Run: `flutter test test/widgets/product_management_page_test.dart --plain-name "ProductDetailDrawer 展示参数快照 关联信息和变更记录"`

Expected: PASS

Run: `flutter test test/widgets/product_module_issue_regression_test.dart --plain-name "产品详情应以页内侧栏展示聚合详情"`

Expected: PASS

- [ ] **Step 5: 提交详情侧栏展示层拆分**

```bash
git add frontend/lib/features/product/presentation/widgets/product_detail_drawer.dart frontend/lib/features/product/presentation/widgets/product_related_info_section.dart frontend/lib/features/product/presentation/widgets/product_history_timeline.dart frontend/lib/features/product/presentation/product_management_page.dart frontend/test/widgets/product_management_page_test.dart
git commit -m "拆分产品详情侧栏展示层"
```

## 任务 4：拆分版本管理弹窗展示层

**Files:**
- Create: `frontend/lib/features/product/presentation/widgets/product_version_dialog.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_version_compare_panel.dart`
- Modify: `frontend/lib/features/product/presentation/product_management_page.dart:446-1245`
- Modify: `frontend/test/widgets/product_management_page_test.dart`

- [ ] **Step 1: 先写失败测试，固定版本管理弹窗展示层锚点和对比区**

```dart
// frontend/test/widgets/product_management_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_dialog.dart';

final DateTime _fixedDate = DateTime.parse('2026-04-20T00:00:00Z');

void main() {
  testWidgets('ProductVersionDialog 展示版本对比区和动作入口', (tester) async {
    final product = ProductItem(
      id: 41,
      name: '产品41',
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
    );
    final versions = [
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
    ];
    final compareResult = ProductVersionCompareResult(
      fromVersion: 1,
      toVersion: 2,
      addedItems: 1,
      removedItems: 0,
      changedItems: 1,
      items: [
        ProductVersionDiffItem(
          key: '产品芯片',
          diffType: 'changed',
          fromValue: 'CHIP-A',
          toValue: 'CHIP-B',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductVersionDialog(
            product: product,
            versions: versions,
            loadingVersions: false,
            operationLoading: false,
            compareLoading: false,
            compareResult: compareResult,
            fromVersion: 1,
            toVersion: 2,
            operationLabel: null,
            canCompareVersions: true,
            canManageVersions: true,
            canActivateVersions: true,
            canEditParameters: true,
            canRollbackVersion: true,
            onClose: () {},
            onCreateVersion: () {},
            onFromVersionChanged: (_) {},
            onToVersionChanged: (_) {},
            onCompare: () {},
            buildVersionActions: (_) => [
              TextButton(onPressed: () {}, child: const Text('激活')),
            ],
            lifecycleLabel: (value) => value == 'draft' ? '草稿' : '已生效',
            formatTime: (_) => '2026-04-20 08:00:00',
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('product-version-dialog')), findsOneWidget);
    expect(find.textContaining('版本管理 - 产品41'), findsOneWidget);
    expect(find.text('新建版本'), findsOneWidget);
    expect(find.text('版本对比'), findsOneWidget);
    expect(find.byKey(const ValueKey('product-version-compare-panel')), findsOneWidget);
    expect(find.textContaining('对比结果：新增 1，移除 0，变更 1'), findsOneWidget);
    expect(find.text('激活'), findsWidgets);
  });
}
```

- [ ] **Step 2: 运行版本管理弹窗测试，确认展示层尚未拆出**

Run: `flutter test test/widgets/product_management_page_test.dart --plain-name "ProductVersionDialog 展示版本对比区和动作入口"`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Undefined class 'ProductVersionDialog'`

- [ ] **Step 3: 实现版本管理弹窗展示层并改主页面装配**

```dart
// frontend/lib/features/product/presentation/widgets/product_version_compare_panel.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/product/models/product_models.dart';

class ProductVersionComparePanel extends StatelessWidget {
  const ProductVersionComparePanel({
    super.key,
    required this.result,
  });

  final ProductVersionCompareResult result;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-version-compare-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '对比结果：新增 ${result.addedItems}，移除 ${result.removedItems}，变更 ${result.changedItems}',
          ),
          const SizedBox(height: 6),
          ...result.items.take(50).map(
            (item) => Text(
              '[${item.diffType}] ${item.key} | ${item.fromValue ?? '-'} -> ${item.toValue ?? '-'}',
            ),
          ),
          const Divider(height: 20),
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/features/product/presentation/widgets/product_version_dialog.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_compare_panel.dart';

class ProductVersionDialog extends StatelessWidget {
  const ProductVersionDialog({
    super.key,
    required this.product,
    required this.versions,
    required this.loadingVersions,
    required this.operationLoading,
    required this.compareLoading,
    required this.compareResult,
    required this.fromVersion,
    required this.toVersion,
    required this.operationLabel,
    required this.canCompareVersions,
    required this.canManageVersions,
    required this.canActivateVersions,
    required this.canEditParameters,
    required this.canRollbackVersion,
    required this.onClose,
    required this.onCreateVersion,
    required this.onFromVersionChanged,
    required this.onToVersionChanged,
    required this.onCompare,
    required this.buildVersionActions,
    required this.lifecycleLabel,
    required this.formatTime,
  });

  final ProductItem product;
  final List<ProductVersionItem> versions;
  final bool loadingVersions;
  final bool operationLoading;
  final bool compareLoading;
  final ProductVersionCompareResult? compareResult;
  final int? fromVersion;
  final int? toVersion;
  final String? operationLabel;
  final bool canCompareVersions;
  final bool canManageVersions;
  final bool canActivateVersions;
  final bool canEditParameters;
  final bool canRollbackVersion;
  final VoidCallback onClose;
  final VoidCallback onCreateVersion;
  final ValueChanged<int?> onFromVersionChanged;
  final ValueChanged<int?> onToVersionChanged;
  final VoidCallback onCompare;
  final List<Widget> Function(ProductVersionItem item) buildVersionActions;
  final String Function(String value) lifecycleLabel;
  final String Function(DateTime value) formatTime;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-version-dialog'),
      child: AlertDialog(
        title: Text('版本管理 - ${product.name}'),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: operationLoading || loadingVersions ? null : onCreateVersion,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('新建版本'),
                    ),
                  ],
                ),
                if (loadingVersions || operationLoading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  if (operationLabel != null) ...[
                    const SizedBox(height: 6),
                    Text(operationLabel!),
                  ],
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<int>(
                      value: fromVersion,
                      hint: const Text('起始版本'),
                      items: versions
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: item.version,
                              child: Text(item.displayVersion),
                            ),
                          )
                          .toList(),
                      onChanged: loadingVersions || operationLoading ? null : onFromVersionChanged,
                    ),
                    DropdownButton<int>(
                      value: toVersion,
                      hint: const Text('目标版本'),
                      items: versions
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: item.version,
                              child: Text(item.displayVersion),
                            ),
                          )
                          .toList(),
                      onChanged: loadingVersions || operationLoading ? null : onToVersionChanged,
                    ),
                    FilledButton(
                      onPressed: loadingVersions ||
                              operationLoading ||
                              compareLoading ||
                              !canCompareVersions ||
                              fromVersion == null ||
                              toVersion == null
                          ? null
                          : onCompare,
                      child: const Text('版本对比'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (compareResult != null) ProductVersionComparePanel(result: compareResult!),
                const Text('版本列表'),
                const SizedBox(height: 8),
                if (!loadingVersions && versions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('暂无版本记录'),
                  )
                else
                  ...versions.map(
                    (item) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${item.displayVersion} / ${lifecycleLabel(item.lifecycleStatus)}'),
                      subtitle: Text(
                        [
                          formatTime(item.createdAt),
                          item.createdByUsername ?? '-',
                          if (item.note != null && item.note!.isNotEmpty) item.note!,
                        ].join('  '),
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: buildVersionActions(item),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: operationLoading ? null : onClose,
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/features/product/presentation/product_management_page.dart
import 'package:mes_client/features/product/presentation/widgets/product_version_compare_panel.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_dialog.dart';

TextButton buildActionButton({
  required String label,
  required VoidCallback? onPressed,
  Color? foregroundColor,
}) {
  return TextButton(
    style: TextButton.styleFrom(
      foregroundColor: foregroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    ),
    onPressed: onPressed,
    child: Text(label),
  );
}

return ProductVersionDialog(
  product: product,
  versions: versionItems,
  loadingVersions: loadingVersions,
  operationLoading: operationLoading,
  compareLoading: compareLoading,
  compareResult: compareResult,
  fromVersion: fromVersion,
  toVersion: toVersion,
  operationLabel: operationLabel,
  canCompareVersions: widget.canCompareVersions,
  canManageVersions: widget.canManageVersions,
  canActivateVersions: widget.canActivateVersions,
  canEditParameters: widget.canEditParameters,
  canRollbackVersion: widget.canRollbackVersion,
  onClose: () => Navigator.of(context).pop(),
  onCreateVersion: () async {
    await runVersionOperation(
      setLocalState,
      loadingText: '正在新建版本...',
      errorPrefix: '新建版本失败',
      action: () async {
        await _productService.createProductVersion(productId: product.id);
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(content: Text('新建版本成功')),
        );
        await reloadVersions(setLocalState);
      },
    );
  },
  onFromVersionChanged: (value) {
    setLocalState(() => fromVersion = value);
  },
  onToVersionChanged: (value) {
    setLocalState(() => toVersion = value);
  },
  onCompare: () async {
    setLocalState(() => compareLoading = true);
    try {
      final result = await _productService.compareProductVersions(
        productId: product.id,
        fromVersion: fromVersion!,
        toVersion: toVersion!,
      );
      if (!mounted || dialogClosed || !(dialogContext?.mounted ?? false)) {
        return;
      }
      setLocalState(() => compareResult = result);
    } finally {
      if (!dialogClosed && mounted && (dialogContext?.mounted ?? false)) {
        setLocalState(() => compareLoading = false);
      }
    }
  },
  buildVersionActions: (item) {
    final isDraft = item.lifecycleStatus == 'draft';
    final isEffective = item.lifecycleStatus == 'effective';
    final widgets = <Widget>[];
    if (widget.canEditParameters && isDraft) {
      widgets.add(
        buildActionButton(
          label: '维护参数',
          onPressed: operationLoading || loadingVersions
              ? null
              : () {
                  dialogClosed = true;
                  Navigator.of(context).pop();
                  widget.onEditParameters(product);
                },
        ),
      );
    }
    if (widget.canManageVersions && isDraft) {
      widgets.add(
        buildActionButton(
          label: '编辑备注',
          onPressed: operationLoading || loadingVersions
              ? null
              : () async {
                  final noteController = TextEditingController(text: item.note ?? '');
                  final newNote = await showLockedFormDialog<String?>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('编辑 ${item.displayVersion} 备注'),
                      content: SizedBox(
                        width: 360,
                        child: TextField(
                          controller: noteController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: '版本备注',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(noteController.text.trim()),
                          child: const Text('保存'),
                        ),
                      ],
                    ),
                  );
                  noteController.dispose();
                  if (newNote == null) {
                    return;
                  }
                  await runVersionOperation(
                    setLocalState,
                    loadingText: '正在更新 ${item.displayVersion} 备注...',
                    errorPrefix: '更新版本备注失败',
                    action: () async {
                      await _productService.updateProductVersionNote(
                        productId: product.id,
                        version: item.version,
                        note: newNote,
                      );
                      if (!mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('备注已更新')),
                      );
                      await reloadVersions(setLocalState);
                    },
                  );
                },
        ),
      );
    }
    if (widget.canActivateVersions && isDraft) {
      widgets.add(
        buildActionButton(
          label: '激活',
          onPressed: operationLoading || loadingVersions
              ? null
              : () async {
                  final confirmed = await confirmVersionAction(
                    title: '确认生效',
                    content:
                        '确认将版本 ${item.displayVersion} 设为生效版本？\n生效后，当前生效版本将自动变为已失效。',
                    confirmText: '确认生效',
                  );
                  if (!confirmed) {
                    return;
                  }
                  await runVersionOperation(
                    setLocalState,
                    loadingText: '正在激活 ${item.displayVersion}...',
                    errorPrefix: '版本激活失败',
                    action: () async {
                      try {
                        await _productService.activateProductVersion(
                          productId: product.id,
                          version: item.version,
                        );
                      } catch (error) {
                        if (_isUnauthorized(error) ||
                            !_errorMessage(error).contains('Impact confirmation required')) {
                          rethrow;
                        }
                        final impact = await _productService.getProductImpactAnalysis(
                          productId: product.id,
                          operation: 'lifecycle',
                          targetStatus: 'active',
                          targetVersion: item.version,
                        );
                        final impactConfirmed = await _confirmImpact(
                          impact,
                          title: '生效影响确认',
                        );
                        if (!impactConfirmed) {
                          return;
                        }
                        await _productService.activateProductVersion(
                          productId: product.id,
                          version: item.version,
                          confirmed: true,
                        );
                      }
                      if (!mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('版本 ${item.displayVersion} 已生效')),
                      );
                      await _loadProducts();
                      await reloadVersions(setLocalState);
                    },
                  );
                },
        ),
      );
    }
    if (widget.canManageVersions && isEffective) {
      widgets.add(
        buildActionButton(
          label: '停用',
          onPressed: operationLoading || loadingVersions
              ? null
              : () async {
                  final confirmed = await confirmVersionAction(
                    title: '确认停用',
                    content:
                        '确认停用版本 ${item.displayVersion}？停用后不可直接恢复，如需再次使用请复制出新草稿。',
                    confirmText: '确认停用',
                    confirmColor: Colors.orange,
                  );
                  if (!confirmed) {
                    return;
                  }
                  await runVersionOperation(
                    setLocalState,
                    loadingText: '正在停用 ${item.displayVersion}...',
                    errorPrefix: '停用版本失败',
                    action: () async {
                      await _productService.disableProductVersion(
                        productId: product.id,
                        version: item.version,
                      );
                      if (!mounted) {
                        return;
                      }
                      final refreshedProduct = await _productService.getProduct(
                        productId: product.id,
                      );
                      if (!mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                            refreshedProduct.lifecycleStatus == 'inactive'
                                ? '版本 ${item.displayVersion} 已停用，产品因无生效版本已同步停用'
                                : '版本 ${item.displayVersion} 已停用',
                          ),
                        ),
                      );
                      await _loadProducts();
                      await reloadVersions(setLocalState);
                    },
                  );
                },
        ),
      );
    }
    if (widget.canRollbackVersion) {
      widgets.add(
        buildActionButton(
          label: '回滚',
          onPressed: operationLoading || loadingVersions
              ? null
              : () async {
                  await runVersionOperation(
                    setLocalState,
                    loadingText: '正在回滚到 ${item.displayVersion}...',
                    errorPrefix: '版本回滚失败',
                    action: () async {
                      final nav = dialogContext != null
                          ? Navigator.of(dialogContext!)
                          : null;
                      final messenger = ScaffoldMessenger.of(context);
                      var confirmed = false;
                      if (widget.canViewImpactAnalysis) {
                        final impact = await _productService.getProductImpactAnalysis(
                          productId: product.id,
                          operation: 'rollback',
                          targetVersion: item.version,
                        );
                        if (impact.requiresConfirmation) {
                          confirmed = await _confirmImpact(
                            impact,
                            title: '回滚影响确认',
                          );
                          if (!confirmed) {
                            return;
                          }
                        }
                      }
                      await _productService.rollbackProduct(
                        productId: product.id,
                        targetVersion: item.version,
                        confirmed: confirmed,
                        note: '回滚到${item.displayVersion}',
                      );
                      if (!mounted) {
                        return;
                      }
                      await reloadVersions(setLocalState);
                      dialogClosed = true;
                      if (dialogContext?.mounted ?? false) {
                        nav?.pop();
                      }
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('已回滚到 ${item.displayVersion}')),
                        );
                        await _loadProducts();
                      }
                    },
                  );
                },
        ),
      );
    }
    if (isDraft) {
      widgets.add(
        buildActionButton(
          label: '删除',
          foregroundColor: Theme.of(context).colorScheme.error,
          onPressed: operationLoading || loadingVersions
              ? null
              : () async {
                  final confirmed = await confirmVersionAction(
                    title: '确认删除',
                    content: '确认删除草稿版本 ${item.displayVersion}？此操作不可撤销。',
                    confirmText: '确认删除',
                    confirmColor: Colors.red,
                  );
                  if (!confirmed) {
                    return;
                  }
                  await runVersionOperation(
                    setLocalState,
                    loadingText: '正在删除 ${item.displayVersion}...',
                    errorPrefix: '删除版本失败',
                    action: () async {
                      await _productService.deleteProductVersion(
                        productId: product.id,
                        version: item.version,
                      );
                      if (!mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('版本 ${item.displayVersion} 已删除')),
                      );
                      await reloadVersions(setLocalState);
                    },
                  );
                },
        ),
      );
    }
    return widgets;
  },
  lifecycleLabel: _versionLifecycleLabel,
  formatTime: _formatTime,
);
```

- [ ] **Step 4: 运行弹窗测试和既有版本弹窗回归**

Run: `flutter test test/widgets/product_management_page_test.dart --plain-name "ProductVersionDialog 展示版本对比区和动作入口"`

Expected: PASS

Run: `flutter test test/widgets/product_module_issue_regression_test.dart --plain-name "版本激活影响分析应使用 lifecycle 操作码"`

Expected: PASS

- [ ] **Step 5: 提交版本管理弹窗展示层拆分**

```bash
git add frontend/lib/features/product/presentation/widgets/product_version_dialog.dart frontend/lib/features/product/presentation/widgets/product_version_compare_panel.dart frontend/lib/features/product/presentation/product_management_page.dart frontend/test/widgets/product_management_page_test.dart
git commit -m "拆分产品版本管理弹窗展示层"
```

## 任务 5：补齐页面回归、integration 与最终收口

**Files:**
- Create: `frontend/integration_test/product_management_flow_test.dart`
- Create: `evidence/2026-04-20_产品管理页第二波迁移实施.md`
- Modify: `frontend/test/widgets/product_management_page_test.dart`
- Modify: `frontend/test/widgets/product_module_issue_regression_test.dart`
- Modify: `frontend/test/widgets/product_page_test.dart`

- [ ] **Step 1: 先写失败的页面级 / integration 观察点，固定最终锚点**

```dart
// frontend/test/widgets/product_management_page_test.dart
testWidgets('ProductManagementPage 保留详情侧栏和版本管理弹窗入口', (tester) async {
  final service = _PageStructureService();

  await tester.pumpWidget(
    MaterialApp(
      theme: buildMesTheme(
        brightness: Brightness.light,
        visualDensity: VisualDensity.standard,
      ),
      home: Scaffold(
        body: SizedBox(
          width: 1440,
          height: 900,
          child: ProductManagementPage(
            session: AppSession(baseUrl: '', accessToken: 'token'),
            onLogout: () {},
            canCreateProduct: true,
            canExportProducts: true,
            canDeleteProduct: true,
            canUpdateLifecycle: true,
            canViewVersions: true,
            canCompareVersions: true,
            canRollbackVersion: true,
            canManageVersions: true,
            canActivateVersions: true,
            canViewImpactAnalysis: true,
            canViewParameters: true,
            canEditParameters: true,
            canExportParameters: true,
            onViewParameters: (_) {},
            onEditParameters: (_) {},
            service: service,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('操作').last);
  await tester.pumpAndSettle();
  expect(find.text('查看详情'), findsOneWidget);
  expect(find.text('版本管理'), findsOneWidget);
});
```

```dart
// frontend/test/widgets/product_module_issue_regression_test.dart
testWidgets('产品详情应以页内侧栏展示聚合详情', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final service = _ProductDetailDrawerService([
    _buildProduct(id: 21, currentVersion: 2, effectiveVersion: 0),
  ]);

  await tester.pumpWidget(
    _host(
      ProductManagementPage(
        session: _session(),
        onLogout: () {},
        canCreateProduct: false,
        canDeleteProduct: false,
        canUpdateLifecycle: false,
        canViewVersions: false,
        canCompareVersions: false,
        canRollbackVersion: false,
        canViewImpactAnalysis: false,
        canViewParameters: false,
        canEditParameters: false,
        onViewParameters: (_) {},
        onEditParameters: (_) {},
        service: service,
      ),
    ),
  );

  await tester.pumpAndSettle();
  await _openPopupMenu(tester, _popupMenuButtonFinder().first);
  await tester.tap(find.text('查看详情').last);
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('product-detail-drawer')), findsOneWidget);
  expect(find.textContaining('产品详情 - 产品21'), findsOneWidget);
});

testWidgets('版本激活影响分析应使用 lifecycle 操作码', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final service = _ActivateImpactService();

  await tester.pumpWidget(
    _host(
      ProductManagementPage(
        session: _session(),
        onLogout: () {},
        canCreateProduct: false,
        canDeleteProduct: false,
        canUpdateLifecycle: false,
        canViewVersions: true,
        canCompareVersions: false,
        canRollbackVersion: false,
        canManageVersions: true,
        canActivateVersions: true,
        canViewImpactAnalysis: true,
        canViewParameters: false,
        canEditParameters: false,
        onViewParameters: (_) {},
        onEditParameters: (_) {},
        service: service,
      ),
    ),
  );

  await tester.pumpAndSettle();
  await tester.tap(find.text('操作').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('版本管理'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('激活').first);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, '确认生效'));
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('product-version-dialog')), findsOneWidget);
  expect(service.impactOperations.first, 'lifecycle');
});
```

```dart
// frontend/integration_test/product_management_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/product_management_page.dart';
import 'package:mes_client/features/product/services/product_service.dart';

final DateTime _fixedDate = DateTime.parse('2026-04-20T00:00:00Z');

class _IntegrationProductService extends ProductService {
  _IntegrationProductService() : super(AppSession(baseUrl: '', accessToken: 'token'));

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
      total: 1,
      items: [
        ProductItem(
          id: 41,
          name: '产品41',
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
      ],
    );
  }

  @override
  Future<ProductDetailResult> getProductDetail({required int productId}) async {
    return ProductDetailResult(
      product: ProductItem(
        id: 41,
        name: '产品41',
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
      detailParameters: ProductParameterListResult(
        productId: 41,
        productName: '产品41',
        parameterScope: 'version',
        version: 2,
        versionLabel: 'V1.1',
        lifecycleStatus: 'draft',
        total: 0,
        items: const [],
      ),
      detailParameterMessage: null,
      latestVersionChangedAt: _fixedDate,
      versionTotal: 1,
      versions: const [],
      historyTotal: 0,
      historyItems: const [],
      relatedInfoSections: const [],
    );
  }

  @override
  Future<ProductVersionListResult> listProductVersions({
    required int productId,
  }) async {
    return ProductVersionListResult(
      total: 1,
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
      ],
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('产品管理页主路径可筛选 打开详情侧栏和版本管理弹窗', (tester) async {
    final service = _IntegrationProductService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1440,
            height: 900,
            child: ProductManagementPage(
              session: AppSession(baseUrl: '', accessToken: 'token'),
              onLogout: () {},
              canCreateProduct: true,
              canExportProducts: true,
              canDeleteProduct: true,
              canUpdateLifecycle: true,
              canViewVersions: true,
              canCompareVersions: true,
              canRollbackVersion: true,
              canManageVersions: true,
              canActivateVersions: true,
              canViewImpactAnalysis: true,
              canViewParameters: true,
              canEditParameters: true,
              canExportParameters: true,
              onViewParameters: (_) {},
              onEditParameters: (_) {},
              service: service,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('product-management-filter-section')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-management-table-section')), findsOneWidget);

    await tester.tap(find.text('操作').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看详情'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('product-detail-drawer')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.tap(find.text('操作').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('版本管理'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('product-version-dialog')), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行最终失败验证，确认新增观察点尚未完整接通**

Run: `flutter test test/widgets/product_management_page_test.dart test/widgets/product_module_issue_regression_test.dart test/widgets/product_page_test.dart`

Expected: FAIL，至少包含：
- 页面级测试找不到详情侧栏或版本管理弹窗新锚点
- 产品模块回归找不到 `product-detail-drawer` 或 `product-version-dialog`

Run: `flutter test -d windows integration_test/product_management_flow_test.dart`

Expected: FAIL，报错包含文件不存在或断言找不到锚点

- [ ] **Step 3: 扩展页面级 / 模块回归 / integration，并创建实施 evidence**

```md
# 任务日志：产品管理页第二波迁移实施

- 日期：2026-04-20
- 执行人：Codex
- 当前状态：已完成

## 1. 输入来源
- 用户指令：按已批准设计继续实施产品管理页第二波迁移
- 设计规格：`docs/superpowers/specs/2026-04-20-product-management-page-second-wave-design.md`
- 实施计划：`docs/superpowers/plans/2026-04-20-product-management-page-second-wave-implementation.md`

## 2. 实施分段
- 任务 1：建立产品管理页基础展示组件
- 任务 2：迁移 `ProductManagementPage` 到统一 CRUD 骨架
- 任务 3：拆分产品详情侧栏展示层
- 任务 4：拆分版本管理弹窗展示层
- 任务 5：补齐页面回归、integration 与最终收口

## 3. 验证结果
- flutter analyze：通过
- flutter test test/widgets/product_management_page_test.dart test/widgets/product_module_issue_regression_test.dart test/widgets/product_page_test.dart：通过
- flutter test -d windows integration_test/product_management_flow_test.dart：通过

## 4. 风险与补偿
- 当前 integration 仅覆盖桌面主路径，不扩展到所有版本弹窗业务动作链路；复杂操作链路继续由 `product_module_issue_regression_test.dart` 兜底

## 5. 迁移说明
- 无迁移，直接替换
```

- [ ] **Step 4: 运行最终验证**

Run: `flutter analyze`

Expected: `No issues found!`

Run: `flutter test test/widgets/product_management_page_test.dart test/widgets/product_module_issue_regression_test.dart test/widgets/product_page_test.dart`

Expected: PASS

Run: `flutter test -d windows integration_test/product_management_flow_test.dart`

Expected: PASS

- [ ] **Step 5: 提交最终验证与留痕**

```bash
git add frontend/integration_test/product_management_flow_test.dart evidence/2026-04-20_产品管理页第二波迁移实施.md frontend/test/widgets/product_management_page_test.dart frontend/test/widgets/product_module_issue_regression_test.dart frontend/test/widgets/product_page_test.dart
git commit -m "补齐产品管理页迁移验证留痕"
```
