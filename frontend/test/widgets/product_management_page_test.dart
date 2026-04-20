import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/product_management_page.dart';
import 'package:mes_client/features/product/presentation/widgets/product_detail_drawer.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_feedback_banner.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_filter_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_page_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_table_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_table_section.dart'
    show ProductManagementTableAction;
import 'package:mes_client/features/product/presentation/widgets/product_version_dialog.dart';
import 'package:mes_client/features/product/services/product_service.dart';

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
    effectiveVersionLabel: effectiveVersion > 0
        ? 'V1.${effectiveVersion - 1}'
        : null,
    effectiveAt: effectiveVersion > 0 ? _fixedDate : null,
    inactiveReason: lifecycleStatus == 'inactive' ? '人工停用' : null,
    lastParameterSummary: null,
    createdAt: _fixedDate,
    updatedAt: _fixedDate,
  );
}

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
        _buildProduct(id: 41),
        _buildProduct(
          id: 42,
          lifecycleStatus: 'inactive',
          currentVersion: 1,
          effectiveVersion: 0,
        ),
      ],
    );
  }
}

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
                    _buildProduct(
                      id: 42,
                      lifecycleStatus: 'inactive',
                      effectiveVersion: 0,
                    ),
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
    expect(
      find.byKey(const ValueKey('product-management-filter-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('product-management-feedback-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('product-management-table-section')),
      findsOneWidget,
    );
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
              _buildProduct(
                id: 42,
                lifecycleStatus: 'inactive',
                effectiveVersion: 0,
              ),
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
            changeTypeLabel: (value) => value == 'edit' ? '编辑' : value,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('product-detail-drawer')), findsOneWidget);
    expect(find.textContaining('产品详情 - 产品41'), findsOneWidget);
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('当前版本参数快照（V1.1）'), findsOneWidget);
    expect(find.text('关联工艺路线'), findsOneWidget);
    expect(find.byKey(const ValueKey('product-history-timeline')), findsOneWidget);
  });

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
