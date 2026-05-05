import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';
import 'package:mes_client/core/widgets/adaptive_table_container.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/product_page.dart';
import 'package:mes_client/features/product/presentation/product_parameter_query_page.dart';
import 'package:mes_client/features/product/presentation/widgets/product_parameter_query_dialog.dart';
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
  String? lastKeyword;
  String? lastCategory;
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
    lastKeyword = keyword;
    lastCategory = category;
    lastLifecycleStatus = lifecycleStatus;
    lastHasEffectiveVersion = hasEffectiveVersion;
    return ProductListResult(total: products.length, items: products);
  }
}

ProductParameterListResult _buildParameterResult({
  required String productName,
  required String versionLabel,
  required int total,
  required List<ProductParameterItem> items,
}) {
  return ProductParameterListResult(
    productId: 81,
    productName: productName,
    parameterScope: 'effective',
    version: 1,
    versionLabel: versionLabel,
    lifecycleStatus: 'effective',
    total: total,
    items: items,
  );
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
              ProductParameterQueryPageHeader(loading: false, onRefresh: () {}),
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
              const ProductParameterQueryFeedbackBanner(message: '加载失败：网络错误'),
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
    expect(find.byType(MesRefreshPageHeader), findsOneWidget);
    expect(find.text('按启用且已有生效版本的产品查看当前生效参数。'), findsNothing);
    expect(find.byTooltip('刷新'), findsOneWidget);
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

  testWidgets('产品参数查询表格区不重复嵌套 AdaptiveTableContainer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: Scaffold(
          body: ProductParameterQueryTableSection(
            products: [_buildProduct(id: 81, effectiveVersion: 1)],
            loading: false,
            emptyText: '暂无产品',
            formatTime: (_) => '2026-04-21 08:00:00',
            onViewParameters: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AdaptiveTableContainer), findsOneWidget);
  });

  testWidgets('ProductParameterQueryPage 列表态接入统一查询骨架并展示锚点', (tester) async {
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
    expect(service.lastLifecycleStatus, isNull);
    expect(service.lastHasEffectiveVersion, isNull);
  });

  testWidgets('产品参数查询页首屏默认查询全部产品而非仅启用生效产品', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = _QueryPageStructureService([
      _buildProduct(id: 91, effectiveVersion: 1),
      _buildProduct(id: 92, lifecycleStatus: 'inactive', effectiveVersion: 0),
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

    expect(service.queryCalls, 1);
    expect(service.lastKeyword, '');
    expect(service.lastCategory, '');
    expect(service.lastLifecycleStatus, isNull);
    expect(service.lastHasEffectiveVersion, isNull);
    expect(find.text('产品91'), findsOneWidget);
    expect(find.text('产品92'), findsOneWidget);
  });

  testWidgets('产品参数查询页已有列表时切回可见不会额外刷新', (tester) async {
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
              isCurrentTabVisible: false,
              canExportParameters: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.queryCalls, 1);

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
              isCurrentTabVisible: true,
              canExportParameters: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(service.queryCalls, 1);
  });

  testWidgets('产品参数查询页首屏合法空列表不会在 build 中重复请求', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = _QueryPageStructureService(const []);

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
    await tester.pump();
    await tester.pump();

    expect(service.queryCalls, 1);
    expect(find.text('暂无产品'), findsOneWidget);
  });

  testWidgets('产品参数查询页在页签重新可见且空列表时只补一次重试', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = _QueryPageStructureService(const []);

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
              isCurrentTabVisible: false,
              service: service,
              canExportParameters: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(service.queryCalls, 1);

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
              isCurrentTabVisible: true,
              service: service,
              canExportParameters: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(service.queryCalls, 2);

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
              isCurrentTabVisible: false,
              service: service,
              canExportParameters: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

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
              isCurrentTabVisible: true,
              service: service,
              canExportParameters: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(service.queryCalls, 2);
  });

  testWidgets('产品参数查询页主动搜索后会重置空列表可见补偿机会', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = _QueryPageStructureService(const []);

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
              isCurrentTabVisible: false,
              service: service,
              canExportParameters: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

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
              isCurrentTabVisible: true,
              service: service,
              canExportParameters: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(service.queryCalls, 2);

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
              isCurrentTabVisible: false,
              service: service,
              canExportParameters: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

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
              isCurrentTabVisible: true,
              service: service,
              canExportParameters: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(service.queryCalls, 2);

    await tester.tap(find.widgetWithText(FilledButton, '搜索'));
    await tester.pump();
    expect(service.queryCalls, 3);

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
              isCurrentTabVisible: false,
              service: service,
              canExportParameters: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

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
              isCurrentTabVisible: true,
              service: service,
              canExportParameters: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(service.queryCalls, 4);
  });

  testWidgets('参数查看弹窗展示顶部摘要和参数表格', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductParameterQueryDialog(
            result: _buildParameterResult(
              productName: '产品81',
              versionLabel: 'V1.0',
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
            ),
            buildParameterValueCell: (item) => Text(item.value),
            onClose: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('product-parameter-query-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('product-parameter-summary-header')),
      findsOneWidget,
    );
    expect(find.text('产品81'), findsOneWidget);
    expect(find.text('版本：V1.0'), findsOneWidget);
    expect(find.text('参数总数：2 项'), findsOneWidget);
    expect(find.text('仅展示当前生效版本参数'), findsOneWidget);
    expect(find.text('图纸链接'), findsOneWidget);
    expect(find.text('本地图纸'), findsOneWidget);
    expect(find.byType(CrudListTableSection), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);
  });

  testWidgets('参数查看弹窗空态时仍保留顶部摘要区', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductParameterQueryDialog(
            result: _buildParameterResult(
              productName: '产品82',
              versionLabel: 'V1.1',
              total: 0,
              items: const [],
            ),
            buildParameterValueCell: (item) => Text(item.value),
            onClose: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('product-parameter-summary-header')),
      findsOneWidget,
    );
    expect(find.text('产品82'), findsOneWidget);
    expect(find.text('参数总数：0 项'), findsOneWidget);
    expect(find.text('该产品暂无参数'), findsOneWidget);
  });
}
