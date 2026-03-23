import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/craft_models.dart';
import 'package:mes_client/models/equipment_models.dart';
import 'package:mes_client/pages/equipment_ledger_page.dart';
import 'package:mes_client/pages/maintenance_execution_page.dart';
import 'package:mes_client/pages/maintenance_item_page.dart';
import 'package:mes_client/pages/maintenance_plan_page.dart';
import 'package:mes_client/pages/maintenance_record_page.dart';
import 'package:mes_client/services/craft_service.dart';
import 'package:mes_client/services/equipment_service.dart';
import 'package:mes_client/widgets/simple_pagination_bar.dart';

class _FakeEquipmentService extends EquipmentService {
  _FakeEquipmentService()
    : super(AppSession(baseUrl: '', accessToken: 'token'));

  int ownersRequestCount = 0;

  @override
  Future<List<EquipmentOwnerOption>> listAllOwners() async {
    ownersRequestCount += 1;
    return [EquipmentOwnerOption(userId: 7, username: 'm1', fullName: null)];
  }

  @override
  Future<EquipmentLedgerListResult> listEquipment({
    required int page,
    required int pageSize,
    String? keyword,
    bool? enabled,
    String? locationKeyword,
    String? ownerName,
  }) async {
    return EquipmentLedgerListResult(
      total: 1,
      items: [
        EquipmentLedgerItem(
          id: 1,
          code: 'EQ-001',
          name: '冲压机-A',
          model: 'JH21',
          location: '一车间-A01',
          ownerName: 'm1',
          remark: '重点设备',
          isEnabled: true,
          createdAt: DateTime.parse('2026-03-01T08:00:00Z'),
          updatedAt: DateTime.parse('2026-03-02T09:30:00Z'),
        ),
      ],
    );
  }

  @override
  Future<MaintenanceItemListResult> listMaintenanceItems({
    required int page,
    required int pageSize,
    String? keyword,
    bool? enabled,
    String? category,
  }) async {
    return MaintenanceItemListResult(
      total: 1,
      items: [
        MaintenanceItemEntry(
          id: 2,
          name: '月度润滑',
          category: '润滑',
          defaultCycleDays: 30,
          defaultDurationMinutes: 45,
          standardDescription: '按SOP执行',
          isEnabled: true,
          createdAt: DateTime.parse('2026-03-01T08:00:00Z'),
          updatedAt: DateTime.parse('2026-03-03T10:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<MaintenancePlanListResult> listMaintenancePlans({
    required int page,
    required int pageSize,
    int? equipmentId,
    int? itemId,
    bool? enabled,
    String? executionProcessCode,
    int? defaultExecutorUserId,
  }) async {
    return MaintenancePlanListResult(
      total: 1,
      items: [
        MaintenancePlanItem(
          id: 3,
          equipmentId: 1,
          equipmentName: '冲压机-A',
          itemId: 2,
          itemName: '月度润滑',
          cycleDays: 30,
          executionProcessCode: 'STAMPING',
          executionProcessName: '冲压工段',
          estimatedDurationMinutes: 45,
          startDate: DateTime.parse('2026-03-01T00:00:00Z'),
          nextDueDate: DateTime.parse('2026-03-31T00:00:00Z'),
          defaultExecutorUserId: 7,
          defaultExecutorUsername: 'm1',
          isEnabled: true,
          createdAt: DateTime.parse('2026-03-01T08:00:00Z'),
          updatedAt: DateTime.parse('2026-03-03T10:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<MaintenanceWorkOrderListResult> listExecutions({
    required int page,
    required int pageSize,
    String? keyword,
    String? status,
    bool mineOnly = false,
    DateTime? dueDateStart,
    DateTime? dueDateEnd,
    String? stageCode,
  }) async {
    return MaintenanceWorkOrderListResult(
      total: 1,
      items: [
        MaintenanceWorkOrderItem(
          id: 4,
          planId: 3,
          equipmentId: 1,
          equipmentName: '冲压机-A',
          sourceEquipmentCode: 'EQ-001',
          itemId: 2,
          itemName: '月度润滑',
          sourceItemName: '月度润滑',
          sourceExecutionProcessCode: 'STAMPING',
          dueDate: DateTime.parse('2026-03-31T00:00:00Z'),
          status: 'pending',
          executorUserId: 7,
          executorUsername: 'm1',
          startedAt: null,
          completedAt: null,
          resultSummary: null,
          resultRemark: null,
          attachmentLink: null,
          attachmentName: null,
          createdAt: DateTime.parse('2026-03-01T08:00:00Z'),
          updatedAt: DateTime.parse('2026-03-03T10:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<MaintenanceRecordListResult> listRecords({
    required int page,
    required int pageSize,
    String? keyword,
    int? executorId,
    DateTime? startDate,
    DateTime? endDate,
    String? resultSummary,
    int? equipmentId,
  }) async {
    return MaintenanceRecordListResult(
      total: 1,
      items: [
        MaintenanceRecordItem(
          id: 5,
          workOrderId: 4,
          equipmentName: '冲压机-A',
          itemName: '月度润滑',
          dueDate: DateTime.parse('2026-03-31T00:00:00Z'),
          executorUserId: 7,
          executorUsername: 'm1',
          completedAt: DateTime.parse('2026-03-31T10:00:00Z'),
          resultSummary: '完成',
          resultRemark: '执行正常',
          attachmentLink: null,
          attachmentName: null,
          createdAt: DateTime.parse('2026-03-31T10:00:00Z'),
          updatedAt: DateTime.parse('2026-03-31T10:00:00Z'),
        ),
      ],
    );
  }
}

class _FakeCraftService extends CraftService {
  _FakeCraftService() : super(AppSession(baseUrl: '', accessToken: 'token'));

  @override
  Future<CraftStageListResult> listStages({
    int page = 1,
    int pageSize = 200,
    String? keyword,
    bool? enabled,
  }) async {
    return CraftStageListResult(
      total: 1,
      items: [
        CraftStageItem(
          id: 9,
          code: 'STAMPING',
          name: '冲压工段',
          sortOrder: 1,
          isEnabled: true,
          processCount: 1,
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
    );
  }
}

Future<void> _pumpPage(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump();
}

void main() {
  final craftService = _FakeCraftService();
  final session = AppSession(baseUrl: '', accessToken: 'token');

  testWidgets('设备台账页面展示需求关键字段', (tester) async {
    final equipmentService = _FakeEquipmentService();
    await _pumpPage(
      tester,
      EquipmentLedgerPage(
        session: session,
        onLogout: () {},
        canWrite: true,
        equipmentService: equipmentService,
      ),
    );

    expect(find.text('设备编号'), findsOneWidget);
    expect(find.text('创建时间'), findsOneWidget);
    expect(find.text('更新时间'), findsOneWidget);
    expect(find.text('冲压机-A'), findsOneWidget);
  });

  testWidgets('保养项目页面按需求字段展示创建时间与更新时间', (tester) async {
    final equipmentService = _FakeEquipmentService();
    await _pumpPage(
      tester,
      MaintenanceItemPage(
        session: session,
        onLogout: () {},
        canWrite: true,
        equipmentService: equipmentService,
      ),
    );

    expect(find.text('项目分类'), findsOneWidget);
    expect(find.text('默认周期天数'), findsOneWidget);
    expect(find.text('默认预计时长'), findsOneWidget);
    expect(find.text('创建时间'), findsOneWidget);
    expect(find.text('更新时间'), findsOneWidget);
    expect(find.text('执行日期'), findsNothing);
  });

  testWidgets('保养计划页面展示执行工段与默认执行人字段', (tester) async {
    final equipmentService = _FakeEquipmentService();
    await _pumpPage(
      tester,
      MaintenancePlanPage(
        session: session,
        onLogout: () {},
        canWrite: true,
        equipmentService: equipmentService,
        craftService: craftService,
      ),
    );

    expect(find.text('保养项目'), findsOneWidget);
    expect(find.text('执行工段'), findsWidgets);
    expect(find.text('下次到期日'), findsOneWidget);
    expect(find.text('默认执行人'), findsWidgets);
    expect(find.text('冲压工段'), findsOneWidget);
    expect(equipmentService.ownersRequestCount, 1);
  });

  testWidgets('保养执行页面展示工单关键字段', (tester) async {
    final equipmentService = _FakeEquipmentService();
    await _pumpPage(
      tester,
      MaintenanceExecutionPage(
        session: session,
        onLogout: () {},
        canExecute: true,
        equipmentService: equipmentService,
        craftService: craftService,
      ),
    );

    expect(find.text('工单编号'), findsOneWidget);
    expect(find.text('到期日期'), findsOneWidget);
    expect(find.text('结果摘要'), findsOneWidget);
    expect(find.text('#4'), findsOneWidget);
  });

  testWidgets('保养记录页面展示到期日期字段', (tester) async {
    final equipmentService = _FakeEquipmentService();
    await _pumpPage(
      tester,
      MaintenanceRecordPage(
        session: session,
        onLogout: () {},
        equipmentService: equipmentService,
      ),
    );

    expect(find.text('记录编号'), findsOneWidget);
    expect(find.text('到期日期'), findsOneWidget);
    expect(find.text('完成时间'), findsOneWidget);
    expect(find.text('执行人'), findsWidgets);
    expect(find.text('执行正常'), findsOneWidget);
  });

  testWidgets('1920x1080 下展示显式分页组件', (tester) async {
    final equipmentService = _FakeEquipmentService();

    await _pumpPage(
      tester,
      EquipmentLedgerPage(
        session: session,
        onLogout: () {},
        canWrite: true,
        equipmentService: equipmentService,
      ),
    );

    expect(find.byType(SimplePaginationBar), findsOneWidget);
    expect(find.text('第 1 / 1 页'), findsOneWidget);
    expect(find.text('每页 20 条'), findsOneWidget);
  });
}
