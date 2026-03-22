import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/equipment_models.dart';
import 'package:mes_client/pages/equipment_detail_page.dart';
import 'package:mes_client/services/equipment_service.dart';

class _FakeEquipmentService extends EquipmentService {
  _FakeEquipmentService({required this.detail})
    : super(AppSession(baseUrl: '', accessToken: 'token'));

  final EquipmentDetailResult detail;

  @override
  Future<EquipmentDetailResult> getEquipmentDetail({
    required int equipmentId,
  }) async {
    return detail;
  }
}

MaintenancePlanItem _buildPlan(int id) {
  return MaintenancePlanItem(
    id: id,
    equipmentId: 9,
    equipmentName: '冲压机',
    itemId: 100 + id,
    itemName: '周保养$id',
    cycleDays: 7,
    executionProcessCode: 'PROC$id',
    executionProcessName: '产线$id',
    estimatedDurationMinutes: 30,
    startDate: DateTime.parse('2026-03-01T00:00:00Z'),
    nextDueDate: DateTime.parse('2026-03-28T00:00:00Z'),
    defaultExecutorUserId: 3,
    defaultExecutorUsername: 'maintainer',
    isEnabled: true,
    createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
    updatedAt: DateTime.parse('2026-03-20T00:00:00Z'),
  );
}

MaintenanceWorkOrderItem _buildWorkOrder(int id) {
  return MaintenanceWorkOrderItem(
    id: id,
    planId: 10,
    equipmentId: 9,
    equipmentName: '冲压机',
    sourceEquipmentCode: 'EQ-009',
    itemId: 200 + id,
    itemName: '点检$id',
    sourceItemName: '点检$id',
    sourceExecutionProcessCode: 'LINE-A',
    dueDate: DateTime.parse('2026-03-27T00:00:00Z'),
    status: 'pending',
    executorUserId: 5,
    executorUsername: 'operator',
    startedAt: null,
    completedAt: null,
    resultSummary: null,
    resultRemark: null,
    attachmentLink: null,
    createdAt: DateTime.parse('2026-03-20T00:00:00Z'),
    updatedAt: DateTime.parse('2026-03-20T00:00:00Z'),
  );
}

MaintenanceRecordItem _buildRecord() {
  return MaintenanceRecordItem(
    id: 31,
    workOrderId: 501,
    equipmentName: '冲压机',
    itemName: '月度润滑检查',
    dueDate: DateTime.parse('2026-03-25T00:00:00Z'),
    executorUserId: 8,
    executorUsername: 'worker',
    completedAt: DateTime.parse('2026-03-24T08:30:00Z'),
    resultSummary: '润滑正常',
    resultRemark: '无需更换耗材',
    attachmentLink: null,
    createdAt: DateTime.parse('2026-03-24T08:30:00Z'),
    updatedAt: DateTime.parse('2026-03-24T08:30:00Z'),
  );
}

EquipmentDetailResult _buildDetail() {
  return EquipmentDetailResult(
    id: 9,
    code: 'EQ-009',
    name: '冲压机',
    model: 'JH21',
    location: '一车间-A01',
    ownerName: 'zhangsan',
    remark: '重点设备',
    isEnabled: true,
    createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
    updatedAt: DateTime.parse('2026-03-20T00:00:00Z'),
    activePlanCount: 2,
    pendingWorkOrderCount: 3,
    activePlans: [_buildPlan(1), _buildPlan(2)],
    pendingWorkOrders: [_buildWorkOrder(11), _buildWorkOrder(12)],
    recentRecords: [_buildRecord()],
  );
}

Future<void> _pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 520);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: EquipmentDetailPage(
        session: AppSession(baseUrl: '', accessToken: 'token'),
        onLogout: () {},
        equipmentId: 9,
        service: _FakeEquipmentService(detail: _buildDetail()),
      ),
    ),
  );

  await tester.pump();
}

void main() {
  testWidgets('展示明确风险摘要与快捷入口，并可跳转到计划区块', (tester) async {
    await _pumpPage(tester);

    expect(find.text('设备风险提示'), findsOneWidget);
    expect(find.text('待执行工单 3'), findsOneWidget);
    expect(find.text('活跃计划 2'), findsOneWidget);
    expect(find.text('当前有3个待执行工单未收口，调整设备前请先核对到期任务与现场状态。'), findsOneWidget);
    expect(find.text('最近一次记录为2026-03-24的“月度润滑检查”，结果：润滑正常。'), findsOneWidget);
    expect(
      find.byKey(const Key('equipment-detail-shortcut-work-orders')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('equipment-detail-shortcut-records')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('equipment-detail-shortcut-plans')),
      findsOneWidget,
    );

    final listView = tester.widget<ListView>(find.byType(ListView));
    final controller = listView.controller!;
    expect(controller.offset, 0);

    await tester.tap(find.byKey(const Key('equipment-detail-shortcut-plans')));
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(0));
    expect(find.text('关联计划'), findsOneWidget);
  });
}
