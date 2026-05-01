import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/production/presentation/production_order_detail_page.dart';
import 'package:mes_client/features/production/services/production_service.dart';

class _FakeProductionOrderDetailService extends ProductionService {
  _FakeProductionOrderDetailService()
    : super(AppSession(baseUrl: '', accessToken: ''));

  @override
  Future<ProductionOrderDetail> getOrderDetail({required int orderId}) async {
    return ProductionOrderDetail.fromJson({
      'order': {
        'id': orderId,
        'order_code': 'PO-$orderId',
        'product_id': 1,
        'product_name': '产品A',
        'quantity': 10,
        'status': 'pending',
        'current_process_code': '01-01',
        'current_process_name': '切割',
        'start_date': '2026-03-01',
        'due_date': '2026-03-10',
        'remark': null,
        'process_template_id': null,
        'process_template_name': null,
        'process_template_version': null,
        'pipeline_enabled': false,
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

void main() {
  testWidgets('production order detail page renders actions and tabs', (
    tester,
  ) async {
    var editCalled = false;
    var pipelineCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ProductionOrderDetailPage(
          session: AppSession(baseUrl: '', accessToken: ''),
          onLogout: () {},
          orderId: 1,
          canEditOrder: true,
          canDeleteOrder: true,
          canCompleteOrder: true,
          canUpdatePipelineMode: true,
          service: _FakeProductionOrderDetailService(),
          onEditOrder: (_) async {
            editCalled = true;
            return true;
          },
          onDeleteOrder: (_) async => false,
          onCompleteOrder: (_) async => false,
          onConfigurePipelineOrder: (_) async {
            pipelineCalled = true;
            return true;
          },
          onDisablePipelineOrder: (_) async => false,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('编辑订单'), findsOneWidget);
    expect(find.text('删除订单'), findsOneWidget);
    expect(find.text('结束订单'), findsOneWidget);
    expect(find.text('并行模式设置'), findsOneWidget);
    expect(find.text('工序'), findsOneWidget);
    expect(find.text('子订单'), findsOneWidget);
    expect(find.text('记录'), findsOneWidget);
    expect(find.text('事件'), findsOneWidget);
    expect(find.byType(CrudListTableSection), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);

    await tester.tap(find.text('编辑订单'));
    await tester.pump();
    expect(editCalled, isTrue);

    await tester.tap(find.text('并行模式设置'));
    await tester.pump();
    expect(pipelineCalled, isTrue);

    await tester.tap(find.text('子订单'));
    await tester.pumpAndSettle();
    expect(find.text('worker'), findsOneWidget);
  });
}
