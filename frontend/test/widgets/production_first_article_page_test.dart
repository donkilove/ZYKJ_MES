import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/production/presentation/production_first_article_page.dart';
import 'package:mes_client/features/production/services/production_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class _FakeProductionFirstArticleService extends ProductionService {
  _FakeProductionFirstArticleService()
    : super(AppSession(baseUrl: '', accessToken: ''));

  _ReviewDraft? lastReviewDraft;
  FirstArticleReviewSessionResult reviewSessionResult =
      FirstArticleReviewSessionResult(
        sessionId: 88,
        reviewUrl: '/first-article-review?token=abc',
        expiresAt: DateTime.parse('2026-04-25T12:05:00Z'),
        status: 'pending',
        firstArticleRecordId: null,
        reviewerUserId: null,
        reviewedAt: null,
        reviewRemark: null,
      );
  FirstArticleReviewSessionResult statusResult =
      FirstArticleReviewSessionResult(
        sessionId: 88,
        reviewUrl: null,
        expiresAt: DateTime.parse('2026-04-25T12:05:00Z'),
        status: 'pending',
        firstArticleRecordId: null,
        reviewerUserId: null,
        reviewedAt: null,
        reviewRemark: null,
      );

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
  Future<FirstArticleReviewSessionResult> createFirstArticleReviewSession({
    required int orderId,
    required int orderProcessId,
    required int? pipelineInstanceId,
    required int? templateId,
    required String checkContent,
    required String testValue,
    required List<int> participantUserIds,
    required int? assistAuthorizationId,
  }) async {
    lastReviewDraft = _ReviewDraft(
      orderId: orderId,
      orderProcessId: orderProcessId,
      pipelineInstanceId: pipelineInstanceId,
      templateId: templateId,
      checkContent: checkContent,
      testValue: testValue,
      participantUserIds: participantUserIds,
      assistAuthorizationId: assistAuthorizationId,
    );
    return reviewSessionResult;
  }

  @override
  Future<FirstArticleReviewSessionResult> getFirstArticleReviewSessionStatus({
    required int orderId,
    required int sessionId,
  }) async {
    return statusResult;
  }
}

class _ReviewDraft {
  const _ReviewDraft({
    required this.orderId,
    required this.orderProcessId,
    required this.pipelineInstanceId,
    required this.templateId,
    required this.checkContent,
    required this.testValue,
    required this.participantUserIds,
    required this.assistAuthorizationId,
  });

  final int orderId;
  final int orderProcessId;
  final int? pipelineInstanceId;
  final int? templateId;
  final String checkContent;
  final String testValue;
  final List<int> participantUserIds;
  final int? assistAuthorizationId;
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
  testWidgets('独立首件录入页发起扫码复核并显示等待状态', (tester) async {
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

    expect(find.text('首件检验码'), findsNothing);
    expect(find.text('不合格'), findsNothing);

    await tester.ensureVisible(find.widgetWithText(FilledButton, '发起扫码复核'));
    await tester.tap(find.widgetWithText(FilledButton, '发起扫码复核'));
    await tester.pump();

    expect(find.text('等待质检扫码复核'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('刷新二维码'), findsOneWidget);
    expect(find.text('/first-article-review?token=abc'), findsOneWidget);
    expect(service.lastReviewDraft, isNotNull);
    expect(service.lastReviewDraft?.templateId, 7);
    expect(service.lastReviewDraft?.checkContent, '模板检验内容');
    expect(service.lastReviewDraft?.testValue, '9.86');
    expect(service.lastReviewDraft?.participantUserIds, [8, 9]);
    expect(service.lastReviewDraft?.pipelineInstanceId, 501);
    expect(service.lastReviewDraft?.assistAuthorizationId, 99);

    service.statusResult = FirstArticleReviewSessionResult(
      sessionId: 88,
      reviewUrl: null,
      expiresAt: DateTime.parse('2026-04-25T12:05:00Z'),
      status: 'approved',
      firstArticleRecordId: 77,
      reviewerUserId: 3,
      reviewedAt: DateTime.parse('2026-04-25T12:02:00Z'),
      reviewRemark: null,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();

    expect(find.text('首件扫码复核已通过'), findsOneWidget);
  });
}
