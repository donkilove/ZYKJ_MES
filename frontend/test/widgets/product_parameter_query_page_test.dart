import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/product_models.dart';
import 'package:mes_client/pages/product_parameter_query_page.dart';
import 'package:mes_client/pages/product_page.dart';
import 'package:mes_client/services/product_service.dart';
import 'package:mes_client/widgets/simple_pagination_bar.dart';

class _FakeProductParameterQueryService extends ProductService {
  _FakeProductParameterQueryService({
    required this.products,
    required this.parameters,
  }) : super(AppSession(baseUrl: '', accessToken: 'token'));

  final List<ProductItem> products;
  final List<ProductParameterItem> parameters;
  final List<int> requestedPages = [];
  final List<int> requestedPageSizes = [];

  @override
  Future<ProductListResult> listProductsForParameterQuery({
    required int page,
    required int pageSize,
    String? keyword,
    String? category,
    String? lifecycleStatus,
    String? effectiveVersionKeyword,
  }) async {
    requestedPages.add(page);
    requestedPageSizes.add(pageSize);
    final start = (page - 1) * pageSize;
    final end = (start + pageSize) > products.length
        ? products.length
        : start + pageSize;
    return ProductListResult(
      total: products.length,
      items: start >= products.length ? const [] : products.sublist(start, end),
    );
  }

  @override
  Future<ProductParameterListResult> listProductParameters({
    required int productId,
    int? version,
    bool effectiveOnly = false,
  }) async {
    return ProductParameterListResult(
      productId: productId,
      productName: '产品$productId',
      parameterScope: effectiveOnly ? 'effective' : 'version',
      version: 2,
      versionLabel: 'V1.1',
      lifecycleStatus: 'effective',
      total: parameters.length,
      items: parameters,
    );
  }
}

ProductItem _buildProduct(int id) {
  final fixedDate = DateTime.parse('2026-03-01T00:00:00Z');
  return ProductItem(
    id: id,
    name: '产品$id',
    category: '贴片',
    remark: '备注$id',
    lifecycleStatus: 'active',
    currentVersion: 2,
    currentVersionLabel: 'V1.1',
    effectiveVersion: 2,
    effectiveVersionLabel: 'V1.1',
    effectiveAt: fixedDate,
    inactiveReason: null,
    lastParameterSummary: '参数摘要$id',
    createdAt: fixedDate,
    updatedAt: fixedDate,
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  _FakeProductParameterQueryService service,
) async {
  await tester.binding.setSurfaceSize(const Size(1920, 1080));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProductParameterQueryPage(
          session: AppSession(baseUrl: '', accessToken: 'token'),
          onLogout: () {},
          tabCode: productParameterQueryTabCode,
          service: service,
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  testWidgets('参数查询页应展示分页并按页切换结果', (tester) async {
    final service = _FakeProductParameterQueryService(
      products: List.generate(55, (index) => _buildProduct(index + 1)),
      parameters: const [],
    );

    await _pumpPage(tester, service);

    expect(find.byType(SimplePaginationBar), findsOneWidget);
    expect(find.text('结果总数'), findsOneWidget);
    expect(find.text('产品1'), findsOneWidget);
    expect(find.text('产品21'), findsNothing);

    await tester.tap(find.byKey(const Key('simple-pagination-page-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第 2 页').last);
    await tester.pumpAndSettle();

    expect(service.requestedPages.last, 2);
    expect(find.text('产品21'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('simple-pagination-page-size-selector')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('50 条/页').last);
    await tester.pumpAndSettle();

    expect(service.requestedPageSizes.last, 50);
    expect(find.text('当前页'), findsOneWidget);
  });

  testWidgets('参数查看弹窗应使用稳定详情工作台承载参数表', (tester) async {
    final service = _FakeProductParameterQueryService(
      products: [_buildProduct(1)],
      parameters: [
        ProductParameterItem(
          name: '产品芯片',
          category: '基础参数',
          type: 'Text',
          value: 'CHIP-X',
          description: '主控芯片',
          sortOrder: 1,
          isPreset: false,
        ),
      ],
    );

    await _pumpPage(tester, service);

    await tester.tap(find.text('操作').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看参数').last);
    await tester.pumpAndSettle();

    expect(find.text('桌面详情工作台视图，保留原只读弹窗流程。'), findsOneWidget);
    expect(find.text('查询摘要'), findsOneWidget);
    expect(find.text('参数总数'), findsOneWidget);
    expect(find.text('产品芯片'), findsOneWidget);
    expect(find.text('主控芯片'), findsOneWidget);
  });
}
