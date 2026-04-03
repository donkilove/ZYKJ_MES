import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/production_models.dart';
import 'package:mes_client/pages/production_first_article_page.dart';
import 'package:mes_client/pages/production_order_query_page.dart';
import 'package:mes_client/services/production_service.dart';

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
    lastKeyword = keyword;
    lastOrderStatus = orderStatus ?? 'all';
    return MyOrderListResult(
      total: 1,
      items: [
        MyOrderItem(
          orderId: 1,
          orderCode: 'PO-QUERY-001',
          productId: 10,
          productName: '产线试产件',
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
          dueDate: DateTime.parse('2026-03-18T00:00:00Z'),
          remark: '',
          updatedAt: DateTime.parse('2026-03-01T08:00:00Z'),
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
}

void main() {
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
    expect(find.text('产线试产件'), findsOneWidget);
    expect(find.text('切割'), findsOneWidget);
    expect(find.text('可见12 / 分配12 / 完成4'), findsOneWidget);
    expect(find.text('2026-03-18'), findsOneWidget);
    expect(find.text('-'), findsWidgets);
    expect(find.text('订单编号'), findsOneWidget);
    expect(find.text('产品型号'), findsOneWidget);
    expect(find.text('供应商'), findsOneWidget);
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

    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, '全部'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('生产中').last);
    await tester.pump();

    expect(service.lastOrderStatus, 'in_progress');
  });

  testWidgets('订单查询页首件入口跳转到独立首件录入页', (tester) async {
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
    await tester.tap(find.text('首件').last);
    await tester.pumpAndSettle();

    expect(find.byType(ProductionFirstArticlePage), findsOneWidget);
    expect(find.textContaining('首件录入'), findsOneWidget);
    expect(find.text('默认模板'), findsNothing);
  });
}
