# 产品模块第二波迁移防回退治理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 Flutter 前端中为产品模块补齐第二波迁移防回退治理，包括独立结构门禁测试和短治理说明，并保持既有产品模块 issue 回归职责不变。

**Architecture:** 先创建 `docs/frontend/product-module-second-wave-guardrails.md`，把“固定模式 / 禁止回退 / 后续自查”写成短文档，再新增 `frontend/test/widgets/product_module_second_wave_guard_test.dart` 作为独立的结构门禁文件。为了让 guard 测试稳定落地，只允许补少量页面头部 `ValueKey` 或等价锚点，不允许顺手扩展成新的页面重构或基础件建设。最终用 `flutter analyze`、新的 guard 测试文件和既有 `product_module_issue_regression_test.dart` 共同验证。

**Tech Stack:** Flutter、Dart、Material 3、`flutter_test`

---

> Flutter 命令默认在 `frontend/` 目录执行；`git`、`docs/`、`evidence/` 操作默认在仓库根目录执行。  
> 本计划遵循“无迁移，直接替换”。  
> 用户当前已经明确偏好在 `main` 分支直接推进，因此计划不再引入额外工作树。  
> 本轮不新增独立 `integration_test`，因为治理目标是结构门禁与共识固化，而不是新功能链路验证。

## 文件结构

### 新增文件

- `docs/frontend/product-module-second-wave-guardrails.md`
  - 产品模块第二波迁移治理说明，只包含固定页面模式、禁止回退清单与后续自查清单
- `frontend/test/widgets/product_module_second_wave_guard_test.dart`
  - 产品模块第二波迁移独立结构门禁文件，按页面分组锁定骨架、锚点、入口和关键接口口径
- `evidence/2026-04-21_产品模块防回退治理实施.md`
  - 本轮实施 evidence 主日志

### 修改文件

- `frontend/lib/features/product/presentation/widgets/product_version_page_header.dart`
  - 为版本管理页头部补稳定 `ValueKey`
- `frontend/lib/features/product/presentation/widgets/product_management_page_header.dart`
  - 为产品管理页头部补稳定 `ValueKey`
- `frontend/lib/features/product/presentation/widgets/product_parameter_management_page_header.dart`
  - 为参数管理页头部补稳定 `ValueKey`
- `frontend/lib/features/product/presentation/widgets/product_parameter_query_page_header.dart`
  - 为参数查询页头部补稳定 `ValueKey`
- `frontend/test/widgets/product_module_issue_regression_test.dart`
  - 不替换原有 issue 回归，只在必要时补少量与治理说明一致的防回退断言

## 任务 1：写治理说明文档

**Files:**
- Create: `docs/frontend/product-module-second-wave-guardrails.md`

- [ ] **Step 1: 创建治理说明文档，固定共识**

```md
# 产品模块第二波迁移治理说明

## 1. 固定页面模式

### 1.1 ProductVersionManagementPage
- 保持“产品选择面板 + 版本工作区”结构
- 左侧继续使用 `ProductSelectorPanel`
- 顶部继续使用 `ProductVersionPageHeader`
- 工作区继续保留 `ProductVersionFeedbackBanner`、`ProductVersionToolbar`、`ProductVersionTableSection`

### 1.2 ProductManagementPage
- 保持 `MesCrudPageScaffold`
- 主页面继续保留 `ProductManagementPageHeader`、`ProductManagementFilterSection`、`ProductManagementFeedbackBanner`、`ProductManagementTableSection`
- 产品详情继续使用 `ProductDetailDrawer`
- 版本管理继续使用 `ProductVersionDialog`

### 1.3 ProductParameterManagementPage
- 列表态继续保持 `MesCrudPageScaffold`
- 列表态继续保留 `ProductParameterManagementPageHeader`、`ProductParameterManagementFilterSection`、`ProductParameterManagementFeedbackBanner`、`ProductParameterVersionTableSection`
- 编辑态继续保留 `ProductParameterEditorHeader`、`ProductParameterEditorToolbar`、`ProductParameterEditorTable`、`ProductParameterEditorFooter`
- 历史链路继续保留 `ProductParameterHistoryDialog` 和 `ProductParameterHistorySnapshotDialog`

### 1.4 ProductParameterQueryPage
- 列表态继续保持 `MesCrudPageScaffold`
- 列表态继续保留 `ProductParameterQueryPageHeader`、`ProductParameterQueryFilterSection`、`ProductParameterQueryFeedbackBanner`、`ProductParameterQueryTableSection`
- 参数查看继续使用 `ProductParameterQueryDialog`
- 弹窗顶部继续保留 `ProductParameterSummaryHeader`

## 2. 禁止回退清单

1. 不允许把 `MesCrudPageScaffold` 改回手工 `Padding + Column + Row` 拼装。
2. 不允许把独立的详情侧栏、版本弹窗、历史弹窗、查询弹窗重新塞回主页面大文件。
3. 不允许把 `ProductParameterQueryPage` 的查询回退到产品管理列表接口。
4. 不允许把 `ProductParameterManagementPage` 的版本绑定、历史绑定和保存绑定改回旧参数接口兜底。
5. 不允许把产品模块第二波迁移后的核心动作入口改散或移出既定工作区。

## 3. 后续改造 Checklist

1. 改产品页前先确认是否仍复用当前页面模式。
2. 改动后先检查稳定 `ValueKey` 和核心锚点是否仍存在。
3. 改动后必须运行：
   - `flutter test test/widgets/product_module_second_wave_guard_test.dart`
   - `flutter test test/widgets/product_module_issue_regression_test.dart`
4. 若改动涉及接口口径，先确认没有回退到旧接口。
```

- [ ] **Step 2: 扫描治理说明文档中的占位词**

Run: `rg -n "待定|占位|后续补充" docs/frontend/product-module-second-wave-guardrails.md`

Expected: 无匹配结果；命令退出码为 `1`

- [ ] **Step 3: 提交治理说明文档**

```bash
git add docs/frontend/product-module-second-wave-guardrails.md
git commit -m "补充产品模块防回退治理说明"
```

## 任务 2：建立 guard 测试文件并锁定版本页与产品页

**Files:**
- Create: `frontend/test/widgets/product_module_second_wave_guard_test.dart`
- Modify: `frontend/lib/features/product/presentation/widgets/product_version_page_header.dart`
- Modify: `frontend/lib/features/product/presentation/widgets/product_management_page_header.dart`

- [ ] **Step 1: 新建 guard 测试文件，先写版本页与产品页失败测试**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/foundation/mes_theme.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_list_detail_shell.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/presentation/product_management_page.dart';
import 'package:mes_client/features/product/presentation/product_page.dart';
import 'package:mes_client/features/product/presentation/product_parameter_management_page.dart';
import 'package:mes_client/features/product/presentation/product_parameter_query_page.dart';
import 'package:mes_client/features/product/presentation/product_version_management_page.dart';
import 'package:mes_client/features/product/services/product_service.dart';

final DateTime _fixedDate = DateTime.parse('2026-04-21T00:00:00Z');

AppSession _session() {
  return AppSession(baseUrl: '', accessToken: 'guard-token');
}

Widget _guardHost(Widget child) {
  return MaterialApp(
    theme: buildMesTheme(
      brightness: Brightness.light,
      visualDensity: VisualDensity.standard,
    ),
    home: Scaffold(body: SizedBox(width: 1600, height: 1200, child: child)),
  );
}

Finder _popupMenuButtonFinder() {
  return find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString().startsWith('PopupMenuButton'),
  );
}

Future<void> _openPopupMenu(WidgetTester tester, Finder finder) async {
  final dynamic state = tester.state(finder);
  state.showButtonMenu();
  await tester.pumpAndSettle();
}

ProductItem _buildProduct({
  required int id,
  required int currentVersion,
  required int effectiveVersion,
  String lifecycleStatus = 'active',
  String category = '贴片',
  String? inactiveReason,
}) {
  return ProductItem(
    id: id,
    name: '产品$id',
    category: category,
    remark: '',
    lifecycleStatus: lifecycleStatus,
    currentVersion: currentVersion,
    currentVersionLabel: 'V1.${currentVersion - 1}',
    effectiveVersion: effectiveVersion,
    effectiveVersionLabel: effectiveVersion > 0
        ? 'V1.${effectiveVersion - 1}'
        : null,
    effectiveAt: effectiveVersion > 0 ? _fixedDate : null,
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
    effectiveAt: lifecycleStatus == 'effective' ? _fixedDate : null,
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
    createdAt: _fixedDate,
    parameterSummary: '当前版本参数摘要',
    parameterCount: 8,
    matchedParameterName: '产品芯片',
    matchedParameterCategory: '基础参数',
    lastModifiedParameter: '产品芯片',
    lastModifiedParameterCategory: '基础参数',
    updatedAt: _fixedDate,
  );
}

class _VersionGuardService extends ProductService {
  _VersionGuardService({required this.products, required this.versions})
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

class _ProductGuardService extends ProductService {
  _ProductGuardService({required this.products, required this.versions})
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
  Future<ProductDetailResult> getProductDetail({required int productId}) async {
    final product = products.single;
    return ProductDetailResult(
      product: product,
      detailParameters: ProductParameterListResult(
        productId: product.id,
        productName: product.name,
        parameterScope: 'version',
        version: 2,
        versionLabel: 'V1.1',
        lifecycleStatus: 'draft',
        total: 1,
        items: [
          ProductParameterItem(
            name: '产品芯片',
            category: '基础参数',
            type: 'Text',
            value: 'CHIP-X',
            description: '详情聚合',
            sortOrder: 1,
            isPreset: false,
          ),
        ],
      ),
      detailParameterMessage: '当前无生效版本，详情已回退展示当前版本参数快照。',
      latestVersionChangedAt: _fixedDate,
      versionTotal: versions.length,
      versions: versions,
      historyTotal: 1,
      historyItems: [
        ProductParameterHistoryItem(
          id: 1,
          productName: product.name,
          productCategory: '贴片',
          version: 2,
          versionLabel: 'V1.1',
          remark: '参数调整',
          changeReason: '参数调整',
          changeType: 'edit',
          parameterName: '产品芯片',
          changedKeys: const ['产品芯片'],
          operatorUsername: 'admin',
          beforeSummary: null,
          afterSummary: null,
          beforeSnapshot: '{}',
          afterSnapshot: '{}',
          createdAt: _fixedDate,
        ),
      ],
      relatedInfoSections: const [],
    );
  }

  @override
  Future<ProductVersionListResult> listProductVersions({
    required int productId,
  }) async {
    return ProductVersionListResult(total: versions.length, items: versions);
  }
}

class _ParameterManagementGuardService extends ProductService {
  _ParameterManagementGuardService(this.rows) : super(_session());

  final List<ProductParameterVersionListItem> rows;

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
    return ProductParameterVersionListResult(total: rows.length, items: rows);
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
      versionLabel: version == null ? null : 'V1.${version - 1}',
      lifecycleStatus: 'draft',
      total: 1,
      items: [
        ProductParameterHistoryItem(
          id: 11,
          productName: '产品$productId',
          productCategory: '贴片',
          version: version,
          versionLabel: version == null ? null : 'V1.${version - 1}',
          remark: '调整芯片参数',
          changeReason: '调整芯片参数',
          changeType: 'edit',
          parameterName: '产品芯片',
          changedKeys: const ['产品芯片'],
          operatorUsername: 'admin',
          beforeSummary: '旧值',
          afterSummary: '新值',
          beforeSnapshot: '{"before":true}',
          afterSnapshot: '{"after":true}',
          createdAt: _fixedDate,
        ),
      ],
    );
  }
}

class _ParameterQueryGuardService extends ProductService {
  _ParameterQueryGuardService(this.products) : super(_session());

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
    throw ApiException('参数查询 guard 测试不应回退产品管理列表接口', 500);
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

  @override
  Future<ProductParameterListResult> listProductParameters({
    required int productId,
    int? version,
    bool effectiveOnly = false,
  }) async {
    final product = products.firstWhere((item) => item.id == productId);
    return ProductParameterListResult(
      productId: product.id,
      productName: product.name,
      parameterScope: 'effective',
      version: product.effectiveVersion,
      versionLabel: product.effectiveVersionLabel ?? 'V1.${product.effectiveVersion - 1}',
      lifecycleStatus: 'effective',
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
    );
  }
}

void main() {
  group('Product module second-wave guard rails', () {
    testWidgets('产品版本管理页保留第二波工作区结构和核心动作入口', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _VersionGuardService(
        products: [
          _buildProduct(id: 61, currentVersion: 2, effectiveVersion: 1),
        ],
        versions: [
          _buildVersion(
            version: 2,
            versionLabel: 'V1.1',
            lifecycleStatus: 'draft',
          ),
          _buildVersion(
            version: 1,
            versionLabel: 'V1.0',
            lifecycleStatus: 'effective',
          ),
        ],
      );

      await tester.pumpWidget(
        _guardHost(
          ProductVersionManagementPage(
            session: _session(),
            onLogout: () {},
            tabCode: productVersionManagementTabCode,
            canManageVersions: true,
            canActivateVersions: true,
            canExportVersionParameters: true,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MesListDetailShell), findsOneWidget);
      expect(
        find.byKey(const ValueKey('product-version-page-header')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('product-selector-panel')), findsOneWidget);

      await tester.tap(find.text('产品61'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('product-version-feedback-banner')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('product-version-toolbar')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('product-version-table-section')),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, '复制版本'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '导出参数'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '编辑版本说明'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '立即生效'), findsOneWidget);
    });

    testWidgets('产品管理页保留第二波列表骨架 详情侧栏和版本弹窗入口', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _ProductGuardService(
        products: [
          _buildProduct(id: 71, currentVersion: 2, effectiveVersion: 1),
        ],
        versions: [
          _buildVersion(
            version: 2,
            versionLabel: 'V1.1',
            lifecycleStatus: 'draft',
          ),
          _buildVersion(
            version: 1,
            versionLabel: 'V1.0',
            lifecycleStatus: 'effective',
          ),
        ],
      );

      await tester.pumpWidget(
        _guardHost(
          ProductManagementPage(
            session: _session(),
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
      );
      await tester.pumpAndSettle();

      expect(find.byType(MesCrudPageScaffold), findsOneWidget);
      expect(
        find.byKey(const ValueKey('product-management-page-header')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('product-management-filter-section')), findsOneWidget);
      expect(find.byKey(const ValueKey('product-management-table-section')), findsOneWidget);

      await _openPopupMenu(tester, _popupMenuButtonFinder().first);
      await tester.tap(find.text('版本管理'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('product-version-dialog')), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '关闭'));
      await tester.pumpAndSettle();

      await _openPopupMenu(tester, _popupMenuButtonFinder().first);
      await tester.tap(find.text('查看详情'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('product-detail-drawer')), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: 运行两个 guard 测试，确认因头部锚点缺失而失败**

Run: `flutter test test/widgets/product_module_second_wave_guard_test.dart --plain-name "产品版本管理页保留第二波工作区结构和核心动作入口"`

Expected: FAIL，找不到 `product-version-page-header`

Run: `flutter test test/widgets/product_module_second_wave_guard_test.dart --plain-name "产品管理页保留第二波列表骨架 详情侧栏和版本弹窗入口"`

Expected: FAIL，找不到 `product-management-page-header`

- [ ] **Step 3: 为版本页和产品页头部补稳定锚点**

```dart
// frontend/lib/features/product/presentation/widgets/product_version_page_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class ProductVersionPageHeader extends StatelessWidget {
  const ProductVersionPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
  });

  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-version-page-header'),
      child: MesPageHeader(
        title: '版本管理',
        subtitle: '左侧选择产品，右侧查看版本工作区与参数动作。',
        actions: [
          FilledButton.tonalIcon(
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新页面'),
          ),
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/features/product/presentation/widgets/product_management_page_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class ProductManagementPageHeader extends StatelessWidget {
  const ProductManagementPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
  });

  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-management-page-header'),
      child: MesPageHeader(
        title: '产品管理',
        subtitle: '统一管理产品筛选、列表、详情和版本工作区入口。',
        actions: [
          FilledButton.tonalIcon(
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新页面'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 重新运行两个 guard 测试，确认版本页和产品页门禁转绿**

Run: `flutter test test/widgets/product_module_second_wave_guard_test.dart --plain-name "产品版本管理页保留第二波工作区结构和核心动作入口"`

Expected: PASS

Run: `flutter test test/widgets/product_module_second_wave_guard_test.dart --plain-name "产品管理页保留第二波列表骨架 详情侧栏和版本弹窗入口"`

Expected: PASS

- [ ] **Step 5: 提交版本页和产品页 guard 门禁**

```bash
git add frontend/test/widgets/product_module_second_wave_guard_test.dart frontend/lib/features/product/presentation/widgets/product_version_page_header.dart frontend/lib/features/product/presentation/widgets/product_management_page_header.dart
git commit -m "增加产品模块治理基础门禁"
```

## 任务 3：扩展 guard 测试并锁定参数管理页与参数查询页

**Files:**
- Modify: `frontend/test/widgets/product_module_second_wave_guard_test.dart`
- Modify: `frontend/lib/features/product/presentation/widgets/product_parameter_management_page_header.dart`
- Modify: `frontend/lib/features/product/presentation/widgets/product_parameter_query_page_header.dart`

- [ ] **Step 1: 追加参数管理页和参数查询页 guard 测试**

```dart
// frontend/test/widgets/product_module_second_wave_guard_test.dart
    testWidgets('产品参数管理页保留第二波列表 编辑和历史结构', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _ParameterManagementGuardService([
        _buildParameterVersionRow(
          productId: 81,
          productName: '产品81',
          version: 1,
          versionLabel: 'V1.0',
          lifecycleStatus: 'effective',
          isEffectiveVersion: true,
        ),
        _buildParameterVersionRow(
          productId: 81,
          productName: '产品81',
          version: 2,
          versionLabel: 'V1.1',
          lifecycleStatus: 'draft',
          isCurrentVersion: true,
        ),
      ]);

      await tester.pumpWidget(
        _guardHost(
          ProductParameterManagementPage(
            session: _session(),
            onLogout: () {},
            tabCode: 'product-parameter-management',
            service: service,
            canExportParameters: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('product-parameter-management-page-header')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('product-parameter-filter-section')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('product-parameter-version-table-section')),
        findsOneWidget,
      );

      await _openPopupMenu(tester, _popupMenuButtonFinder().first);
      await tester.tap(find.text('查看历史'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('product-parameter-history-dialog')), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, '关闭'));
      await tester.pumpAndSettle();

      await _openPopupMenu(tester, _popupMenuButtonFinder().at(1));
      await tester.tap(find.text('编辑参数'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('product-parameter-editor-header')), findsOneWidget);
      expect(find.byKey(const ValueKey('product-parameter-editor-toolbar')), findsOneWidget);
      expect(find.byKey(const ValueKey('product-parameter-editor-table')), findsOneWidget);
      expect(find.byKey(const ValueKey('product-parameter-editor-footer')), findsOneWidget);
    });

    testWidgets('产品参数查询页保留第二波查询骨架与参数弹窗摘要结构', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = _ParameterQueryGuardService([
        _buildProduct(id: 91, currentVersion: 2, effectiveVersion: 1),
      ]);

      await tester.pumpWidget(
        _guardHost(
          ProductParameterQueryPage(
            session: _session(),
            onLogout: () {},
            tabCode: productParameterQueryTabCode,
            service: service,
            canExportParameters: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('product-parameter-query-page-header')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('product-parameter-query-filter-section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('product-parameter-query-table-section')),
        findsOneWidget,
      );
      expect(service.queryCalls, 1);

      await tester.tap(find.widgetWithText(TextButton, '查看参数'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('product-parameter-query-dialog')), findsOneWidget);
      expect(find.byKey(const ValueKey('product-parameter-summary-header')), findsOneWidget);
      expect(find.text('仅展示当前生效版本参数'), findsOneWidget);
    });
```

- [ ] **Step 2: 运行两个新增 guard 测试，确认因参数页头部锚点缺失而失败**

Run: `flutter test test/widgets/product_module_second_wave_guard_test.dart --plain-name "产品参数管理页保留第二波列表 编辑和历史结构"`

Expected: FAIL，找不到 `product-parameter-management-page-header`

Run: `flutter test test/widgets/product_module_second_wave_guard_test.dart --plain-name "产品参数查询页保留第二波查询骨架与参数弹窗摘要结构"`

Expected: FAIL，找不到 `product-parameter-query-page-header`

- [ ] **Step 3: 为参数管理页和参数查询页头部补稳定锚点**

```dart
// frontend/lib/features/product/presentation/widgets/product_parameter_management_page_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class ProductParameterManagementPageHeader extends StatelessWidget {
  const ProductParameterManagementPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
  });

  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-parameter-management-page-header'),
      child: MesPageHeader(
        title: '版本参数管理',
        subtitle: '按版本查看、编辑和导出产品参数。',
        actions: [
          FilledButton.tonalIcon(
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新页面'),
          ),
        ],
      ),
    );
  }
}
```

```dart
// frontend/lib/features/product/presentation/widgets/product_parameter_query_page_header.dart
import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';

class ProductParameterQueryPageHeader extends StatelessWidget {
  const ProductParameterQueryPageHeader({
    super.key,
    required this.loading,
    required this.onRefresh,
  });

  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-parameter-query-page-header'),
      child: MesPageHeader(
        title: '产品参数查询',
        subtitle: '按启用且已有生效版本的产品查看当前生效参数。',
        actions: [
          FilledButton.tonalIcon(
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新页面'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 重新运行参数页 guard 测试，并补跑两条既有 issue 回归**

Run: `flutter test test/widgets/product_module_second_wave_guard_test.dart --plain-name "产品参数管理页保留第二波列表 编辑和历史结构"`

Expected: PASS

Run: `flutter test test/widgets/product_module_second_wave_guard_test.dart --plain-name "产品参数查询页保留第二波查询骨架与参数弹窗摘要结构"`

Expected: PASS

Run: `flutter test test/widgets/product_module_issue_regression_test.dart --plain-name "参数管理页首屏应展示版本行且操作绑定对应版本"`

Expected: PASS

Run: `flutter test test/widgets/product_module_issue_regression_test.dart --plain-name "参数查询页应支持弹窗 Link 打开 导出与跳转后查看"`

Expected: PASS

- [ ] **Step 5: 提交参数页 guard 门禁**

```bash
git add frontend/test/widgets/product_module_second_wave_guard_test.dart frontend/lib/features/product/presentation/widgets/product_parameter_management_page_header.dart frontend/lib/features/product/presentation/widgets/product_parameter_query_page_header.dart
git commit -m "补齐产品模块参数页治理门禁"
```

## 任务 4：最终验证与实施留痕

**Files:**
- Create: `evidence/2026-04-21_产品模块防回退治理实施.md`

- [ ] **Step 1: 创建实施 evidence 主日志**

```md
# 任务日志：产品模块防回退治理实施

- 日期：2026-04-21
- 执行人：Codex
- 当前状态：已完成

## 1. 输入来源
- 用户指令：
  - 在完成产品模块第二波迁移后，先做产品模块防回退治理
- 设计规格：
  - `docs/superpowers/specs/2026-04-21-product-module-second-wave-guardrails-design.md`
- 实施计划：
  - `docs/superpowers/plans/2026-04-21-product-module-second-wave-guardrails-implementation.md`

## 2. 实施分段
- 任务 1：写治理说明文档
- 任务 2：建立 guard 测试并锁定版本页与产品页
- 任务 3：扩展 guard 测试并锁定参数管理页与参数查询页
- 任务 4：最终验证与实施留痕

## 3. 验证结果
- `flutter analyze`：通过
- `flutter test test/widgets/product_module_second_wave_guard_test.dart`：通过
- `flutter test test/widgets/product_module_issue_regression_test.dart`：通过

## 4. 风险与补偿
- 本轮未新增独立 `integration_test`，因为治理目标是结构门禁而非新功能链路
- 若后续 guard 测试需要更多稳定锚点，仅允许补少量 `ValueKey` 或少量文案锚点，不允许扩大到页面重构

## 5. 迁移说明
- 无迁移，直接替换
```

- [ ] **Step 2: 运行最终验证**

Run: `flutter analyze`

Expected: `No issues found!`

Run: `flutter test test/widgets/product_module_second_wave_guard_test.dart`

Expected: PASS

Run: `flutter test test/widgets/product_module_issue_regression_test.dart`

Expected: PASS

- [ ] **Step 3: 提交最终治理结果**

```bash
git add docs/frontend/product-module-second-wave-guardrails.md frontend/test/widgets/product_module_second_wave_guard_test.dart frontend/lib/features/product/presentation/widgets/product_version_page_header.dart frontend/lib/features/product/presentation/widgets/product_management_page_header.dart frontend/lib/features/product/presentation/widgets/product_parameter_management_page_header.dart frontend/lib/features/product/presentation/widgets/product_parameter_query_page_header.dart evidence/2026-04-21_产品模块防回退治理实施.md
git commit -m "完成产品模块防回退治理"
```
