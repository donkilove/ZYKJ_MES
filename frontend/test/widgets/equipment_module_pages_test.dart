import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';
import 'package:mes_client/features/equipment/presentation/equipment_ledger_page.dart';
import 'package:mes_client/features/equipment/presentation/maintenance_execution_page.dart';
import 'package:mes_client/features/equipment/presentation/maintenance_item_page.dart';
import 'package:mes_client/features/equipment/presentation/maintenance_plan_page.dart';
import 'package:mes_client/features/equipment/presentation/maintenance_record_page.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/equipment/services/equipment_service.dart';

class _FakeEquipmentService extends EquipmentService {
  _FakeEquipmentService({
    List<EquipmentOwnerOption>? owners,
    List<EquipmentLedgerItem>? equipmentItems,
    List<MaintenanceItemEntry>? maintenanceItems,
    List<MaintenanceWorkOrderItem>? workOrders,
  }) : _owners =
           owners ??
           [EquipmentOwnerOption(userId: 7, username: 'm1', fullName: null)],
       _equipmentItems =
           equipmentItems ??
           [
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
       _maintenanceItems =
           maintenanceItems ??
           [
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
       _workOrders =
           workOrders ??
           [
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
       super(AppSession(baseUrl: '', accessToken: 'token'));

  int ownersRequestCount = 0;
  int startExecutionCalls = 0;
  int completeExecutionCalls = 0;
  int cancelExecutionCalls = 0;
  int getWorkOrderDetailCalls = 0;
  final List<EquipmentOwnerOption> _owners;
  final List<EquipmentLedgerItem> _equipmentItems;
  final List<MaintenanceItemEntry> _maintenanceItems;
  final List<MaintenanceWorkOrderItem> _workOrders;

  @override
  Future<List<EquipmentOwnerOption>> listAllOwners() async {
    ownersRequestCount += 1;
    return _owners;
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
      total: _equipmentItems.length,
      items: _equipmentItems,
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
      total: _maintenanceItems.length,
      items: _maintenanceItems,
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
      total: _workOrders.length,
      items: List<MaintenanceWorkOrderItem>.from(_workOrders),
    );
  }

  @override
  Future<void> startExecution({required int workOrderId}) async {
    startExecutionCalls += 1;
    _replaceWorkOrder(
      workOrderId,
      (item) => MaintenanceWorkOrderItem(
        id: item.id,
        planId: item.planId,
        equipmentId: item.equipmentId,
        equipmentName: item.equipmentName,
        sourceEquipmentCode: item.sourceEquipmentCode,
        itemId: item.itemId,
        itemName: item.itemName,
        sourceItemName: item.sourceItemName,
        sourceExecutionProcessCode: item.sourceExecutionProcessCode,
        dueDate: item.dueDate,
        status: 'in_progress',
        executorUserId: item.executorUserId,
        executorUsername: item.executorUsername,
        startedAt: DateTime.parse('2026-03-31T08:00:00Z'),
        completedAt: item.completedAt,
        resultSummary: item.resultSummary,
        resultRemark: item.resultRemark,
        attachmentLink: item.attachmentLink,
        attachmentName: item.attachmentName,
        createdAt: item.createdAt,
        updatedAt: DateTime.parse('2026-03-31T08:00:00Z'),
      ),
    );
  }

  @override
  Future<void> completeExecution({
    required int workOrderId,
    required String resultSummary,
    String? resultRemark,
    String? attachmentLink,
  }) async {
    completeExecutionCalls += 1;
    _replaceWorkOrder(
      workOrderId,
      (item) => MaintenanceWorkOrderItem(
        id: item.id,
        planId: item.planId,
        equipmentId: item.equipmentId,
        equipmentName: item.equipmentName,
        sourceEquipmentCode: item.sourceEquipmentCode,
        itemId: item.itemId,
        itemName: item.itemName,
        sourceItemName: item.sourceItemName,
        sourceExecutionProcessCode: item.sourceExecutionProcessCode,
        dueDate: item.dueDate,
        status: 'done',
        executorUserId: item.executorUserId,
        executorUsername: item.executorUsername,
        startedAt: item.startedAt ?? DateTime.parse('2026-03-31T08:00:00Z'),
        completedAt: DateTime.parse('2026-03-31T09:00:00Z'),
        resultSummary: resultSummary,
        resultRemark: resultRemark,
        attachmentLink: attachmentLink,
        attachmentName: attachmentLink == null ? null : 'report.pdf',
        createdAt: item.createdAt,
        updatedAt: DateTime.parse('2026-03-31T09:00:00Z'),
      ),
    );
  }

  @override
  Future<void> cancelExecution({required int workOrderId}) async {
    cancelExecutionCalls += 1;
    _replaceWorkOrder(
      workOrderId,
      (item) => MaintenanceWorkOrderItem(
        id: item.id,
        planId: item.planId,
        equipmentId: item.equipmentId,
        equipmentName: item.equipmentName,
        sourceEquipmentCode: item.sourceEquipmentCode,
        itemId: item.itemId,
        itemName: item.itemName,
        sourceItemName: item.sourceItemName,
        sourceExecutionProcessCode: item.sourceExecutionProcessCode,
        dueDate: item.dueDate,
        status: 'cancelled',
        executorUserId: item.executorUserId,
        executorUsername: item.executorUsername,
        startedAt: item.startedAt,
        completedAt: item.completedAt,
        resultSummary: item.resultSummary,
        resultRemark: item.resultRemark,
        attachmentLink: item.attachmentLink,
        attachmentName: item.attachmentName,
        createdAt: item.createdAt,
        updatedAt: DateTime.parse('2026-03-31T09:30:00Z'),
      ),
    );
  }

  @override
  Future<MaintenanceWorkOrderDetail> getWorkOrderDetail({
    required int workOrderId,
  }) async {
    getWorkOrderDetailCalls += 1;
    final item = _workOrders.singleWhere((entry) => entry.id == workOrderId);
    return MaintenanceWorkOrderDetail(
      id: item.id,
      planId: item.planId,
      equipmentId: item.equipmentId,
      equipmentName: item.equipmentName,
      sourceEquipmentCode: item.sourceEquipmentCode,
      itemId: item.itemId,
      itemName: item.itemName,
      sourceItemName: item.sourceItemName,
      sourceExecutionProcessCode: item.sourceExecutionProcessCode,
      dueDate: item.dueDate,
      status: item.status,
      executorUserId: item.executorUserId,
      executorUsername: item.executorUsername,
      startedAt: item.startedAt,
      completedAt: item.completedAt,
      resultSummary: item.resultSummary,
      resultRemark: item.resultRemark,
      attachmentLink: item.attachmentLink,
      attachmentName: item.attachmentName,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      sourcePlanId: item.planId,
      sourcePlanCycleDays: 30,
      sourcePlanStartDate: DateTime.parse('2026-03-01T00:00:00Z'),
      sourcePlanSummary: '冲压机-A / 月度润滑',
      sourceEquipmentName: item.equipmentName,
      sourceItemId: item.itemId,
      recordId: item.status == 'done' ? 5 : null,
    );
  }

  void _replaceWorkOrder(
    int workOrderId,
    MaintenanceWorkOrderItem Function(MaintenanceWorkOrderItem item) transform,
  ) {
    final index = _workOrders.indexWhere((item) => item.id == workOrderId);
    _workOrders[index] = transform(_workOrders[index]);
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
  _FakeCraftService({List<CraftStageItem>? stages})
    : _stages =
          stages ??
          [
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
      super(AppSession(baseUrl: '', accessToken: 'token'));

  final List<CraftStageItem> _stages;

  @override
  Future<CraftStageListResult> listStages({
    int page = 1,
    int pageSize = 200,
    String? keyword,
    bool? enabled,
  }) async {
    return CraftStageListResult(total: _stages.length, items: _stages);
  }
}

EquipmentLedgerItem _buildEquipmentLedgerItem({
  required int id,
  required String code,
  required String name,
}) {
  return EquipmentLedgerItem(
    id: id,
    code: code,
    name: name,
    model: 'JH21',
    location: '一车间-A01',
    ownerName: 'm1',
    remark: '重点设备',
    isEnabled: true,
    createdAt: DateTime.parse('2026-03-01T08:00:00Z'),
    updatedAt: DateTime.parse('2026-03-02T09:30:00Z'),
  );
}

MaintenanceItemEntry _buildMaintenanceItemEntry({
  required int id,
  required String name,
}) {
  return MaintenanceItemEntry(
    id: id,
    name: name,
    category: '润滑',
    defaultCycleDays: 30,
    defaultDurationMinutes: 45,
    standardDescription: '按SOP执行',
    isEnabled: true,
    createdAt: DateTime.parse('2026-03-01T08:00:00Z'),
    updatedAt: DateTime.parse('2026-03-03T10:00:00Z'),
  );
}

MaintenanceWorkOrderItem _buildMaintenanceWorkOrderItem({
  required int id,
  required String equipmentName,
  required String itemName,
}) {
  return MaintenanceWorkOrderItem(
    id: id,
    planId: 3,
    equipmentId: 1,
    equipmentName: equipmentName,
    sourceEquipmentCode: 'EQ-001',
    itemId: 2,
    itemName: itemName,
    sourceItemName: itemName,
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
  );
}

CraftStageItem _buildCraftStageItem({
  required int id,
  required String code,
  required String name,
}) {
  return CraftStageItem(
    id: id,
    code: code,
    name: name,
    sortOrder: 1,
    isEnabled: true,
    processCount: 1,
    createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
    updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1920, 1200),
}) async {
  tester.view.physicalSize = size;
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

  testWidgets('设备台账页面在窄宽度下工具栏可稳定渲染', (tester) async {
    final equipmentService = _FakeEquipmentService();
    await _pumpPage(
      tester,
      EquipmentLedgerPage(
        session: session,
        onLogout: () {},
        canWrite: true,
        equipmentService: equipmentService,
      ),
      size: const Size(900, 1200),
    );

    expect(find.text('搜索设备编号/名称/型号/位置/负责人'), findsOneWidget);
    expect(find.text('位置筛选'), findsOneWidget);
    expect(find.text('新增设备'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('设备台账页面负责人长文本下拉展开与选中不抛异常', (tester) async {
    final equipmentService = _FakeEquipmentService(
      owners: [
        EquipmentOwnerOption(
          userId: 7,
          username: 'admin',
          fullName: 'system admin with a very long display name',
        ),
      ],
    );
    await _pumpPage(
      tester,
      EquipmentLedgerPage(
        session: session,
        onLogout: () {},
        canWrite: true,
        equipmentService: equipmentService,
      ),
      size: const Size(900, 1200),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await tester.tap(find.textContaining('admin (system admin').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('admin (system admin'), findsWidgets);
    expect(tester.takeException(), isNull);
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

  testWidgets('保养计划页面长文本筛选下拉展开与选中不抛异常', (tester) async {
    final equipmentService = _FakeEquipmentService(
      owners: [
        EquipmentOwnerOption(
          userId: 7,
          username: 'executor_admin',
          fullName:
              'maintenance default executor with a very long display name',
        ),
      ],
      equipmentItems: [
        _buildEquipmentLedgerItem(
          id: 1,
          code: 'EQ-ULTRA-LONG-0001',
          name: '超长设备名称用于验证保养计划筛选下拉选中态不会出现布局溢出',
        ),
      ],
      maintenanceItems: [
        _buildMaintenanceItemEntry(
          id: 2,
          name: '超长保养项目名称用于验证项目筛选下拉在窄空间中仍能稳定显示',
        ),
      ],
    );
    final longStageName = '超长执行工段名称用于验证保养计划页面工段筛选下拉不会触发溢出';
    final customCraftService = _FakeCraftService(
      stages: [
        _buildCraftStageItem(id: 9, code: 'STAMPING', name: longStageName),
      ],
    );

    await _pumpPage(
      tester,
      MaintenancePlanPage(
        session: session,
        onLogout: () {},
        canWrite: true,
        equipmentService: equipmentService,
        craftService: customCraftService,
      ),
      size: const Size(1500, 1200),
    );

    await tester.tap(find.byType(DropdownButtonFormField<int?>).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.textContaining('EQ-ULTRA-LONG-0001').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int?>).at(1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.textContaining('超长保养项目名称').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.textContaining('超长执行工段名称').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int?>).at(2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.textContaining('executor_admin').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('EQ-ULTRA-LONG-0001'), findsWidgets);
    expect(find.textContaining('超长保养项目名称'), findsWidgets);
    expect(find.textContaining('超长执行工段名称'), findsWidgets);
    expect(find.textContaining('executor_admin'), findsWidgets);
    expect(tester.takeException(), isNull);
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

  testWidgets('保养执行页面工段长文本下拉展开与选中不抛异常', (tester) async {
    final equipmentService = _FakeEquipmentService(
      workOrders: [
        _buildMaintenanceWorkOrderItem(
          id: 4,
          equipmentName: '冲压机-A',
          itemName: '月度润滑',
        ),
      ],
    );
    final customCraftService = _FakeCraftService(
      stages: [
        _buildCraftStageItem(
          id: 9,
          code: 'STAMPING',
          name: '超长工段名称用于验证保养执行页面筛选下拉选中态不会出现布局溢出',
        ),
      ],
    );

    await _pumpPage(
      tester,
      MaintenanceExecutionPage(
        session: session,
        onLogout: () {},
        canExecute: true,
        equipmentService: equipmentService,
        craftService: customCraftService,
      ),
      size: const Size(1200, 1200),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String?>).last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await tester.tap(find.textContaining('超长工段名称').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('超长工段名称'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('保养执行页面可完成开始执行与详情跳转', (tester) async {
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

    await tester.tap(find.byKey(const Key('maintenance-execution-start-4')));
    await tester.pumpAndSettle();

    expect(equipmentService.startExecutionCalls, 1);
    expect(find.text('执行中'), findsOneWidget);

    await tester.tap(find.byKey(const Key('maintenance-execution-detail-4')));
    await tester.pumpAndSettle();

    expect(equipmentService.getWorkOrderDetailCalls, 1);
    expect(find.text('保养执行详情 #4'), findsOneWidget);
    expect(find.text('冲压机-A / 月度润滑'), findsOneWidget);
  });

  testWidgets('保养执行页面可完成完成执行', (tester) async {
    final inProgressService = _FakeEquipmentService(
      workOrders: [
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
          status: 'in_progress',
          executorUserId: 7,
          executorUsername: 'm1',
          startedAt: DateTime.parse('2026-03-31T08:00:00Z'),
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

    await _pumpPage(
      tester,
      MaintenanceExecutionPage(
        session: session,
        onLogout: () {},
        canExecute: true,
        equipmentService: inProgressService,
        craftService: craftService,
      ),
    );

    await tester.tap(find.byKey(const Key('maintenance-execution-complete-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '提交'));
    await tester.pumpAndSettle();

    expect(inProgressService.completeExecutionCalls, 1);
    expect(
      inProgressService
          .listExecutions(page: 1, pageSize: 30)
          .then((result) => result.items.single.status),
      completion('done'),
    );
  });

  testWidgets('保养执行页面可取消工单', (tester) async {
    final pendingService = _FakeEquipmentService();
    await _pumpPage(
      tester,
      MaintenanceExecutionPage(
        session: session,
        onLogout: () {},
        canExecute: true,
        equipmentService: pendingService,
        craftService: craftService,
      ),
    );

    await tester.tap(find.byKey(const Key('maintenance-execution-cancel-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确认'));
    await tester.pumpAndSettle();

    expect(pendingService.cancelExecutionCalls, 1);
    expect(find.text('已取消'), findsOneWidget);
  });

  testWidgets('保养执行页面可根据 jump payload 直达详情', (tester) async {
    final equipmentService = _FakeEquipmentService();

    await _pumpPage(
      tester,
      MaintenanceExecutionPage(
        session: session,
        onLogout: () {},
        canExecute: true,
        equipmentService: equipmentService,
        craftService: craftService,
        jumpPayloadJson: '{"action":"detail","work_order_id":4}',
      ),
    );
    await tester.pumpAndSettle();

    expect(equipmentService.getWorkOrderDetailCalls, 1);
    expect(find.text('保养执行详情 #4'), findsOneWidget);
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
}
