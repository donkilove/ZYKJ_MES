import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/production_models.dart';
import 'package:mes_client/pages/production_order_query_detail_page.dart';
import 'package:mes_client/services/production_service.dart';

class _FakeProductionOrderQueryDetailService extends ProductionService {
  _FakeProductionOrderQueryDetailService()
    : super(AppSession(baseUrl: '', accessToken: ''));

  @override
  Future<ProductionOrderDetail> getOrderDetail({required int orderId}) async {
    return ProductionOrderDetail.fromJson({
      'order': {
        'id': orderId,
        'order_code': 'PO-$orderId',
        'product_id': 1,
        'product_name': '产品A',
        'product_version': 3,
        'quantity': 10,
        'status': 'in_progress',
        'current_process_code': '01-01',
        'current_process_name': '切割',
        'start_date': '2026-03-01',
        'due_date': '2026-03-10',
        'remark': null,
        'process_template_id': 7,
        'process_template_name': '标准模板',
        'process_template_version': 5,
        'pipeline_enabled': true,
        'pipeline_process_codes': [],
        'created_by_user_id': 1,
        'created_by_username': 'admin',
        'created_at': '2026-03-01T00:00:00Z',
        'updated_at': '2026-03-01T00:00:00Z',
      },
      'processes': [
        {
          'id': 11,
          'stage_id': 1,
          'stage_code': '01',
          'stage_name': '切割段',
          'process_code': '01-01',
          'process_name': '切割',
          'process_order': 1,
          'status': 'in_progress',
          'visible_quantity': 10,
          'completed_quantity': 5,
          'created_at': '2026-03-01T00:00:00Z',
          'updated_at': '2026-03-01T00:00:00Z',
        },
      ],
      'sub_orders': [
        {
          'id': 21,
          'order_process_id': 11,
          'process_code': '01-01',
          'process_name': '切割',
          'operator_user_id': 8,
          'operator_username': 'worker',
          'assigned_quantity': 10,
          'completed_quantity': 5,
          'status': 'in_progress',
          'is_visible': true,
          'created_at': '2026-03-01T00:00:00Z',
          'updated_at': '2026-03-01T00:00:00Z',
        },
      ],
      'records': [
        {
          'id': 31,
          'order_process_id': 11,
          'process_code': '01-01',
          'process_name': '切割',
          'operator_user_id': 8,
          'operator_username': 'worker',
          'production_quantity': 5,
          'record_type': 'production',
          'created_at': '2026-03-01T00:00:00Z',
        },
      ],
      'events': [
        {
          'id': 41,
          'event_type': 'created',
          'event_title': '创建订单',
          'event_detail': '订单已创建',
          'operator_user_id': 1,
          'operator_username': 'admin',
          'payload_json': '{}',
          'created_at': '2026-03-01T00:00:00Z',
        },
      ],
    });
  }
}

MyOrderItem _buildMyOrderItem() {
  return MyOrderItem(
    orderId: 1,
    orderCode: 'PO-1',
    productId: 1,
    productName: '产品A',
    supplierName: '供应商甲',
    quantity: 10,
    orderStatus: 'in_progress',
    currentProcessId: 11,
    currentStageId: 1,
    currentStageCode: '01',
    currentStageName: '切割段',
    currentProcessCode: '01-01',
    currentProcessName: '切割',
    currentProcessOrder: 1,
    processStatus: 'in_progress',
    visibleQuantity: 10,
    processCompletedQuantity: 5,
    userSubOrderId: 21,
    userAssignedQuantity: 10,
    userCompletedQuantity: 5,
    operatorUserId: 8,
    operatorUsername: 'worker',
    workView: 'own',
    assistAuthorizationId: null,
    pipelineInstanceId: 501,
    pipelineInstanceNo: 'P1-21-1-PIPE0501',
    pipelineModeEnabled: false,
    pipelineStartAllowed: true,
    pipelineEndAllowed: true,
    maxProducibleQuantity: 5,
    canFirstArticle: true,
    canEndProduction: true,
    dueDate: DateTime.parse('2026-03-10T00:00:00Z'),
    remark: '查询备注',
    updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
  );
}

void main() {
  testWidgets('production query detail page renders tabs and action buttons', (
    tester,
  ) async {
    var firstCalled = false;
    var endCalled = false;
    var manualRepairCalled = false;
    var applyAssistCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ProductionOrderQueryDetailPage(
          session: AppSession(baseUrl: '', accessToken: ''),
          onLogout: () {},
          orderId: 1,
          canFirstArticle: true,
          canEndProduction: true,
          canCreateManualRepairOrder: true,
          canCreateAssistAuthorization: true,
          initialOrderContext: _buildMyOrderItem(),
          service: _FakeProductionOrderQueryDetailService(),
          onSubmitFirstArticle: (_) async {
            firstCalled = true;
            return true;
          },
          onEndProduction: (_) async {
            endCalled = true;
            return true;
          },
          onCreateManualRepair: (_) async {
            manualRepairCalled = true;
            return true;
          },
          onApplyAssist: (_) async {
            applyAssistCalled = true;
            return true;
          },
          onRefreshOrderContext: (_) async =>
              MyOrderContextResult(found: true, item: _buildMyOrderItem()),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('首件'), findsOneWidget);
    expect(find.text('报工'), findsOneWidget);
    expect(find.text('手工送修建单'), findsOneWidget);
    expect(find.text('发起代班'), findsOneWidget);
    expect(find.text('工序'), findsOneWidget);
    expect(find.text('子订单'), findsOneWidget);
    expect(find.text('记录'), findsOneWidget);
    expect(find.text('事件'), findsOneWidget);
    expect(find.text('订单号：PO-1'), findsOneWidget);
    expect(find.text('产品版本：3'), findsOneWidget);
    expect(find.text('模板名称/版本：标准模板 v5'), findsOneWidget);
    expect(find.text('并行模式：开启'), findsOneWidget);
    expect(find.text('并行实例：P1-21-1-PIPE0501'), findsOneWidget);
    expect(find.text('视角：我的工单'), findsOneWidget);
    expect(find.text('创建人：admin'), findsOneWidget);
    expect(find.textContaining('创建时间：2026-03-01'), findsOneWidget);

    await tester.tap(find.text('首件'));
    await tester.pumpAndSettle();
    expect(firstCalled, isTrue);

    await tester.tap(find.text('报工'));
    await tester.pumpAndSettle();
    expect(endCalled, isTrue);

    await tester.tap(find.text('手工送修建单'));
    await tester.pumpAndSettle();
    expect(manualRepairCalled, isTrue);

    await tester.tap(find.text('发起代班'));
    await tester.pumpAndSettle();
    expect(applyAssistCalled, isTrue);

    await tester.tap(find.text('子订单'));
    await tester.pumpAndSettle();
    expect(find.text('worker'), findsOneWidget);
  });

  testWidgets(
    'query detail page falls back to readonly when context not found',
    (tester) async {
      var firstCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ProductionOrderQueryDetailPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            orderId: 1,
            canFirstArticle: true,
            canEndProduction: true,
            canCreateManualRepairOrder: true,
            canCreateAssistAuthorization: true,
            initialOrderContext: _buildMyOrderItem(),
            service: _FakeProductionOrderQueryDetailService(),
            onSubmitFirstArticle: (_) async {
              firstCalled = true;
              return true;
            },
            onEndProduction: (_) async => false,
            onCreateManualRepair: (_) async => false,
            onApplyAssist: (_) async => false,
            onRefreshOrderContext: (_) async =>
                MyOrderContextResult(found: false, item: null),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('首件'));
      await tester.pumpAndSettle();

      expect(firstCalled, isTrue);
      expect(find.textContaining('仅保留详情查看'), findsOneWidget);
      final firstButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '首件'),
      );
      expect(firstButton.onPressed, isNull);
    },
  );
}
