import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_list_detail_shell.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/product_management_page.dart';
import 'package:mes_client/features/product/presentation/product_page.dart';
import 'package:mes_client/features/product/presentation/product_parameter_management_page.dart';
import 'package:mes_client/features/product/presentation/product_parameter_query_page.dart';
import 'package:mes_client/features/product/presentation/product_version_management_page.dart';
import 'package:mes_client/features/product/services/product_service.dart';

final DateTime _fixedDate = DateTime.parse('2026-04-21T00:00:00Z');

AppSession _session() {
  return AppSession(baseUrl: '', accessToken: 'guard-token');
}

Widget _guardHost(Widget child) {
  return MaterialApp(
    theme: buildMesTheme(
      brightness: Brightness.light,
      visualDensity: VisualDensity.standard,
    ),
    home: Scaffold(body: SizedBox(width: 1600, height: 1200, child: child)),
  );
}

Finder _popupMenuButtonFinder() {
  return find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString().startsWith('PopupMenuButton'),
  );
}

Future<void> _openPopupMenu(WidgetTester tester, Finder finder) async {
  final dynamic state = tester.state(finder);
  state.showButtonMenu();
  await tester.pumpAndSettle();
}

ProductItem _buildProduct({
  required int id,
  required int currentVersion,
  required int effectiveVersion,
  String lifecycleStatus = 'active',
  String category = '贴片',
  String? inactiveReason,
}) {
  return ProductItem(
    id: id,
    name: '产品$id',
    category: category,
    remark: '',
    lifecycleStatus: lifecycleStatus,
    currentVersion: currentVersion,
    currentVersionLabel: 'V1.${currentVersion - 1}',
    effectiveVersion: effectiveVersion,
    effectiveVersionLabel: effectiveVersion > 0
        ? 'V1.${effectiveVersion - 1}'
        : null,
    effectiveAt: effectiveVersion > 0 ? _fixedDate : null,
    inactiveReason: inactiveReason,
    lastParameterSummary: null,
    createdAt: _fixedDate,
    updatedAt: _fixedDate,
  );
}

ProductVersionItem _buildVersion({
  required int version,
  required String versionLabel,
  required String lifecycleStatus,
}) {
  return ProductVersionItem(
    version: version,
    versionLabel: versionLabel,
    lifecycleStatus: lifecycleStatus,
    action: 'create',
    note: null,
    effectiveAt: lifecycleStatus == 'effective' ? _fixedDate : null,
    sourceVersion: null,
    sourceVersionLabel: null,
    createdByUserId: 1,
    createdByUsername: 'admin',
    createdAt: _fixedDate,
  );
}

ProductParameterVersionListItem _buildParameterVersionRow({
  required int productId,
  required String productName,
  required int version,
  required String versionLabel,
  required String lifecycleStatus,
  bool isCurrentVersion = false,
  bool isEffectiveVersion = false,
}) {
  return ProductParameterVersionListItem(
    productId: productId,
    productName: productName,
    productCategory: '贴片',
    version: version,
    versionLabel: versionLabel,
    lifecycleStatus: lifecycleStatus,
    isCurrentVersion: isCurrentVersion,
    isEffectiveVersion: isEffectiveVersion,
    createdAt: _fixedDate,
    parameterSummary: '当前版本参数摘要',
    parameterCount: 8,
    matchedParameterName: '产品芯片',
    matchedParameterCategory: '基础参数',
    lastModifiedParameter: '产品芯片',
    lastModifiedParameterCategory: '基础参数',
    updatedAt: _fixedDate,
  );
}

class _VersionGuardService extends ProductService {
  _VersionGuardService({required this.products, required this.versions})
    : super(_session());

  final List<ProductItem> products;
  final List<ProductVersionItem> versions;

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
    return ProductListResult(total: products.length, items: products);
  }

  @override
  Future<ProductVersionListResult> listProductVersions({
    required int productId,
  }) async {
    return ProductVersionListResult(total: versions.length, items: versions);
  }
}

class _ProductGuardService extends ProductService {
  _ProductGuardService({required this.products, required this.versions})
    : super(_session());

  final List<ProductItem> products;
  final List<ProductVersionItem> versions;

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
    return ProductListResult(total: products.length, items: products);
  }

  @override
  Future<ProductDetailResult> getProductDetail({required int productId}) async {
    final product = products.single;
    return ProductDetailResult(
      product: product,
      detailParameters: ProductParameterListResult(
        productId: product.id,
        productName: product.name,
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
      versionTotal: versions.length,
      versions: versions,
      historyTotal: 1,
      historyItems: [
        ProductParameterHistoryItem(
          id: 1,
          productName: product.name,
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
      relatedInfoSections: const [],
    );
  }

  @override
  Future<ProductVersionListResult> listProductVersions({
    required int productId,
  }) async {
    return ProductVersionListResult(total: versions.length, items: versions);
  }
}

class _ParameterManagementGuardService extends ProductService {
  _ParameterManagementGuardService(this.rows) : super(_session());

  final List<ProductParameterVersionListItem> rows;

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
    return ProductParameterVersionListResult(total: rows.length, items: rows);
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
      versionLabel: version == null ? null : 'V1.${version - 1}',
      lifecycleStatus: 'draft',
      total: 1,
      items: [
        ProductParameterHistoryItem(
          id: 11,
          productName: '产品$productId',
          productCategory: '贴片',
          version: version,
          versionLabel: version == null ? null : 'V1.${version - 1}',
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
  }
}

class _ParameterQueryGuardService extends ProductService {
  _ParameterQueryGuardService(this.products) : super(_session());

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
    throw ApiException('参数查询 guard 测试不应回退产品管理列表接口', 500);
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

  @override
  Future<ProductParameterListResult> listProductParameters({
    required int productId,
    int? version,
    bool effectiveOnly = false,
  }) async {
    final product = products.firstWhere((item) => item.id == productId);
    return ProductParameterListResult(
      productId: product.id,
      productName: product.name,
      parameterScope: 'effective',
      version: product.effectiveVersion,
      versionLabel:
          product.effectiveVersionLabel ?? 'V1.${product.effectiveVersion - 1}',
      lifecycleStatus: 'effective',
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
    );
  }
}

void main() {
  group('Product module second-wave guard rails', () {
    testWidgets('产品版本管理页保留第二波工作区结构和核心动作入口', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _VersionGuardService(
        products: [
          _buildProduct(id: 61, currentVersion: 2, effectiveVersion: 1),
        ],
        versions: [
          _buildVersion(
            version: 2,
            versionLabel: 'V1.1',
            lifecycleStatus: 'draft',
          ),
          _buildVersion(
            version: 1,
            versionLabel: 'V1.0',
            lifecycleStatus: 'effective',
          ),
        ],
      );

      await tester.pumpWidget(
        _guardHost(
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

      expect(find.byType(MesListDetailShell), findsOneWidget);
      expect(
        find.byKey(const ValueKey('product-version-page-header')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('product-selector-panel')),
        findsOneWidget,
      );

      await tester.tap(find.text('产品61'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('product-version-feedback-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('product-version-toolbar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('product-version-table-section')),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, '复制版本'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '导出参数'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '编辑版本说明'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '立即生效'), findsOneWidget);
    });

    testWidgets('产品管理页保留第二波列表骨架 详情侧栏和版本弹窗入口', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _ProductGuardService(
        products: [
          _buildProduct(id: 71, currentVersion: 2, effectiveVersion: 1),
        ],
        versions: [
          _buildVersion(
            version: 2,
            versionLabel: 'V1.1',
            lifecycleStatus: 'draft',
          ),
          _buildVersion(
            version: 1,
            versionLabel: 'V1.0',
            lifecycleStatus: 'effective',
          ),
        ],
      );

      await tester.pumpWidget(
        _guardHost(
          ProductManagementPage(
            session: _session(),
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
      );
      await tester.pumpAndSettle();

      expect(find.byType(MesCrudPageScaffold), findsOneWidget);
      expect(
        find.byKey(const ValueKey('product-management-page-header')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('product-management-filter-section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('product-management-table-section')),
        findsOneWidget,
      );

      await _openPopupMenu(tester, _popupMenuButtonFinder().first);
      await tester.tap(find.text('版本管理'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('product-version-dialog')), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, '关闭'));
      await tester.pumpAndSettle();

      await _openPopupMenu(tester, _popupMenuButtonFinder().first);
      await tester.tap(find.text('查看详情'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('product-detail-drawer')), findsOneWidget);
    });

    testWidgets('产品参数管理页保留第二波列表 编辑和历史结构', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _ParameterManagementGuardService([
        _buildParameterVersionRow(
          productId: 81,
          productName: '产品81',
          version: 1,
          versionLabel: 'V1.0',
          lifecycleStatus: 'effective',
          isEffectiveVersion: true,
        ),
        _buildParameterVersionRow(
          productId: 81,
          productName: '产品81',
          version: 2,
          versionLabel: 'V1.1',
          lifecycleStatus: 'draft',
          isCurrentVersion: true,
        ),
      ]);

      await tester.pumpWidget(
        _guardHost(
          ProductParameterManagementPage(
            session: _session(),
            onLogout: () {},
            tabCode: 'product-parameter-management',
            service: service,
            canExportParameters: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('product-parameter-management-page-header')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('product-parameter-filter-section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('product-parameter-version-table-section')),
        findsOneWidget,
      );

      await _openPopupMenu(tester, _popupMenuButtonFinder().first);
      await tester.tap(find.text('查看历史'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('product-parameter-history-dialog')),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, '关闭'));
      await tester.pumpAndSettle();

      await _openPopupMenu(tester, _popupMenuButtonFinder().at(1));
      await tester.tap(find.text('编辑参数'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('product-parameter-editor-header')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('product-parameter-editor-toolbar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('product-parameter-editor-table')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('product-parameter-editor-footer')),
        findsOneWidget,
      );
    });

    testWidgets('产品参数查询页保留第二波查询骨架与参数弹窗摘要结构', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _ParameterQueryGuardService([
        _buildProduct(id: 91, currentVersion: 2, effectiveVersion: 1),
      ]);

      await tester.pumpWidget(
        _guardHost(
          ProductParameterQueryPage(
            session: _session(),
            onLogout: () {},
            tabCode: productParameterQueryTabCode,
            service: service,
            canExportParameters: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('product-parameter-query-page-header')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('product-parameter-query-filter-section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('product-parameter-query-table-section')),
        findsOneWidget,
      );
      expect(service.queryCalls, 1);

      await tester.tap(find.widgetWithText(TextButton, '查看参数'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('product-parameter-query-dialog')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('product-parameter-summary-header')),
        findsOneWidget,
      );
      expect(find.text('仅展示当前生效版本参数'), findsOneWidget);
    });
  });
}
