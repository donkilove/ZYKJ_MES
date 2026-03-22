import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/craft_models.dart';
import 'package:mes_client/pages/process_management_page.dart';
import 'package:mes_client/services/craft_service.dart';

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

void main() {
  testWidgets('工序管理引用弹窗展示编码字段', (tester) async {
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
            craftService: _FakeCraftService(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('操作').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看引用').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('工序引用分析：激光切割'), findsOneWidget);
    expect(find.textContaining('编码/编号：TPL-21'), findsOneWidget);
  });
}
