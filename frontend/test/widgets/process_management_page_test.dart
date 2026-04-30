import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/craft/presentation/process_management_page.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';

class _FakeCraftService extends CraftService {
  _FakeCraftService() : super(AppSession(baseUrl: '', accessToken: ''));

  final List<CraftStageItem> _stages = [
    CraftStageItem(
      id: 1,
      code: 'CUT',
      name: '切割段',
      sortOrder: 1,
      isEnabled: true,
      processCount: 1,
      createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
      updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
    ),
  ];
  final List<CraftProcessItem> _processes = [
    CraftProcessItem(
      id: 11,
      code: 'CUT-01',
      name: '激光切割',
      stageId: 1,
      stageCode: 'CUT',
      stageName: '切割段',
      isEnabled: true,
      createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
      updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
    ),
  ];

  int createProcessCalls = 0;
  int deleteProcessCalls = 0;
  CraftProcessItem? lastCreatedProcess;
  int? lastDeletedProcessId;

  @override
  Future<CraftStageListResult> listStages({
    int page = 1,
    int pageSize = 200,
    String? keyword,
    bool? enabled,
  }) async {
    return CraftStageListResult(total: _stages.length, items: List.of(_stages));
  }

  @override
  Future<CraftProcessListResult> listProcesses({
    int page = 1,
    int pageSize = 500,
    String? keyword,
    int? stageId,
    bool? enabled,
  }) async {
    return CraftProcessListResult(
      total: _processes.length,
      items: List.of(_processes),
    );
  }

  @override
  Future<CraftProcessItem> createProcess({
    required String code,
    required String name,
    required int stageId,
    String remark = '',
  }) async {
    createProcessCalls += 1;
    final created = CraftProcessItem(
      id: 20,
      code: code,
      name: name,
      stageId: stageId,
      stageCode: 'CUT',
      stageName: '切割段',
      isEnabled: true,
      remark: remark,
      createdAt: DateTime.parse('2026-03-02T00:00:00Z'),
      updatedAt: DateTime.parse('2026-03-02T00:00:00Z'),
    );
    lastCreatedProcess = created;
    _processes.add(created);
    return created;
  }

  @override
  Future<void> deleteProcess({required int processId}) async {
    deleteProcessCalls += 1;
    lastDeletedProcessId = processId;
    _processes.removeWhere((item) => item.id == processId);
  }

  @override
  Future<CraftProcessReferenceResult> getProcessReferences({
    required int processId,
  }) async {
    return CraftProcessReferenceResult(
      processId: processId,
      processCode: 'CUT-01',
      processName: '激光切割',
      total: 1,
      items: [
        CraftReferenceItem(
          refType: 'template',
          refId: 21,
          refCode: 'TPL-21',
          refName: '切割模板',
          detail: 'published',
        ),
      ],
    );
  }
}

Future<void> _pumpProcessManagementPage(
  WidgetTester tester, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProcessManagementPage(
          session: AppSession(baseUrl: '', accessToken: ''),
          onLogout: () {},
          canWrite: true,
          craftService: _FakeCraftService(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('默认进入工序主视图并显示视图切换按钮', (tester) async {
    await _pumpProcessManagementPage(tester, size: const Size(1400, 1200));

    expect(tester.takeException(), isNull);
    expect(find.byType(MesPageHeader), findsOneWidget);
    expect(find.byKey(const ValueKey('process-management-feedback-banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('process-management-view-switch')), findsOneWidget);
    expect(find.byKey(const ValueKey('process-item-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('process-stage-panel')), findsNothing);
    expect(find.byKey(const ValueKey('process-focus-panel')), findsNothing);
    expect(find.text('全部状态'), findsNothing);
    expect(find.byTooltip('导出工段'), findsNothing);
    expect(find.byTooltip('导出工序'), findsNothing);
  });

  testWidgets('点击工段列表按钮后切换到工段视图', (tester) async {
    await _pumpProcessManagementPage(tester, size: const Size(1400, 1200));

    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('process-view-switch-stage')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('process-stage-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('process-item-panel')),
      findsNothing,
    );
  });

  testWidgets('工序管理引用弹窗展示编码字段', (tester) async {
    await _pumpProcessManagementPage(tester, size: const Size(1600, 1200));

    await tester.tap(find.text('操作').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看引用').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('process-reference-dialog')), findsOneWidget);
    expect(find.text('工序引用分析：激光切割'), findsOneWidget);
    expect(find.textContaining('编码/编号：TPL-21'), findsOneWidget);
  });

  testWidgets('jump 命中工序时自动停留在工序视图并展示反馈横幅', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProcessManagementPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canWrite: true,
            craftService: _FakeCraftService(),
            processId: 11,
            jumpRequestId: 1,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('process-management-feedback-banner')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('process-management-view-switch')), findsOneWidget);
    expect(find.byKey(const ValueKey('process-item-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('process-stage-panel')), findsNothing);
    expect(find.textContaining('已定位工序 #11 激光切割'), findsOneWidget);
    expect(find.text('CUT-01'), findsOneWidget);
  });

  testWidgets('工序管理支持新增与删除工序', (tester) async {
    final craftService = _FakeCraftService();
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProcessManagementPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canWrite: true,
            craftService: craftService,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(
      find.byKey(const ValueKey('process-management-create-process-button')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '工序编码序号（两位）'),
      '02',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '小工序名称'), '折弯');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(craftService.createProcessCalls, 1);
    expect(craftService.lastCreatedProcess?.code, 'CUT-02');
    expect(find.text('折弯'), findsOneWidget);

    await tester.tap(find.text('操作').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(craftService.deleteProcessCalls, 1);
    expect(craftService.lastDeletedProcessId, 20);
    expect(find.text('折弯'), findsNothing);
  });
}
