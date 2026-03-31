import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/craft_models.dart';
import 'package:mes_client/pages/process_management_page.dart';
import 'package:mes_client/services/craft_service.dart';
import 'package:mes_client/widgets/crud_page_header.dart';

class _FakeCraftService extends CraftService {
  _FakeCraftService() : super(AppSession(baseUrl: '', accessToken: ''));

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
          id: 1,
          code: 'CUT',
          name: '切割段',
          sortOrder: 1,
          isEnabled: true,
          processCount: 1,
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
    );
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
      total: 1,
      items: [
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
      ],
    );
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
  testWidgets('中等桌面宽度下恢复左右双栏并接入公共页头', (tester) async {
    await _pumpProcessManagementPage(tester, size: const Size(1200, 1200));

    expect(tester.takeException(), isNull);
    expect(find.byType(CrudPageHeader), findsOneWidget);
    expect(find.text('全部状态'), findsNothing);
    expect(find.byTooltip('导出工段'), findsNothing);
    expect(find.byTooltip('导出工序'), findsNothing);

    final stageListTopLeft = tester.getTopLeft(find.text('工段列表'));
    final processListTopLeft = tester.getTopLeft(find.text('工序列表'));

    expect(processListTopLeft.dy, lessThan(stageListTopLeft.dy + 80));
    expect(processListTopLeft.dx, greaterThan(stageListTopLeft.dx + 80));
  });

  testWidgets('窄屏宽度下仍保持上下单栏兜底', (tester) async {
    await _pumpProcessManagementPage(tester, size: const Size(900, 1200));

    expect(tester.takeException(), isNull);

    final stageListTopLeft = tester.getTopLeft(find.text('工段列表'));
    final processListTopLeft = tester.getTopLeft(find.text('工序列表'));

    expect(processListTopLeft.dy, greaterThan(stageListTopLeft.dy + 80));
  });

  testWidgets('工序管理引用弹窗展示编码字段', (tester) async {
    await _pumpProcessManagementPage(tester, size: const Size(1600, 1200));

    await tester.tap(find.text('操作').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看引用').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('工序引用分析：激光切割'), findsOneWidget);
    expect(find.textContaining('编码/编号：TPL-21'), findsOneWidget);
  });
}
