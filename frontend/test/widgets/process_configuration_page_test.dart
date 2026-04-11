import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/craft/presentation/process_configuration_page.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/production/services/production_service.dart';

class _FakeCraftService extends CraftService {
  _FakeCraftService({
    this.systemMasterTemplate,
    this.templates = const [],
    this.templateVersions = const {},
    this.systemMasterTemplateVersions,
    this.templateImpactByVersion = const {},
  }) : super(AppSession(baseUrl: '', accessToken: ''));

  final CraftSystemMasterTemplateItem? systemMasterTemplate;
  final List<CraftTemplateItem> templates;
  final Map<int, List<CraftTemplateVersionItem>> templateVersions;
  final CraftSystemMasterTemplateVersionListResult?
  systemMasterTemplateVersions;
  final Map<int?, CraftTemplateImpactAnalysis> templateImpactByVersion;
  final List<int?> requestedImpactVersions = [];
  final List<int> disabledTemplateIds = [];
  final List<int> deletedTemplateIds = [];

  @override
  Future<CraftStageListResult> listStages({
    int page = 1,
    int pageSize = 200,
    String? keyword,
    bool? enabled,
  }) async {
    return CraftStageListResult(
      total: 1,
      items: [
        CraftStageItem(
          id: 1,
          code: 'CUT',
          name: '切割段',
          sortOrder: 1,
          isEnabled: true,
          processCount: 1,
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<CraftProcessListResult> listProcesses({
    int page = 1,
    int pageSize = 500,
    String? keyword,
    int? stageId,
    bool? enabled,
  }) async {
    return CraftProcessListResult(
      total: 1,
      items: [
        CraftProcessItem(
          id: 11,
          code: 'CUT-01',
          name: '激光切割',
          stageId: 1,
          stageCode: 'CUT',
          stageName: '切割段',
          isEnabled: true,
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<CraftTemplateListResult> listTemplates({
    int page = 1,
    int pageSize = 500,
    int? productId,
    String? keyword,
    String? productCategory,
    bool? isDefault,
    bool? enabled = true,
    String? lifecycleStatus,
    DateTime? updatedFrom,
    DateTime? updatedTo,
  }) async {
    return CraftTemplateListResult(total: templates.length, items: templates);
  }

  @override
  Future<CraftSystemMasterTemplateItem?> getSystemMasterTemplate() async {
    return systemMasterTemplate;
  }

  @override
  Future<CraftTemplateVersionListResult> listTemplateVersions({
    required int templateId,
  }) async {
    final items = templateVersions[templateId] ?? const [];
    return CraftTemplateVersionListResult(total: items.length, items: items);
  }

  @override
  Future<CraftSystemMasterTemplateVersionListResult>
  listSystemMasterTemplateVersions() async {
    return systemMasterTemplateVersions ??
        CraftSystemMasterTemplateVersionListResult(total: 0, items: const []);
  }

  @override
  Future<CraftTemplateImpactAnalysis> getTemplateImpactAnalysis({
    required int templateId,
    int? targetVersion,
  }) async {
    requestedImpactVersions.add(targetVersion);
    return templateImpactByVersion[targetVersion] ??
        CraftTemplateImpactAnalysis(
          targetVersion: targetVersion ?? 0,
          totalOrders: 0,
          pendingOrders: 0,
          inProgressOrders: 0,
          syncableOrders: 0,
          blockedOrders: 0,
          totalReferences: 0,
          userStageReferenceCount: 0,
          templateReuseReferenceCount: 0,
          items: const [],
          referenceItems: const [],
        );
  }

  @override
  Future<CraftTemplateDetail> disableTemplate({required int templateId}) async {
    disabledTemplateIds.add(templateId);
    return CraftTemplateDetail(template: templates.first, steps: const []);
  }

  @override
  Future<void> deleteTemplate({required int templateId}) async {
    deletedTemplateIds.add(templateId);
  }
}

class _FakeProductionService extends ProductionService {
  _FakeProductionService(this.products)
    : super(AppSession(baseUrl: '', accessToken: ''));

  final List<ProductionProductOption> products;

  @override
  Future<List<ProductionProductOption>> listProductOptions() async {
    return products;
  }
}

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    _FakeCraftService? craftService,
    List<ProductionProductOption>? products,
    CraftSystemMasterTemplateItem? systemMasterTemplate,
    List<CraftTemplateItem> templates = const [],
    Map<int, List<CraftTemplateVersionItem>> templateVersions = const {},
    CraftSystemMasterTemplateVersionListResult? systemMasterTemplateVersions,
    int? templateId,
    int? version,
    bool systemMasterVersions = false,
    int jumpRequestId = 0,
  }) async {
    tester.view.physicalSize = const Size(1600, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProcessConfigurationPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canViewTemplates: true,
            canManageTemplates: true,
            canManageSystemMasterTemplate: true,
            craftService:
                craftService ??
                _FakeCraftService(
                  systemMasterTemplate: systemMasterTemplate,
                  templates: templates,
                  templateVersions: templateVersions,
                  systemMasterTemplateVersions: systemMasterTemplateVersions,
                ),
            productionService: _FakeProductionService(
              products ??
                  [
                    ProductionProductOption(id: 1, name: '产品A'),
                    ProductionProductOption(id: 2, name: '产品B'),
                  ],
            ),
            templateId: templateId,
            version: version,
            systemMasterVersions: systemMasterVersions,
            jumpRequestId: jumpRequestId,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  CraftTemplateItem buildTemplate({
    required int id,
    required int productId,
    required String productName,
    required String templateName,
    String productCategory = '标准件',
    String lifecycleStatus = 'published',
    bool enabled = true,
    bool isDefault = false,
    int version = 1,
  }) {
    final now = DateTime.parse('2026-03-02T00:00:00Z');
    return CraftTemplateItem(
      id: id,
      productId: productId,
      productName: productName,
      productCategory: productCategory,
      templateName: templateName,
      version: version,
      lifecycleStatus: lifecycleStatus,
      publishedVersion: version,
      isDefault: isDefault,
      isEnabled: enabled,
      createdByUserId: 9,
      createdByUsername: 'planner',
      updatedByUserId: 9,
      updatedByUsername: 'planner',
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('未选择产品时右侧展示空列表态', (tester) async {
    await pumpPage(
      tester,
      templates: [
        buildTemplate(
          id: 1,
          productId: 1,
          productName: '产品A',
          templateName: 'A-模板',
        ),
      ],
    );

    expect(find.text('产品列表'), findsOneWidget);
    expect(find.text('模板工作区'), findsOneWidget);
    expect(find.text('未选择产品，当前不展示模板列表。'), findsOneWidget);
    expect(find.text('A-模板'), findsNothing);
  });

  testWidgets('选择产品后仅展示当前产品模板并移除模板筛选区', (tester) async {
    await pumpPage(
      tester,
      templates: [
        buildTemplate(
          id: 1,
          productId: 1,
          productName: '产品A',
          templateName: 'A-模板',
          lifecycleStatus: 'draft',
          isDefault: true,
        ),
        buildTemplate(
          id: 2,
          productId: 2,
          productName: '产品B',
          templateName: 'B-模板',
          lifecycleStatus: 'archived',
        ),
      ],
    );

    await tester.tap(find.text('产品A').last);
    await tester.pumpAndSettle();

    expect(find.text('当前产品：产品A'), findsOneWidget);
    expect(find.text('A-模板'), findsOneWidget);
    expect(find.text('B-模板'), findsNothing);
    expect(find.text('新增模板'), findsOneWidget);
    expect(find.text('从系统母版套版'), findsOneWidget);
    expect(find.text('从已有模板复制'), findsNothing);
    expect(find.text('导出模板'), findsNothing);
    expect(find.text('导出版本参数'), findsNothing);
    expect(find.text('批量导入'), findsNothing);
    expect(find.text('模板筛选'), findsNothing);
    expect(find.text('生命周期筛选'), findsNothing);
    expect(find.text('启用状态筛选'), findsNothing);
    expect(find.text('产品分类筛选'), findsNothing);
    expect(find.text('模板名称搜索'), findsNothing);
  });

  testWidgets('产品列表展示默认模板配置状态点', (tester) async {
    await pumpPage(
      tester,
      templates: [
        buildTemplate(
          id: 1,
          productId: 1,
          productName: '产品A',
          templateName: 'A-默认模板',
          isDefault: true,
        ),
        buildTemplate(
          id: 2,
          productId: 2,
          productName: '产品B',
          templateName: 'B-普通模板',
          isDefault: false,
        ),
      ],
    );

    expect(find.text('已配置默认模板'), findsOneWidget);
    expect(find.text('未配置默认模板'), findsOneWidget);
  });

  testWidgets('产品列表为可滚动区域且仍可切换到后续产品', (tester) async {
    final products = List.generate(
      10,
      (index) => ProductionProductOption(
        id: index + 1,
        name: '产品${(index + 1).toString().padLeft(2, '0')}',
      ),
    );

    final templates = List.generate(
      10,
      (index) => buildTemplate(
        id: index + 1,
        productId: index + 1,
        productName: '产品${(index + 1).toString().padLeft(2, '0')}',
        templateName: '模板${(index + 1).toString().padLeft(2, '0')}',
      ),
    );

    await pumpPage(tester, products: products, templates: templates);

    final productList = find.byKey(
      const ValueKey('process-config-product-list-scroll'),
    );
    expect(productList, findsOneWidget);
    expect(find.text('产品10'), findsNothing);

    await tester.drag(productList, const Offset(0, -500));
    await tester.pumpAndSettle();

    await tester.tap(find.text('产品10').last);
    await tester.pumpAndSettle();

    expect(find.text('当前产品：产品10'), findsOneWidget);
    expect(find.text('模板10'), findsOneWidget);
    expect(find.text('模板01'), findsNothing);
  });

  testWidgets('模板操作菜单仅保留主链路入口', (tester) async {
    await pumpPage(
      tester,
      templates: [
        buildTemplate(
          id: 1,
          productId: 1,
          productName: '产品A',
          templateName: 'A-模板',
          lifecycleStatus: 'draft',
        ),
      ],
    );

    await tester.tap(find.text('产品A').last);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byWidgetPredicate((widget) => widget is PopupMenuButton).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('发布'), findsOneWidget);
    expect(find.text('查看详情'), findsOneWidget);
    expect(find.text('版本管理'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.text('复制（同产品）'), findsNothing);
    expect(find.text('跨产品复制'), findsNothing);
    expect(find.text('影响分析'), findsNothing);
    expect(find.text('版本对比'), findsNothing);
    expect(find.text('回滚模板'), findsNothing);
  });

  testWidgets('接收模板跳转参数后自动选中所属产品', (tester) async {
    await pumpPage(
      tester,
      templates: [
        buildTemplate(
          id: 18,
          productId: 1,
          productName: '产品A',
          templateName: '切割模板18',
          version: 5,
        ),
      ],
      templateId: 18,
      jumpRequestId: 1,
    );

    expect(find.textContaining('已定位模板 #18 切割模板18'), findsOneWidget);
    expect(find.text('当前产品：产品A'), findsOneWidget);
    expect(find.text('切割模板18'), findsOneWidget);
    expect(find.text('查看详情'), findsOneWidget);
  });

  testWidgets('接收模板版本跳转参数后自动打开版本管理', (tester) async {
    await pumpPage(
      tester,
      templates: [
        buildTemplate(
          id: 18,
          productId: 1,
          productName: '产品A',
          templateName: '切割模板18',
          version: 5,
        ),
      ],
      templateVersions: {
        18: [
          CraftTemplateVersionItem(
            version: 5,
            action: 'publish',
            recordType: 'publish',
            recordTitle: '发布记录 P5',
            recordSummary: '当前版本',
            note: '当前版本',
            sourceVersion: 4,
            createdByUserId: 9,
            createdByUsername: 'planner',
            createdAt: DateTime.parse('2026-03-02T00:00:00Z'),
          ),
          CraftTemplateVersionItem(
            version: 4,
            action: 'publish',
            recordType: 'publish',
            recordTitle: '发布记录 P4',
            recordSummary: '目标版本',
            note: '目标版本',
            sourceVersion: 3,
            createdByUserId: 9,
            createdByUsername: 'planner',
            createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          ),
        ],
      },
      templateId: 18,
      version: 4,
      jumpRequestId: 2,
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('版本管理 - 切割模板18'), findsOneWidget);
    expect(find.textContaining('已自动定位目标版本 v4'), findsOneWidget);
    expect(find.text('发布记录 P4 · 目标版本'), findsOneWidget);
  });

  testWidgets('系统母版历史版本跳转仍可用', (tester) async {
    await pumpPage(
      tester,
      systemMasterVersions: true,
      jumpRequestId: 3,
      systemMasterTemplateVersions: CraftSystemMasterTemplateVersionListResult(
        total: 1,
        items: [
          CraftSystemMasterTemplateVersionItem(
            version: 2,
            action: 'publish',
            note: '发布母版',
            createdByUserId: 9,
            createdByUsername: 'planner',
            createdAt: DateTime.parse('2026-03-02T00:00:00Z'),
            steps: [
              CraftSystemMasterTemplateVersionStepItem(
                id: 201,
                stepOrder: 1,
                stageId: 1,
                stageCode: 'CUT',
                stageName: '切割段',
                processId: 11,
                processCode: 'CUT-01',
                processName: '激光切割',
                createdAt: DateTime.parse('2026-03-02T00:00:00Z'),
                updatedAt: DateTime.parse('2026-03-02T00:00:00Z'),
              ),
            ],
          ),
        ],
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('系统母版历史版本'), findsOneWidget);
    expect(find.text('v2 · publish'), findsOneWidget);
  });

  testWidgets('停用模板遇到阻断级引用时禁止继续提交', (tester) async {
    final craftService = _FakeCraftService(
      templates: [
        buildTemplate(
          id: 18,
          productId: 1,
          productName: '产品A',
          templateName: '切割模板18',
        ),
      ],
      templateImpactByVersion: {
        null: CraftTemplateImpactAnalysis(
          targetVersion: 5,
          totalOrders: 1,
          pendingOrders: 0,
          inProgressOrders: 1,
          syncableOrders: 0,
          blockedOrders: 1,
          totalReferences: 0,
          userStageReferenceCount: 0,
          templateReuseReferenceCount: 0,
          items: [
            CraftTemplateImpactOrderItem(
              orderId: 1002,
              orderCode: 'MO-1002',
              orderStatus: 'in_progress',
              syncable: false,
              reason: '当前工序无法对齐目标版本',
            ),
          ],
          referenceItems: const [],
        ),
      },
    );

    await pumpPage(tester, craftService: craftService);
    await tester.tap(find.text('产品A').last);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byWidgetPredicate((widget) => widget is PopupMenuButton).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('停用').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('当前存在 1 条阻断级引用'), findsOneWidget);
    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '停用'),
    );
    expect(confirmButton.onPressed, isNull);
    expect(craftService.disabledTemplateIds, isEmpty);
  });
}
