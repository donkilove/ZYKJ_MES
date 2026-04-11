import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';

void main() {
  test('maintenance cycle constants keep expected values', () {
    expect(maintenanceCycleWeekly, 7);
    expect(maintenanceCycleMonthly, 30);
    expect(maintenanceCycleQuarterly, 90);
    expect(maintenanceCycleYearly, 365);
  });

  test(
    'EquipmentOwnerOption.displayName formats with and without full name',
    () {
      final withFullName = EquipmentOwnerOption.fromJson({
        'username': 'admin',
        'full_name': '管理员',
      });
      final withoutFullName = EquipmentOwnerOption.fromJson({
        'username': 'operator',
        'full_name': '   ',
      });

      expect(withFullName.displayName, contains('admin'));
      expect(withFullName.displayName, contains('管理员'));
      expect(withoutFullName.displayName, 'operator');
    },
  );

  test('MaintenanceItemEntry.executionDateLabel returns category labels', () {
    final weekly = MaintenanceItemEntry.fromJson({
      'id': 1,
      'name': '周检',
      'default_cycle_days': maintenanceCycleWeekly,
      'is_enabled': true,
      'created_at': '2026-03-01T00:00:00Z',
      'updated_at': '2026-03-01T00:00:00Z',
    });
    final monthly = MaintenanceItemEntry.fromJson({
      'id': 2,
      'name': '月检',
      'default_cycle_days': maintenanceCycleMonthly,
      'is_enabled': true,
      'created_at': '2026-03-01T00:00:00Z',
      'updated_at': '2026-03-01T00:00:00Z',
    });
    final quarterly = MaintenanceItemEntry.fromJson({
      'id': 3,
      'name': '季检',
      'default_cycle_days': maintenanceCycleQuarterly,
      'is_enabled': true,
      'created_at': '2026-03-01T00:00:00Z',
      'updated_at': '2026-03-01T00:00:00Z',
    });
    final yearly = MaintenanceItemEntry.fromJson({
      'id': 4,
      'name': '年检',
      'default_cycle_days': maintenanceCycleYearly,
      'is_enabled': true,
      'created_at': '2026-03-01T00:00:00Z',
      'updated_at': '2026-03-01T00:00:00Z',
    });
    final custom = MaintenanceItemEntry.fromJson({
      'id': 5,
      'name': '自定义',
      'default_cycle_days': 10,
      'is_enabled': true,
      'created_at': '2026-03-01T00:00:00Z',
      'updated_at': '2026-03-01T00:00:00Z',
    });

    expect(weekly.executionDateLabel, isNotEmpty);
    expect(monthly.executionDateLabel, isNotEmpty);
    expect(quarterly.executionDateLabel, isNotEmpty);
    expect(yearly.executionDateLabel, isNotEmpty);
    expect(custom.executionDateLabel, '每10天执行');
    expect(custom.executionDateLabel, isNot(weekly.executionDateLabel));
  });

  test('equipment and maintenance models parse json and wrappers', () {
    final equipment = EquipmentLedgerItem.fromJson({
      'id': 1,
      'code': 'EQ-01',
      'name': '机台1',
      'model': 'M1',
      'location': 'A区',
      'owner_name': 'admin',
      'is_enabled': true,
      'created_at': '2026-03-01T10:00:00Z',
      'updated_at': '2026-03-01T10:00:00Z',
    });
    final plan = MaintenancePlanItem.fromJson({
      'id': 2,
      'equipment_id': 1,
      'equipment_name': '机台1',
      'item_id': 3,
      'item_name': '点检',
      'cycle_days': 7,
      'execution_process_code': '01-01',
      'execution_process_name': '切割',
      'estimated_duration_minutes': 30,
      'start_date': '2026-03-01',
      'next_due_date': '2026-03-08',
      'default_executor_user_id': 11,
      'default_executor_username': 'op',
      'is_enabled': true,
      'created_at': '2026-03-01T10:00:00Z',
      'updated_at': '2026-03-01T10:00:00Z',
    });
    final generate = MaintenancePlanGenerateResult.fromJson({
      'created': true,
      'work_order_id': 5,
      'due_date': '2026-03-08',
      'next_due_date': '2026-03-15',
    });
    final workOrder = MaintenanceWorkOrderItem.fromJson({
      'id': 9,
      'plan_id': 2,
      'equipment_id': 1,
      'equipment_name': '机台1',
      'source_equipment_code': 'EQ-01',
      'item_id': 3,
      'item_name': '点检',
      'source_item_name': '点检',
      'source_execution_process_code': '01-01',
      'due_date': '2026-03-08',
      'status': 'pending',
      'executor_user_id': null,
      'executor_username': null,
      'started_at': null,
      'completed_at': null,
      'result_summary': null,
      'result_remark': null,
      'attachment_link': null,
      'attachment_name': null,
      'created_at': '2026-03-01T10:00:00Z',
      'updated_at': '2026-03-01T10:00:00Z',
    });
    final workOrderDetail = MaintenanceWorkOrderDetail.fromJson({
      'id': 9,
      'plan_id': 2,
      'equipment_id': 1,
      'equipment_name': '机台1',
      'source_equipment_code': 'EQ-01',
      'source_equipment_name': '机台1',
      'item_id': 3,
      'item_name': '点检',
      'source_item_id': 3,
      'source_item_name': '点检',
      'source_execution_process_code': '01-01',
      'source_plan_id': 2,
      'source_plan_cycle_days': 30,
      'source_plan_start_date': '2026-03-01',
      'source_plan_summary': '计划#2 / 周期30天 / 起始2026-03-01',
      'due_date': '2026-03-08',
      'status': 'pending',
      'executor_user_id': null,
      'executor_username': null,
      'started_at': null,
      'completed_at': null,
      'result_summary': null,
      'result_remark': null,
      'attachment_link': 'https://example.com/work-orders/order-9.pdf',
      'attachment_name': 'order-9.pdf',
      'created_at': '2026-03-01T10:00:00Z',
      'updated_at': '2026-03-01T10:00:00Z',
      'record_id': 10,
    });
    final record = MaintenanceRecordItem.fromJson({
      'id': 10,
      'work_order_id': 9,
      'equipment_name': '机台1',
      'item_name': '点检',
      'due_date': '2026-03-08',
      'executor_user_id': 12,
      'executor_username': 'worker',
      'completed_at': '2026-03-08T11:00:00Z',
      'result_summary': '完成',
      'result_remark': '正常',
      'attachment_link': 'http://example.com/file',
      'attachment_name': 'file',
      'created_at': '2026-03-08T11:00:00Z',
      'updated_at': '2026-03-08T11:00:00Z',
    });
    final recordDetail = MaintenanceRecordDetail.fromJson({
      'id': 10,
      'work_order_id': 9,
      'equipment_name': '机台1',
      'item_name': '点检',
      'due_date': '2026-03-08',
      'executor_user_id': 12,
      'executor_username': 'worker',
      'completed_at': '2026-03-08T11:00:00Z',
      'result_summary': '完成',
      'result_remark': '正常',
      'attachment_link': 'http://example.com/file',
      'attachment_name': 'file',
      'created_at': '2026-03-08T11:00:00Z',
      'updated_at': '2026-03-08T11:00:00Z',
      'source_plan_id': 2,
      'source_plan_cycle_days': 30,
      'source_plan_start_date': '2026-03-01',
      'source_plan_summary': '计划#2 / 周期30天 / 起始2026-03-01',
      'source_equipment_code': 'EQ-01',
      'source_equipment_name': '机台1',
      'source_execution_process_code': '01-01',
      'source_item_id': 3,
      'source_item_name': '点检',
    });
    final equipmentDetail = EquipmentDetailResult.fromJson({
      'id': 1,
      'code': 'EQ-01',
      'name': '机台1',
      'model': 'M1',
      'location': 'A区',
      'owner_name': 'admin',
      'remark': '重点设备',
      'is_enabled': true,
      'created_at': '2026-03-01T10:00:00Z',
      'updated_at': '2026-03-01T10:00:00Z',
      'active_plan_count': 1,
      'pending_work_order_count': 1,
      'active_plans_scope_limited': true,
      'pending_work_orders_scope_limited': false,
      'recent_records_scope_limited': true,
      'active_plans': [
        {
          'id': 2,
          'equipment_id': 1,
          'equipment_name': '机台1',
          'item_id': 3,
          'item_name': '点检',
          'cycle_days': 7,
          'execution_process_code': '01-01',
          'execution_process_name': '切割',
          'estimated_duration_minutes': 30,
          'start_date': '2026-03-01',
          'next_due_date': '2026-03-08',
          'default_executor_user_id': 11,
          'default_executor_username': 'op',
          'is_enabled': true,
          'created_at': '2026-03-01T10:00:00Z',
          'updated_at': '2026-03-01T10:00:00Z',
        },
      ],
      'pending_work_orders': [
        {
          'id': 9,
          'plan_id': 2,
          'equipment_id': 1,
          'equipment_name': '机台1',
          'source_equipment_code': 'EQ-01',
          'item_id': 3,
          'item_name': '点检',
          'source_item_name': '点检',
          'source_execution_process_code': '01-01',
          'due_date': '2026-03-08',
          'status': 'pending',
          'executor_user_id': null,
          'executor_username': null,
          'started_at': null,
          'completed_at': null,
           'result_summary': null,
           'result_remark': null,
           'attachment_link': null,
           'attachment_name': null,
           'created_at': '2026-03-01T10:00:00Z',
           'updated_at': '2026-03-01T10:00:00Z',
        },
      ],
      'recent_records': [
        {
          'id': 10,
          'work_order_id': 9,
          'equipment_name': '机台1',
          'item_name': '点检',
          'due_date': '2026-03-08',
          'executor_user_id': 12,
          'executor_username': 'worker',
          'completed_at': '2026-03-08T11:00:00Z',
           'result_summary': '完成',
           'result_remark': '正常',
           'attachment_link': 'http://example.com/file',
           'attachment_name': 'file',
           'created_at': '2026-03-08T11:00:00Z',
           'updated_at': '2026-03-08T11:00:00Z',
        },
      ],
    });
    final maintenanceItem = MaintenanceItemEntry.fromJson({
      'id': 6,
      'name': '点检',
      'default_cycle_days': 30,
      'is_enabled': true,
      'created_at': '2026-03-01T00:00:00Z',
      'updated_at': '2026-03-01T00:00:00Z',
    });

    expect(equipment.code, 'EQ-01');
    expect(equipmentDetail.activePlansScopeLimited, isTrue);
    expect(equipmentDetail.recentRecordsScopeLimited, isTrue);
    expect(plan.executionProcessName, '切割');
    expect(generate.workOrderId, 5);
    expect(
      maintenanceItem.createdAt.toUtc().toIso8601String(),
      '2026-03-01T00:00:00.000Z',
    );
    expect(workOrder.startedAt, isNull);
    expect(workOrder.sourceEquipmentCode, 'EQ-01');
    expect(workOrderDetail.attachmentName, 'order-9.pdf');
    expect(workOrderDetail.sourcePlanSummary, '计划#2 / 周期30天 / 起始2026-03-01');
    expect(record.dueDate.year, 2026);
    expect(record.dueDate.month, 3);
    expect(record.dueDate.day, 8);
    expect(record.resultSummary, '完成');
    expect(record.attachmentName, 'file');
    expect(recordDetail.sourceEquipmentName, '机台1');
    expect(recordDetail.sourceExecutionProcessCode, '01-01');

    expect(EquipmentLedgerListResult(total: 1, items: [equipment]).total, 1);
    expect(
      MaintenanceItemListResult(total: 1, items: [maintenanceItem]).total,
      1,
    );
    expect(MaintenancePlanListResult(total: 1, items: [plan]).items.length, 1);
    expect(
      MaintenanceWorkOrderListResult(total: 1, items: [workOrder]).items.length,
      1,
    );
    expect(
      MaintenanceRecordListResult(total: 1, items: [record]).items.length,
      1,
    );
  });
}
