import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/production/presentation/production_first_article_page.dart';
import 'package:mes_client/features/production/presentation/production_order_query_detail_page.dart';
import 'package:mes_client/features/production/presentation/production_order_query_page.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/production/services/production_service.dart';

String _extractColumnLabel(Widget widget) {
  if (widget is Text) {
    return widget.data ?? '';
  }
  if (widget is Align) {
    return _extractColumnLabel(widget.child!);
  }
  if (widget is Padding) {
    return _extractColumnLabel(widget.child!);
  }
  throw StateError('未识别的列表表头组件：${widget.runtimeType}');
}

class _FakeProductionOrderQueryPageService extends ProductionService {
  _FakeProductionOrderQueryPageService()
    : super(AppSession(baseUrl: '', accessToken: ''));

  String? lastKeyword;
  String lastOrderStatus = 'all';
  String lastExportViewMode = 'own';
  String lastExportOrderStatus = 'all';
  int exportCallCount = 0;
  int? lastExportProxyOperatorUserId;
  int? lastExportCurrentProcessId;
  final List<int> requestedPages = <int>[];
  final List<int> proxyStageFilterRequests = <int>[];
  int endProductionCallCount = 0;
  int manualRepairCallCount = 0;
  int assistAuthorizationCallCount = 0;
  int? lastEndProductionQuantity;
  List<ProductionDefectItemInput> lastEndProductionDefects = const [];
  int? lastManualRepairProductionQuantity;
  List<ProductionDefectItemInput> lastManualRepairDefects = const [];
  int? lastTargetOperatorUserId;
  int? lastHelperUserId;
  String? lastAssistReason;

  @override
  Future<MyOrderListResult> listMyOrders({
    required int page,
    required int pageSize,
    String? keyword,
    String? viewMode,
    int? proxyOperatorUserId,
    String? orderStatus,
    int? currentProcessId,
  }) async {
    requestedPages.add(page);
    lastKeyword = keyword;
    lastOrderStatus = orderStatus ?? 'all';
    return MyOrderListResult(
      total: 401,
      items: [
        MyOrderItem(
          orderId: 1,
          orderCode: 'PO-QUERY-00$page',
          productId: 10,
          productName: '产线试产件$page',
          supplierName: null,
          quantity: 12,
          orderStatus: 'in_progress',
          currentProcessId: 21,
          currentStageId: 5,
          currentStageCode: 'CUT',
          currentStageName: '切割段',
          currentProcessCode: 'CUT-01',
          currentProcessName: '切割',
          currentProcessOrder: 1,
          processStatus: 'in_progress',
          visibleQuantity: 12,
          processCompletedQuantity: 4,
          userSubOrderId: 31,
          userAssignedQuantity: 12,
          userCompletedQuantity: 4,
          operatorUserId: 8,
          operatorUsername: 'zhangsan',
          workView: 'own',
          assistAuthorizationId: null,
          pipelineInstanceId: 301,
          pipelineInstanceNo: 'P1-31-1-PIPE0001',
          pipelineModeEnabled: true,
          pipelineStartAllowed: true,
          pipelineEndAllowed: true,
          maxProducibleQuantity: 8,
          canFirstArticle: true,
          canEndProduction: true,
          canApplyAssist: true,
          canCreateManualRepair: true,
          dueDate: DateTime.parse('2026-03-18T00:00:00Z'),
          remark: '',
          updatedAt: DateTime.parse('2026-03-01T08:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<ProductionExportResult> exportMyOrders({
    String? keyword,
    String viewMode = 'own',
    int? proxyOperatorUserId,
    String? orderStatus,
    int? currentProcessId,
  }) async {
    exportCallCount += 1;
    lastKeyword = keyword;
    lastExportViewMode = viewMode;
    lastExportProxyOperatorUserId = proxyOperatorUserId;
    lastExportOrderStatus = orderStatus ?? 'all';
    lastExportCurrentProcessId = currentProcessId;
    return ProductionExportResult(
      fileName: 'my-orders.csv',
      mimeType: 'text/csv',
      contentBase64: 'YWJj',
      exportedCount: 1,
    );
  }

  @override
  Future<AssistUserOptionListResult> listAssistUserOptions({
    required int page,
    required int pageSize,
    String? keyword,
    String? roleCode,
    int? stageId,
  }) async {
    if (roleCode == 'operator') {
      if (stageId != null) {
        proxyStageFilterRequests.add(stageId);
      }
      final items = switch (stageId) {
        1 => [
          AssistUserOptionItem(
            id: 101,
            username: 'stage1_operator',
            fullName: '一段操作员',
            roleCodes: const ['operator'],
          ),
        ],
        2 => [
          AssistUserOptionItem(
            id: 201,
            username: 'stage2_operator',
            fullName: '二段操作员',
            roleCodes: const ['operator'],
          ),
        ],
        _ => [
          AssistUserOptionItem(
            id: 101,
            username: 'stage1_operator',
            fullName: '一段操作员',
            roleCodes: const ['operator'],
          ),
          AssistUserOptionItem(
            id: 201,
            username: 'stage2_operator',
            fullName: '二段操作员',
            roleCodes: const ['operator'],
          ),
        ],
      };
      return AssistUserOptionListResult(total: items.length, items: items);
    }
    return AssistUserOptionListResult(
      total: 1,
      items: [
        AssistUserOptionItem(
          id: 301,
          username: 'helper_user',
          fullName: '代班人',
          roleCodes: const ['assist'],
        ),
      ],
    );
  }

  @override
  Future<FirstArticleTemplateListResult> listFirstArticleTemplates({
    required int orderId,
    required int orderProcessId,
  }) async {
    return FirstArticleTemplateListResult(
      total: 1,
      items: [
        FirstArticleTemplateItem(
          id: 1,
          productId: 10,
          processCode: 'CUT-01',
          templateName: '默认模板',
          checkContent: '模板内容',
          testValue: '9.86',
        ),
      ],
    );
  }

  @override
  Future<FirstArticleParticipantOptionListResult>
  listFirstArticleParticipantOptions({required int orderId}) async {
    return FirstArticleParticipantOptionListResult(
      total: 1,
      items: [
        FirstArticleParticipantOptionItem(
          id: 8,
          username: 'zhangsan',
          fullName: '张三',
        ),
      ],
    );
  }

  @override
  Future<FirstArticleParameterListResult> getFirstArticleParameters({
    required int orderId,
    required int orderProcessId,
  }) async {
    return FirstArticleParameterListResult(
      productId: 10,
      productName: '产线试产件',
      parameterScope: 'effective',
      version: 1,
      versionLabel: 'v1',
      lifecycleStatus: 'active',
      total: 1,
      items: [
        FirstArticleParameterItem(
          name: '长度',
          category: '尺寸',
          type: 'text',
          value: '10mm',
          description: '参数说明',
          sortOrder: 1,
          isPreset: true,
        ),
      ],
    );
  }

  @override
  Future<ProductionOrderDetail> getOrderDetail({required int orderId}) async {
    return ProductionOrderDetail.fromJson({
      'order': {
        'id': orderId,
        'order_code': 'PO-$orderId',
        'product_id': 10,
        'product_name': '产线试产件',
        'product_version': 1,
        'quantity': 12,
        'status': 'in_progress',
        'current_process_code': 'CUT-01',
        'current_process_name': '切割',
        'start_date': '2026-03-01',
        'due_date': '2026-03-18',
        'remark': '',
        'process_template_id': 1,
        'process_template_name': '默认模板',
        'process_template_version': 1,
        'pipeline_enabled': true,
        'pipeline_process_codes': [],
        'created_by_user_id': 1,
        'created_by_username': 'admin',
        'created_at': '2026-03-01T00:00:00Z',
        'updated_at': '2026-03-01T08:00:00Z',
      },
      'processes': [
        {
          'id': 11,
          'stage_id': 1,
          'stage_code': 'CUT',
          'stage_name': '切割段',
          'process_code': 'CUT-01',
          'process_name': '切割',
          'process_order': 1,
          'status': 'in_progress',
          'visible_quantity': 12,
          'completed_quantity': 4,
          'created_at': '2026-03-01T00:00:00Z',
          'updated_at': '2026-03-01T08:00:00Z',
        },
      ],
      'sub_orders': [
        {
          'id': 31,
          'order_process_id': 11,
          'process_code': 'CUT-01',
          'process_name': '切割',
          'operator_user_id': 8,
          'operator_username': 'zhangsan',
          'assigned_quantity': 12,
          'completed_quantity': 4,
          'status': 'in_progress',
          'is_visible': true,
          'created_at': '2026-03-01T00:00:00Z',
          'updated_at': '2026-03-01T08:00:00Z',
        },
      ],
      'records': [
        {
          'id': 41,
          'order_process_id': 11,
          'process_code': 'CUT-01',
          'process_name': '切割',
          'operator_user_id': 8,
          'operator_username': 'zhangsan',
          'production_quantity': 4,
          'record_type': 'production',
          'created_at': '2026-03-01T08:00:00Z',
        },
      ],
      'events': [
        {
          'id': 51,
          'event_type': 'created',
          'event_title': '创建订单',
          'event_detail': '订单已创建',
          'operator_user_id': 1,
          'operator_username': 'admin',
          'payload_json': '{}',
          'created_at': '2026-03-01T08:30:00Z',
        },
      ],
    });
  }

  @override
  Future<ProductionActionResult> endProduction({
    required int orderId,
    required int orderProcessId,
    int? pipelineInstanceId,
    required int quantity,
    String? remark,
    int? effectiveOperatorUserId,
    int? assistAuthorizationId,
    List<ProductionDefectItemInput>? defectItems,
  }) async {
    endProductionCallCount += 1;
    lastEndProductionQuantity = quantity;
    lastEndProductionDefects = defectItems ?? const [];
    return ProductionActionResult(
      orderId: orderId,
      status: 'completed',
      message: 'ok',
    );
  }

  @override
  Future<RepairOrderItem> createManualRepairOrder({
    required int orderId,
    required int orderProcessId,
    required int productionQuantity,
    required List<ProductionDefectItemInput> defectItems,
  }) async {
    manualRepairCallCount += 1;
    lastManualRepairProductionQuantity = productionQuantity;
    lastManualRepairDefects = defectItems;
    return RepairOrderItem.fromJson({
      'id': 501,
      'order_id': orderId,
      'order_code': 'PO-$orderId',
      'order_process_id': orderProcessId,
      'process_code': 'CUT-01',
      'process_name': '切割',
      'status': 'in_repair',
      'production_quantity': productionQuantity,
      'defect_quantity': defectItems.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      ),
      'operator_user_id': 8,
      'operator_username': 'zhangsan',
      'created_at': '2026-03-01T00:00:00Z',
      'updated_at': '2026-03-01T00:00:00Z',
    });
  }

  @override
  Future<AssistAuthorizationItem> createAssistAuthorization({
    required int orderId,
    required int orderProcessId,
    required int targetOperatorUserId,
    required int helperUserId,
    String? reason,
  }) async {
    assistAuthorizationCallCount += 1;
    lastTargetOperatorUserId = targetOperatorUserId;
    lastHelperUserId = helperUserId;
    lastAssistReason = reason;
    return AssistAuthorizationItem.fromJson({
      'id': 701,
      'order_id': orderId,
      'order_code': 'PO-$orderId',
      'order_process_id': orderProcessId,
      'process_code': 'CUT-01',
      'process_name': '切割',
      'requester_user_id': targetOperatorUserId,
      'requester_username': 'zhangsan',
      'helper_user_id': helperUserId,
      'helper_username': 'helper_user',
      'status': 'approved',
      'reason': reason,
      'review_remark': null,
      'created_at': '2026-03-01T00:00:00Z',
      'updated_at': '2026-03-01T00:00:00Z',
    });
  }
}

class _FakeCraftService extends CraftService {
  _FakeCraftService() : super(AppSession(baseUrl: '', accessToken: ''));

  @override
  Future<CraftStageLightListResult> listStageLightOptions({
    bool? enabled = true,
  }) async {
    return CraftStageLightListResult(
      total: 2,
      items: [
        CraftStageLightItem(
          id: 1,
          code: 'CUT',
          name: '切割段',
          sortOrder: 1,
          isEnabled: true,
        ),
        CraftStageLightItem(
          id: 2,
          code: 'POL',
          name: '抛光段',
          sortOrder: 2,
          isEnabled: true,
        ),
      ],
    );
  }
}

Finder _findDropdownByLabel(String labelText) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField &&
        widget.decoration.labelText == labelText,
  );
}

void main() {
  testWidgets('生产订单查询页支持 route payload 进入异常过滤态', (tester) async {
    final service = _FakeProductionOrderQueryPageService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionOrderQueryPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canFirstArticle: true,
            canEndProduction: true,
            canCreateManualRepairOrder: true,
            canCreateAssistAuthorization: true,
            canProxyView: false,
            canExportCsv: true,
            routePayloadJson: '{"dashboard_filter":"exception"}',
            service: service,
            pollInterval: Duration.zero,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(service.lastOrderStatus, 'in_progress');
  });

  testWidgets('订单查询页支持筛选并展示工单列表', (tester) async {
    final service = _FakeProductionOrderQueryPageService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionOrderQueryPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canFirstArticle: true,
            canEndProduction: true,
            canCreateManualRepairOrder: true,
            canCreateAssistAuthorization: true,
            canProxyView: false,
            canExportCsv: false,
            service: service,
            pollInterval: Duration.zero,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(const ValueKey('productionOrderQueryListCard')),
      findsOneWidget,
    );
    expect(find.text('生产订单查询'), findsOneWidget);
    expect(find.text('PO-QUERY-001'), findsOneWidget);
    expect(find.text('产线试产件1'), findsOneWidget);
    expect(find.text('切割'), findsOneWidget);
    expect(find.text('可见12 / 分配12 / 完成4'), findsOneWidget);
    expect(find.text('2026-03-18'), findsOneWidget);
    expect(find.text('-'), findsWidgets);
    expect(find.text('订单编号'), findsOneWidget);
    expect(find.text('产品型号'), findsOneWidget);
    expect(find.text('供应商'), findsOneWidget);
    expect(find.text('搜索订单号/产品/供应商/工序'), findsOneWidget);
    expect(find.text('数量概况'), findsOneWidget);
    expect(find.text('交货日期'), findsOneWidget);
    expect(find.text('备注'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);

    final dataTable = tester.widget<DataTable>(find.byType(DataTable));
    final columnLabels = dataTable.columns
        .map((column) => _extractColumnLabel(column.label))
        .toList();
    expect(
      columnLabels,
      equals(['订单编号', '产品型号', '供应商', '工序', '数量概况', '状态', '交货日期', '备注', '操作']),
    );

    await tester.enterText(find.byType(TextField).first, 'PO-QUERY');
    await tester.tap(find.widgetWithText(FilledButton, '查询'));
    await tester.pump();

    expect(service.lastKeyword, 'PO-QUERY');
    expect(service.requestedPages, [1, 1]);

    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, '全部'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('生产中').last);
    await tester.pump();

    expect(service.lastOrderStatus, 'in_progress');
  });

  testWidgets('订单查询页仅在具备权限时显示导出按钮', (tester) async {
    final service = _FakeProductionOrderQueryPageService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionOrderQueryPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canFirstArticle: true,
            canEndProduction: true,
            canCreateManualRepairOrder: true,
            canCreateAssistAuthorization: true,
            canProxyView: false,
            canExportCsv: false,
            service: service,
            pollInterval: Duration.zero,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.widgetWithText(FilledButton, '导出CSV'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionOrderQueryPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canFirstArticle: true,
            canEndProduction: true,
            canCreateManualRepairOrder: true,
            canCreateAssistAuthorization: true,
            canProxyView: false,
            canExportCsv: true,
            service: service,
            pollInterval: Duration.zero,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.widgetWithText(FilledButton, '导出CSV'), findsOneWidget);
  });

  testWidgets('订单查询页导出按钮触发导出主链路', (tester) async {
    final service = _FakeProductionOrderQueryPageService();
    String? savedFilename;
    String? savedContentBase64;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionOrderQueryPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canFirstArticle: true,
            canEndProduction: true,
            canCreateManualRepairOrder: true,
            canCreateAssistAuthorization: true,
            canProxyView: false,
            canExportCsv: true,
            service: service,
            saveExportFile:
                ({
                  required String filename,
                  required String contentBase64,
                }) async {
                  savedFilename = filename;
                  savedContentBase64 = contentBase64;
                  return 'C:/tmp/$filename';
                },
            pollInterval: Duration.zero,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField).first, 'PO-QUERY');
    await tester.tap(find.widgetWithText(FilledButton, '导出CSV'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(service.exportCallCount, 1);
    expect(service.lastKeyword, 'PO-QUERY');
    expect(service.lastExportViewMode, 'own');
    expect(service.lastExportOrderStatus, 'all');
    expect(savedFilename, 'my-orders.csv');
    expect(savedContentBase64, 'YWJj');
    expect(find.textContaining('导出成功（1 条）'), findsOneWidget);
  });

  testWidgets('订单查询页翻页请求生效且搜索会回到第一页', (tester) async {
    final service = _FakeProductionOrderQueryPageService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionOrderQueryPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canFirstArticle: true,
            canEndProduction: true,
            canCreateManualRepairOrder: true,
            canCreateAssistAuthorization: true,
            canProxyView: false,
            canExportCsv: false,
            service: service,
            pollInterval: Duration.zero,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('第 1 / 3 页'), findsOneWidget);
    expect(find.text('PO-QUERY-001'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '下一页'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(service.requestedPages, [1, 2]);
    expect(find.text('第 2 / 3 页'), findsOneWidget);
    expect(find.text('PO-QUERY-002'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'RESET');
    await tester.tap(find.widgetWithText(FilledButton, '查询'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(service.requestedPages, [1, 2, 1]);
    expect(service.lastKeyword, 'RESET');
    expect(find.text('第 1 / 3 页'), findsOneWidget);
    expect(find.text('PO-QUERY-001'), findsOneWidget);
  });

  testWidgets('订单查询页开始首件入口跳转到独立首件录入页', (tester) async {
    final service = _FakeProductionOrderQueryPageService();
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionOrderQueryPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canFirstArticle: true,
            canEndProduction: true,
            canCreateManualRepairOrder: true,
            canCreateAssistAuthorization: true,
            canProxyView: false,
            canExportCsv: false,
            service: service,
            pollInterval: Duration.zero,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.ensureVisible(find.byType(PopupMenuButton<String>));
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始首件').last);
    await tester.pumpAndSettle();

    expect(find.byType(ProductionFirstArticlePage), findsOneWidget);
    expect(find.textContaining('首件录入'), findsOneWidget);
    expect(find.text('默认模板'), findsNothing);
  });

  testWidgets('订单查询页操作菜单包含历史且可跳转到历史视图', (tester) async {
    final service = _FakeProductionOrderQueryPageService();
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionOrderQueryPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canFirstArticle: true,
            canEndProduction: true,
            canCreateManualRepairOrder: true,
            canCreateAssistAuthorization: true,
            canProxyView: false,
            canExportCsv: false,
            service: service,
            pollInterval: Duration.zero,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.ensureVisible(find.byType(PopupMenuButton<String>));
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('历史').last, findsOneWidget);

    await tester.tap(find.text('历史').last);
    await tester.pumpAndSettle();

    expect(find.byType(ProductionOrderQueryDetailPage), findsOneWidget);
    final historyTabContext = tester.element(find.byType(TabBar));
    expect(DefaultTabController.of(historyTabContext).index, 3);
    expect(find.text('创建订单'), findsOneWidget);
  });

  testWidgets('订单查询页详情入口仍默认打开首个详情标签', (tester) async {
    final service = _FakeProductionOrderQueryPageService();
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionOrderQueryPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canFirstArticle: true,
            canEndProduction: true,
            canCreateManualRepairOrder: true,
            canCreateAssistAuthorization: true,
            canProxyView: false,
            canExportCsv: false,
            service: service,
            pollInterval: Duration.zero,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.ensureVisible(find.byType(PopupMenuButton<String>));
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('详情').last);
    await tester.pumpAndSettle();

    expect(find.byType(ProductionOrderQueryDetailPage), findsOneWidget);
    final detailTabContext = tester.element(find.byType(TabBar));
    expect(DefaultTabController.of(detailTabContext).index, 0);
    expect(find.text('顺序'), findsOneWidget);
  });

  testWidgets('代理视角展示工段与操作员控件', (tester) async {
    final service = _FakeProductionOrderQueryPageService();
    final craftService = _FakeCraftService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionOrderQueryPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canFirstArticle: true,
            canEndProduction: true,
            canCreateManualRepairOrder: true,
            canCreateAssistAuthorization: true,
            canProxyView: true,
            canExportCsv: false,
            service: service,
            craftService: craftService,
            pollInterval: Duration.zero,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, '我的工单'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('代理操作员视角').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('代理工段'), findsOneWidget);
    expect(find.text('代理操作员'), findsOneWidget);
    expect(find.text('请先选择工段，再选择代理操作员查看工单'), findsOneWidget);
  });

  testWidgets('代理视角切换工段会重载操作员选项', (tester) async {
    final service = _FakeProductionOrderQueryPageService();
    final craftService = _FakeCraftService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionOrderQueryPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canFirstArticle: true,
            canEndProduction: true,
            canCreateManualRepairOrder: true,
            canCreateAssistAuthorization: true,
            canProxyView: true,
            canExportCsv: false,
            service: service,
            craftService: craftService,
            pollInterval: Duration.zero,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, '我的工单'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('代理操作员视角').last);
    await tester.pumpAndSettle();

    await tester.tap(_findDropdownByLabel('代理工段'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('切割段').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(_findDropdownByLabel('代理操作员'));
    await tester.pumpAndSettle();
    expect(find.text('stage1_operator (一段操作员)').last, findsOneWidget);
    await tester.tap(find.text('stage1_operator (一段操作员)').last);
    await tester.pumpAndSettle();

    await tester.tap(_findDropdownByLabel('代理工段'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('抛光段').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(service.proxyStageFilterRequests, [1, 2]);

    await tester.tap(_findDropdownByLabel('代理操作员'));
    await tester.pumpAndSettle();
    expect(find.text('stage2_operator (二段操作员)').last, findsOneWidget);
  });

  testWidgets('代理视角未选择操作员时显示提示且不误查列表', (tester) async {
    final service = _FakeProductionOrderQueryPageService();
    final craftService = _FakeCraftService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionOrderQueryPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canFirstArticle: true,
            canEndProduction: true,
            canCreateManualRepairOrder: true,
            canCreateAssistAuthorization: true,
            canProxyView: true,
            canExportCsv: false,
            service: service,
            craftService: craftService,
            pollInterval: Duration.zero,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(service.requestedPages, [1]);

    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, '我的工单'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('代理操作员视角').last);
    await tester.pumpAndSettle();

    await tester.tap(_findDropdownByLabel('代理工段'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('切割段').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('请先选择代理操作员后查看工单'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '查询'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(service.requestedPages, [1]);
    expect(find.text('请先选择代理操作员后查看工单'), findsOneWidget);
  });

  testWidgets('订单查询页结束生产提交主链路可用', (tester) async {
    final service = _FakeProductionOrderQueryPageService();
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionOrderQueryPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canFirstArticle: true,
            canEndProduction: true,
            canCreateManualRepairOrder: true,
            canCreateAssistAuthorization: true,
            canProxyView: false,
            canExportCsv: false,
            service: service,
            pollInterval: Duration.zero,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('结束生产').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '新增'));
    await tester.pumpAndSettle();
    final endFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(endFields.at(0), '3');
    await tester.enterText(endFields.at(1), '毛刺');
    await tester.enterText(endFields.at(2), '1');
    await tester.tap(find.widgetWithText(FilledButton, '提交'));
    await tester.pumpAndSettle();

    expect(service.endProductionCallCount, 1);
    expect(service.lastEndProductionQuantity, 3);
    expect(service.lastEndProductionDefects, hasLength(1));
    expect(service.lastEndProductionDefects.first.phenomenon, '毛刺');
    expect(find.text('结束生产成功'), findsOneWidget);
  });

  testWidgets('订单查询页手工送修建单主链路可用', (tester) async {
    final service = _FakeProductionOrderQueryPageService();
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionOrderQueryPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canFirstArticle: true,
            canEndProduction: true,
            canCreateManualRepairOrder: true,
            canCreateAssistAuthorization: true,
            canProxyView: false,
            canExportCsv: false,
            service: service,
            pollInterval: Duration.zero,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('送修').last);
    await tester.pumpAndSettle();
    final repairFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(repairFields.at(0), '4');
    await tester.enterText(repairFields.at(1), '裂纹');
    await tester.enterText(repairFields.at(2), '2');
    await tester.tap(find.widgetWithText(FilledButton, '提交建单'));
    await tester.pumpAndSettle();

    expect(service.manualRepairCallCount, 1);
    expect(service.lastManualRepairProductionQuantity, 4);
    expect(service.lastManualRepairDefects, hasLength(1));
    expect(service.lastManualRepairDefects.first.phenomenon, '裂纹');
  });

  testWidgets('订单查询页发起代班主链路可用', (tester) async {
    final service = _FakeProductionOrderQueryPageService();
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionOrderQueryPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canFirstArticle: true,
            canEndProduction: true,
            canCreateManualRepairOrder: true,
            canCreateAssistAuthorization: true,
            canProxyView: false,
            canExportCsv: false,
            service: service,
            pollInterval: Duration.zero,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('代班').last);
    await tester.pumpAndSettle();
    await tester.tap(_findDropdownByLabel('代班人'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('helper_user').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '代班原因（可选）'), '夜班支援');
    await tester.tap(find.widgetWithText(FilledButton, '发起代班'));
    await tester.pumpAndSettle();

    expect(service.assistAuthorizationCallCount, 1);
    expect(service.lastTargetOperatorUserId, 8);
    expect(service.lastHelperUserId, 301);
    expect(service.lastAssistReason, '夜班支援');
  });
}
