import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/production_models.dart';
import 'package:mes_client/pages/production_order_query_page.dart';
import 'package:mes_client/services/production_service.dart';

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
          updatedAt: DateTime.parse('2026-03-01T08:00:00Z'),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('订单查询页支持筛选并展示工单列表', (tester) async {
    final service = _FakeProductionOrderQueryPageService();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

    expect(find.text('生产订单查询'), findsOneWidget);
    expect(find.text('PO-QUERY-001'), findsOneWidget);
    expect(find.text('产线试产件'), findsOneWidget);
    expect(find.text('切割段'), findsOneWidget);
    expect(find.text('P1-31-1-PIPE0001'), findsOneWidget);
    expect(find.text('第 1 / 1 页'), findsOneWidget);
    expect(find.text('操作'), findsWidgets);

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
}
