import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/product_page.dart';
import 'package:mes_client/features/product/presentation/product_parameter_query_page.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_feedback_banner.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_filter_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_page_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_table_section.dart';
import 'package:mes_client/features/product/services/product_service.dart';

final DateTime _fixedDate = DateTime.parse('2026-04-21T00:00:00Z');

ProductItem _buildProduct({
  required int id,
  String category = '贴片',
  String lifecycleStatus = 'active',
  int effectiveVersion = 1,
}) {
  return ProductItem(
    id: id,
    name: '产品$id',
    category: category,
    remark: '',
    lifecycleStatus: lifecycleStatus,
    currentVersion: effectiveVersion == 0 ? 1 : effectiveVersion,
    currentVersionLabel: effectiveVersion == 0
        ? 'V1.0'
        : 'V1.${effectiveVersion - 1}',
    effectiveVersion: effectiveVersion,
    effectiveVersionLabel: effectiveVersion == 0
        ? null
        : 'V1.${effectiveVersion - 1}',
    effectiveAt: effectiveVersion == 0 ? null : _fixedDate,
    inactiveReason: null,
    lastParameterSummary: null,
    createdAt: _fixedDate,
    updatedAt: _fixedDate,
  );
}

AppSession _session() => AppSession(baseUrl: '', accessToken: 'token');

class _QueryPageStructureService extends ProductService {
  _QueryPageStructureService(this.products) : super(_session());

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
    throw ApiException('参数查询页不应回退产品管理列表接口', 500);
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
}

void main() {
  testWidgets('产品参数查询页基础组件提供稳定页头 筛选区 反馈区和列表区锚点', (tester) async {
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
              ProductParameterQueryPageHeader(
                loading: false,
                onRefresh: () {},
              ),
              ProductParameterQueryFilterSection(
                keywordController: keywordController,
                categoryOptions: const ['贴片', 'DTU', '套件'],
                selectedCategory: '',
                loading: false,
                canExportParameters: true,
                onCategoryChanged: (_) {},
                onSearch: () {},
                onExport: () {},
              ),
              const ProductParameterQueryFeedbackBanner(
                message: '加载失败：网络错误',
              ),
              Expanded(
                child: ProductParameterQueryTableSection(
                  products: [
                    _buildProduct(id: 81, effectiveVersion: 1),
                    _buildProduct(id: 82, category: '', effectiveVersion: 2),
                  ],
                  loading: false,
                  emptyText: '暂无产品',
                  formatTime: (_) => '2026-04-21 08:00:00',
                  onViewParameters: (_) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('产品参数查询'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('product-parameter-query-filter-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('product-parameter-query-feedback-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('product-parameter-query-table-section')),
      findsOneWidget,
    );
    expect(find.text('搜索产品名称'), findsOneWidget);
    expect(find.text('分类筛选'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '搜索'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '导出'), findsOneWidget);
    expect(find.text('产品81'), findsOneWidget);
    expect(find.text('产品82'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '查看参数'), findsNWidgets(2));
  });

  testWidgets('ProductParameterQueryPage 列表态接入统一查询骨架并展示锚点', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = _QueryPageStructureService([
      _buildProduct(id: 91, effectiveVersion: 1),
    ]);

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
            child: ProductParameterQueryPage(
              session: _session(),
              onLogout: () {},
              tabCode: productParameterQueryTabCode,
              service: service,
              canExportParameters: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MesCrudPageScaffold), findsOneWidget);
    expect(find.byType(ProductParameterQueryPageHeader), findsOneWidget);
    expect(
      find.byKey(const ValueKey('product-parameter-query-filter-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('product-parameter-query-table-section')),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, '导出'), findsOneWidget);
    expect(service.queryCalls, 1);
    expect(find.text('产品91'), findsOneWidget);
  });
}
