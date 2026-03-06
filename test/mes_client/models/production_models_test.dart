import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/production_models.dart';

void main() {
  test('production status helpers map known statuses and keep unknown', () {
    expect(productionOrderStatusLabel('pending'), isNot('pending'));
    expect(productionOrderStatusLabel('in_progress'), isNot('in_progress'));
    expect(productionOrderStatusLabel('completed'), isNot('completed'));
    expect(productionOrderStatusLabel('custom'), 'custom');

    expect(productionProcessStatusLabel('partial'), isNot('partial'));
    expect(productionProcessStatusLabel('x'), 'x');

    expect(productionSubOrderStatusLabel('done'), isNot('done'));
    expect(productionSubOrderStatusLabel('y'), 'y');
  });

  test('order and detail models parse nested payload', () {
    final order = ProductionOrderItem.fromJson({
      'id': 1,
      'order_code': 'PO-1',
      'product_id': 10,
      'product_name': '产品A',
      'quantity': 100,
      'status': 'pending',
      'current_process_code': null,
      'current_process_name': null,
      'start_date': '',
      'due_date': null,
      'remark': '备注',
      'process_template_id': 5,
      'process_template_name': '默认模板',
      'process_template_version': 2,
      'created_by_user_id': 1,
      'created_by_username': 'admin',
      'created_at': '2026-03-01T00:00:00Z',
      'updated_at': '2026-03-01T00:00:00Z',
    });
    final detail = ProductionOrderDetail.fromJson({
      'order': {
        'id': 1,
        'order_code': 'PO-1',
        'product_id': 10,
        'product_name': '产品A',
        'quantity': 100,
        'status': 'pending',
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
          'visible_quantity': 80,
          'completed_quantity': 20,
          'created_at': '2026-03-01T00:00:00Z',
          'updated_at': '2026-03-01T00:00:00Z',
        },
      ],
      'sub_orders': [
        {
          'id': 22,
          'order_process_id': 11,
          'process_code': '01-01',
          'process_name': '切割',
          'operator_user_id': 7,
          'operator_username': 'worker',
          'assigned_quantity': 20,
          'completed_quantity': 10,
          'status': 'in_progress',
          'is_visible': true,
          'created_at': '2026-03-01T00:00:00Z',
          'updated_at': '2026-03-01T00:00:00Z',
        },
      ],
      'records': [
        {
          'id': 33,
          'order_process_id': 11,
          'process_code': '01-01',
          'process_name': '切割',
          'operator_user_id': 7,
          'operator_username': 'worker',
          'production_quantity': 5,
          'record_type': 'production',
          'created_at': '2026-03-01T00:00:00Z',
        },
      ],
      'events': [
        {
          'id': 44,
          'event_type': 'created',
          'event_title': '创建订单',
          'event_detail': null,
          'operator_user_id': 1,
          'operator_username': 'admin',
          'payload_json': '{}',
          'created_at': '2026-03-01T00:00:00Z',
        },
      ],
    });

    expect(order.startDate, isNull);
    expect(order.dueDate, isNull);
    expect(detail.processes.single.processCode, '01-01');
    expect(detail.subOrders.single.isVisible, isTrue);
    expect(detail.records.single.productionQuantity, 5);
    expect(detail.events.single.eventType, 'created');
    expect(ProductionOrderListResult(total: 1, items: [order]).items.length, 1);
  });

  test('my-order/stats/options models parse and payload serializes', () {
    final myOrder = MyOrderItem.fromJson({
      'order_id': 9,
      'order_code': 'PO-9',
      'product_id': 2,
      'product_name': '产品X',
      'quantity': 300,
      'order_status': 'in_progress',
      'current_process_id': 8,
      'current_stage_id': 1,
      'current_stage_code': '01',
      'current_stage_name': '切割段',
      'current_process_code': '01-01',
      'current_process_name': '切割',
      'current_process_order': 1,
      'process_status': 'pending',
      'visible_quantity': 200,
      'process_completed_quantity': 100,
      'user_sub_order_id': 10,
      'user_assigned_quantity': 50,
      'user_completed_quantity': 20,
      'max_producible_quantity': 30,
      'can_first_article': true,
      'can_end_production': false,
      'updated_at': '2026-03-01T00:00:00Z',
    });
    final action = ProductionActionResult.fromJson({
      'order_id': 9,
      'status': 'ok',
      'message': 'done',
    });
    final overview = ProductionStatsOverview.fromJson({
      'total_orders': 10,
      'pending_orders': 2,
      'in_progress_orders': 5,
      'completed_orders': 3,
      'total_quantity': 1000,
      'finished_quantity': 800,
    });
    final processStat = ProductionProcessStatItem.fromJson({
      'process_code': '01-01',
      'process_name': '切割',
      'total_orders': 3,
      'pending_orders': 1,
      'in_progress_orders': 1,
      'partial_orders': 1,
      'completed_orders': 0,
      'total_visible_quantity': 100,
      'total_completed_quantity': 60,
    });
    final operatorStat = ProductionOperatorStatItem.fromJson({
      'operator_user_id': 1,
      'operator_username': 'op',
      'process_code': '01-01',
      'process_name': '切割',
      'production_records': 12,
      'production_quantity': 50,
      'last_production_at': '',
    });
    final productOption = ProductionProductOption.fromJson({
      'id': 2,
      'name': '产品X',
    });
    final processOption = ProductionProcessOption.fromJson({
      'id': 3,
      'code': '01-01',
      'name': '切割',
      'stage_id': 1,
      'stage_code': '01',
      'stage_name': '切割段',
    });
    const step = ProductionOrderProcessStepInput(
      stepOrder: 1,
      stageId: 1,
      processId: 3,
    );

    expect(myOrder.canFirstArticle, isTrue);
    expect(action.message, 'done');
    expect(overview.finishedQuantity, 800);
    expect(processStat.totalVisibleQuantity, 100);
    expect(operatorStat.lastProductionAt, isNull);
    expect(productOption.id, 2);
    expect(processOption.stageCode, '01');
    expect(step.toJson(), {'step_order': 1, 'stage_id': 1, 'process_id': 3});
    expect(MyOrderListResult(total: 1, items: [myOrder]).items.single.orderId, 9);
  });
}
