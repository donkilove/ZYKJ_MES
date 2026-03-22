import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/services/api_exception.dart';
import 'package:mes_client/services/equipment_service.dart';

import '../support/http_test_server.dart';

Map<String, dynamic> _equipmentJson() {
  return {
    'id': 1,
    'code': 'EQ-01',
    'name': '设备1',
    'model': 'M1',
    'location': 'A区',
    'owner_name': 'admin',
    'remark': '主线设备',
    'is_enabled': true,
    'created_at': '2026-03-01T00:00:00Z',
    'updated_at': '2026-03-01T00:00:00Z',
  };
}

Map<String, dynamic> _maintenanceItemJson() {
  return {
    'id': 2,
    'name': '点检',
    'category': '常规',
    'default_cycle_days': 30,
    'default_duration_minutes': 45,
    'standard_description': '按SOP执行',
    'is_enabled': true,
    'created_at': '2026-03-01T00:00:00Z',
    'updated_at': '2026-03-01T00:00:00Z',
  };
}

Map<String, dynamic> _maintenancePlanJson() {
  return {
    'id': 3,
    'equipment_id': 1,
    'equipment_name': '设备1',
    'item_id': 2,
    'item_name': '点检',
    'cycle_days': 30,
    'execution_process_code': '01-01',
    'execution_process_name': '切割',
    'estimated_duration_minutes': 20,
    'start_date': '2026-03-01',
    'next_due_date': '2026-03-31',
    'default_executor_user_id': 8,
    'default_executor_username': 'worker',
    'is_enabled': true,
    'created_at': '2026-03-01T00:00:00Z',
    'updated_at': '2026-03-01T00:00:00Z',
  };
}

Map<String, dynamic> _workOrderJson() {
  return {
    'id': 4,
    'plan_id': 3,
    'equipment_id': 1,
    'equipment_name': '设备1',
    'source_equipment_code': 'EQ-01',
    'item_id': 2,
    'item_name': '点检',
    'source_item_name': '点检',
    'source_execution_process_code': '01-01',
    'due_date': '2026-03-31',
    'status': 'pending',
    'executor_user_id': 8,
    'executor_username': 'worker',
    'started_at': null,
    'completed_at': null,
    'result_summary': null,
    'result_remark': null,
    'attachment_link': null,
    'attachment_name': null,
    'created_at': '2026-03-01T00:00:00Z',
    'updated_at': '2026-03-01T00:00:00Z',
  };
}

Map<String, dynamic> _workOrderDetailJson() {
  return {
    ..._workOrderJson(),
    'source_plan_id': 3,
    'source_plan_cycle_days': 30,
    'source_plan_start_date': '2026-03-01',
    'source_plan_summary': '计划#3 / 周期30天 / 起始2026-03-01',
    'source_execution_process_code': '01-01',
    'source_equipment_name': '设备1',
    'source_item_id': 2,
    'source_item_name': '点检',
  };
}

Map<String, dynamic> _recordJson() {
  return {
    'id': 5,
    'work_order_id': 4,
    'equipment_name': '设备1',
    'item_name': '点检',
    'due_date': '2026-03-31',
    'executor_user_id': 8,
    'executor_username': 'worker',
    'completed_at': '2026-03-31T10:00:00Z',
    'result_summary': '完成',
    'result_remark': '正常',
    'attachment_link': 'https://example.com/reports/checklist.pdf',
    'attachment_name': 'checklist.pdf',
    'created_at': '2026-03-31T10:00:00Z',
    'updated_at': '2026-03-31T10:00:00Z',
  };
}

Map<String, dynamic> _recordDetailJson() {
  return {
    ..._recordJson(),
    'source_plan_id': 3,
    'source_plan_cycle_days': 30,
    'source_plan_start_date': '2026-03-01',
    'source_plan_summary': '计划#3 / 周期30天 / 起始2026-03-01',
    'source_equipment_code': 'EQ-01',
    'source_equipment_name': '设备1',
    'source_execution_process_code': '01-01',
    'source_item_id': 2,
    'source_item_name': '点检',
  };
}

Map<String, dynamic> _equipmentDetailJson() {
  return {
    ..._equipmentJson(),
    'active_plan_count': 2,
    'pending_work_order_count': 1,
    'active_plans_scope_limited': true,
    'pending_work_orders_scope_limited': false,
    'recent_records_scope_limited': true,
    'active_plans': [_maintenancePlanJson()],
    'pending_work_orders': [_workOrderJson()],
    'recent_records': [_recordJson()],
  };
}

Map<String, dynamic> _runtimeParameterJson() {
  return {
    'id': 6,
    'equipment_id': 1,
    'equipment_type': '冲压机',
    'equipment_code': 'EQ-01',
    'equipment_name': '设备1',
    'param_code': 'PRESSURE',
    'param_name': '压力',
    'unit': 'bar',
    'standard_value': 1.2,
    'upper_limit': 1.5,
    'lower_limit': 1.0,
    'effective_at': '2026-03-01T00:00:00Z',
    'is_enabled': true,
    'remark': '关键参数',
    'created_at': '2026-03-01T00:00:00Z',
    'updated_at': '2026-03-01T00:00:00Z',
  };
}

void main() {
  group('EquipmentService', () {
    test('covers all equipment and maintenance APIs', () async {
      final server = await TestHttpServer.start({
        'GET /equipment/owners': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'items': [
                {'id': 1, 'username': 'admin', 'full_name': '管理员'},
              ],
            },
          },
        ),
        'GET /equipment/ledger/1/detail': (_) =>
            TestResponse.json(200, body: {'data': _equipmentDetailJson()}),
        'GET /equipment/ledger': (request) {
          expect(request.uri.queryParameters['page'], '1');
          expect(request.uri.queryParameters['page_size'], '20');
          expect(request.uri.queryParameters['keyword'], '设备');
          expect(request.uri.queryParameters['enabled'], 'true');
          expect(request.uri.queryParameters['location_keyword'], 'A区');
          expect(request.uri.queryParameters['owner_name'], 'admin');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'items': [_equipmentJson()],
              },
            },
          );
        },
        'POST /equipment/ledger': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['code'], 'EQ-02');
          expect(body['remark'], '新增备注');
          return TestResponse.json(201, body: {'data': {}});
        },
        'PUT /equipment/ledger/1': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['name'], '设备1-更新');
          expect(body['remark'], '更新备注');
          return TestResponse.json(200, body: {'data': {}});
        },
        'POST /equipment/ledger/1/toggle': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body.containsKey('enabled'), isTrue);
          return TestResponse.json(200, body: {'data': {}});
        },
        'DELETE /equipment/ledger/1': (_) =>
            TestResponse.json(200, body: {'data': {}}),
        'GET /equipment/items': (request) {
          expect(request.uri.queryParameters['keyword'], '点检');
          expect(request.uri.queryParameters['enabled'], 'true');
          expect(request.uri.queryParameters['category'], '常规');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'items': [_maintenanceItemJson()],
              },
            },
          );
        },
        'POST /equipment/items': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['name'], '润滑');
          expect(body['category'], '润滑类');
          expect(body['default_duration_minutes'], 50);
          return TestResponse.json(201, body: {'data': {}});
        },
        'PUT /equipment/items/2': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['default_cycle_days'], 7);
          expect(body['standard_description'], '更新标准描述');
          return TestResponse.json(200, body: {'data': {}});
        },
        'POST /equipment/items/2/toggle': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body.containsKey('enabled'), isTrue);
          return TestResponse.json(200, body: {'data': {}});
        },
        'DELETE /equipment/items/2': (_) =>
            TestResponse.json(200, body: {'data': {}}),
        'GET /equipment/plans': (request) {
          expect(request.uri.queryParameters['equipment_id'], '1');
          expect(request.uri.queryParameters['item_id'], '2');
          expect(request.uri.queryParameters['enabled'], 'true');
          expect(
            request.uri.queryParameters['execution_process_code'],
            '01-01',
          );
          expect(request.uri.queryParameters['default_executor_user_id'], '8');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'items': [_maintenancePlanJson()],
              },
            },
          );
        },
        'POST /equipment/plans': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['start_date'], '2026-03-01');
          expect(body['next_due_date'], '2026-03-31');
          expect(body['cycle_days'], 35);
          return TestResponse.json(201, body: {'data': {}});
        },
        'PUT /equipment/plans/3': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['execution_process_code'], '01-02');
          expect(body['cycle_days'], 40);
          return TestResponse.json(200, body: {'data': {}});
        },
        'POST /equipment/plans/3/toggle': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body.containsKey('enabled'), isTrue);
          return TestResponse.json(200, body: {'data': {}});
        },
        'DELETE /equipment/plans/3': (_) =>
            TestResponse.json(200, body: {'data': {}}),
        'POST /equipment/plans/3/generate': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'created': true,
              'work_order_id': 4,
              'due_date': '2026-03-31',
              'next_due_date': '2026-04-30',
            },
          },
        ),
        'GET /equipment/executions': (request) {
          expect(request.uri.queryParameters['page'], '1');
          expect(request.uri.queryParameters['page_size'], '10');
          expect(request.uri.queryParameters['keyword'], '设备');
          expect(request.uri.queryParameters['status'], 'pending');
          expect(request.uri.queryParameters['mine'], 'true');
          expect(request.uri.queryParameters['due_date_start'], '2026-03-01');
          expect(request.uri.queryParameters['due_date_end'], '2026-03-31');
          expect(request.uri.queryParameters['stage_code'], '01-01');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'items': [_workOrderJson()],
              },
            },
          );
        },
        'GET /equipment/executions/4/detail': (_) =>
            TestResponse.json(200, body: {'data': _workOrderDetailJson()}),
        'POST /equipment/executions/4/start': (_) =>
            TestResponse.json(200, body: {'data': {}}),
        'POST /equipment/executions/4/complete': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['result_summary'], '已完成');
          expect(body['result_remark'], '正常');
          expect(body['attachment_link'], 'https://example.com/report.png');
          return TestResponse.json(200, body: {'data': {}});
        },
        'POST /equipment/executions/4/cancel': (_) =>
            TestResponse.json(200, body: {'data': {}}),
        'GET /equipment/records': (request) {
          expect(request.uri.queryParameters['executor_id'], '8');
          expect(request.uri.queryParameters['start_date'], '2026-03-01');
          expect(request.uri.queryParameters['end_date'], '2026-03-31');
          expect(request.uri.queryParameters['result_summary'], '完成');
          expect(request.uri.queryParameters['equipment_id'], '1');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'items': [_recordJson()],
              },
            },
          );
        },
        'GET /equipment/records/5/detail': (_) =>
            TestResponse.json(200, body: {'data': _recordDetailJson()}),
        'GET /equipment/runtime-parameters': (request) {
          expect(request.uri.queryParameters['equipment_id'], '1');
          expect(request.uri.queryParameters['equipment_type'], '冲压机');
          expect(request.uri.queryParameters['is_enabled'], 'true');
          expect(request.uri.queryParameters['keyword'], '压力');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'items': [_runtimeParameterJson()],
              },
            },
          );
        },
      });
      addTearDown(server.close);

      final service = EquipmentService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-equipment'),
      );

      final owners = await service.listAllOwners();
      final equipmentDetail = await service.getEquipmentDetail(equipmentId: 1);
      final equipment = await service.listEquipment(
        page: 1,
        pageSize: 20,
        keyword: '  设备 ',
        enabled: true,
        locationKeyword: 'A区',
        ownerName: 'admin',
      );
      await service.createEquipment(
        code: 'EQ-02',
        name: '设备2',
        model: 'M2',
        location: 'B区',
        ownerName: 'admin',
        remark: '新增备注',
      );
      await service.updateEquipment(
        equipmentId: 1,
        code: 'EQ-01',
        name: '设备1-更新',
        model: 'M1',
        location: 'A区',
        ownerName: 'admin',
        remark: '更新备注',
      );
      await service.toggleEquipment(equipmentId: 1, enabled: true);
      await service.disableEquipment(equipmentId: 1);
      await service.deleteEquipment(equipmentId: 1);

      final items = await service.listMaintenanceItems(
        page: 1,
        pageSize: 20,
        keyword: '  点检 ',
        enabled: true,
        category: '常规',
      );
      await service.createMaintenanceItem(
        name: '润滑',
        defaultCycleDays: 30,
        category: '润滑类',
        defaultDurationMinutes: 50,
        standardDescription: '标准描述',
      );
      await service.updateMaintenanceItem(
        itemId: 2,
        name: '润滑-更新',
        defaultCycleDays: 7,
        category: '更新分类',
        defaultDurationMinutes: 60,
        standardDescription: '更新标准描述',
      );
      await service.toggleMaintenanceItem(itemId: 2, enabled: true);
      await service.disableMaintenanceItem(itemId: 2);
      await service.deleteMaintenanceItem(itemId: 2);

      final plans = await service.listMaintenancePlans(
        page: 1,
        pageSize: 20,
        equipmentId: 1,
        itemId: 2,
        enabled: true,
        executionProcessCode: '01-01',
        defaultExecutorUserId: 8,
      );
      await service.createMaintenancePlan(
        equipmentId: 1,
        itemId: 2,
        executionProcessCode: '01-01',
        startDate: DateTime(2026, 3, 1),
        estimatedDurationMinutes: 20,
        nextDueDate: DateTime(2026, 3, 31),
        defaultExecutorUserId: 8,
        cycleDays: 35,
      );
      await service.updateMaintenancePlan(
        planId: 3,
        equipmentId: 1,
        itemId: 2,
        executionProcessCode: '01-02',
        startDate: DateTime(2026, 3, 1),
        estimatedDurationMinutes: 25,
        nextDueDate: DateTime(2026, 4, 1),
        defaultExecutorUserId: 8,
        cycleDays: 40,
      );
      await service.toggleMaintenancePlan(planId: 3, enabled: true);
      await service.deleteMaintenancePlan(planId: 3);
      final generated = await service.generateMaintenancePlan(planId: 3);

      final executions = await service.listExecutions(
        page: 1,
        pageSize: 10,
        keyword: '  设备 ',
        status: 'pending',
        mineOnly: true,
        dueDateStart: DateTime(2026, 3, 1),
        dueDateEnd: DateTime(2026, 3, 31),
        stageCode: '01-01',
      );
      final workOrderDetail = await service.getWorkOrderDetail(workOrderId: 4);
      await service.startExecution(workOrderId: 4);
      await service.completeExecution(
        workOrderId: 4,
        resultSummary: '已完成',
        resultRemark: '正常',
        attachmentLink: 'https://example.com/report.png',
      );
      await service.cancelExecution(workOrderId: 4);
      final records = await service.listRecords(
        page: 1,
        pageSize: 20,
        keyword: '设备',
        executorId: 8,
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 31),
        resultSummary: '完成',
        equipmentId: 1,
      );
      final recordDetail = await service.getRecordDetail(recordId: 5);
      final runtimeParameters = await service.listRuntimeParameters(
        equipmentId: 1,
        equipmentType: '冲压机',
        keyword: '压力',
        isEnabled: true,
      );

      expect(owners.single.username, 'admin');
      expect(owners.single.userId, 1);
      expect(equipmentDetail.activePlanCount, 2);
      expect(equipmentDetail.activePlansScopeLimited, isTrue);
      expect(equipmentDetail.recentRecordsScopeLimited, isTrue);
      expect(equipment.items.single.code, 'EQ-01');
      expect(items.items.single.name, '点检');
      expect(plans.items.single.executionProcessCode, '01-01');
      expect(generated.workOrderId, 4);
      expect(executions.items.single.id, 4);
      expect(workOrderDetail.sourcePlanId, 3);
      expect(workOrderDetail.sourcePlanSummary, '计划#3 / 周期30天 / 起始2026-03-01');
      expect(records.items.single.workOrderId, 4);
      expect(records.items.single.attachmentName, 'checklist.pdf');
      expect(recordDetail.sourceEquipmentCode, 'EQ-01');
      expect(recordDetail.sourceEquipmentName, '设备1');
      expect(recordDetail.sourceExecutionProcessCode, '01-01');
      expect(recordDetail.attachmentName, 'checklist.pdf');
      expect(runtimeParameters.items.single.equipmentType, '冲压机');
      expect(server.requests.length, 28);
    });

    test('throws ApiException when backend returns non-200 status', () async {
      final server = await TestHttpServer.start({
        'GET /equipment/ledger': (_) =>
            TestResponse.json(500, body: {'message': 'ledger failure'}),
      });
      addTearDown(server.close);

      final service = EquipmentService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-equipment'),
      );

      await expectLater(
        () => service.listEquipment(page: 1, pageSize: 20),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message', 'ledger failure'),
        ),
      );
    });
  });
}
