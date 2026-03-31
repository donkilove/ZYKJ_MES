import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/authz_models.dart';
import 'package:mes_client/models/product_models.dart';
import 'package:mes_client/pages/product_management_page.dart';
import 'package:mes_client/pages/product_parameter_management_page.dart';
import 'package:mes_client/pages/product_parameter_query_page.dart';
import 'package:mes_client/pages/product_page.dart';
import 'package:mes_client/pages/product_version_management_page.dart';
import 'package:mes_client/services/api_exception.dart';
import 'package:mes_client/services/product_service.dart';

final DateTime _fixedDate = DateTime.parse('2026-03-01T00:00:00Z');

AppSession _session() {
  return AppSession(baseUrl: '', accessToken: 'test-token');
}

ProductItem _buildProduct({
  required int id,
  required int currentVersion,
  required int effectiveVersion,
  String lifecycleStatus = 'active',
  String remark = '',
  String? inactiveReason,
}) {
  return ProductItem(
    id: id,
    name: '产品$id',
    category: '贴片',
    remark: remark,
    lifecycleStatus: lifecycleStatus,
    currentVersion: currentVersion,
    currentVersionLabel: 'V1.${currentVersion - 1}',
    effectiveVersion: effectiveVersion,
    effectiveVersionLabel: effectiveVersion > 0
        ? 'V1.${effectiveVersion - 1}'
        : null,
    effectiveAt: _fixedDate,
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
    effectiveAt: null,
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
  String? parameterSummary,
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
    parameterSummary: parameterSummary,
    parameterCount: 8,
    matchedParameterName: '产品芯片',
    matchedParameterCategory: '基础参数',
    lastModifiedParameter: '产品芯片',
    lastModifiedParameterCategory: '基础参数',
    updatedAt: _fixedDate,
  );
}

class _VersionListService extends ProductService {
  _VersionListService({required this.products, required this.versions})
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

class _SwitchFallthroughService extends _VersionListService {
  _SwitchFallthroughService()
    : super(
        products: [
          _buildProduct(id: 1, currentVersion: 1, effectiveVersion: 1),
        ],
        versions: [
          _buildVersion(
            version: 1,
            versionLabel: 'V1.0',
            lifecycleStatus: 'draft',
          ),
        ],
      );

  @override
  Future<ProductVersionItem> copyProductVersion({
    required int productId,
    required int sourceVersion,
  }) async {
    return _buildVersion(
      version: 2,
      versionLabel: 'V1.1',
      lifecycleStatus: 'draft',
    );
  }
}

class _ProductListOnlyService extends ProductService {
  _ProductListOnlyService(this.products) : super(_session());

  final List<ProductItem> products;

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
}

class _ProductManagementFilterContractService extends _ProductListOnlyService {
  _ProductManagementFilterContractService(super.products);

  DateTime? lastUpdatedAfter;
  DateTime? lastUpdatedBefore;

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
    lastUpdatedAfter = updatedAfter;
    lastUpdatedBefore = updatedBefore;
    return super.listProducts(
      page: page,
      pageSize: pageSize,
      keyword: keyword,
      category: category,
      lifecycleStatus: lifecycleStatus,
      hasEffectiveVersion: hasEffectiveVersion,
      updatedAfter: updatedAfter,
      updatedBefore: updatedBefore,
      currentVersionKeyword: currentVersionKeyword,
      currentParamNameKeyword: currentParamNameKeyword,
      currentParamCategoryKeyword: currentParamCategoryKeyword,
    );
  }
}

class _PagedProductListService extends ProductService {
  _PagedProductListService(this.products) : super(_session());

  final List<ProductItem> products;
  final List<int> pageCalls = [];

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
    pageCalls.add(page);
    final trimmedKeyword = keyword?.trim() ?? '';
    final filtered = products.where((product) {
      if (trimmedKeyword.isNotEmpty && !product.name.contains(trimmedKeyword)) {
        return false;
      }
      if ((category ?? '').isNotEmpty && product.category != category) {
        return false;
      }
      if ((lifecycleStatus ?? '').isNotEmpty &&
          product.lifecycleStatus != lifecycleStatus) {
        return false;
      }
      if (hasEffectiveVersion != null) {
        final matched = product.effectiveVersion > 0;
        if (matched != hasEffectiveVersion) {
          return false;
        }
      }
      if (updatedAfter != null && product.updatedAt.isBefore(updatedAfter)) {
        return false;
      }
      if (updatedBefore != null && product.updatedAt.isAfter(updatedBefore)) {
        return false;
      }
      return true;
    }).toList();
    final start = (page - 1) * pageSize;
    final items = start >= filtered.length
        ? const <ProductItem>[]
        : filtered.sublist(
            start,
            start + pageSize > filtered.length
                ? filtered.length
                : start + pageSize,
          );
    return ProductListResult(total: filtered.length, items: items);
  }

  @override
  Future<void> deleteProduct({
    required int productId,
    required String password,
  }) async {
    products.removeWhere((product) => product.id == productId);
  }
}

class _ProductFormService extends _ProductListOnlyService {
  _ProductFormService(super.products);

  String? createdName;
  String? createdCategory;
  String? createdRemark;
  int? updatedProductId;
  String? updatedName;
  String? updatedCategory;
  String? updatedRemark;

  @override
  Future<void> createProduct({
    required String name,
    required String category,
    String remark = '',
  }) async {
    createdName = name;
    createdCategory = category;
    createdRemark = remark;
  }

  @override
  Future<ProductItem> updateProduct({
    required int productId,
    required String name,
    required String category,
    String remark = '',
  }) async {
    updatedProductId = productId;
    updatedName = name;
    updatedCategory = category;
    updatedRemark = remark;
    return _buildProduct(
      id: productId,
      currentVersion: 1,
      effectiveVersion: 1,
      remark: remark,
    );
  }
}

class _ActivateImpactService extends _VersionListService {
  _ActivateImpactService()
    : super(
        products: [
          _buildProduct(id: 1, currentVersion: 1, effectiveVersion: 1),
        ],
        versions: [
          _buildVersion(
            version: 1,
            versionLabel: 'V1.0',
            lifecycleStatus: 'draft',
          ),
        ],
      );

  final List<String> impactOperations = [];

  @override
  Future<ProductVersionItem> activateProductVersion({
    required int productId,
    required int version,
    bool confirmed = false,
    int? expectedEffectiveVersion,
  }) async {
    if (!confirmed) {
      throw ApiException('Impact confirmation required before activation', 400);
    }
    return _buildVersion(
      version: version,
      versionLabel: 'V1.0',
      lifecycleStatus: 'effective',
    );
  }

  @override
  Future<ProductImpactAnalysisResult> getProductImpactAnalysis({
    required int productId,
    required String operation,
    String? targetStatus,
    int? targetVersion,
  }) async {
    impactOperations.add(operation);
    return ProductImpactAnalysisResult(
      operation: operation,
      targetStatus: targetStatus,
      targetVersion: targetVersion,
      totalOrders: 1,
      pendingOrders: 1,
      inProgressOrders: 0,
      requiresConfirmation: false,
      items: const [],
    );
  }
}

class _ParameterManagementContractService extends ProductService {
  _ParameterManagementContractService()
    : products = [
        _buildProduct(id: 41, currentVersion: 2, effectiveVersion: 1),
      ],
      super(_session());

  final List<ProductItem> products;
  final List<ProductParameterVersionListItem> parameterVersionRows = [
    _buildParameterVersionRow(
      productId: 41,
      productName: '产品41',
      version: 1,
      versionLabel: 'V1.0',
      lifecycleStatus: 'effective',
      isEffectiveVersion: true,
      parameterSummary: '历史版本参数',
    ),
    _buildParameterVersionRow(
      productId: 41,
      productName: '产品41',
      version: 2,
      versionLabel: 'V1.1',
      lifecycleStatus: 'draft',
      isCurrentVersion: true,
      parameterSummary: '当前草稿参数',
    ),
  ];
  final List<int> versionLoadCalls = [];
  final List<int> versionUpdateCalls = [];
  final List<int> historyCalls = [];
  final List<int> listPageSizes = [];
  String? lastVersionKeyword;
  String? lastParamNameKeyword;
  String? lastParamCategoryKeyword;
  DateTime? lastUpdatedAfter;
  DateTime? lastUpdatedBefore;
  int legacyListCalls = 0;

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
  Future<ProductParameterListResult> listProductParameters({
    required int productId,
    int? version,
    bool effectiveOnly = false,
  }) {
    legacyListCalls += 1;
    throw ApiException('参数管理页不应回退旧参数接口', 500);
  }

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
    listPageSizes.add(pageSize);
    lastVersionKeyword = versionKeyword;
    lastParamNameKeyword = paramNameKeyword;
    lastParamCategoryKeyword = paramCategoryKeyword;
    lastUpdatedAfter = updatedAfter;
    lastUpdatedBefore = updatedBefore;
    return ProductParameterVersionListResult(
      total: parameterVersionRows.length,
      items: parameterVersionRows,
    );
  }

  @override
  Future<ProductParameterListResult> getProductVersionParameters({
    required int productId,
    required int version,
  }) async {
    versionLoadCalls.add(version);
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
  Future<ProductParameterUpdateResult> updateProductParameters({
    required int productId,
    required int version,
    required String remark,
    required List<ProductParameterUpdateItem> items,
    bool confirmed = false,
  }) async {
    versionUpdateCalls.add(version);
    return ProductParameterUpdateResult(
      parameterScope: 'version',
      version: version,
      updatedCount: items.length,
      changedKeys: items.map((item) => item.name).toList(),
    );
  }

  @override
  Future<ProductParameterHistoryListResult> listProductParameterHistory({
    required int productId,
    int? version,
    required int page,
    required int pageSize,
  }) async {
    historyCalls.add(version ?? -1);
    return ProductParameterHistoryListResult(
      version: version,
      versionLabel: version == null ? null : 'V1.${version - 1}',
      lifecycleStatus: 'draft',
      total: 1,
      items: [
        ProductParameterHistoryItem(
          id: 900,
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
          beforeSummary: '产品芯片: 分类=基础参数; 类型=Text; 值=旧值; 说明=-',
          afterSummary: '产品芯片: 分类=基础参数; 类型=Text; 值=新值; 说明=-',
          beforeSnapshot: '{"before":true}',
          afterSnapshot: '{"after":true}',
          createdAt: _fixedDate,
        ),
      ],
    );
  }
}

class _ParameterQueryRoutingService extends ProductService {
  _ParameterQueryRoutingService() : super(_session());

  int versionCalls = 0;
  int effectiveCalls = 0;

  @override
  Future<ProductParameterListResult> getProductVersionParameters({
    required int productId,
    required int version,
  }) async {
    versionCalls += 1;
    return ProductParameterListResult(
      productId: productId,
      productName: '产品$productId',
      parameterScope: 'version',
      version: version,
      versionLabel: 'V1.${version - 1}',
      lifecycleStatus: 'draft',
      total: 0,
      items: const [],
    );
  }

  @override
  Future<ProductParameterListResult> getEffectiveProductParameters({
    required int productId,
  }) async {
    effectiveCalls += 1;
    return ProductParameterListResult(
      productId: productId,
      productName: '产品$productId',
      parameterScope: 'effective',
      version: 4,
      versionLabel: 'V1.3',
      lifecycleStatus: 'effective',
      total: 0,
      items: const [],
    );
  }
}

class _ProductDetailDrawerService extends _ProductListOnlyService {
  _ProductDetailDrawerService(super.products);

  @override
  Future<ProductDetailResult> getProductDetail({required int productId}) async {
    return ProductDetailResult(
      product: products.single,
      detailParameters: ProductParameterListResult(
        productId: productId,
        productName: products.single.name,
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
        _buildVersion(
          version: 2,
          versionLabel: 'V1.1',
          lifecycleStatus: 'draft',
        ),
      ],
      historyTotal: 1,
      historyItems: [
        ProductParameterHistoryItem(
          id: 1,
          productName: products.single.name,
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
        ProductRelatedInfoSection(
          code: 'equipment',
          title: '关联设备',
          total: 0,
          emptyMessage: '当前仓库尚未沉淀产品-设备关联数据。',
        ),
      ],
    );
  }
}

class _ParameterQueryPageService extends ProductService {
  _ParameterQueryPageService(this.products) : super(_session());

  final List<ProductItem> products;
  int parameterQueryCalls = 0;
  int legacyListCalls = 0;
  final List<int> pageSizes = [];
  String? lastLifecycleStatus;
  bool? lastHasEffectiveVersion;

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
    legacyListCalls += 1;
    throw ApiException('参数查询页不应依赖产品管理列表权限接口', 500);
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
    parameterQueryCalls += 1;
    pageSizes.add(pageSize);
    lastLifecycleStatus = lifecycleStatus;
    lastHasEffectiveVersion = hasEffectiveVersion;
    return ProductListResult(total: products.length, items: products);
  }
}

Widget _host(Widget child) {
  return MaterialApp(
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

void main() {
  final overlongRemark = List.filled(501, 'a').join();
  final overlongName = List.filled(129, 'a').join();

  group('Product module issue regressions', () {
    testWidgets('版本管理页权限应绑定管理能力而非查看能力', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _host(
          ProductPage(
            session: _session(),
            onLogout: () {},
            visibleTabCodes: const [productVersionManagementTabCode],
            capabilityCodes: {
              ProductFeaturePermissionCodes.versionAnalysisView,
            },
            productVersionService: _VersionListService(
              products: [],
              versions: [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final versionPage = tester.widget<ProductVersionManagementPage>(
        find.byType(ProductVersionManagementPage),
      );

      expect(
        versionPage.canManageVersions,
        isFalse,
        reason: '仅有版本查看权限时，不应放开版本写操作入口。',
      );
    });

    testWidgets('版本管理中点击复制不应弹出停用或删除确认框', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _SwitchFallthroughService();

      await tester.pumpWidget(
        _host(
          ProductVersionManagementPage(
            session: _session(),
            onLogout: () {},
            tabCode: productVersionManagementTabCode,
            canManageVersions: true,
            service: service,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('产品1'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('复制版本').last);
      await tester.pumpAndSettle();

      expect(find.text('确认停用'), findsNothing, reason: '复制操作不应触发停用分支。');
      expect(find.text('确认删除'), findsNothing, reason: '复制操作不应触发删除分支。');
    });

    testWidgets('产品管理页应按后端语义显示版本号', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _ProductListOnlyService([
        _buildProduct(id: 11, currentVersion: 3, effectiveVersion: 2),
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

      expect(
        find.text('V1.1'),
        findsOneWidget,
        reason: 'effective_version=2 应显示为 V1.1。',
      );
      expect(
        find.text('V1.3'),
        findsNothing,
        reason: 'current_version=3 不应显示为 V1.3。',
      );
    });

    testWidgets('产品管理页不再显示更新时间筛选且请求不传更新时间参数', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _ProductManagementFilterContractService([
        _buildProduct(id: 12, currentVersion: 2, effectiveVersion: 1),
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

      expect(find.text('更新起始日期'), findsNothing);
      expect(find.text('更新截止日期'), findsNothing);
      expect(find.text('清除日期'), findsNothing);
      expect(service.lastUpdatedAfter, isNull);
      expect(service.lastUpdatedBefore, isNull);
    });

    testWidgets('产品管理页应支持分页并在搜索和结果集缩小后校正页码', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _PagedProductListService([
        _buildProduct(
          id: 1,
          currentVersion: 1,
          effectiveVersion: 1,
          remark: '唯一',
        ),
        ...List.generate(
          100,
          (index) => _buildProduct(
            id: index + 2,
            currentVersion: 1,
            effectiveVersion: 1,
          ),
        ),
      ]);
      service.products[0] = ProductItem(
        id: service.products[0].id,
        name: '唯一搜索产品',
        category: service.products[0].category,
        remark: service.products[0].remark,
        lifecycleStatus: service.products[0].lifecycleStatus,
        currentVersion: service.products[0].currentVersion,
        currentVersionLabel: service.products[0].currentVersionLabel,
        effectiveVersion: service.products[0].effectiveVersion,
        effectiveVersionLabel: service.products[0].effectiveVersionLabel,
        effectiveAt: service.products[0].effectiveAt,
        inactiveReason: service.products[0].inactiveReason,
        lastParameterSummary: service.products[0].lastParameterSummary,
        createdAt: service.products[0].createdAt,
        updatedAt: service.products[0].updatedAt,
      );

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

      expect(find.text('第 1 / 3 页'), findsOneWidget);
      expect(find.text('总数：101'), findsNothing);

      await tester.tap(find.widgetWithText(OutlinedButton, '下一页'));
      await tester.pumpAndSettle();
      expect(find.text('第 2 / 3 页'), findsOneWidget);

      await tester.tap(find.byTooltip('刷新'));
      await tester.pumpAndSettle();
      expect(find.text('第 2 / 3 页'), findsOneWidget, reason: '刷新应保留当前页。');
      expect(service.pageCalls.last, 2);

      await tester.tap(find.widgetWithText(OutlinedButton, '下一页'));
      await tester.pumpAndSettle();
      expect(find.text('第 3 / 3 页'), findsOneWidget);
      expect(find.text('产品101'), findsOneWidget);

      service.products.removeWhere((product) => product.id == 101);
      await tester.tap(find.byTooltip('刷新'));
      await tester.pumpAndSettle();

      expect(
        find.text('第 2 / 2 页'),
        findsOneWidget,
        reason: '结果集缩小后越界页码应自动回退。',
      );
      expect(service.pageCalls.sublist(service.pageCalls.length - 2), [3, 2]);

      await tester.enterText(
        find.widgetWithText(TextField, '搜索产品名称'),
        '唯一搜索产品',
      );
      await tester.tap(find.widgetWithText(FilledButton, '搜索产品'));
      await tester.pumpAndSettle();

      expect(find.text('第 1 / 1 页'), findsOneWidget, reason: '搜索后应回到第一页。');
      expect(service.pageCalls.last, 1);
      expect(find.text('唯一搜索产品'), findsWidgets);
      expect(find.text('产品52'), findsNothing);

      final searchButton = find.widgetWithText(FilledButton, '搜索产品');
      final addButton = find.widgetWithText(FilledButton, '添加产品');
      final exportButton = find.widgetWithText(OutlinedButton, '导出产品');

      expect(searchButton, findsOneWidget);
      expect(addButton, findsOneWidget);
      expect(exportButton, findsOneWidget);

      final searchLeft = tester.getTopLeft(searchButton).dx;
      final addLeft = tester.getTopLeft(addButton).dx;
      final exportLeft = tester.getTopLeft(exportButton).dx;

      expect(searchLeft < addLeft, isTrue, reason: '搜索产品按钮应位于添加产品之前。');
      expect(addLeft < exportLeft, isTrue, reason: '添加产品按钮应位于导出产品之前。');
    });

    testWidgets('产品管理页筛选变更后应回到第一页', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _PagedProductListService([
        ...List.generate(
          60,
          (index) => _buildProduct(
            id: index + 1,
            currentVersion: 1,
            effectiveVersion: 1,
            lifecycleStatus: 'active',
          ),
        ),
        ...List.generate(
          60,
          (index) => _buildProduct(
            id: index + 61,
            currentVersion: 1,
            effectiveVersion: 1,
            lifecycleStatus: 'inactive',
          ),
        ),
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
      await tester.tap(find.widgetWithText(OutlinedButton, '下一页'));
      await tester.pumpAndSettle();
      expect(find.text('第 2 / 3 页'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('停用').last);
      await tester.pumpAndSettle();

      expect(find.text('第 1 / 2 页'), findsOneWidget);
      expect(service.pageCalls.last, 1, reason: '筛选变化后应回到第一页。');
    });

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

      expect(find.text('产品详情 - 产品21'), findsOneWidget);
      expect(find.text('页内侧边栏展示完整详情快照'), findsOneWidget);
      expect(find.text('当前版本参数快照（V1.1）'), findsOneWidget);
      expect(find.text('当前无生效版本，详情已回退展示当前版本参数快照。'), findsOneWidget);
      expect(find.text('关联信息'), findsOneWidget);
      expect(find.textContaining('贴片主线工艺'), findsOneWidget);
      expect(find.text('当前仓库尚未沉淀产品-设备关联数据。'), findsOneWidget);
      expect(find.textContaining('参数调整'), findsOneWidget);
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

      expect(service.impactOperations, isNotEmpty, reason: '应触发生效影响分析查询。');
      expect(
        service.impactOperations.first,
        'lifecycle',
        reason: '版本生效影响分析应走 lifecycle 操作码。',
      );
    });

    testWidgets('新建产品弹窗应显示默认启用并在提交时 trim', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _ProductFormService(const []);

      await tester.pumpWidget(
        _host(
          ProductManagementPage(
            session: _session(),
            onLogout: () {},
            canCreateProduct: true,
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
      await tester.tap(find.widgetWithText(FilledButton, '添加产品'));
      await tester.pumpAndSettle();

      expect(find.text('默认状态'), findsOneWidget);
      expect(find.text('启用'), findsWidgets);

      await tester.enterText(
        find.widgetWithText(TextFormField, '产品名称'),
        '  新产品  ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '备注'),
        '  需要 trim  ',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('贴片').last);
      await tester.pumpAndSettle();
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      expect(service.createdName, '新产品');
      expect(service.createdCategory, '贴片');
      expect(service.createdRemark, '需要 trim');
    });

    testWidgets('版本管理页应提示停用产品需先生效版本', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _VersionListService(
        products: [
          _buildProduct(
            id: 31,
            currentVersion: 2,
            effectiveVersion: 0,
            lifecycleStatus: 'inactive',
            inactiveReason: '当前无生效版本，请前往版本管理生效版本后恢复启用',
          ),
        ],
        versions: [
          _buildVersion(
            version: 2,
            versionLabel: 'V1.1',
            lifecycleStatus: 'draft',
          ),
        ],
      );

      await tester.pumpWidget(
        _host(
          ProductVersionManagementPage(
            session: _session(),
            onLogout: () {},
            tabCode: productVersionManagementTabCode,
            canManageVersions: true,
            service: service,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('产品31'));
      await tester.pumpAndSettle();

      expect(find.text('当前无生效版本，请前往版本管理生效版本后恢复启用'), findsOneWidget);
    });

    testWidgets('产品管理页停用产品应提供独立启用入口', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _ProductListOnlyService([
        _buildProduct(
          id: 32,
          currentVersion: 2,
          effectiveVersion: 1,
          lifecycleStatus: 'inactive',
          inactiveReason: '人工停用',
        ),
      ]);

      await tester.pumpWidget(
        _host(
          ProductManagementPage(
            session: _session(),
            onLogout: () {},
            canCreateProduct: false,
            canDeleteProduct: false,
            canUpdateLifecycle: true,
            canViewVersions: true,
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
      await tester.tap(find.text('操作').last);
      await tester.pumpAndSettle();

      expect(find.text('启用'), findsOneWidget);
      expect(find.text('去版本管理生效'), findsNothing);
    });

    testWidgets('版本管理页顶部应显式展示复制版本和导出参数入口', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _VersionListService(
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

      expect(find.widgetWithText(OutlinedButton, '复制版本'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '导出参数'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '编辑版本说明'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '立即生效'), findsOneWidget);
    });

    testWidgets('产品表单应拦截未选分类 空白名称和超长备注', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _ProductFormService(const []);

      await tester.pumpWidget(
        _host(
          ProductManagementPage(
            session: _session(),
            onLogout: () {},
            canCreateProduct: true,
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
      await tester.tap(find.widgetWithText(FilledButton, '添加产品'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, '产品名称'), '   ');
      await tester.enterText(
        find.widgetWithText(TextFormField, '备注'),
        overlongRemark,
      );
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pump();

      expect(find.text('请选择产品分类'), findsWidgets);
      expect(find.text('产品名称不能为空'), findsOneWidget);
      expect(find.text('备注不能超过 500 个字符'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, '产品名称'),
        overlongName,
      );
      await tester.pump();

      expect(find.text('产品名称不能超过 128 个字符'), findsOneWidget);
      expect(service.createdName, isNull);
    });

    testWidgets('编辑产品弹窗应显示当前状态并在提交时 trim', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _ProductFormService([
        _buildProduct(
          id: 21,
          currentVersion: 1,
          effectiveVersion: 1,
          lifecycleStatus: 'inactive',
          remark: '旧备注',
        ),
      ]);

      await tester.pumpWidget(
        _host(
          ProductManagementPage(
            session: _session(),
            onLogout: () {},
            canCreateProduct: true,
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
      await tester.tap(find.text('操作').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑产品'));
      await tester.pumpAndSettle();

      expect(find.text('当前状态'), findsOneWidget);
      expect(find.text('停用'), findsWidgets);

      await tester.enterText(
        find.widgetWithText(TextFormField, '产品名称'),
        '  已更新产品  ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '备注'),
        '  已更新备注  ',
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      expect(service.updatedProductId, 21);
      expect(service.updatedName, '已更新产品');
      expect(service.updatedRemark, '已更新备注');
    });

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

      expect(find.text('版本参数管理'), findsOneWidget);
      expect(find.text('产品分类'), findsOneWidget);
      expect(find.text('创建时间'), findsOneWidget);
      expect(find.text('参数总数'), findsNothing);
      expect(find.text('命中参数名称'), findsNothing);
      expect(find.text('命中参数分组'), findsNothing);
      expect(find.text('最近变更参数'), findsNothing);
      expect(find.text('最后修改时间'), findsNothing);
      expect(find.text('V1.0 / #1'), findsOneWidget);
      expect(find.text('V1.1 / #2'), findsOneWidget);
      expect(find.text('产品芯片'), findsNothing);
      expect(find.text('基础参数'), findsNothing);
      expect(service.legacyListCalls, 0, reason: '首屏列表不应回退旧产品参数接口。');
      expect(service.listPageSizes, [
        200,
      ], reason: '首屏列表查询应遵守后端 page_size<=200 限制。');

      await _openPopupMenu(tester, _popupMenuButtonFinder().first);
      await tester.tap(find.text('查看历史'));
      await tester.pumpAndSettle();

      expect(service.historyCalls, [1], reason: '历史查询应绑定所选版本行。');
      expect(find.textContaining('参数变更历史 - 产品41 / 贴片 / V1.0'), findsOneWidget);
      expect(find.textContaining('变更原因：调整芯片参数'), findsOneWidget);
      expect(find.textContaining('变更前：产品芯片:'), findsOneWidget);
      expect(find.textContaining('变更后：产品芯片:'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '关闭'));
      await tester.pumpAndSettle();

      await _openPopupMenu(tester, _popupMenuButtonFinder().at(1));
      await tester.tap(find.text('编辑参数'));
      await tester.pumpAndSettle();

      expect(service.versionLoadCalls, [2], reason: '编辑入口应显式加载所选版本参数。');
      expect(
        service.legacyListCalls,
        0,
        reason: '编辑入口不应回退旧 `/products/{id}/parameters` 口径。',
      );

      await tester.enterText(find.byType(TextField).last, '版本参数保存备注');
      await tester.tap(find.widgetWithText(FilledButton, '保存参数'));
      await tester.pumpAndSettle();

      expect(service.versionUpdateCalls, [2], reason: '保存入口应显式提交当前编辑版本。');
      expect(service.legacyListCalls, 0, reason: '保存链路不应触发旧参数读取兜底。');
    });

    testWidgets('参数管理页列表态不再显示明细筛选且请求不传对应参数', (tester) async {
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

      expect(find.text('搜索产品名称'), findsOneWidget);
      expect(find.text('分类筛选'), findsOneWidget);
      expect(find.text('版本号筛选'), findsNothing);
      expect(find.text('参数名称筛选'), findsNothing);
      expect(find.text('参数分组筛选'), findsNothing);
      expect(find.text('修改起始日期'), findsNothing);
      expect(find.text('修改截止日期'), findsNothing);
      expect(find.text('清除日期'), findsNothing);
      expect(find.text('筛选条件直接命中版本参数明细；查看/编辑/历史/导出均绑定当前版本行。'), findsNothing);
      expect(service.lastVersionKeyword, isNull);
      expect(service.lastParamNameKeyword, isNull);
      expect(service.lastParamCategoryKeyword, isNull);
      expect(service.lastUpdatedAfter, isNull);
      expect(service.lastUpdatedBefore, isNull);
    });

    testWidgets('参数编辑应即时提示 Link 格式错误', (tester) async {
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
      await _openPopupMenu(tester, _popupMenuButtonFinder().at(1));
      await tester.tap(find.text('编辑参数'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Link').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), 'ftp://invalid');
      await tester.pump();

      expect(
        find.text('Link 参数仅支持 http://、https://、\\\\、盘符绝对路径'),
        findsOneWidget,
      );
    });

    test('服务层参数查询缺少显式口径时不再回退旧接口', () async {
      final service = _ParameterQueryRoutingService();

      expect(
        () => service.listProductParameters(productId: 9),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('必须显式指定 version'),
          ),
        ),
      );

      final effectiveResult = await service.listProductParameters(
        productId: 9,
        effectiveOnly: true,
      );

      expect(effectiveResult.parameterScope, 'effective');
      expect(effectiveResult.version, 4);
      expect(
        service.effectiveCalls,
        1,
        reason: 'effectiveOnly=true 应显式走生效参数接口。',
      );
      expect(service.versionCalls, 0, reason: '生效参数查询不应混用版本参数接口。');
    });

    testWidgets('参数查询页应使用只读查询接口而非产品列表接口', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _ParameterQueryPageService([
        _buildProduct(id: 51, currentVersion: 2, effectiveVersion: 1),
      ]);

      await tester.pumpWidget(
        _host(
          ProductParameterQueryPage(
            session: _session(),
            onLogout: () {},
            tabCode: productParameterQueryTabCode,
            service: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(service.parameterQueryCalls, 1);
      expect(service.pageSizes, [200], reason: '参数查询首屏应使用后端允许的分页大小。');
      expect(
        service.lastLifecycleStatus,
        'active',
        reason: '参数查询页应固定查询启用中的产品。',
      );
      expect(
        service.lastHasEffectiveVersion,
        isTrue,
        reason: '参数查询页应固定查询已有生效版本的产品。',
      );
      expect(service.legacyListCalls, 0);
      expect(find.text('产品51'), findsOneWidget);
      expect(find.text('状态筛选'), findsNothing);
      expect(find.text('生效版本号筛选'), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(find.widgetWithText(TextButton, '查看参数'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('操作'),
          matching: find.byWidgetPredicate(
            (widget) => widget is Align && widget.alignment == Alignment.center,
          ),
        ),
        findsOneWidget,
        reason: '操作列表头应在列宽内真正居中，而不只是文本居中。',
      );
      expect(
        find.ancestor(
          of: find.widgetWithText(TextButton, '查看参数'),
          matching: find.byWidgetPredicate(
            (widget) => widget is Align && widget.alignment == Alignment.center,
          ),
        ),
        findsOneWidget,
        reason: '查看参数按钮应通过公共单元格包装保持垂直居中和水平居中。',
      );
    });
  });
}
