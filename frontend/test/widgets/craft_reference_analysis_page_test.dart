import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/craft_models.dart';
import 'package:mes_client/pages/craft_reference_analysis_page.dart';
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
    return CraftProcessListResult(total: 0, items: const []);
  }

  @override
  Future<CraftTemplateListResult> listTemplates({
    int page = 1,
    int pageSize = 500,
    int? productId,
    String? keyword,
    bool? enabled = true,
    String? lifecycleStatus,
  }) async {
    return CraftTemplateListResult(total: 0, items: const []);
  }

  @override
  Future<CraftStageReferenceResult> getStageReferences({
    required int stageId,
  }) async {
    return CraftStageReferenceResult(
      stageId: stageId,
      stageCode: 'CUT',
      stageName: '切割段',
      total: 1,
      items: [
        CraftReferenceItem(
          refType: 'process',
          refId: 11,
          refCode: 'CUT-01',
          refName: '激光切割',
          detail: '模板步骤引用',
          jumpModule: 'craft',
          jumpTarget: 'process-management?process_id=11',
          refStatus: '正在使用',
        ),
      ],
    );
  }
}

void main() {
  testWidgets('引用分析页展示编码字段并支持跳转', (tester) async {
    String? capturedModuleCode;
    String? capturedJumpTarget;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CraftReferenceAnalysisPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            craftService: _FakeCraftService(),
            onNavigate: ({required String moduleCode, String? jumpTarget}) {
              capturedModuleCode = moduleCode;
              capturedJumpTarget = jumpTarget;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('切割段'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('编码/编号：CUT-01'), findsOneWidget);
    await tester.tap(find.text('跳转工艺模块'));
    await tester.pumpAndSettle();

    expect(capturedModuleCode, 'craft');
    expect(capturedJumpTarget, 'process-management?process_id=11');
  });
}
