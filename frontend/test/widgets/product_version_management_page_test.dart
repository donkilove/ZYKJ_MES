import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/core/ui/patterns/mes_list_detail_shell.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/product_page.dart';
import 'package:mes_client/features/product/presentation/product_version_management_page.dart';
import 'package:mes_client/features/product/presentation/widgets/product_selector_panel.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_feedback_banner.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_page_header.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_table_section.dart';
import 'package:mes_client/features/product/presentation/widgets/product_version_toolbar.dart';
import 'package:mes_client/features/product/services/product_service.dart';

final DateTime _fixedDate = DateTime.parse('2026-04-20T00:00:00Z');

ProductItem _buildProduct({
  required int id,
  required String name,
  String lifecycleStatus = 'active',
  int effectiveVersion = 1,
  String? inactiveReason,
}) {
  return ProductItem(
    id: id,
    name: name,
    category: '贴片',
    remark: '',
    lifecycleStatus: lifecycleStatus,
    currentVersion: 2,
    currentVersionLabel: 'V1.1',
    effectiveVersion: effectiveVersion,
    effectiveVersionLabel: effectiveVersion > 0 ? 'V1.0' : null,
    effectiveAt: _fixedDate,
    inactiveReason: inactiveReason,
    lastParameterSummary: null,
    createdAt: _fixedDate,
    updatedAt: _fixedDate,
  );
}

ProductVersionItem _buildVersion({
  required int version,
  required String label,
  required String lifecycleStatus,
  String? note,
}) {
  return ProductVersionItem(
    version: version,
    versionLabel: label,
    lifecycleStatus: lifecycleStatus,
    action: 'create',
    note: note,
    effectiveAt: lifecycleStatus == 'effective' ? _fixedDate : null,
    sourceVersion: null,
    sourceVersionLabel: null,
    createdByUserId: 1,
    createdByUsername: 'admin',
    createdAt: _fixedDate,
  );
}

class _PageStructureService extends ProductService {
  _PageStructureService()
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
        _buildProduct(id: 101, name: '产品101'),
        _buildProduct(
          id: 102,
          name: '产品102',
          lifecycleStatus: 'inactive',
          effectiveVersion: 0,
          inactiveReason: '当前无生效版本，请先将目标版本设为生效后再恢复启用。',
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
        _buildVersion(
          version: 2,
          label: 'V1.1',
          lifecycleStatus: 'draft',
          note: '草稿版本',
        ),
        _buildVersion(
          version: 1,
          label: 'V1.0',
          lifecycleStatus: 'effective',
          note: '当前生效',
        ),
      ],
    );
  }
}

void main() {
  testWidgets('产品版本页拆分组件提供稳定页头 反馈 工具栏与表格锚点', (tester) async {
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final searchController = TextEditingController(text: '产品101');
    addTearDown(searchController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: Scaffold(
          body: Column(
            children: [
              ProductVersionPageHeader(
                loading: false,
                onRefresh: () {},
              ),
              ProductVersionFeedbackBanner(
                hasDraft: true,
                product: _buildProduct(
                  id: 101,
                  name: '产品101',
                  lifecycleStatus: 'inactive',
                  effectiveVersion: 0,
                  inactiveReason: '当前无生效版本，请先将目标版本设为生效后再恢复启用。',
                ),
                effectiveVersion: _buildVersion(
                  version: 1,
                  label: 'V1.0',
                  lifecycleStatus: 'effective',
                ),
                formatDate: (value) => '2026-04-20 08:00',
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: ProductSelectorPanel(
                        searchController: searchController,
                        loading: false,
                        products: [
                          _buildProduct(id: 101, name: '产品101'),
                          _buildProduct(
                            id: 102,
                            name: '产品102',
                            lifecycleStatus: 'inactive',
                            effectiveVersion: 0,
                          ),
                        ],
                        selectedProductId: 101,
                        page: 1,
                        totalPages: 3,
                        total: 120,
                        onSearchSubmitted: (_) {},
                        onRefresh: () {},
                        onSelectProduct: (_) {},
                        onPreviousPage: () {},
                        onNextPage: () {},
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          ProductVersionToolbar(
                            product: _buildProduct(id: 101, name: '产品101'),
                            selectedVersion: _buildVersion(
                              version: 2,
                              label: 'V1.1',
                              lifecycleStatus: 'draft',
                            ),
                            hasDraft: true,
                            canManageVersions: true,
                            canActivateVersions: true,
                            canExportVersionParameters: true,
                            onCreateVersion: () {},
                            onCopyVersion: () {},
                            onEditVersionNote: () {},
                            onExportParameters: () {},
                            onActivateVersion: () {},
                            onRefresh: () {},
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ProductVersionTableSection(
                              versions: [
                                _buildVersion(
                                  version: 2,
                                  label: 'V1.1',
                                  lifecycleStatus: 'draft',
                                  note: '草稿版本',
                                ),
                              ],
                              loading: false,
                              selectedVersionNumber: 2,
                              canManageVersions: true,
                              canActivateVersions: true,
                              canExportVersionParameters: true,
                              onSelectVersion: (_) {},
                              onShowDetail: (_) {},
                              onActivate: (_) {},
                              onCopy: (_) {},
                              onEditNote: (_) {},
                              onEditParameters: (_) {},
                              onExport: (_) {},
                              onDisable: (_) {},
                              onDelete: (_) {},
                              formatDate: (_) => '2026-04-20 08:00',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('版本管理'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('product-version-feedback-banner')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('product-selector-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-version-toolbar')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('product-version-table-section')),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, '复制版本'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '立即生效'), findsOneWidget);
  });

  testWidgets('版本表格区保留行级操作菜单文案', (tester) async {
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 600,
            child: ProductVersionTableSection(
              versions: [
                _buildVersion(
                  version: 2,
                  label: 'V1.1',
                  lifecycleStatus: 'draft',
                  note: '草稿版本',
                ),
              ],
              loading: false,
              selectedVersionNumber: 2,
              canManageVersions: true,
              canActivateVersions: true,
              canExportVersionParameters: true,
              onSelectVersion: (_) {},
              onShowDetail: (_) {},
              onActivate: (_) {},
              onCopy: (_) {},
              onEditNote: (_) {},
              onEditParameters: (_) {},
              onExport: (_) {},
              onDisable: (_) {},
              onDelete: (_) {},
              formatDate: (_) => '2026-04-20 08:00',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('查看详情'), findsOneWidget);
    expect(find.text('立即生效'), findsOneWidget);
    expect(find.text('复制版本'), findsOneWidget);
    expect(find.text('编辑版本说明'), findsOneWidget);
    expect(find.text('维护参数'), findsOneWidget);
    expect(find.text('导出版本参数'), findsOneWidget);
    expect(find.text('删除版本'), findsOneWidget);
  });

  testWidgets('ProductVersionManagementPage 接入主从骨架并装配拆分组件', (tester) async {
    tester.view.physicalSize = const Size(1800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = _PageStructureService();

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
    await tester.tap(find.text('产品101'));
    await tester.pumpAndSettle();

    expect(find.byType(ProductVersionPageHeader), findsOneWidget);
    expect(find.byType(MesListDetailShell), findsOneWidget);
    expect(find.byKey(const ValueKey('product-selector-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('product-version-toolbar')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('product-version-table-section')),
      findsOneWidget,
    );
  });

  testWidgets('ProductVersionManagementPage 窄宽度下仍保留产品区与版本工作区', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = _PageStructureService();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildMesTheme(
          brightness: Brightness.light,
          visualDensity: VisualDensity.standard,
        ),
        home: Scaffold(
          body: SizedBox(
            width: 760,
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
    await tester.tap(find.text('产品101'));
    await tester.pumpAndSettle();

    final sidebarRect = tester.getRect(
      find.byKey(const ValueKey('mes-list-detail-shell-sidebar')),
    );
    final contentRect = tester.getRect(
      find.byKey(const ValueKey('mes-list-detail-shell-content')),
    );

    expect(sidebarRect.top, lessThan(contentRect.top));
    expect(find.byKey(const ValueKey('product-version-toolbar')), findsOneWidget);

    final contentScrollable = find.descendant(
      of: find.byKey(const ValueKey('mes-list-detail-shell-content')),
      matching: find.byType(Scrollable),
    );
    await tester.drag(contentScrollable.first, const Offset(0, -240));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('product-version-table-section')),
      findsOneWidget,
    );
  });
}
