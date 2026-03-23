import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/craft_models.dart';
import 'package:mes_client/pages/process_management_page.dart';
import 'package:mes_client/services/craft_service.dart';

class _FakeCraftService extends CraftService {
  _FakeCraftService({
    List<CraftStageItem>? stages,
    List<CraftProcessItem>? processes,
  }) : _stages = stages ?? _defaultStages,
       _processes = processes ?? _defaultProcesses,
       super(AppSession(baseUrl: '', accessToken: ''));

  static final List<CraftStageItem> _defaultStages = [
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

  static final List<CraftProcessItem> _defaultProcesses = [
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

  final List<CraftStageItem> _stages;
  final List<CraftProcessItem> _processes;

  @override
  Future<CraftStageListResult> listStages({
    int page = 1,
    int pageSize = 200,
    String? keyword,
    bool? enabled,
  }) async {
    return CraftStageListResult(total: _stages.length, items: _stages);
  }

  @override
  Future<CraftProcessListResult> listProcesses({
    int page = 1,
    int pageSize = 500,
    String? keyword,
    int? stageId,
    bool? enabled,
  }) async {
    return CraftProcessListResult(total: _processes.length, items: _processes);
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

Future<void> _pumpPage(
  WidgetTester tester, {
  required CraftService service,
  int? processId,
  int jumpRequestId = 0,
}) async {
  tester.view.physicalSize = const Size(1920, 1080);
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
          craftService: service,
          processId: processId,
          jumpRequestId: jumpRequestId,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

List<CraftStageItem> _buildStages(int count) {
  return List.generate(count, (index) {
    final sequence = index + 1;
    return CraftStageItem(
      id: sequence,
      code: 'STG-${sequence.toString().padLeft(2, '0')}',
      name: '工段$sequence',
      sortOrder: sequence,
      isEnabled: sequence.isOdd,
      processCount: 12,
      createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
      updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
    );
  });
}

List<CraftProcessItem> _buildProcesses({
  required int count,
  required int stageId,
  required String stageCode,
  required String stageName,
}) {
  return List.generate(count, (index) {
    final sequence = index + 1;
    return CraftProcessItem(
      id: sequence,
      code: '$stageCode-${sequence.toString().padLeft(2, '0')}',
      name: '工序$sequence',
      stageId: stageId,
      stageCode: stageCode,
      stageName: stageName,
      isEnabled: sequence.isOdd,
      createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
      updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
    );
  });
}

void main() {
  testWidgets('工序管理引用弹窗展示编码字段', (tester) async {
    await _pumpPage(tester, service: _FakeCraftService());

    await tester.tap(find.text('操作').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看引用').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('工序引用分析：激光切割'), findsOneWidget);
    expect(find.textContaining('编码/编号：TPL-21'), findsOneWidget);
  });

  testWidgets('桌面布局支持双区分页和筛选重置', (tester) async {
    final stages = _buildStages(12);
    final processes = _buildProcesses(
      count: 12,
      stageId: 1,
      stageCode: stages.first.code,
      stageName: stages.first.name,
    );

    await _pumpPage(
      tester,
      service: _FakeCraftService(stages: stages, processes: processes),
    );

    expect(find.text('工段列表'), findsOneWidget);
    expect(find.text('工序列表'), findsOneWidget);
    expect(find.text('STG-11'), findsNothing);

    await tester.tap(find.text('下一页').first);
    await tester.pumpAndSettle();

    expect(find.text('STG-11'), findsOneWidget);
    expect(find.text('STG-12'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('process-management-process-search')),
      '不存在的工序',
    );
    await tester.tap(
      find.byKey(const Key('process-management-process-search-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂无小工序'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('process-management-process-reset-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('STG-01-01'), findsOneWidget);
  });

  testWidgets('工序跳转保持联动过滤并定位到正确分页', (tester) async {
    final stages = [
      CraftStageItem(
        id: 1,
        code: 'CUT',
        name: '切割段',
        sortOrder: 1,
        isEnabled: true,
        processCount: 12,
        createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
        updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
      ),
    ];
    final processes = _buildProcesses(
      count: 12,
      stageId: 1,
      stageCode: 'CUT',
      stageName: '切割段',
    );

    await _pumpPage(
      tester,
      service: _FakeCraftService(stages: stages, processes: processes),
      processId: 11,
      jumpRequestId: 1,
    );

    expect(find.textContaining('已定位工序 #11 工序11'), findsOneWidget);
    expect(find.text('第 2 / 2 页'), findsOneWidget);
    expect(find.text('CUT-11'), findsOneWidget);
    expect(find.text('CUT-01'), findsNothing);
  });
}
