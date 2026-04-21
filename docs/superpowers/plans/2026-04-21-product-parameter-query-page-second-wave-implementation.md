# 产品参数查询页第二波迁移 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 Flutter 前端中完成 `ProductParameterQueryPage` 第二波 UI 迁移，统一查询页骨架，拆分参数查看弹窗展示层，并补齐页面级 widget 回归与 evidence 闭环。

**Architecture:** 先在 `features/product/presentation/widgets/` 下建立查询页基础展示组件，包括页头、筛选区、反馈区和列表区，再将 `ProductParameterQueryPage` 接入 `MesCrudPageScaffold`。随后拆出 `ProductParameterQueryDialog` 和产品参数域内可复用的 `ProductParameterSummaryHeader`，保持查询、导出、Link 打开、`jump command` 和服务调用全部留在主页面。测试按“基础组件 -> 主页面骨架 -> 弹窗与摘要 -> 回归 / evidence”顺序推进，现有业务语义保持不变。

**Tech Stack:** Flutter、Dart、Material 3、`flutter_test`

---

> Flutter 命令默认在 `frontend/` 目录执行；`git`、`evidence` 与计划文档操作默认在仓库根目录执行。  
> 本计划遵循“无迁移，直接替换”。  
> 本页复杂度低于参数管理页，本计划默认不新增独立 `integration_test`，以页面级 widget test + 既有产品模块回归收口。  
> 当前工作区在计划编写完成时应保持仅包含本计划文档与计划阶段 `evidence`，执行本计划时再新增实施阶段 `evidence/2026-04-21_产品参数查询页第二波迁移实施.md`。

## 文件结构

### 新增文件

- `frontend/lib/features/product/presentation/widgets/product_parameter_query_page_header.dart`
  - 查询页页头，只负责页面标题与刷新入口
- `frontend/lib/features/product/presentation/widgets/product_parameter_query_filter_section.dart`
  - 查询页筛选区，承接产品名称、分类、搜索和导出入口
- `frontend/lib/features/product/presentation/widgets/product_parameter_query_feedback_banner.dart`
  - 查询页页内反馈区
- `frontend/lib/features/product/presentation/widgets/product_parameter_query_table_section.dart`
  - 查询页列表区，承接 DataTable、状态列和操作列包装
- `frontend/lib/features/product/presentation/widgets/product_parameter_query_dialog.dart`
  - 参数查看弹窗整体展示层
- `frontend/lib/features/product/presentation/widgets/product_parameter_summary_header.dart`
  - 产品参数域内可复用的顶部摘要展示组件
- `frontend/test/widgets/product_parameter_query_page_test.dart`
  - 产品参数查询页第二波迁移的页面级 widget test
- `evidence/2026-04-21_产品参数查询页第二波迁移实施.md`
  - 实施阶段主日志，由执行阶段创建

### 修改文件

- `frontend/lib/features/product/presentation/product_parameter_query_page.dart`
  - 保留列表加载、导出、Link 打开、参数请求和 `jump command` 处理，但改为装配新展示组件
- `frontend/test/widgets/product_module_issue_regression_test.dart`
  - 保留并扩展参数查询页相关回归断言

## 任务 1：建立查询页基础展示组件

**Files:**
- Create: `frontend/lib/features/product/presentation/widgets/product_parameter_query_page_header.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_parameter_query_filter_section.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_parameter_query_feedback_banner.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_parameter_query_table_section.dart`
- Create: `frontend/test/widgets/product_parameter_query_page_test.dart`

- [ ] **Step 1: 先写失败测试，固定基础展示组件的稳定锚点**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_feedback_banner.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_filter_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_page_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_table_section.dart';

final DateTime _fixedDate = DateTime.parse('2026-04-21T00:00:00Z');

ProductItem _buildProduct({
  required int id,
  String category = '贴片',
  String lifecycleStatus = 'active',
  int effectiveVersion = 1,
}) {
  return ProductItem(
    id: id,
    name: '产品$id',
    category: category,
    remark: '',
    lifecycleStatus: lifecycleStatus,
    currentVersion: effectiveVersion == 0 ? 1 : effectiveVersion,
    currentVersionLabel: effectiveVersion == 0 ? 'V1.0' : 'V1.${effectiveVersion - 1}',
    effectiveVersion: effectiveVersion,
    effectiveVersionLabel: effectiveVersion == 0 ? null : 'V1.${effectiveVersion - 1}',
    effectiveAt: effectiveVersion == 0 ? null : _fixedDate,
    inactiveReason: null,
    lastParameterSummary: null,
    createdAt: _fixedDate,
    updatedAt: _fixedDate,
  );
}

void main() {
  testWidgets('产品参数查询页基础组件提供稳定页头 筛选区 反馈区和列表区锚点', (tester) async {
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
              ProductParameterQueryPageHeader(
                loading: false,
                onRefresh: () {},
              ),
              ProductParameterQueryFilterSection(
                keywordController: keywordController,
                categoryOptions: const ['贴片', 'DTU', '套件'],
                selectedCategory: '',
                loading: false,
                canExportParameters: true,
                onCategoryChanged: (_) {},
                onSearch: () {},
                onExport: () {},
              ),
              const ProductParameterQueryFeedbackBanner(
                message: '加载失败：网络错误',
              ),
              Expanded(
                child: ProductParameterQueryTableSection(
                  products: [
                    _buildProduct(id: 81, effectiveVersion: 1),
                    _buildProduct(id: 82, category: '', effectiveVersion: 2),
                  ],
                  loading: false,
                  emptyText: '暂无产品',
                  formatTime: (_) => '2026-04-21 08:00:00',
                  onViewParameters: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('产品参数查询'), findsOneWidget);
    expect(find.byKey(const ValueKey('product-parameter-query-filter-section')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-parameter-query-feedback-banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-parameter-query-table-section')), findsOneWidget);
    expect(find.text('搜索产品名称'), findsOneWidget);
    expect(find.text('分类筛选'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '搜索'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '导出'), findsOneWidget);
    expect(find.text('产品81'), findsOneWidget);
    expect(find.text('产品82'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '查看参数'), findsNWidgets(2));
  });
}
```

- [ ] **Step 2: 运行页面级测试，确认基础展示组件尚未存在**

Run: `flutter test test/widgets/product_parameter_query_page_test.dart --plain-name "产品参数查询页基础组件提供稳定页头 筛选区 反馈区和列表区锚点"`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Undefined class 'ProductParameterQueryPageHeader'`

- [ ] **Step 3: 实现查询页基础展示组件**

```dart
// frontend/lib/features/product/presentation/widgets/product_parameter_query_page_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class ProductParameterQueryPageHeader extends StatelessWidget {
  const ProductParameterQueryPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
  });

  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return MesPageHeader(
      title: '产品参数查询',
      subtitle: '按启用且已有生效版本的产品查看当前生效参数。',
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
// frontend/lib/features/product/presentation/widgets/product_parameter_query_filter_section.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';

class ProductParameterQueryFilterSection extends StatelessWidget {
  const ProductParameterQueryFilterSection({
    super.key,
    required this.keywordController,
    required this.categoryOptions,
    required this.selectedCategory,
    required this.loading,
    required this.canExportParameters,
    required this.onCategoryChanged,
    required this.onSearch,
    required this.onExport,
  });

  final TextEditingController keywordController;
  final List<String> categoryOptions;
  final String selectedCategory;
  final bool loading;
  final bool canExportParameters;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onSearch;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-parameter-query-filter-section'),
      child: MesFilterBar(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
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
              width: 160,
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
            FilledButton.icon(
              onPressed: loading ? null : onSearch,
              icon: const Icon(Icons.search),
              label: const Text('搜索'),
            ),
            OutlinedButton.icon(
              onPressed: loading || !canExportParameters ? null : onExport,
              icon: const Icon(Icons.download),
              label: const Text('导出'),
            ),
          ],
        ),
      ),
    );
  }
}
```

```dart
// frontend/lib/features/product/presentation/widgets/product_parameter_query_feedback_banner.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_inline_banner.dart';

class ProductParameterQueryFeedbackBanner extends StatelessWidget {
  const ProductParameterQueryFeedbackBanner({
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
      key: const ValueKey('product-parameter-query-feedback-banner'),
      child: MesInlineBanner.error(message: message),
    );
  }
}
```

```dart
// frontend/lib/features/product/presentation/widgets/product_parameter_query_table_section.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/widgets/adaptive_table_container.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';
import 'package:mes_client/features/product/models/product_models.dart';

class ProductParameterQueryTableSection extends StatelessWidget {
  const ProductParameterQueryTableSection({
    super.key,
    required this.products,
    required this.loading,
    required this.emptyText,
    required this.formatTime,
    required this.onViewParameters,
  });

  final List<ProductItem> products;
  final bool loading;
  final String emptyText;
  final String Function(DateTime value) formatTime;
  final ValueChanged<ProductItem> onViewParameters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KeyedSubtree(
      key: const ValueKey('product-parameter-query-table-section'),
      child: CrudListTableSection(
        loading: loading,
        isEmpty: products.isEmpty,
        emptyText: emptyText,
        enableUnifiedHeaderStyle: true,
        child: AdaptiveTableContainer(
          child: UnifiedListTableHeaderStyle.wrap(
            theme: theme,
            child: DataTable(
              columns: [
                UnifiedListTableHeaderStyle.column(context, '产品名称'),
                UnifiedListTableHeaderStyle.column(context, '产品分类'),
                UnifiedListTableHeaderStyle.column(context, '生效版本'),
                UnifiedListTableHeaderStyle.column(context, '当前状态'),
                UnifiedListTableHeaderStyle.column(context, '创建时间'),
                UnifiedListTableHeaderStyle.column(
                  context,
                  '操作',
                  textAlign: TextAlign.center,
                ),
              ],
              rows: products.map((product) {
                return DataRow(
                  cells: [
                    DataCell(Text(product.name)),
                    DataCell(Text(product.category.isEmpty ? '-' : product.category)),
                    DataCell(
                      Text(
                        product.effectiveVersionLabel ??
                            (product.effectiveVersion > 0
                                ? 'V1.${product.effectiveVersion - 1}'
                                : '-'),
                      ),
                    ),
                    DataCell(Text(_lifecycleLabel(product.lifecycleStatus))),
                    DataCell(Text(formatTime(product.createdAt))),
                    DataCell(
                      UnifiedListTableHeaderStyle.cellContent(
                        TextButton(
                          onPressed: () => onViewParameters(product),
                          child: const Text('查看参数'),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

String _lifecycleLabel(String value) {
  switch (value) {
    case 'active':
    case 'effective':
      return '启用';
    case 'inactive':
      return '停用';
    default:
      return value.isEmpty ? '-' : value;
  }
}
```

- [ ] **Step 4: 重新运行页面级测试，确认基础展示组件可用**

Run: `flutter test test/widgets/product_parameter_query_page_test.dart --plain-name "产品参数查询页基础组件提供稳定页头 筛选区 反馈区和列表区锚点"`

Expected: PASS

- [ ] **Step 5: 提交基础展示组件**

```bash
git add frontend/lib/features/product/presentation/widgets/product_parameter_query_page_header.dart frontend/lib/features/product/presentation/widgets/product_parameter_query_filter_section.dart frontend/lib/features/product/presentation/widgets/product_parameter_query_feedback_banner.dart frontend/lib/features/product/presentation/widgets/product_parameter_query_table_section.dart frontend/test/widgets/product_parameter_query_page_test.dart
git commit -m "拆分产品参数查询页基础组件"
```

## 任务 2：迁移主页面到统一查询页骨架

**Files:**
- Modify: `frontend/lib/features/product/presentation/product_parameter_query_page.dart`
- Modify: `frontend/test/widgets/product_parameter_query_page_test.dart`

- [ ] **Step 1: 为主页面骨架迁移补失败测试，固定统一锚点和查询口径**

```dart
// frontend/test/widgets/product_parameter_query_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/product_page.dart';
import 'package:mes_client/features/product/presentation/product_parameter_query_page.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_page_header.dart';
import 'package:mes_client/features/product/services/product_service.dart';

AppSession _session() => AppSession(baseUrl: '', accessToken: 'token');

class _QueryPageStructureService extends ProductService {
  _QueryPageStructureService(this.products) : super(_session());

  final List<ProductItem> products;
  int queryCalls = 0;

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
    throw ApiException('参数查询页不应回退产品管理列表接口', 500);
  }

  @override
  Future<ProductListResult> listProductsForParameterQuery({
    required int page,
    required int pageSize,
    String? keyword,
    String? category,
    String? lifecycleStatus,
    bool? hasEffectiveVersion,
    String? effectiveVersionKeyword,
  }) async {
    queryCalls += 1;
    return ProductListResult(total: products.length, items: products);
  }
}

testWidgets('ProductParameterQueryPage 列表态接入统一查询骨架并展示锚点', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final service = _QueryPageStructureService([
    _buildProduct(id: 91, effectiveVersion: 1),
  ]);

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
          child: ProductParameterQueryPage(
            session: _session(),
            onLogout: () {},
            tabCode: productParameterQueryTabCode,
            service: service,
            canExportParameters: true,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byType(MesCrudPageScaffold), findsOneWidget);
  expect(find.byType(ProductParameterQueryPageHeader), findsOneWidget);
  expect(find.byKey(const ValueKey('product-parameter-query-filter-section')), findsOneWidget);
  expect(find.byKey(const ValueKey('product-parameter-query-table-section')), findsOneWidget);
  expect(find.widgetWithText(OutlinedButton, '导出'), findsOneWidget);
  expect(service.queryCalls, 1);
  expect(find.text('产品91'), findsOneWidget);
});
```

- [ ] **Step 2: 运行主页面结构测试，确认仍在旧式手工拼装**

Run: `flutter test test/widgets/product_parameter_query_page_test.dart --plain-name "ProductParameterQueryPage 列表态接入统一查询骨架并展示锚点"`

Expected: FAIL，至少包含：
- 找不到 `MesCrudPageScaffold`
- 找不到 `product-parameter-query-filter-section` 或 `product-parameter-query-table-section`

- [ ] **Step 3: 将主页面切到 `MesCrudPageScaffold` 并装配新查询组件**

```dart
// frontend/lib/features/product/presentation/product_parameter_query_page.dart
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_feedback_banner.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_filter_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_page_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_table_section.dart';

Widget _buildListView() {
  return MesCrudPageScaffold(
    header: ProductParameterQueryPageHeader(
      loading: _loading,
      onRefresh: _loadProducts,
    ),
    filters: ProductParameterQueryFilterSection(
      keywordController: _keywordController,
      categoryOptions: _productCategoryOptions,
      selectedCategory: _selectedCategoryFilter,
      loading: _loading,
      canExportParameters: widget.canExportParameters,
      onCategoryChanged: (value) {
        setState(() {
          _selectedCategoryFilter = value;
        });
        _loadProducts();
      },
      onSearch: _loadProducts,
      onExport: _exportParameters,
    ),
    banner: _message.isEmpty
        ? null
        : ProductParameterQueryFeedbackBanner(message: _message),
    content: ProductParameterQueryTableSection(
      products: _filteredProducts,
      loading: _loading,
      emptyText: '暂无产品',
      formatTime: _formatTime,
      onViewParameters: _showParametersDialog,
    ),
  );
}

@override
Widget build(BuildContext context) {
  return _buildListView();
}
```

- [ ] **Step 4: 运行主页面结构测试和既有查询接口回归**

Run: `flutter test test/widgets/product_parameter_query_page_test.dart --plain-name "ProductParameterQueryPage 列表态接入统一查询骨架并展示锚点"`

Expected: PASS

Run: `flutter test test/widgets/product_module_issue_regression_test.dart --plain-name "参数查询页应使用只读查询接口而非产品列表接口"`

Expected: PASS

- [ ] **Step 5: 提交主页面骨架迁移**

```bash
git add frontend/lib/features/product/presentation/product_parameter_query_page.dart frontend/test/widgets/product_parameter_query_page_test.dart
git commit -m "迁移产品参数查询页列表骨架"
```

## 任务 3：拆分参数查看弹窗与可复用摘要组件

**Files:**
- Create: `frontend/lib/features/product/presentation/widgets/product_parameter_query_dialog.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_parameter_summary_header.dart`
- Modify: `frontend/lib/features/product/presentation/product_parameter_query_page.dart`
- Modify: `frontend/test/widgets/product_parameter_query_page_test.dart`

- [ ] **Step 1: 先写失败测试，固定弹窗骨架、摘要区和空态位置**

```dart
// frontend/test/widgets/product_parameter_query_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_dialog.dart';

ProductParameterListResult _buildParameterResult({
  required String productName,
  required String versionLabel,
  required int total,
  required List<ProductParameterItem> items,
}) {
  return ProductParameterListResult(
    productId: 81,
    productName: productName,
    parameterScope: 'effective',
    version: 1,
    versionLabel: versionLabel,
    lifecycleStatus: 'effective',
    total: total,
    items: items,
  );
}

testWidgets('参数查看弹窗展示顶部摘要和参数表格', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProductParameterQueryDialog(
          result: _buildParameterResult(
            productName: '产品81',
            versionLabel: 'V1.0',
            total: 2,
            items: [
              ProductParameterItem(
                name: '图纸链接',
                category: '文档',
                type: 'Link',
                value: 'https://example.com/files/spec.pdf',
                description: '在线资料',
                sortOrder: 1,
                isPreset: false,
              ),
              ProductParameterItem(
                name: '本地图纸',
                category: '文档',
                type: 'Link',
                value: r'C:\docs\manual.pdf',
                description: '',
                sortOrder: 2,
                isPreset: false,
              ),
            ],
          ),
          buildParameterValueCell: (item) => Text(item.value),
          onClose: () {},
        ),
      ),
    ),
  );

  expect(find.byKey(const ValueKey('product-parameter-query-dialog')), findsOneWidget);
  expect(find.byKey(const ValueKey('product-parameter-summary-header')), findsOneWidget);
  expect(find.text('产品81'), findsOneWidget);
  expect(find.text('版本：V1.0'), findsOneWidget);
  expect(find.text('参数总数：2 项'), findsOneWidget);
  expect(find.text('仅展示当前生效版本参数'), findsOneWidget);
  expect(find.text('图纸链接'), findsOneWidget);
  expect(find.text('本地图纸'), findsOneWidget);
});

testWidgets('参数查看弹窗空态时仍保留顶部摘要区', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProductParameterQueryDialog(
          result: _buildParameterResult(
            productName: '产品82',
            versionLabel: 'V1.1',
            total: 0,
            items: const [],
          ),
          buildParameterValueCell: (item) => Text(item.value),
          onClose: () {},
        ),
      ),
    ),
  );

  expect(find.byKey(const ValueKey('product-parameter-summary-header')), findsOneWidget);
  expect(find.text('产品82'), findsOneWidget);
  expect(find.text('参数总数：0 项'), findsOneWidget);
  expect(find.text('该产品暂无参数'), findsOneWidget);
});
```

- [ ] **Step 2: 运行弹窗测试，确认展示层与摘要组件尚未拆出**

Run: `flutter test test/widgets/product_parameter_query_page_test.dart --plain-name "参数查看弹窗展示顶部摘要和参数表格"`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Undefined class 'ProductParameterQueryDialog'`

Run: `flutter test test/widgets/product_parameter_query_page_test.dart --plain-name "参数查看弹窗空态时仍保留顶部摘要区"`

Expected: FAIL，原因同上

- [ ] **Step 3: 实现参数查看弹窗与可复用摘要组件，并改主页面装配**

```dart
// frontend/lib/features/product/presentation/widgets/product_parameter_summary_header.dart
import 'package:flutter/material.dart';

class ProductParameterSummaryHeader extends StatelessWidget {
  const ProductParameterSummaryHeader({
    super.key,
    required this.productName,
    required this.versionLabel,
    required this.parameterCount,
    this.scopeHint = '仅展示当前生效版本参数',
  });

  final String productName;
  final String versionLabel;
  final int parameterCount;
  final String scopeHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KeyedSubtree(
      key: const ValueKey('product-parameter-summary-header'),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                productName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text('版本：${versionLabel.isEmpty ? '-' : versionLabel}'),
                  Text('参数总数：$parameterCount 项'),
                ],
              ),
              if (scopeHint.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  scopeHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

```dart
// frontend/lib/features/product/presentation/widgets/product_parameter_query_dialog.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/widgets/adaptive_table_container.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_summary_header.dart';

class ProductParameterQueryDialog extends StatelessWidget {
  const ProductParameterQueryDialog({
    super.key,
    required this.result,
    required this.buildParameterValueCell,
    required this.onClose,
  });

  final ProductParameterListResult result;
  final Widget Function(ProductParameterItem item) buildParameterValueCell;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-parameter-query-dialog'),
      child: AlertDialog(
        title: Text('产品参数 - ${result.productName}'),
        content: SizedBox(
          width: 1000,
          height: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductParameterSummaryHeader(
                productName: result.productName,
                versionLabel: result.versionLabel,
                parameterCount: result.total,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: result.items.isEmpty
                    ? const Center(child: Text('该产品暂无参数'))
                    : AdaptiveTableContainer(
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('参数名称')),
                            DataColumn(label: Text('参数分类')),
                            DataColumn(label: Text('参数类型')),
                            DataColumn(label: Text('参数值')),
                            DataColumn(label: Text('参数说明')),
                          ],
                          rows: result.items.map((item) {
                            return DataRow(
                              cells: [
                                DataCell(Text(item.name)),
                                DataCell(Text(item.category)),
                                DataCell(Text(item.type)),
                                DataCell(buildParameterValueCell(item)),
                                DataCell(
                                  Text(item.description.isEmpty ? '-' : item.description),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: onClose, child: const Text('关闭')),
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/features/product/presentation/product_parameter_query_page.dart
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_dialog.dart';

await showDialog<void>(
  context: context,
  builder: (context) {
    return ProductParameterQueryDialog(
      result: result,
      buildParameterValueCell: _buildParameterValueCell,
      onClose: () => Navigator.of(context).pop(),
    );
  },
);
```

- [ ] **Step 4: 运行弹窗测试与既有交互回归**

Run: `flutter test test/widgets/product_parameter_query_page_test.dart`

Expected: PASS

Run: `flutter test test/widgets/product_module_issue_regression_test.dart --plain-name "参数查询页应支持弹窗 Link 打开 导出与跳转后查看"`

Expected: PASS

- [ ] **Step 5: 提交弹窗与摘要组件拆分**

```bash
git add frontend/lib/features/product/presentation/widgets/product_parameter_query_dialog.dart frontend/lib/features/product/presentation/widgets/product_parameter_summary_header.dart frontend/lib/features/product/presentation/product_parameter_query_page.dart frontend/test/widgets/product_parameter_query_page_test.dart
git commit -m "拆分产品参数查询页参数弹窗展示层"
```

## 任务 4：扩展回归并完成实施 evidence 收口

**Files:**
- Modify: `frontend/test/widgets/product_module_issue_regression_test.dart`
- Create: `evidence/2026-04-21_产品参数查询页第二波迁移实施.md`

- [ ] **Step 1: 扩展既有交互回归，固定摘要区在跳转打开与直接打开场景都存在**

```dart
// frontend/test/widgets/product_module_issue_regression_test.dart
expect(find.byKey(const ValueKey('product-parameter-summary-header')), findsOneWidget);
expect(find.text('仅展示当前生效版本参数'), findsOneWidget);
expect(find.text('参数总数：2 项'), findsOneWidget);

await tester.tap(find.widgetWithText(FilledButton, '关闭'));
await tester.pumpAndSettle();
expect(handledJumpSeq, 9);

await tester.tap(find.widgetWithText(OutlinedButton, '导出'));
await tester.pumpAndSettle();
expect(service.exportCalls, 1);

await tester.tap(find.widgetWithText(TextButton, '查看参数'));
await tester.pumpAndSettle();
expect(service.detailCalls, 2);
expect(find.byKey(const ValueKey('product-parameter-summary-header')), findsOneWidget);
```

- [ ] **Step 2: 创建实施阶段 evidence 主日志**

```md
# 任务日志：产品参数查询页第二波迁移实施

- 日期：2026-04-21
- 执行人：Codex
- 当前状态：已完成

## 1. 输入来源
- 用户指令：
  - 在批准 `ProductParameterQueryPage` 第二波迁移设计后继续实施
- 设计规格：
  - `docs/superpowers/specs/2026-04-21-product-parameter-query-page-second-wave-design.md`
- 实施计划：
  - `docs/superpowers/plans/2026-04-21-product-parameter-query-page-second-wave-implementation.md`

## 2. 实施分段
- 任务 1：建立查询页基础展示组件
- 任务 2：迁移主页面到统一查询页骨架
- 任务 3：拆分参数查看弹窗与可复用摘要组件
- 任务 4：扩展回归并完成实施 evidence 收口

## 3. 验证结果
- `flutter analyze`：通过
- `flutter test test/widgets/product_parameter_query_page_test.dart`：通过
- `flutter test test/widgets/product_module_issue_regression_test.dart --plain-name "参数查询页应使用只读查询接口而非产品列表接口"`：通过
- `flutter test test/widgets/product_module_issue_regression_test.dart --plain-name "参数查询页应支持弹窗 Link 打开 导出与跳转后查看"`：通过

## 4. 风险与补偿
- 当前未新增独立 `integration_test`，由页面级 widget test 与既有产品模块回归共同覆盖主路径

## 5. 迁移说明
- 无迁移，直接替换
```

- [ ] **Step 3: 运行最终验证**

Run: `flutter analyze`

Expected: `No issues found!`

Run: `flutter test test/widgets/product_parameter_query_page_test.dart`

Expected: PASS

Run: `flutter test test/widgets/product_module_issue_regression_test.dart --plain-name "参数查询页应使用只读查询接口而非产品列表接口"`

Expected: PASS

Run: `flutter test test/widgets/product_module_issue_regression_test.dart --plain-name "参数查询页应支持弹窗 Link 打开 导出与跳转后查看"`

Expected: PASS

- [ ] **Step 4: 提交最终回归与实施留痕**

```bash
git add frontend/lib/features/product/presentation/product_parameter_query_page.dart frontend/lib/features/product/presentation/widgets/product_parameter_query_page_header.dart frontend/lib/features/product/presentation/widgets/product_parameter_query_filter_section.dart frontend/lib/features/product/presentation/widgets/product_parameter_query_feedback_banner.dart frontend/lib/features/product/presentation/widgets/product_parameter_query_table_section.dart frontend/lib/features/product/presentation/widgets/product_parameter_query_dialog.dart frontend/lib/features/product/presentation/widgets/product_parameter_summary_header.dart frontend/test/widgets/product_parameter_query_page_test.dart frontend/test/widgets/product_module_issue_regression_test.dart evidence/2026-04-21_产品参数查询页第二波迁移实施.md
git commit -m "完成产品参数查询页第二波迁移"
```
