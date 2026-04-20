import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/product_management_page.dart';
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

    expect(
      find.byKey(const ValueKey('product-management-filter-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('product-management-table-section')),
      findsOneWidget,
    );

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
