import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/product_parameter_management_page.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_editor_footer.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_editor_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_editor_row_model.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_editor_table.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_editor_toolbar.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_management_feedback_banner.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_management_filter_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_management_page_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_version_table_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_version_table_section.dart'
    show ProductParameterManagementListAction;
import 'package:mes_client/features/product/services/product_service.dart';

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

class _PageStructureService extends ProductService {
  _PageStructureService()
    : super(AppSession(baseUrl: '', accessToken: 'token'));

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
    );
  }
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
    expect(
      find.byKey(const ValueKey('product-parameter-filter-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('product-parameter-feedback-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('product-parameter-version-table-section')),
      findsOneWidget,
    );
    expect(find.text('搜索产品名称'), findsOneWidget);
    expect(find.text('分类筛选'), findsOneWidget);
    expect(find.text('产品41'), findsWidgets);
    expect(find.text('V1.0 / #1'), findsOneWidget);
    expect(find.text('V1.1 / #2'), findsOneWidget);
  });

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

  testWidgets('产品参数编辑态展示头部 工具条 表格和底部动作区', (tester) async {
    final row = ProductParameterEditorRowModel.empty(rowId: 1);
    addTearDown(row.dispose);
    final remarkController = TextEditingController(text: '本次修改备注');
    addTearDown(remarkController.dispose);

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
                remarkController: remarkController,
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
