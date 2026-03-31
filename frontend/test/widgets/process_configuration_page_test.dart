import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/craft_models.dart';
import 'package:mes_client/models/production_models.dart';
import 'package:mes_client/pages/process_configuration_page.dart';
import 'package:mes_client/services/craft_service.dart';
import 'package:mes_client/services/production_service.dart';

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
  final List<int> archivedTemplateIds = [];
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
  Future<CraftTemplateVersionCompareResult> compareTemplateVersions({
    required int templateId,
    required int fromVersion,
    required int toVersion,
  }) async {
    return CraftTemplateVersionCompareResult(
      fromVersion: fromVersion,
      toVersion: toVersion,
      addedSteps: 0,
      removedSteps: 0,
      changedSteps: 0,
      items: const [],
    );
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
  Future<CraftTemplateDetail> archiveTemplate({required int templateId}) async {
    archivedTemplateIds.add(templateId);
    return CraftTemplateDetail(template: templates.first, steps: const []);
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
  _FakeProductionService() : super(AppSession(baseUrl: '', accessToken: ''));

  @override
  Future<List<ProductionProductOption>> listProductOptions() async {
    return [ProductionProductOption(id: 1, name: '产品A')];
  }
}

void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    _FakeCraftService? craftService,
    CraftSystemMasterTemplateItem? systemMasterTemplate,
    List<CraftTemplateItem> templates = const [],
    Map<int, List<CraftTemplateVersionItem>> templateVersions = const {},
    CraftSystemMasterTemplateVersionListResult? systemMasterTemplateVersions,
    int? templateId,
    int? version,
    bool systemMasterVersions = false,
    int jumpRequestId = 0,
  }) async {
    tester.view.physicalSize = const Size(1920, 2200);
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
            productionService: _FakeProductionService(),
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

  CraftTemplateItem buildTemplate({required int id, required int version}) {
    final now = DateTime.parse('2026-03-02T00:00:00Z');
    return CraftTemplateItem(
      id: id,
      productId: 1,
      productName: '产品A',
      productCategory: '标准件',
      templateName: '切割模板$id',
      version: version,
      lifecycleStatus: 'published',
      publishedVersion: version,
      isDefault: true,
      isEnabled: true,
      createdByUserId: 9,
      createdByUsername: 'planner',
      updatedByUserId: 9,
      updatedByUsername: 'planner',
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('已配置系统母版时默认展示摘要并提供管理入口', (tester) async {
    await pumpPage(
      tester,
      systemMasterTemplate: CraftSystemMasterTemplateItem(
        id: 1,
        version: 3,
        createdByUserId: 9,
        createdByUsername: 'planner',
        updatedByUserId: 9,
        updatedByUsername: 'planner',
        createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
        updatedAt: DateTime.parse('2026-03-02T00:00:00Z'),
        steps: [
          CraftSystemMasterTemplateStepItem(
            id: 101,
            stepOrder: 1,
            stageId: 1,
            stageCode: 'CUT',
            stageName: '切割段',
            processId: 11,
            processCode: 'CUT-01',
            processName: '激光切割',
            isKeyProcess: true,
            createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
            updatedAt: DateTime.parse('2026-03-02T00:00:00Z'),
          ),
        ],
      ),
    );

    expect(find.text('系统母版管理'), findsOneWidget);
    expect(find.text('系统默认工序母版已配置，可按需查看步骤、历史版本与维护入口。'), findsOneWidget);
    expect(find.text('CUT 切割段'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('无系统母版时主页面安全降级', (tester) async {
    await pumpPage(tester);

    expect(find.text('系统母版管理'), findsOneWidget);
    expect(find.text('系统母版步骤'), findsOneWidget);
    expect(find.text('暂无系统母版步骤'), findsOneWidget);
    expect(find.text('未配置'), findsWidgets);
  });

  testWidgets('接收模板跳转参数后定位到目标模板', (tester) async {
    await pumpPage(
      tester,
      templates: [buildTemplate(id: 18, version: 5)],
      templateId: 18,
      jumpRequestId: 1,
    );

    expect(find.textContaining('已定位模板 #18 切割模板18'), findsOneWidget);
    expect(find.text('查看详情'), findsOneWidget);
  });

  testWidgets('接收模板版本跳转参数后自动打开版本视图', (tester) async {
    await pumpPage(
      tester,
      templates: [buildTemplate(id: 18, version: 5)],
      templateVersions: {
        18: [
          CraftTemplateVersionItem(
            version: 5,
            action: 'publish',
            recordType: 'publish',
            recordTitle: '发布记录 P5',
            recordSummary: '草稿经发布门禁确认后成为当前生效版本',
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
            recordSummary: '草稿经发布门禁确认后成为当前生效版本',
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

  testWidgets('接收系统母版历史版本跳转参数后自动打开历史版本视图', (tester) async {
    await pumpPage(
      tester,
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
                isKeyProcess: false,
                createdAt: DateTime.parse('2026-03-02T00:00:00Z'),
                updatedAt: DateTime.parse('2026-03-02T00:00:00Z'),
              ),
            ],
          ),
        ],
      ),
      systemMasterVersions: true,
      jumpRequestId: 3,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('系统母版历史版本'), findsOneWidget);
    expect(find.text('v2 · publish'), findsOneWidget);
  });

  testWidgets('回滚弹窗切换目标版本时刷新专属预览', (tester) async {
    final craftService = _FakeCraftService(
      templates: [buildTemplate(id: 18, version: 5)],
      templateVersions: {
        18: [
          CraftTemplateVersionItem(
            version: 5,
            action: 'publish',
            recordType: 'publish',
            recordTitle: '发布记录 P5',
            recordSummary: '草稿经发布门禁确认后成为当前生效版本',
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
            recordSummary: '草稿经发布门禁确认后成为当前生效版本',
            note: '可回滚版本',
            sourceVersion: 3,
            createdByUserId: 9,
            createdByUsername: 'planner',
            createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          ),
        ],
      },
      templateImpactByVersion: {
        5: CraftTemplateImpactAnalysis(
          targetVersion: 5,
          totalOrders: 3,
          pendingOrders: 2,
          inProgressOrders: 1,
          syncableOrders: 3,
          blockedOrders: 0,
          totalReferences: 0,
          userStageReferenceCount: 0,
          templateReuseReferenceCount: 0,
          items: [
            CraftTemplateImpactOrderItem(
              orderId: 1001,
              orderCode: 'MO-1001',
              orderStatus: 'pending',
              syncable: true,
              reason: null,
            ),
          ],
          referenceItems: const [],
        ),
        4: CraftTemplateImpactAnalysis(
          targetVersion: 4,
          totalOrders: 1,
          pendingOrders: 0,
          inProgressOrders: 1,
          syncableOrders: 0,
          blockedOrders: 1,
          totalReferences: 2,
          userStageReferenceCount: 1,
          templateReuseReferenceCount: 1,
          items: [
            CraftTemplateImpactOrderItem(
              orderId: 1002,
              orderCode: 'MO-1002',
              orderStatus: 'in_progress',
              syncable: false,
              reason: '当前工序无法对齐目标版本',
            ),
          ],
          referenceItems: [
            CraftTemplateImpactReferenceItem(
              refType: 'user_stage',
              refId: 31,
              refCode: 'operator_a',
              refName: '操作员A',
              detail: '工段：CUT 切割段',
              refStatus: '正在使用',
              jumpModule: 'user',
              jumpTarget: 'user-management?user_id=31',
              riskLevel: 'medium',
              riskNote: '需确认用户工段分配',
            ),
            CraftTemplateImpactReferenceItem(
              refType: 'template_reuse',
              refId: 32,
              refCode: 'TMP-32',
              refName: '复用模板32',
              detail: '复用到 产品B · published',
              refStatus: '正在使用',
              jumpModule: 'craft',
              jumpTarget: 'process-configuration?template_id=32',
              riskLevel: 'medium',
              riskNote: '需确认复用模板联动',
            ),
          ],
        ),
      },
    );

    await pumpPage(
      tester,
      craftService: craftService,
      templateId: 18,
      version: 4,
      jumpRequestId: 4,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.widgetWithText(FilledButton, '回滚').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('当前预览版本：v5'), findsOneWidget);
    expect(find.text('总计 3'), findsOneWidget);
    expect(find.text('MO-1001'), findsOneWidget);

    await tester.tap(find.text('v5').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('v4').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('当前预览版本：v4'), findsOneWidget);
    expect(find.text('总计 1'), findsOneWidget);
    expect(find.text('MO-1002'), findsOneWidget);
    expect(find.text('关键引用对象'), findsOneWidget);
    expect(find.textContaining('operator_a 操作员A'), findsOneWidget);
    expect(find.textContaining('TMP-32 复用模板32'), findsOneWidget);
    expect(find.textContaining('当前工序无法对齐目标版本'), findsOneWidget);
    expect(craftService.requestedImpactVersions, containsAllInOrder([5, 4]));
  });

  testWidgets('主页面显式提供套版复制与导出版本参数入口', (tester) async {
    await pumpPage(
      tester,
      templates: [buildTemplate(id: 18, version: 5)],
      templateId: 18,
      jumpRequestId: 5,
    );

    expect(find.text('从系统母版套版'), findsAtLeastNWidgets(1));
    expect(find.text('从已有模板复制'), findsOneWidget);
    expect(find.text('导出版本参数'), findsOneWidget);
  });

  testWidgets('展开系统母版后页面仍可下滚且模板操作按钮可正常打开', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpPage(
      tester,
      systemMasterTemplate: CraftSystemMasterTemplateItem(
        id: 1,
        version: 3,
        createdByUserId: 9,
        createdByUsername: 'planner',
        updatedByUserId: 9,
        updatedByUsername: 'planner',
        createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
        updatedAt: DateTime.parse('2026-03-02T00:00:00Z'),
        steps: List.generate(
          12,
          (index) => CraftSystemMasterTemplateStepItem(
            id: index + 1,
            stepOrder: index + 1,
            stageId: 1,
            stageCode: 'CUT',
            stageName: '切割段',
            processId: 11,
            processCode: 'CUT-01',
            processName: '激光切割',
            isKeyProcess: index.isEven,
            createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
            updatedAt: DateTime.parse('2026-03-02T00:00:00Z'),
          ),
        ),
      ),
      templates: [buildTemplate(id: 18, version: 5)],
    );

    await tester.tap(find.text('系统母版管理'));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('模板工作区'),
      find.byType(SingleChildScrollView).first,
      const Offset(0, -300),
    );
    expect(find.text('模板工作区'), findsOneWidget);

    await tester.tap(find.text('操作').last);
    await tester.pumpAndSettle();

    expect(find.text('查看详情'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('系统母版展开后摘要区与步骤区构建稳定', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpPage(
      tester,
      systemMasterTemplate: CraftSystemMasterTemplateItem(
        id: 1,
        version: 3,
        createdByUserId: 9,
        createdByUsername: 'planner',
        updatedByUserId: 9,
        updatedByUsername: 'planner',
        createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
        updatedAt: DateTime.parse('2026-03-02T00:00:00Z'),
        steps: [
          CraftSystemMasterTemplateStepItem(
            id: 101,
            stepOrder: 1,
            stageId: 1,
            stageCode: 'CUT',
            stageName: '切割段',
            processId: 11,
            processCode: 'CUT-01',
            processName: '激光切割',
            isKeyProcess: true,
            createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
            updatedAt: DateTime.parse('2026-03-02T00:00:00Z'),
          ),
        ],
      ),
      templates: [buildTemplate(id: 18, version: 5)],
    );

    await tester.tap(find.text('系统母版管理'));
    await tester.pumpAndSettle();

    expect(find.text('系统母版管理'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('模板筛选区在窄一些的桌面宽度下不再溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1180, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpPage(tester, templates: [buildTemplate(id: 18, version: 5)]);

    await tester.dragUntilVisible(
      find.text('按生命周期筛选'),
      find.byType(SingleChildScrollView).first,
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();

    expect(find.text('默认模板筛选'), findsOneWidget);
    expect(find.text('启用状态筛选'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('模板筛选区在更窄桌面宽度下自动切换为双列或单列', (tester) async {
    await tester.binding.setSurfaceSize(const Size(920, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpPage(tester, templates: [buildTemplate(id: 18, version: 5)]);

    await tester.dragUntilVisible(
      find.text('按生命周期筛选'),
      find.byType(SingleChildScrollView).first,
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();

    expect(find.text('模板名称搜索'), findsOneWidget);
    expect(find.text('产品分类筛选'), findsOneWidget);
    expect(find.text('清空本地筛选'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('新建模板不再显示直接发布入口', (tester) async {
    await pumpPage(tester, templates: [buildTemplate(id: 18, version: 5)]);

    await tester.tap(find.widgetWithText(FilledButton, '新增模板'));
    await tester.pumpAndSettle();

    expect(find.text('新建后直接发布'), findsNothing);
    expect(find.textContaining('统一先保存为草稿'), findsOneWidget);
    expect(find.text('标准工时(分钟)'), findsNothing);
    expect(find.text('步骤说明'), findsNothing);
  });

  testWidgets('停用模板遇到阻断级引用时展示后端拦截状态', (tester) async {
    final craftService = _FakeCraftService(
      templates: [buildTemplate(id: 18, version: 5)],
      templateImpactByVersion: {
        null: CraftTemplateImpactAnalysis(
          targetVersion: 5,
          totalOrders: 1,
          pendingOrders: 0,
          inProgressOrders: 1,
          syncableOrders: 0,
          blockedOrders: 1,
          totalReferences: 1,
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
