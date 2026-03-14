import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/authz_models.dart';
import 'package:mes_client/models/product_models.dart';
import 'package:mes_client/pages/product_management_page.dart';
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
}) {
  return ProductItem(
    id: id,
    name: '产品$id',
    category: '贴片',
    remark: '',
    lifecycleStatus: 'active',
    currentVersion: currentVersion,
    effectiveVersion: effectiveVersion,
    effectiveAt: _fixedDate,
    inactiveReason: null,
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
    sourceVersion: null,
    sourceVersionLabel: null,
    createdByUserId: 1,
    createdByUsername: 'admin',
    createdAt: _fixedDate,
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
  }) async {
    return ProductListResult(total: products.length, items: products);
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

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SizedBox(width: 1600, height: 1200, child: child)),
  );
}

void main() {
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
  });
}
