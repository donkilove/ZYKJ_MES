# 产品参数管理页第二波迁移 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 Flutter 前端中完成产品参数管理页第二波 UI 迁移，统一列表态与编辑态骨架，拆分历史弹窗展示层，并补齐 widget / integration / evidence 闭环。

**Architecture:** 先在 `features/product/presentation/widgets/` 建立列表态基础展示组件，再将 `ProductParameterManagementPage` 的列表态接入统一骨架。随后继续拆出编辑态展示层和历史弹窗展示层，保持参数编辑逻辑、脏数据判断、Link 校验、服务调用和 `jump command` 处理留在主页面。测试按“列表态组件 -> 列表态主页面 -> 编辑态 -> 历史弹窗 -> 页面回归 / integration / evidence”顺序推进，现有业务语义保持不变。

**Tech Stack:** Flutter、Dart、Material 3、`flutter_test`、`integration_test`

---

> Flutter 命令默认在 `frontend/` 目录执行；`git`、`evidence` 与计划文档操作默认在仓库根目录执行。  
> 本计划遵循“无迁移，直接替换”。  
> 用户已明确要求在当前 `main` 分支内直接执行，不派发子 AGENT。  
> 当前工作区已有两处与本计划无关的改动：`evidence/2026-04-20_产品版本管理页第二波迁移实施.md`、`evidence/2026-04-20_产品管理页第二波迁移实施.md`。执行本计划时不要误将这两个文件一并提交。

## 文件结构

### 新增文件

- `frontend/lib/features/product/presentation/widgets/product_parameter_management_page_header.dart`
  - 列表态页头，只负责页面标题与刷新入口
- `frontend/lib/features/product/presentation/widgets/product_parameter_management_filter_section.dart`
  - 列表态筛选区，承接产品名称、分类和列表态主操作
- `frontend/lib/features/product/presentation/widgets/product_parameter_management_feedback_banner.dart`
  - 列表态页内反馈区
- `frontend/lib/features/product/presentation/widgets/product_parameter_version_table_section.dart`
  - 列表态版本参数表格区
- `frontend/lib/features/product/presentation/widgets/product_parameter_editor_row_model.dart`
  - 编辑态参数行视图模型，承接控制器与参数类型状态
- `frontend/lib/features/product/presentation/widgets/product_parameter_editor_header.dart`
  - 编辑态头部，负责返回入口、标题和只读提示
- `frontend/lib/features/product/presentation/widgets/product_parameter_editor_toolbar.dart`
  - 编辑态工具条，负责分组筛选、刷新和未保存修改提示
- `frontend/lib/features/product/presentation/widgets/product_parameter_editor_table.dart`
  - 编辑态参数表格主体
- `frontend/lib/features/product/presentation/widgets/product_parameter_editor_footer.dart`
  - 编辑态底部动作区，负责新增参数、备注输入和保存/取消
- `frontend/lib/features/product/presentation/widgets/product_parameter_history_dialog.dart`
  - 历史弹窗整体展示层
- `frontend/lib/features/product/presentation/widgets/product_parameter_history_snapshot_dialog.dart`
  - 历史快照查看弹窗
- `frontend/test/widgets/product_parameter_management_page_test.dart`
  - 产品参数管理页第二波迁移的页面级 widget test
- `frontend/integration_test/product_parameter_management_flow_test.dart`
  - 产品参数管理页桌面主路径 integration test
- `evidence/2026-04-20_产品参数管理页第二波迁移实施.md`
  - 本轮实施 evidence 主日志

### 修改文件

- `frontend/lib/features/product/presentation/product_parameter_management_page.dart`
  - 保留列表数据加载、编辑态进入、保存、历史查询、导出和 `jump command` 处理，但改为装配新展示组件
- `frontend/test/widgets/product_module_issue_regression_test.dart`
  - 保留并扩展参数管理页相关回归断言
- `frontend/test/widgets/product_page_test.dart`
  - 保持最小回归，确认产品模块页签装配未被破坏

## 任务 1：建立列表态基础展示组件

**Files:**
- Create: `frontend/lib/features/product/presentation/widgets/product_parameter_management_page_header.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_parameter_management_filter_section.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_parameter_management_feedback_banner.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_parameter_version_table_section.dart`
- Create: `frontend/test/widgets/product_parameter_management_page_test.dart`

- [ ] **Step 1: 先写失败测试，固定列表态基础组件锚点**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_management_feedback_banner.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_management_filter_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_management_page_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_version_table_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_version_table_section.dart'
    show ProductParameterManagementListAction;

final DateTime _fixedDate = DateTime.parse('2026-04-20T00:00:00Z');

ProductParameterVersionListItem _buildVersionRow({
  required int productId,
  required int version,
  required String lifecycleStatus,
  bool isCurrentVersion = false,
  bool isEffectiveVersion = false,
}) {
  return ProductParameterVersionListItem(
    productId: productId,
    productName: '产品$productId',
    productCategory: '贴片',
    version: version,
    versionLabel: 'V1.${version - 1}',
    lifecycleStatus: lifecycleStatus,
    isCurrentVersion: isCurrentVersion,
    isEffectiveVersion: isEffectiveVersion,
    createdAt: _fixedDate,
    parameterSummary: '当前草稿参数',
    parameterCount: 8,
    matchedParameterName: '产品芯片',
    matchedParameterCategory: '基础参数',
    lastModifiedParameter: '产品芯片',
    lastModifiedParameterCategory: '基础参数',
    updatedAt: _fixedDate,
  );
}

void main() {
  testWidgets('参数管理页列表态组件提供稳定页头 筛选区 反馈区和表格锚点', (tester) async {
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
              ProductParameterManagementPageHeader(
                loading: false,
                onRefresh: () {},
              ),
              ProductParameterManagementFilterSection(
                keywordController: keywordController,
                selectedCategory: '',
                loading: false,
                onCategoryChanged: (_) {},
                onSearch: () {},
              ),
              const ProductParameterManagementFeedbackBanner(
                message: '加载失败：网络错误',
              ),
              Expanded(
                child: ProductParameterVersionTableSection(
                  rows: [
                    _buildVersionRow(
                      productId: 41,
                      version: 1,
                      lifecycleStatus: 'effective',
                      isEffectiveVersion: true,
                    ),
                    _buildVersionRow(
                      productId: 41,
                      version: 2,
                      lifecycleStatus: 'draft',
                      isCurrentVersion: true,
                    ),
                  ],
                  loading: false,
                  emptyText: '暂无版本参数记录',
                  formatTime: (_) => '2026-04-20 08:00:00',
                  buildActionItems: (_) => const [
                    PopupMenuItem<ProductParameterManagementListAction>(
                      value: ProductParameterManagementListAction.view,
                      child: Text('查看参数'),
                    ),
                    PopupMenuItem<ProductParameterManagementListAction>(
                      value: ProductParameterManagementListAction.history,
                      child: Text('查看历史'),
                    ),
                  ],
                  onSelected: (action, row) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('版本参数管理'), findsOneWidget);
    expect(find.byKey(const ValueKey('product-parameter-filter-section')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-parameter-feedback-banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-parameter-version-table-section')), findsOneWidget);
    expect(find.text('搜索产品名称'), findsOneWidget);
    expect(find.text('分类筛选'), findsOneWidget);
    expect(find.text('产品41'), findsWidgets);
    expect(find.text('V1.0 / #1'), findsOneWidget);
    expect(find.text('V1.1 / #2'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行页面级测试，确认列表态基础组件尚未存在**

Run: `flutter test test/widgets/product_parameter_management_page_test.dart`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Undefined class 'ProductParameterManagementPageHeader'`

- [ ] **Step 3: 实现列表态基础展示组件**

```dart
// frontend/lib/features/product/presentation/widgets/product_parameter_management_page_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class ProductParameterManagementPageHeader extends StatelessWidget {
  const ProductParameterManagementPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
  });

  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return MesPageHeader(
      title: '版本参数管理',
      subtitle: '按版本查看、编辑和导出产品参数。',
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
// frontend/lib/features/product/presentation/widgets/product_parameter_management_filter_section.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';

class ProductParameterManagementFilterSection extends StatelessWidget {
  const ProductParameterManagementFilterSection({
    super.key,
    required this.keywordController,
    required this.selectedCategory,
    required this.loading,
    required this.onCategoryChanged,
    required this.onSearch,
  });

  final TextEditingController keywordController;
  final String selectedCategory;
  final bool loading;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-parameter-filter-section'),
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
                items: const [
                  DropdownMenuItem<String>(value: '', child: Text('全部')),
                  DropdownMenuItem<String>(value: '贴片', child: Text('贴片')),
                  DropdownMenuItem<String>(value: 'DTU', child: Text('DTU')),
                  DropdownMenuItem<String>(value: '套件', child: Text('套件')),
                ],
                onChanged: loading ? null : (value) => onCategoryChanged(value ?? ''),
              ),
            ),
            FilledButton.icon(
              onPressed: loading ? null : onSearch,
              icon: const Icon(Icons.search),
              label: const Text('搜索'),
            ),
          ],
        ),
      ),
    );
  }
}
```

```dart
// frontend/lib/features/product/presentation/widgets/product_parameter_management_feedback_banner.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_inline_banner.dart';

class ProductParameterManagementFeedbackBanner extends StatelessWidget {
  const ProductParameterManagementFeedbackBanner({
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
      key: const ValueKey('product-parameter-feedback-banner'),
      child: MesInlineBanner.error(message: message),
    );
  }
}
```

```dart
// frontend/lib/features/product/presentation/widgets/product_parameter_version_table_section.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/widgets/adaptive_table_container.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';
import 'package:mes_client/features/product/models/product_models.dart';

enum ProductParameterManagementListAction { view, edit, history, export }

class ProductParameterVersionTableSection extends StatelessWidget {
  const ProductParameterVersionTableSection({
    super.key,
    required this.rows,
    required this.loading,
    required this.emptyText,
    required this.formatTime,
    required this.buildActionItems,
    required this.onSelected,
  });

  final List<ProductParameterVersionListItem> rows;
  final bool loading;
  final String emptyText;
  final String Function(DateTime value) formatTime;
  final List<PopupMenuEntry<ProductParameterManagementListAction>> Function(
    ProductParameterVersionListItem row,
  )
  buildActionItems;
  final void Function(
    ProductParameterManagementListAction action,
    ProductParameterVersionListItem row,
  )
  onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KeyedSubtree(
      key: const ValueKey('product-parameter-version-table-section'),
      child: CrudListTableSection(
        loading: loading,
        isEmpty: rows.isEmpty,
        emptyText: emptyText,
        enableUnifiedHeaderStyle: true,
        child: AdaptiveTableContainer(
          child: UnifiedListTableHeaderStyle.wrap(
            theme: theme,
            child: DataTable(
              columns: [
                UnifiedListTableHeaderStyle.column(context, '产品名称'),
                UnifiedListTableHeaderStyle.column(context, '产品分类'),
                UnifiedListTableHeaderStyle.column(context, '版本标签/版本号'),
                UnifiedListTableHeaderStyle.column(context, '创建时间'),
                UnifiedListTableHeaderStyle.column(context, '版本状态'),
                UnifiedListTableHeaderStyle.column(
                  context,
                  '操作',
                  textAlign: TextAlign.center,
                ),
              ],
              rows: rows.map((row) {
                return DataRow(
                  cells: [
                    DataCell(Text(row.productName)),
                    DataCell(Text(row.productCategory.isEmpty ? '-' : row.productCategory)),
                    DataCell(Text('${row.versionLabel} / #${row.version}')),
                    DataCell(Text(formatTime(row.createdAt))),
                    DataCell(
                      Text(
                        [
                          _lifecycleLabel(row.lifecycleStatus),
                          if (row.isCurrentVersion) '当前版本',
                          if (row.isEffectiveVersion) '生效版本',
                        ].join(' / '),
                      ),
                    ),
                    DataCell(
                      UnifiedListTableHeaderStyle.actionMenuButton<
                          ProductParameterManagementListAction>(
                        theme: theme,
                        onSelected: (action) => onSelected(action, row),
                        itemBuilder: (context) => buildActionItems(row),
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
    case 'draft':
      return '草稿';
    case 'effective':
      return '已生效';
    case 'obsolete':
      return '已失效';
    case 'disabled':
      return '已停用';
    default:
      return value.isEmpty ? '-' : value;
  }
}
```

- [ ] **Step 4: 重新运行页面级测试，确认列表态基础组件可用**

Run: `flutter test test/widgets/product_parameter_management_page_test.dart`

Expected: PASS

- [ ] **Step 5: 提交列表态基础组件**

```bash
git add frontend/lib/features/product/presentation/widgets/product_parameter_management_page_header.dart frontend/lib/features/product/presentation/widgets/product_parameter_management_filter_section.dart frontend/lib/features/product/presentation/widgets/product_parameter_management_feedback_banner.dart frontend/lib/features/product/presentation/widgets/product_parameter_version_table_section.dart frontend/test/widgets/product_parameter_management_page_test.dart
git commit -m "拆分产品参数管理页列表态组件"
```

## 任务 2：迁移列表态到统一页面骨架

**Files:**
- Modify: `frontend/lib/features/product/presentation/product_parameter_management_page.dart`
- Modify: `frontend/test/widgets/product_parameter_management_page_test.dart`

- [ ] **Step 1: 为列表态骨架迁移补失败测试，固定统一锚点**

```dart
// frontend/test/widgets/product_parameter_management_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/product_parameter_management_page.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_management_feedback_banner.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_management_filter_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_management_page_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_version_table_section.dart';
import 'package:mes_client/features/product/services/product_service.dart';

final DateTime _fixedDate = DateTime.parse('2026-04-20T00:00:00Z');

class _PageStructureService extends ProductService {
  _PageStructureService() : super(AppSession(baseUrl: '', accessToken: 'token'));

  @override
  Future<ProductParameterVersionListResult> listProductParameterVersions({
    required int page,
    required int pageSize,
    String? keyword,
    String? category,
    String? versionKeyword,
    String? paramNameKeyword,
    String? paramCategoryKeyword,
    String? lifecycleStatus,
    DateTime? updatedAfter,
    DateTime? updatedBefore,
  }) async {
    return ProductParameterVersionListResult(
      total: 2,
      items: [
        ProductParameterVersionListItem(
          productId: 41,
          productName: '产品41',
          productCategory: '贴片',
          version: 1,
          versionLabel: 'V1.0',
          lifecycleStatus: 'effective',
          isCurrentVersion: false,
          isEffectiveVersion: true,
          createdAt: _fixedDate,
          parameterSummary: '历史版本参数',
          parameterCount: 8,
          matchedParameterName: '产品芯片',
          matchedParameterCategory: '基础参数',
          lastModifiedParameter: '产品芯片',
          lastModifiedParameterCategory: '基础参数',
          updatedAt: _fixedDate,
        ),
        ProductParameterVersionListItem(
          productId: 41,
          productName: '产品41',
          productCategory: '贴片',
          version: 2,
          versionLabel: 'V1.1',
          lifecycleStatus: 'draft',
          isCurrentVersion: true,
          isEffectiveVersion: false,
          createdAt: _fixedDate,
          parameterSummary: '当前草稿参数',
          parameterCount: 8,
          matchedParameterName: '产品芯片',
          matchedParameterCategory: '基础参数',
          lastModifiedParameter: '产品芯片',
          lastModifiedParameterCategory: '基础参数',
          updatedAt: _fixedDate,
        ),
      ],
    );
  }
}

void main() {
  testWidgets('ProductParameterManagementPage 列表态接入统一骨架并展示锚点', (tester) async {
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
            child: ProductParameterManagementPage(
              session: AppSession(baseUrl: '', accessToken: 'token'),
              onLogout: () {},
              tabCode: 'product-parameter-management',
              service: service,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MesCrudPageScaffold), findsOneWidget);
    expect(find.byType(ProductParameterManagementPageHeader), findsOneWidget);
    expect(find.byType(ProductParameterManagementFilterSection), findsOneWidget);
    expect(find.byType(ProductParameterVersionTableSection), findsOneWidget);
    expect(find.byType(ProductParameterManagementFeedbackBanner), findsNothing);
  });
}
```

- [ ] **Step 2: 运行列表态结构测试，确认主页面尚未迁移**

Run: `flutter test test/widgets/product_parameter_management_page_test.dart --plain-name "ProductParameterManagementPage 列表态接入统一骨架并展示锚点"`

Expected: FAIL，断言找不到 `MesCrudPageScaffold` 或 `ProductParameterVersionTableSection`

- [ ] **Step 3: 收敛列表态到统一页面骨架**

```dart
// frontend/lib/features/product/presentation/product_parameter_management_page.dart
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_management_feedback_banner.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_management_filter_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_management_page_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_version_table_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_version_table_section.dart'
    show ProductParameterManagementListAction;

List<PopupMenuEntry<ProductParameterManagementListAction>> _buildListActionMenuItems() {
  return [
    const PopupMenuItem(
      value: ProductParameterManagementListAction.view,
      child: Text('查看参数'),
    ),
    const PopupMenuItem(
      value: ProductParameterManagementListAction.history,
      child: Text('查看历史'),
    ),
    const PopupMenuItem(
      value: ProductParameterManagementListAction.edit,
      child: Text('编辑参数'),
    ),
    if (widget.canExportParameters)
      const PopupMenuItem(
        value: ProductParameterManagementListAction.export,
        child: Text('导出参数'),
      ),
  ];
}

Future<void> _handleListAction(
  ProductParameterManagementListAction action,
  ProductParameterVersionListItem row,
) async {
  switch (action) {
    case ProductParameterManagementListAction.view:
      await _enterEditor(row);
      return;
    case ProductParameterManagementListAction.history:
      await _showHistoryDialog(row);
      return;
    case ProductParameterManagementListAction.edit:
      await _enterEditor(row);
      return;
    case ProductParameterManagementListAction.export:
      await _exportVersionParameters(row);
      return;
  }
}

Widget _buildListView() {
  final rows = _filteredVersionRows;
  return MesCrudPageScaffold(
    header: ProductParameterManagementPageHeader(
      loading: _loading,
      onRefresh: _loadProducts,
    ),
    filters: ProductParameterManagementFilterSection(
      keywordController: _keywordController,
      selectedCategory: _selectedCategoryFilter,
      loading: _loading,
      onCategoryChanged: (value) {
        setState(() {
          _selectedCategoryFilter = value;
        });
        _loadProducts();
      },
      onSearch: _loadProducts,
    ),
    banner: _message.isEmpty
        ? null
        : ProductParameterManagementFeedbackBanner(message: _message),
    content: ProductParameterVersionTableSection(
      rows: rows,
      loading: _loading,
      emptyText: '暂无版本参数记录',
      formatTime: _formatTime,
      buildActionItems: (row) => _buildListActionMenuItems(),
      onSelected: _handleListAction,
    ),
  );
}

@override
Widget build(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: _editingTarget == null ? _buildListView() : _buildEditorView(),
  );
}
```

- [ ] **Step 4: 重新运行列表态结构测试**

Run: `flutter test test/widgets/product_parameter_management_page_test.dart --plain-name "ProductParameterManagementPage 列表态接入统一骨架并展示锚点"`

Expected: PASS

- [ ] **Step 5: 提交列表态骨架迁移**

```bash
git add frontend/lib/features/product/presentation/product_parameter_management_page.dart frontend/test/widgets/product_parameter_management_page_test.dart
git commit -m "迁移产品参数管理页列表态到统一骨架"
```

## 任务 3：拆分编辑态展示层

**Files:**
- Create: `frontend/lib/features/product/presentation/widgets/product_parameter_editor_row_model.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_parameter_editor_header.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_parameter_editor_toolbar.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_parameter_editor_table.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_parameter_editor_footer.dart`
- Modify: `frontend/lib/features/product/presentation/product_parameter_management_page.dart`
- Modify: `frontend/test/widgets/product_parameter_management_page_test.dart`

- [ ] **Step 1: 先写失败测试，固定编辑态骨架与主要锚点**

```dart
// frontend/test/widgets/product_parameter_management_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_editor_footer.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_editor_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_editor_row_model.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_editor_table.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_editor_toolbar.dart';

void main() {
  testWidgets('产品参数编辑态展示头部 工具条 表格和底部动作区', (tester) async {
    final row = ProductParameterEditorRowModel.empty(rowId: 1);
    addTearDown(row.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const ProductParameterEditorHeader(
                productName: '产品41',
                versionLabel: 'V1.1',
                lifecycleStatus: 'draft',
                hasUnsavedChanges: true,
                onBack: null,
              ),
              ProductParameterEditorToolbar(
                groupFilter: '',
                categorySuggestions: const ['基础参数', '产品测试参数'],
                hasUnsavedChanges: true,
                onGroupChanged: (_) {},
                onRefresh: () {},
                refreshEnabled: true,
              ),
              Expanded(
                child: ProductParameterEditorTable(
                  rows: [row],
                  visibleRows: [row],
                  editorReadOnly: false,
                  editorSubmitting: false,
                  onTypeChanged: (target, value) {},
                  onValueChanged: (target, value) {},
                  onDescriptionChanged: (target) {},
                  onCategoryChanged: (target) {},
                  onDeleteRow: (target) {},
                  onReorder: (oldIndex, newIndex) {},
                ),
              ),
              ProductParameterEditorFooter(
                remarkController: TextEditingController(text: '本次修改备注'),
                editorReadOnly: false,
                editorSubmitting: false,
                onAddRow: () {},
                onCancel: () {},
                onSave: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('product-parameter-editor-header')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-parameter-editor-toolbar')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-parameter-editor-table')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-parameter-editor-footer')), findsOneWidget);
    expect(find.textContaining('编辑版本参数 - 产品41'), findsOneWidget);
    expect(find.text('新增参数'), findsOneWidget);
    expect(find.text('保存参数'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行编辑态测试，确认展示层尚未拆出**

Run: `flutter test test/widgets/product_parameter_management_page_test.dart --plain-name "产品参数编辑态展示头部 工具条 表格和底部动作区"`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Undefined class 'ProductParameterEditorHeader'`

- [ ] **Step 3: 实现编辑态展示层并改主页面装配**

```dart
// frontend/lib/features/product/presentation/widgets/product_parameter_editor_row_model.dart
import 'package:flutter/material.dart';

class ProductParameterEditorRowModel {
  ProductParameterEditorRowModel.initial({
    required this.rowId,
    required String name,
    required String category,
    required String parameterType,
    required String value,
    required String description,
  }) : nameController = TextEditingController(text: name),
       categoryController = TextEditingController(text: category),
       valueController = TextEditingController(text: value),
       descriptionController = TextEditingController(text: description),
       parameterType = parameterType == 'Link' ? 'Link' : 'Text';

  ProductParameterEditorRowModel.empty({required this.rowId})
    : nameController = TextEditingController(),
      categoryController = TextEditingController(),
      valueController = TextEditingController(),
      descriptionController = TextEditingController(),
      parameterType = 'Text';

  final int rowId;
  final TextEditingController nameController;
  final TextEditingController categoryController;
  final TextEditingController valueController;
  final TextEditingController descriptionController;
  String parameterType;
  bool categoryListenerBound = false;

  void dispose() {
    nameController.dispose();
    categoryController.dispose();
    valueController.dispose();
    descriptionController.dispose();
  }
}
```

```dart
// frontend/lib/features/product/presentation/widgets/product_parameter_editor_header.dart
import 'package:flutter/material.dart';

class ProductParameterEditorHeader extends StatelessWidget {
  const ProductParameterEditorHeader({
    super.key,
    required this.productName,
    required this.versionLabel,
    required this.lifecycleStatus,
    required this.hasUnsavedChanges,
    required this.onBack,
  });

  final String productName;
  final String versionLabel;
  final String lifecycleStatus;
  final bool hasUnsavedChanges;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-parameter-editor-header'),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('返回列表'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '编辑版本参数 - $productName（$versionLabel）',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (lifecycleStatus.isNotEmpty)
            Chip(
              label: Text(lifecycleStatus == 'draft' ? '草稿可编辑' : '非草稿只读'),
              visualDensity: VisualDensity.compact,
            ),
          if (hasUnsavedChanges) ...[
            const SizedBox(width: 8),
            Chip(
              label: const Text('有未保存修改'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/features/product/presentation/widgets/product_parameter_editor_toolbar.dart
import 'package:flutter/material.dart';

class ProductParameterEditorToolbar extends StatelessWidget {
  const ProductParameterEditorToolbar({
    super.key,
    required this.groupFilter,
    required this.categorySuggestions,
    required this.hasUnsavedChanges,
    required this.onGroupChanged,
    required this.onRefresh,
    required this.refreshEnabled,
  });

  final String groupFilter;
  final List<String> categorySuggestions;
  final bool hasUnsavedChanges;
  final ValueChanged<String> onGroupChanged;
  final VoidCallback onRefresh;
  final bool refreshEnabled;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-parameter-editor-toolbar'),
      child: Row(
        children: [
          const Spacer(),
          SizedBox(
            width: 180,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: '参数分组筛选',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: groupFilter,
                  isDense: true,
                  items: [
                    const DropdownMenuItem<String>(value: '', child: Text('全部分组')),
                    ...categorySuggestions.map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      ),
                    ),
                  ],
                  onChanged: (value) => onGroupChanged(value ?? ''),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '刷新参数',
            onPressed: refreshEnabled ? onRefresh : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/features/product/presentation/widgets/product_parameter_editor_table.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_editor_row_model.dart';

class ProductParameterEditorTable extends StatelessWidget {
  const ProductParameterEditorTable({
    super.key,
    required this.rows,
    required this.visibleRows,
    required this.editorReadOnly,
    required this.editorSubmitting,
    required this.onTypeChanged,
    required this.onValueChanged,
    required this.onDescriptionChanged,
    required this.onCategoryChanged,
    required this.onDeleteRow,
    required this.onReorder,
  });

  final List<ProductParameterEditorRowModel> rows;
  final List<ProductParameterEditorRowModel> visibleRows;
  final bool editorReadOnly;
  final bool editorSubmitting;
  final void Function(ProductParameterEditorRowModel row, String value) onTypeChanged;
  final void Function(ProductParameterEditorRowModel row, String value) onValueChanged;
  final void Function(ProductParameterEditorRowModel row) onDescriptionChanged;
  final void Function(ProductParameterEditorRowModel row) onCategoryChanged;
  final void Function(ProductParameterEditorRowModel row) onDeleteRow;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-parameter-editor-table'),
      child: ListView.builder(
        itemCount: visibleRows.length,
        itemBuilder: (context, index) {
          final row = visibleRows[index];
          return Card(
            key: ValueKey(row.rowId),
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: row.nameController,
                      readOnly: editorReadOnly,
                      decoration: const InputDecoration(
                        labelText: '参数名',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: row.categoryController,
                      readOnly: editorReadOnly,
                      onChanged: editorReadOnly ? null : (_) => onCategoryChanged(row),
                      decoration: const InputDecoration(
                        labelText: '分组',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      initialValue: row.parameterType,
                      decoration: const InputDecoration(
                        labelText: '类型',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem<String>(value: 'Text', child: Text('Text')),
                        DropdownMenuItem<String>(value: 'Link', child: Text('Link')),
                      ],
                      onChanged: editorReadOnly || editorSubmitting
                          ? null
                          : (value) => onTypeChanged(row, value ?? 'Text'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: row.valueController,
                      readOnly: editorReadOnly,
                      onChanged: editorReadOnly ? null : (value) => onValueChanged(row, value),
                      decoration: const InputDecoration(
                        labelText: '值',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: row.descriptionController,
                      readOnly: editorReadOnly,
                      onChanged: editorReadOnly ? null : (_) => onDescriptionChanged(row),
                      decoration: const InputDecoration(
                        labelText: '说明',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '删除',
                    onPressed: editorSubmitting || editorReadOnly ? null : () => onDeleteRow(row),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
```

```dart
// frontend/lib/features/product/presentation/widgets/product_parameter_editor_footer.dart
import 'package:flutter/material.dart';

class ProductParameterEditorFooter extends StatelessWidget {
  const ProductParameterEditorFooter({
    super.key,
    required this.remarkController,
    required this.editorReadOnly,
    required this.editorSubmitting,
    required this.onAddRow,
    required this.onCancel,
    required this.onSave,
  });

  final TextEditingController remarkController;
  final bool editorReadOnly;
  final bool editorSubmitting;
  final VoidCallback onAddRow;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-parameter-editor-footer'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: editorSubmitting || editorReadOnly ? null : onAddRow,
              icon: const Icon(Icons.add),
              label: const Text('新增参数'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: remarkController,
            maxLines: 2,
            readOnly: editorReadOnly,
            decoration: const InputDecoration(
              labelText: '本次修改备注（必填）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: editorSubmitting ? null : onCancel,
                child: const Text('取消'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: editorSubmitting || editorReadOnly ? null : onSave,
                child: editorSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存参数'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/features/product/presentation/product_parameter_management_page.dart
import 'package:mes_client/features/product/presentation/widgets/product_parameter_editor_footer.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_editor_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_editor_row_model.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_editor_table.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_editor_toolbar.dart';

List<ProductParameterEditorRowModel> _editorRows = const [];

void _disposeEditorRows() {
  for (final row in _editorRows) {
    row.dispose();
  }
  _editorRows = const [];
}

void _handleEditorValueChanged(ProductParameterEditorRowModel row, String value) {
  if (row.parameterType == 'Link') {
    setState(() {});
  }
  _markDirty();
}

void _attachCategoryDirtyListener(ProductParameterEditorRowModel row) {
  if (row.categoryListenerBound) {
    return;
  }
  row.categoryController.addListener(() {
    if (!mounted || _editorLoading) {
      return;
    }
    _markDirty();
  });
  row.categoryListenerBound = true;
}

Widget _buildEditorView() {
  final theme = Theme.of(context);
  final target = _editingTarget!;
  final visibleRows = _editorGroupFilter.isEmpty
      ? _editorRows
      : _editorRows
            .where((row) => row.categoryController.text.trim() == _editorGroupFilter)
            .toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ProductParameterEditorHeader(
        productName: target.productName,
        versionLabel: _editingVersionLabel.isEmpty ? target.versionLabel : _editingVersionLabel,
        lifecycleStatus: _editingLifecycleStatus,
        hasUnsavedChanges: _hasUnsavedChanges,
        onBack: _editorSubmitting ? null : _exitEditor,
      ),
      const SizedBox(height: 12),
      ProductParameterEditorToolbar(
        groupFilter: _editorGroupFilter,
        categorySuggestions: _buildCategorySuggestions(),
        hasUnsavedChanges: _hasUnsavedChanges,
        onGroupChanged: (value) {
          setState(() {
            _editorGroupFilter = value;
          });
        },
        onRefresh: () => _enterEditor(
          target,
          requestedVersionLabel: _editingVersionLabel.isEmpty ? null : _editingVersionLabel,
        ),
        refreshEnabled: !_editorSubmitting,
      ),
      const SizedBox(height: 12),
      if (_editorMessage.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            _editorMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      if (_editorReadOnly)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '当前版本不是草稿，参数仅可查看。如需修改，请先在版本管理中复制或新建草稿版本。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.secondary,
            ),
          ),
        ),
      Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _editorLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ProductParameterEditorTable(
                          rows: _editorRows,
                          visibleRows: visibleRows,
                          editorReadOnly: _editorReadOnly,
                          editorSubmitting: _editorSubmitting,
                          onTypeChanged: (row, value) {
                            setState(() {
                              row.parameterType = value;
                            });
                            _markDirty();
                          },
                          onValueChanged: _handleEditorValueChanged,
                          onDescriptionChanged: (row) => _markDirty(),
                          onCategoryChanged: (row) => _markDirty(),
                          onDeleteRow: (row) {
                            setState(() {
                              _editorRows = _editorRows
                                  .where((item) => item.rowId != row.rowId)
                                  .toList(growable: false);
                              row.dispose();
                            });
                            _markDirty();
                          },
                          onReorder: (oldIndex, newIndex) {},
                        ),
                ),
                const SizedBox(height: 12),
                ProductParameterEditorFooter(
                  remarkController: _remarkController,
                  editorReadOnly: _editorReadOnly,
                  editorSubmitting: _editorSubmitting,
                  onAddRow: () {
                    setState(() {
                      final row = ProductParameterEditorRowModel.empty(
                        rowId: _nextEditorRowId(),
                      );
                      _attachCategoryDirtyListener(row);
                      _editorRows = [..._editorRows, row];
                    });
                    _markDirty();
                  },
                  onCancel: _exitEditor,
                  onSave: _saveEditor,
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
```

- [ ] **Step 4: 运行编辑态测试**

Run: `flutter test test/widgets/product_parameter_management_page_test.dart --plain-name "产品参数编辑态展示头部 工具条 表格和底部动作区"`

Expected: PASS

- [ ] **Step 5: 提交编辑态展示层拆分**

```bash
git add frontend/lib/features/product/presentation/widgets/product_parameter_editor_row_model.dart frontend/lib/features/product/presentation/widgets/product_parameter_editor_header.dart frontend/lib/features/product/presentation/widgets/product_parameter_editor_toolbar.dart frontend/lib/features/product/presentation/widgets/product_parameter_editor_table.dart frontend/lib/features/product/presentation/widgets/product_parameter_editor_footer.dart frontend/lib/features/product/presentation/product_parameter_management_page.dart frontend/test/widgets/product_parameter_management_page_test.dart
git commit -m "拆分产品参数管理页编辑态展示层"
```

## 任务 4：拆分历史弹窗展示层

**Files:**
- Create: `frontend/lib/features/product/presentation/widgets/product_parameter_history_dialog.dart`
- Create: `frontend/lib/features/product/presentation/widgets/product_parameter_history_snapshot_dialog.dart`
- Modify: `frontend/lib/features/product/presentation/product_parameter_management_page.dart`
- Modify: `frontend/test/widgets/product_parameter_management_page_test.dart`

- [ ] **Step 1: 先写失败测试，固定历史弹窗展示层和快照入口**

```dart
// frontend/test/widgets/product_parameter_management_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_history_dialog.dart';

final DateTime _fixedDate = DateTime.parse('2026-04-20T00:00:00Z');

void main() {
  testWidgets('历史弹窗展示历史列表与快照入口', (tester) async {
    final history = ProductParameterHistoryListResult(
      version: 1,
      versionLabel: 'V1.0',
      lifecycleStatus: 'draft',
      total: 1,
      items: [
        ProductParameterHistoryItem(
          id: 900,
          productName: '产品41',
          productCategory: '贴片',
          version: 1,
          versionLabel: 'V1.0',
          remark: '调整芯片参数',
          changeReason: '调整芯片参数',
          changeType: 'edit',
          parameterName: '产品芯片',
          changedKeys: const ['产品芯片'],
          operatorUsername: 'admin',
          beforeSummary: '旧值',
          afterSummary: '新值',
          beforeSnapshot: '{"before":true}',
          afterSnapshot: '{"after":true}',
          createdAt: _fixedDate,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductParameterHistoryDialog(
            row: ProductParameterVersionListItem(
              productId: 41,
              productName: '产品41',
              productCategory: '贴片',
              version: 1,
              versionLabel: 'V1.0',
              lifecycleStatus: 'effective',
              isCurrentVersion: false,
              isEffectiveVersion: true,
              createdAt: _fixedDate,
              parameterSummary: null,
              parameterCount: 8,
              matchedParameterName: '产品芯片',
              matchedParameterCategory: '基础参数',
              lastModifiedParameter: '产品芯片',
              lastModifiedParameterCategory: '基础参数',
              updatedAt: _fixedDate,
            ),
            history: history,
            formatTime: (_) => '2026-04-20 08:00:00',
            historyTypeLabel: (value) => value == 'edit' ? '编辑' : value,
            onClose: () {},
            onViewSnapshot: (item) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('product-parameter-history-dialog')), findsOneWidget);
    expect(find.textContaining('参数变更历史 - 产品41 / 贴片 / V1.0'), findsOneWidget);
    expect(find.textContaining('变更原因：调整芯片参数'), findsOneWidget);
    expect(find.text('查看快照'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行历史弹窗测试，确认展示层尚未拆出**

Run: `flutter test test/widgets/product_parameter_management_page_test.dart --plain-name "历史弹窗展示历史列表与快照入口"`

Expected: FAIL，报错包含 `Target of URI doesn't exist` 或 `Undefined class 'ProductParameterHistoryDialog'`

- [ ] **Step 3: 实现历史弹窗展示层并改主页面装配**

```dart
// frontend/lib/features/product/presentation/widgets/product_parameter_history_snapshot_dialog.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/product/models/product_models.dart';

class ProductParameterHistorySnapshotDialog extends StatelessWidget {
  const ProductParameterHistorySnapshotDialog({
    super.key,
    required this.item,
    required this.onClose,
  });

  final ProductParameterHistoryItem item;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('变更前后快照'),
      content: SizedBox(
        width: 680,
        height: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('变更前：', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SelectableText(item.beforeSnapshot),
              const SizedBox(height: 12),
              const Text('变更后：', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SelectableText(item.afterSnapshot),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(onPressed: onClose, child: const Text('关闭')),
      ],
    );
  }
}
```

```dart
// frontend/lib/features/product/presentation/widgets/product_parameter_history_dialog.dart
import 'package:flutter/material.dart';
import 'package:mes_client/features/product/models/product_models.dart';

class ProductParameterHistoryDialog extends StatelessWidget {
  const ProductParameterHistoryDialog({
    super.key,
    required this.row,
    required this.history,
    required this.formatTime,
    required this.historyTypeLabel,
    required this.onClose,
    required this.onViewSnapshot,
  });

  final ProductParameterVersionListItem row;
  final ProductParameterHistoryListResult history;
  final String Function(DateTime value) formatTime;
  final String Function(String value) historyTypeLabel;
  final VoidCallback onClose;
  final ValueChanged<ProductParameterHistoryItem> onViewSnapshot;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-parameter-history-dialog'),
      child: AlertDialog(
        title: Text(
          '参数变更历史 - ${row.productName} / ${row.productCategory} / ${history.versionLabel ?? row.versionLabel}',
        ),
        content: SizedBox(
          width: 760,
          height: 480,
          child: history.items.isEmpty
              ? const Center(child: Text('暂无历史记录'))
              : ListView.separated(
                  itemCount: history.items.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = history.items[index];
                    final keySummary = item.changedKeys.isEmpty
                        ? '无参数字段变化'
                        : item.changedKeys.join(', ');
                    final typeLabel = historyTypeLabel(item.changeType);
                    return ListTile(
                      title: Text('$typeLabel / ${item.parameterName ?? '未指定参数'}'),
                      subtitle: Text(
                        '产品：${item.productName}   分类：${item.productCategory.isEmpty ? '-' : item.productCategory}\n'
                        '时间：${formatTime(item.createdAt)}\n'
                        '版本：${item.versionLabel ?? '-'}   操作人：${item.operatorUsername}   类型：$typeLabel\n'
                        '参数：$keySummary\n'
                        '变更原因：${item.changeReason}\n'
                        '变更前：${item.beforeSummary ?? '-'}\n'
                        '变更后：${item.afterSummary ?? '-'}',
                      ),
                      isThreeLine: false,
                      trailing: item.beforeSnapshot != '{}' || item.afterSnapshot != '{}'
                          ? TextButton(
                              onPressed: () => onViewSnapshot(item),
                              child: const Text('查看快照'),
                            )
                          : null,
                    );
                  },
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
// frontend/lib/features/product/presentation/product_parameter_management_page.dart
import 'package:mes_client/features/product/presentation/widgets/product_parameter_history_dialog.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_history_snapshot_dialog.dart';

await showDialog<void>(
  context: context,
  builder: (context) {
    return ProductParameterHistoryDialog(
      row: row,
      history: dialogHistory,
      formatTime: _formatTime,
      historyTypeLabel: _historyTypeLabel,
      onClose: () => Navigator.of(context).pop(),
      onViewSnapshot: (item) {
        showDialog<void>(
          context: context,
          builder: (snapshotContext) {
            return ProductParameterHistorySnapshotDialog(
              item: item,
              onClose: () => Navigator.of(snapshotContext).pop(),
            );
          },
        );
      },
    );
  },
);
```

- [ ] **Step 4: 运行历史弹窗测试和既有历史回归**

Run: `flutter test test/widgets/product_parameter_management_page_test.dart --plain-name "历史弹窗展示历史列表与快照入口"`

Expected: PASS

Run: `flutter test test/widgets/product_module_issue_regression_test.dart --plain-name "参数管理页首屏应展示版本行且操作绑定对应版本"`

Expected: PASS

- [ ] **Step 5: 提交历史弹窗展示层拆分**

```bash
git add frontend/lib/features/product/presentation/widgets/product_parameter_history_dialog.dart frontend/lib/features/product/presentation/widgets/product_parameter_history_snapshot_dialog.dart frontend/lib/features/product/presentation/product_parameter_management_page.dart frontend/test/widgets/product_parameter_management_page_test.dart
git commit -m "拆分产品参数管理页历史弹窗展示层"
```

## 任务 5：补齐页面回归、integration 与最终收口

**Files:**
- Create: `frontend/integration_test/product_parameter_management_flow_test.dart`
- Create: `evidence/2026-04-20_产品参数管理页第二波迁移实施.md`
- Modify: `frontend/test/widgets/product_parameter_management_page_test.dart`
- Modify: `frontend/test/widgets/product_module_issue_regression_test.dart`
- Modify: `frontend/test/widgets/product_page_test.dart`

- [ ] **Step 1: 先写失败的页面级 / integration 观察点，固定最终锚点**

```dart
// frontend/test/widgets/product_parameter_management_page_test.dart
testWidgets('参数管理页保留列表态 编辑态和历史弹窗入口', (tester) async {
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
          child: ProductParameterManagementPage(
            session: AppSession(baseUrl: '', accessToken: 'token'),
            onLogout: () {},
            tabCode: 'product-parameter-management',
            service: service,
            canExportParameters: true,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byKey(const ValueKey('product-parameter-version-table-section')), findsOneWidget);
  await tester.tap(find.text('编辑参数').first);
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('product-parameter-editor-header')), findsOneWidget);
});
```

```dart
// frontend/test/widgets/product_module_issue_regression_test.dart
testWidgets('参数管理页首屏应展示版本行且操作绑定对应版本', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final service = _ParameterManagementContractService();

  await tester.pumpWidget(
    _host(
      ProductParameterManagementPage(
        session: _session(),
        onLogout: () {},
        tabCode: 'product-parameter-management',
        service: service,
      ),
    ),
  );

  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('product-parameter-version-table-section')), findsOneWidget);

  await _openPopupMenu(tester, _popupMenuButtonFinder().first);
  await tester.tap(find.text('查看历史'));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('product-parameter-history-dialog')), findsOneWidget);

  await tester.tap(find.widgetWithText(FilledButton, '关闭'));
  await tester.pumpAndSettle();

  await _openPopupMenu(tester, _popupMenuButtonFinder().at(1));
  await tester.tap(find.text('编辑参数'));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('product-parameter-editor-header')), findsOneWidget);
});
```

```dart
// frontend/integration_test/product_parameter_management_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mes_client.core.models.app_session.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/product_parameter_management_page.dart';
import 'package:mes_client/features/product/services/product_service.dart';

final DateTime _fixedDate = DateTime.parse('2026-04-20T00:00:00Z');

class _IntegrationProductService extends ProductService {
  _IntegrationProductService() : super(AppSession(baseUrl: '', accessToken: 'token'));

  @override
  Future<ProductParameterVersionListResult> listProductParameterVersions({
    required int page,
    required int pageSize,
    String? keyword,
    String? category,
    String? versionKeyword,
    String? paramNameKeyword,
    String? paramCategoryKeyword,
    String? lifecycleStatus,
    DateTime? updatedAfter,
    DateTime? updatedBefore,
  }) async {
    return ProductParameterVersionListResult(
      total: 1,
      items: [
        ProductParameterVersionListItem(
          productId: 41,
          productName: '产品41',
          productCategory: '贴片',
          version: 2,
          versionLabel: 'V1.1',
          lifecycleStatus: 'draft',
          isCurrentVersion: true,
          isEffectiveVersion: false,
          createdAt: _fixedDate,
          parameterSummary: '当前草稿参数',
          parameterCount: 8,
          matchedParameterName: '产品芯片',
          matchedParameterCategory: '基础参数',
          lastModifiedParameter: '产品芯片',
          lastModifiedParameterCategory: '基础参数',
          updatedAt: _fixedDate,
        ),
      ],
    );
  }

  @override
  Future<ProductParameterListResult> getProductVersionParameters({
    required int productId,
    required int version,
  }) async {
    return ProductParameterListResult(
      productId: productId,
      productName: '产品$productId',
      parameterScope: 'version',
      version: version,
      versionLabel: 'V1.${version - 1}',
      lifecycleStatus: 'draft',
      total: 1,
      items: [
        ProductParameterItem(
          name: '产品名称',
          category: '基础参数',
          type: 'Text',
          value: '产品$productId',
          description: '',
          sortOrder: 1,
          isPreset: true,
        ),
      ],
    );
  }

  @override
  Future<ProductParameterHistoryListResult> listProductParameterHistory({
    required int productId,
    int? version,
    required int page,
    required int pageSize,
  }) async {
    return ProductParameterHistoryListResult(
      version: version,
      versionLabel: 'V1.${(version ?? 1) - 1}',
      lifecycleStatus: 'draft',
      total: 0,
      items: const [],
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('产品参数管理页主路径可进入编辑态并打开历史弹窗', (tester) async {
    final service = _IntegrationProductService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1440,
            height: 900,
            child: ProductParameterManagementPage(
              session: AppSession(baseUrl: '', accessToken: 'token'),
              onLogout: () {},
              tabCode: 'product-parameter-management',
              service: service,
              canExportParameters: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('product-parameter-filter-section')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-parameter-version-table-section')), findsOneWidget);

    await tester.tap(find.text('编辑参数').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('product-parameter-editor-header')), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '返回列表'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看历史').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('product-parameter-history-dialog')), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行最终失败验证，确认新增观察点尚未完整接通**

Run: `flutter test test/widgets/product_parameter_management_page_test.dart test/widgets/product_module_issue_regression_test.dart test/widgets/product_page_test.dart`

Expected: FAIL，至少包含：
- 页面级测试找不到编辑态或历史弹窗新锚点
- 产品模块回归找不到 `product-parameter-history-dialog` 或 `product-parameter-editor-header`

Run: `flutter test -d windows integration_test/product_parameter_management_flow_test.dart`

Expected: FAIL，报错包含文件不存在或断言找不到锚点

- [ ] **Step 3: 扩展页面级 / 模块回归 / integration，并创建实施 evidence**

```md
# 任务日志：产品参数管理页第二波迁移实施

- 日期：2026-04-20
- 执行人：Codex
- 当前状态：已完成

## 1. 输入来源
- 用户指令：按已批准设计继续实施产品参数管理页第二波迁移
- 设计规格：`docs/superpowers/specs/2026-04-20-product-parameter-management-page-second-wave-design.md`
- 实施计划：`docs/superpowers/plans/2026-04-20-product-parameter-management-page-second-wave-implementation.md`

## 2. 实施分段
- 任务 1：建立列表态基础展示组件
- 任务 2：迁移列表态到统一页面骨架
- 任务 3：拆分编辑态展示层
- 任务 4：拆分历史弹窗展示层
- 任务 5：补齐页面回归、integration 与最终收口

## 3. 验证结果
- flutter analyze：通过
- flutter test test/widgets/product_parameter_management_page_test.dart test/widgets/product_module_issue_regression_test.dart test/widgets/product_page_test.dart：通过
- flutter test -d windows integration_test/product_parameter_management_flow_test.dart：通过

## 4. 风险与补偿
- 当前 integration 仅覆盖桌面主路径，不扩展到所有参数编辑行为；复杂编辑逻辑继续由 `product_module_issue_regression_test.dart` 兜底

## 5. 迁移说明
- 无迁移，直接替换
```

- [ ] **Step 4: 运行最终验证**

Run: `flutter analyze`

Expected: `No issues found!`

Run: `flutter test test/widgets/product_parameter_management_page_test.dart test/widgets/product_module_issue_regression_test.dart test/widgets/product_page_test.dart`

Expected: PASS

Run: `flutter test -d windows integration_test/product_parameter_management_flow_test.dart`

Expected: PASS

- [ ] **Step 5: 提交最终验证与留痕**

```bash
git add frontend/integration_test/product_parameter_management_flow_test.dart evidence/2026-04-20_产品参数管理页第二波迁移实施.md frontend/test/widgets/product_parameter_management_page_test.dart frontend/test/widgets/product_module_issue_regression_test.dart frontend/test/widgets/product_page_test.dart
git commit -m "补齐产品参数管理页迁移验证留痕"
```
