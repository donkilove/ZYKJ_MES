import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/production/presentation/production_first_article_page.dart';
import 'package:mes_client/features/production/services/production_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('操作员发起扫码复核后轮询到质检通过', (tester) async {
    final service = _ScanReviewFakeProductionService();
    await tester.binding.setSurfaceSize(const Size(1000, 1200));
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

    await tester.enterText(find.widgetWithText(TextField, '首件内容'), '外观无划伤');
    await tester.enterText(find.widgetWithText(TextField, '首件测试值'), '长度 10.01');
    await tester.ensureVisible(find.widgetWithText(FilledButton, '发起扫码复核'));
    await tester.tap(find.widgetWithText(FilledButton, '发起扫码复核'));
    await tester.pump();

    expect(find.byType(QrImageView), findsOneWidget);
    service.approveLatestSession();
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();

    expect(find.text('首件扫码复核已通过'), findsOneWidget);
  });
}

class _ScanReviewFakeProductionService extends ProductionService {
  _ScanReviewFakeProductionService()
    : super(AppSession(baseUrl: '', accessToken: ''));

  bool _approved = false;

  void approveLatestSession() {
    _approved = true;
  }

  @override
  Future<FirstArticleTemplateListResult> listFirstArticleTemplates({
    required int orderId,
    required int orderProcessId,
  }) async {
    return FirstArticleTemplateListResult(total: 0, items: const []);
  }

  @override
  Future<FirstArticleParticipantOptionListResult>
  listFirstArticleParticipantOptions({required int orderId}) async {
    return FirstArticleParticipantOptionListResult(total: 0, items: const []);
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
    return _session(
      status: 'pending',
      reviewUrl: '/first-article-review?token=abc',
    );
  }

  @override
  Future<FirstArticleReviewSessionResult> getFirstArticleReviewSessionStatus({
    required int orderId,
    required int sessionId,
  }) async {
    return _approved
        ? _session(
            status: 'approved',
            reviewUrl: null,
            firstArticleRecordId: 77,
            reviewerUserId: 3,
            reviewedAt: DateTime.parse('2026-04-25T12:02:00Z'),
          )
        : _session(status: 'pending', reviewUrl: null);
  }
}

FirstArticleReviewSessionResult _session({
  required String status,
  required String? reviewUrl,
  int? firstArticleRecordId,
  int? reviewerUserId,
  DateTime? reviewedAt,
}) {
  return FirstArticleReviewSessionResult(
    sessionId: 88,
    reviewUrl: reviewUrl,
    expiresAt: DateTime.parse('2026-04-25T12:05:00Z'),
    status: status,
    firstArticleRecordId: firstArticleRecordId,
    reviewerUserId: reviewerUserId,
    reviewedAt: reviewedAt,
    reviewRemark: null,
  );
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
    assistAuthorizationId: null,
    pipelineInstanceId: null,
    pipelineInstanceNo: null,
    pipelineModeEnabled: false,
    pipelineStartAllowed: true,
    pipelineEndAllowed: true,
    maxProducibleQuantity: 5,
    canFirstArticle: true,
    canEndProduction: true,
    canApplyAssist: false,
    canCreateManualRepair: false,
    dueDate: null,
    remark: null,
    updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
  );
}
