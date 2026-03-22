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
    String? productCategory,
    bool? isDefault,
    bool? enabled = true,
    String? lifecycleStatus,
    DateTime? updatedFrom,
    DateTime? updatedTo,
  }) async {
    return CraftTemplateListResult(
      total: 1,
      items: [
        CraftTemplateItem(
          id: 21,
          productId: 5,
          productName: '产品A',
          templateName: '模板A',
          version: 2,
          lifecycleStatus: 'published',
          publishedVersion: 2,
          isDefault: true,
          isEnabled: true,
          createdByUserId: 1,
          createdByUsername: 'planner',
          updatedByUserId: 1,
          updatedByUsername: 'planner',
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<CraftTemplateReferenceResult> getTemplateReferences({
    required int templateId,
  }) async {
    return CraftTemplateReferenceResult(
      templateId: templateId,
      templateName: '模板A',
      productId: 5,
      productName: '产品A',
      total: 2,
      orderReferenceCount: 1,
      userStageReferenceCount: 1,
      templateReuseReferenceCount: 1,
      blockingReferenceCount: 1,
      hasBlockingReferences: true,
      items: [
        CraftReferenceItem(
          refType: 'user_stage',
          refId: 31,
          refCode: 'operator_a',
          refName: '操作员A',
          detail: '工段：CUT 切割段',
          jumpModule: 'user',
          jumpTarget: 'user-management?user_id=31',
          refStatus: '正在使用',
          riskLevel: 'medium',
        ),
        CraftReferenceItem(
          refType: 'template_reuse',
          refId: 22,
          refCode: 'TMP-22',
          refName: '模板B',
          detail: '复用到 产品B · published',
          jumpModule: 'craft',
          jumpTarget: 'process-configuration?template_id=22',
          refStatus: '正在使用',
        ),
      ],
    );
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

  testWidgets('按模板查询纳入模板复用下游关系', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CraftReferenceAnalysisPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            craftService: _FakeCraftService(),
            onNavigate: ({required String moduleCode, String? jumpTarget}) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('模板'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('模板A'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('用户工段 1'), findsOneWidget);
    expect(find.text('模板复用 1'), findsOneWidget);
    expect(find.text('阻断 1'), findsOneWidget);
    expect(find.textContaining('operator_a'), findsOneWidget);
  });
}
