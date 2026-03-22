import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/authz_models.dart';
import 'package:mes_client/models/product_models.dart';
import 'package:mes_client/pages/product_management_page.dart';
import 'package:mes_client/pages/product_parameter_management_page.dart';
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
    effectiveVersion: effectiveVersion,
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
    parameterSummary: parameterSummary,
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
    String category = '',
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
    String category = '',
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
    String? lifecycleStatus,
    DateTime? updatedAfter,
    DateTime? updatedBefore,
  }) async {
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
      total: 0,
      items: const [],
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

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SizedBox(width: 1600, height: 1200, child: child)),
  );
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
      await tester.tap(find.text('复制版本'));
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

    testWidgets('新建产品弹窗应显示待生效状态并在提交时 trim', (tester) async {
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
      expect(find.text('停用（待生效版本）'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, '产品名称'),
        '  新产品  ',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '备注'),
        '  需要 trim  ',
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      expect(service.createdName, '新产品');
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

    testWidgets('产品表单应拦截空白名称和超长备注', (tester) async {
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
      await tester.pump();

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

      expect(find.text('版本参数列表'), findsOneWidget);
      expect(find.text('V1.0 / #1'), findsOneWidget);
      expect(find.text('V1.1 / #2'), findsOneWidget);
      expect(find.text('历史版本参数'), findsOneWidget);
      expect(find.text('当前草稿参数'), findsOneWidget);
      expect(service.legacyListCalls, 0, reason: '首屏列表不应回退旧产品参数接口。');

      await tester.tap(find.text('操作').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看历史'));
      await tester.pumpAndSettle();

      expect(service.historyCalls, [1], reason: '历史查询应绑定所选版本行。');
      expect(find.text('暂无历史记录'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '关闭'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('操作').at(2));
      await tester.pumpAndSettle();
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
  });
}
