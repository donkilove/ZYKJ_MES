import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_feedback_banner.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_filter_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_page_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_table_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_management_table_section.dart'
    show ProductManagementTableAction;

final DateTime _fixedDate = DateTime.parse('2026-04-20T00:00:00Z');

ProductItem _buildProduct({
  required int id,
  String lifecycleStatus = 'active',
  int currentVersion = 2,
  int effectiveVersion = 1,
}) {
  return ProductItem(
    id: id,
    name: '产品$id',
    category: '贴片',
    remark: '',
    lifecycleStatus: lifecycleStatus,
    currentVersion: currentVersion,
    currentVersionLabel: 'V1.${currentVersion - 1}',
    effectiveVersion: effectiveVersion,
    effectiveVersionLabel: effectiveVersion > 0
        ? 'V1.${effectiveVersion - 1}'
        : null,
    effectiveAt: effectiveVersion > 0 ? _fixedDate : null,
    inactiveReason: lifecycleStatus == 'inactive' ? '人工停用' : null,
    lastParameterSummary: null,
    createdAt: _fixedDate,
    updatedAt: _fixedDate,
  );
}

void main() {
  testWidgets('产品管理页展示组件提供稳定页头 筛选区 反馈区和列表区锚点', (tester) async {
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
              ProductManagementPageHeader(
                loading: false,
                onRefresh: () {},
              ),
              ProductManagementFilterSection(
                keywordController: keywordController,
                categoryOptions: const ['贴片', 'DTU', '套件'],
                selectedCategory: '',
                selectedStatus: '',
                selectedEffectiveVersion: '',
                loading: false,
                canCreateProduct: true,
                canExportProducts: true,
                onCategoryChanged: (_) {},
                onStatusChanged: (_) {},
                onEffectiveVersionChanged: (_) {},
                onSearch: () {},
                onCreate: () {},
                onExport: () {},
              ),
              const ProductManagementFeedbackBanner(
                message: '加载失败：网络错误',
              ),
              Expanded(
                child: ProductManagementTableSection(
                  products: [
                    _buildProduct(id: 41),
                    _buildProduct(
                      id: 42,
                      lifecycleStatus: 'inactive',
                      effectiveVersion: 0,
                    ),
                  ],
                  loading: false,
                  emptyText: '暂无产品',
                  formatTime: (value) => '2026-04-20 08:00:00',
                  buildActionItems: (_) => const [
                    PopupMenuItem<ProductManagementTableAction>(
                      value: ProductManagementTableAction.viewDetail,
                      child: Text('查看详情'),
                    ),
                    PopupMenuItem<ProductManagementTableAction>(
                      value: ProductManagementTableAction.version,
                      child: Text('版本管理'),
                    ),
                  ],
                  onSelected: (_, __) {},
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('产品管理'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('product-management-filter-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('product-management-feedback-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('product-management-table-section')),
      findsOneWidget,
    );
    expect(find.text('搜索产品'), findsOneWidget);
    expect(find.text('添加产品'), findsOneWidget);
    expect(find.text('导出产品'), findsOneWidget);
    expect(find.text('产品41'), findsOneWidget);
    expect(find.text('产品42'), findsOneWidget);
  });

  testWidgets('产品状态薄包装按产品生命周期展示启用或停用语义', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: Scaffold(
          body: ProductManagementTableSection(
            products: [
              _buildProduct(id: 41, lifecycleStatus: 'active'),
              _buildProduct(
                id: 42,
                lifecycleStatus: 'inactive',
                effectiveVersion: 0,
              ),
            ],
            loading: false,
            emptyText: '暂无产品',
            formatTime: (value) => '2026-04-20 08:00:00',
            buildActionItems: (_) => const [],
            onSelected: (_, __) {},
          ),
        ),
      ),
    );

    expect(find.text('启用'), findsWidgets);
    expect(find.text('停用'), findsWidgets);
  });
}
