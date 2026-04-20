import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/product_page.dart';
import 'package:mes_client/features/product/presentation/product_version_management_page.dart';
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
      total: 2,
      items: [
        ProductItem(
          id: 101,
          name: '产品101',
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
          id: 102,
          name: '产品102',
          category: '贴片',
          remark: '',
          lifecycleStatus: 'inactive',
          currentVersion: 1,
          currentVersionLabel: 'V1.0',
          effectiveVersion: 0,
          effectiveVersionLabel: null,
          effectiveAt: null,
          inactiveReason: '当前无生效版本，请先将目标版本设为生效后再恢复启用。',
          lastParameterSummary: null,
          createdAt: _fixedDate,
          updatedAt: _fixedDate,
        ),
      ],
    );
  }

  @override
  Future<ProductVersionListResult> listProductVersions({
    required int productId,
  }) async {
    return ProductVersionListResult(
      total: 2,
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
      ],
    );
  }

  @override
  Future<ProductItem> getProduct({required int productId}) async {
    return ProductItem(
      id: productId,
      name: '产品$productId',
      category: '贴片',
      remark: '',
      lifecycleStatus: productId == 102 ? 'inactive' : 'active',
      currentVersion: 2,
      currentVersionLabel: 'V1.1',
      effectiveVersion: productId == 102 ? 0 : 1,
      effectiveVersionLabel: productId == 102 ? null : 'V1.0',
      effectiveAt: productId == 102 ? null : _fixedDate,
      inactiveReason: productId == 102
          ? '当前无生效版本，请先将目标版本设为生效后再恢复启用。'
          : null,
      lastParameterSummary: null,
      createdAt: _fixedDate,
      updatedAt: _fixedDate,
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('产品版本管理页主路径展示产品区与版本工作区', (tester) async {
    final service = _IntegrationProductService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1440,
            height: 900,
            child: ProductVersionManagementPage(
              session: AppSession(baseUrl: '', accessToken: 'token'),
              onLogout: () {},
              tabCode: productVersionManagementTabCode,
              canManageVersions: true,
              canActivateVersions: true,
              canExportVersionParameters: true,
              service: service,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('版本管理'), findsOneWidget);
    expect(find.byKey(const ValueKey('product-selector-panel')), findsOneWidget);

    await tester.tap(find.text('产品101'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('product-version-toolbar')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('product-version-table-section')),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, '复制版本'), findsOneWidget);
  });
}
