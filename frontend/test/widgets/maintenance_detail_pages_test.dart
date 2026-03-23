import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/equipment_models.dart';
import 'package:mes_client/pages/maintenance_execution_detail_page.dart';
import 'package:mes_client/pages/maintenance_record_detail_page.dart';
import 'package:mes_client/services/equipment_service.dart';

class _FakeEquipmentService extends EquipmentService {
  _FakeEquipmentService({
    required this.workOrderDetail,
    required this.recordDetail,
  }) : super(AppSession(baseUrl: '', accessToken: 'token'));

  final MaintenanceWorkOrderDetail workOrderDetail;
  final MaintenanceRecordDetail recordDetail;

  @override
  Future<MaintenanceWorkOrderDetail> getWorkOrderDetail({
    required int workOrderId,
  }) async {
    return workOrderDetail;
  }

  @override
  Future<MaintenanceRecordDetail> getRecordDetail({
    required int recordId,
  }) async {
    return recordDetail;
  }
}

MaintenanceWorkOrderDetail _buildWorkOrderDetail() {
  return MaintenanceWorkOrderDetail(
    id: 501,
    planId: 12,
    equipmentId: 9,
    equipmentName: '冲压机',
    sourceEquipmentCode: 'EQ-009',
    itemId: 18,
    itemName: '月度点检',
    sourceItemName: '月度点检快照',
    sourceExecutionProcessCode: 'LINE-A',
    dueDate: DateTime.parse('2026-03-27T00:00:00Z'),
    status: 'done',
    executorUserId: 3,
    executorUsername: 'maintainer',
    startedAt: DateTime.parse('2026-03-26T01:00:00Z'),
    completedAt: DateTime.parse('2026-03-26T02:30:00Z'),
    resultSummary: '全部正常',
    resultRemark: '已完成处理',
    attachmentLink: null,
    attachmentName: null,
    createdAt: DateTime.parse('2026-03-25T00:00:00Z'),
    updatedAt: DateTime.parse('2026-03-26T02:30:00Z'),
    sourcePlanId: 12,
    sourcePlanCycleDays: 30,
    sourcePlanStartDate: DateTime.parse('2026-03-01T00:00:00Z'),
    sourcePlanSummary: '月度设备点检',
    sourceEquipmentName: '冲压机快照',
    sourceItemId: 18,
    recordId: 701,
  );
}

MaintenanceRecordDetail _buildRecordDetail() {
  return MaintenanceRecordDetail(
    id: 701,
    workOrderId: 501,
    equipmentName: '冲压机',
    itemName: '月度点检',
    dueDate: DateTime.parse('2026-03-27T00:00:00Z'),
    executorUserId: 3,
    executorUsername: 'maintainer',
    completedAt: DateTime.parse('2026-03-26T02:30:00Z'),
    resultSummary: '全部正常',
    resultRemark: '记录已归档',
    attachmentLink: null,
    attachmentName: null,
    createdAt: DateTime.parse('2026-03-26T02:30:00Z'),
    updatedAt: DateTime.parse('2026-03-26T02:30:00Z'),
    sourcePlanId: 12,
    sourcePlanCycleDays: 30,
    sourcePlanStartDate: DateTime.parse('2026-03-01T00:00:00Z'),
    sourcePlanSummary: '月度设备点检',
    sourceEquipmentCode: 'EQ-009',
    sourceEquipmentName: '冲压机快照',
    sourceExecutionProcessCode: 'LINE-A',
    sourceItemId: 18,
    sourceItemName: '月度点检快照',
  );
}

Future<void> _setDesktopSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1920, 1080));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('保养执行详情页应展示桌面化摘要卡与分区卡', (tester) async {
    await _setDesktopSurface(tester);
    final service = _FakeEquipmentService(
      workOrderDetail: _buildWorkOrderDetail(),
      recordDetail: _buildRecordDetail(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MaintenanceExecutionDetailPage(
          session: AppSession(baseUrl: '', accessToken: 'token'),
          onLogout: () {},
          workOrderId: 501,
          equipmentService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('工单 #501'), findsOneWidget);
    expect(find.text('来源信息'), findsOneWidget);
    expect(find.text('执行结果'), findsOneWidget);
    expect(find.text('查看生成记录'), findsOneWidget);
    expect(find.text('全部正常'), findsOneWidget);
  });

  testWidgets('保养记录详情页应展示桌面化摘要卡与来源区块', (tester) async {
    await _setDesktopSurface(tester);
    final service = _FakeEquipmentService(
      workOrderDetail: _buildWorkOrderDetail(),
      recordDetail: _buildRecordDetail(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MaintenanceRecordDetailPage(
          session: AppSession(baseUrl: '', accessToken: 'token'),
          onLogout: () {},
          recordId: 701,
          equipmentService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('记录 #701'), findsOneWidget);
    expect(find.text('来源信息'), findsOneWidget);
    expect(find.text('执行结果'), findsOneWidget);
    expect(find.text('查看来源工单'), findsOneWidget);
    expect(find.text('记录已归档'), findsOneWidget);
  });
}
