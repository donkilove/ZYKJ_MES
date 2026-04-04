import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/production_models.dart';
import 'package:mes_client/pages/production_first_article_page.dart';
import 'package:mes_client/services/production_service.dart';

class _FakeProductionFirstArticleService extends ProductionService {
  _FakeProductionFirstArticleService()
    : super(AppSession(baseUrl: '', accessToken: ''));

  FirstArticleSubmitRequestInput? lastRequest;

  @override
  Future<FirstArticleTemplateListResult> listFirstArticleTemplates({
    required int orderId,
    required int orderProcessId,
  }) async {
    return FirstArticleTemplateListResult(
      total: 1,
      items: [
        FirstArticleTemplateItem(
          id: 7,
          productId: 1,
          processCode: '01-01',
          templateName: '默认模板',
          checkContent: '模板检验内容',
          testValue: '9.86',
        ),
      ],
    );
  }

  @override
  Future<FirstArticleParticipantOptionListResult>
  listFirstArticleParticipantOptions({required int orderId}) async {
    return FirstArticleParticipantOptionListResult(
      total: 2,
      items: [
        FirstArticleParticipantOptionItem(
          id: 8,
          username: 'worker',
          fullName: '张三',
        ),
        FirstArticleParticipantOptionItem(
          id: 9,
          username: 'helper',
          fullName: '李四',
        ),
      ],
    );
  }

  @override
  Future<FirstArticleParameterListResult> getFirstArticleParameters({
    required int orderId,
    required int orderProcessId,
  }) async {
    return FirstArticleParameterListResult(
      productId: 1,
      productName: '产品A',
      parameterScope: 'effective',
      version: 2,
      versionLabel: 'v2',
      lifecycleStatus: 'active',
      total: 1,
      items: [
        FirstArticleParameterItem(
          name: '长度',
          category: '尺寸',
          type: 'text',
          value: '10mm',
          description: '参数说明',
          sortOrder: 1,
          isPreset: true,
        ),
      ],
    );
  }

  @override
  Future<ProductionActionResult> submitFirstArticle({
    required int orderId,
    required FirstArticleSubmitRequestInput request,
  }) async {
    lastRequest = request;
    return ProductionActionResult(
      orderId: orderId,
      status: 'ok',
      message: 'ok',
    );
  }
}

MyOrderItem _buildOrder() {
  return MyOrderItem(
    orderId: 1,
    orderCode: 'PO-1',
    productId: 1,
    productName: '产品A',
    supplierName: '供应商甲',
    quantity: 10,
    orderStatus: 'in_progress',
    currentProcessId: 11,
    currentStageId: 1,
    currentStageCode: '01',
    currentStageName: '切割段',
    currentProcessCode: '01-01',
    currentProcessName: '切割',
    currentProcessOrder: 1,
    processStatus: 'in_progress',
    visibleQuantity: 10,
    processCompletedQuantity: 5,
    userSubOrderId: 21,
    userAssignedQuantity: 10,
    userCompletedQuantity: 5,
    operatorUserId: 8,
    operatorUsername: 'worker',
    workView: 'own',
    assistAuthorizationId: 99,
    pipelineInstanceId: 501,
    pipelineInstanceNo: 'PIPE-501',
    pipelineModeEnabled: true,
    pipelineStartAllowed: true,
    pipelineEndAllowed: true,
    maxProducibleQuantity: 5,
    canFirstArticle: true,
    canEndProduction: true,
    canApplyAssist: true,
    canCreateManualRepair: true,
    dueDate: DateTime.parse('2026-03-10T00:00:00Z'),
    remark: '备注',
    updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
  );
}

void main() {
  testWidgets('独立首件录入页支持模板带出参数查看参与人选择与提交', (tester) async {
    final service = _FakeProductionFirstArticleService();
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ProductionFirstArticlePage(
          session: AppSession(baseUrl: '', accessToken: ''),
          onLogout: () {},
          order: _buildOrder(),
          service: service,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('首件录入'), findsOneWidget);
    expect(find.text('产品A'), findsOneWidget);
    expect(find.text('切割'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '首件模板'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('默认模板'));
    await tester.pumpAndSettle();

    expect(find.text('模板检验内容'), findsOneWidget);
    expect(find.text('9.86'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '查看参数'));
    await tester.pumpAndSettle();
    expect(find.text('长度'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '添加操作员'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('worker (张三)'));
    await tester.tap(find.text('helper (李四)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '确定'));
    await tester.pumpAndSettle();

    expect(find.text('worker (张三)'), findsOneWidget);
    expect(find.text('helper (李四)'), findsOneWidget);

    await tester.ensureVisible(find.text('不合格'));
    await tester.tap(find.text('不合格'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '首件检验码'), 'code-fa2');
    await tester.enterText(find.widgetWithText(TextField, '备注'), '首件备注');
    await tester.ensureVisible(find.widgetWithText(FilledButton, '提交首件'));
    await tester.tap(find.widgetWithText(FilledButton, '提交首件'));
    await tester.pumpAndSettle();

    expect(service.lastRequest, isNotNull);
    expect(service.lastRequest?.templateId, 7);
    expect(service.lastRequest?.checkContent, '模板检验内容');
    expect(service.lastRequest?.testValue, '9.86');
    expect(service.lastRequest?.result, 'failed');
    expect(service.lastRequest?.participantUserIds, [8, 9]);
    expect(service.lastRequest?.verificationCode, 'code-fa2');
    expect(service.lastRequest?.remark, '首件备注');
  });
}
