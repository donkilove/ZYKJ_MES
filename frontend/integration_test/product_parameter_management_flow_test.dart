import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/product_parameter_management_page.dart';
import 'package:mes_client/features/product/services/product_service.dart';

final DateTime _fixedDate = DateTime.parse('2026-04-20T00:00:00Z');

class _IntegrationProductService extends ProductService {
  _IntegrationProductService()
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

    final popupButtons = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString().startsWith('PopupMenuButton'),
    );

    await tester.tap(popupButtons.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑参数').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('product-parameter-editor-header')), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '返回列表'));
    await tester.pumpAndSettle();

    await tester.tap(popupButtons.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看历史').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('product-parameter-history-dialog')), findsOneWidget);
  });
}
