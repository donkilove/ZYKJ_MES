import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/production_models.dart';
import 'package:mes_client/pages/production_assist_approval_page.dart';
import 'package:mes_client/services/production_service.dart';

class _FakeAssistApprovalService extends ProductionService {
  _FakeAssistApprovalService() : super(AppSession(baseUrl: '', accessToken: ''));

  int? lastAuthorizationId;
  bool? lastApprove;
  String? lastReviewRemark;

  @override
  Future<AssistAuthorizationListResult> listAssistAuthorizations({
    required int page,
    required int pageSize,
    String? status,
  }) async {
    return AssistAuthorizationListResult(
      total: 1,
      items: [
        AssistAuthorizationItem(
          id: 1,
          orderId: 100,
          orderCode: 'PO-ASSIST-1',
          orderProcessId: 11,
          processCode: '01-01',
          processName: '切割',
          targetOperatorUserId: 8,
          targetOperatorUsername: 'operator-a',
          requesterUserId: 9,
          requesterUsername: 'requester',
          helperUserId: 10,
          helperUsername: 'helper',
          status: 'pending',
          reason: '需要代班',
          reviewRemark: null,
          reviewerUserId: null,
          reviewerUsername: null,
          reviewedAt: null,
          firstArticleUsedAt: null,
          endProductionUsedAt: null,
          consumedAt: null,
          createdAt: DateTime(2026, 3, 1, 8),
          updatedAt: DateTime(2026, 3, 1, 8),
        ),
      ],
    );
  }

  @override
  Future<AssistAuthorizationItem> reviewAssistAuthorization({
    required int authorizationId,
    required bool approve,
    String? reviewRemark,
  }) async {
    lastAuthorizationId = authorizationId;
    lastApprove = approve;
    lastReviewRemark = reviewRemark;
    return AssistAuthorizationItem(
      id: authorizationId,
      orderId: 100,
      orderCode: 'PO-ASSIST-1',
      orderProcessId: 11,
      processCode: '01-01',
      processName: '切割',
      targetOperatorUserId: 8,
      targetOperatorUsername: 'operator-a',
      requesterUserId: 9,
      requesterUsername: 'requester',
      helperUserId: 10,
      helperUsername: 'helper',
      status: approve ? 'approved' : 'rejected',
      reason: '需要代班',
      reviewRemark: reviewRemark,
      reviewerUserId: 1,
      reviewerUsername: 'admin',
      reviewedAt: DateTime(2026, 3, 1, 9),
      firstArticleUsedAt: null,
      endProductionUsedAt: null,
      consumedAt: null,
      createdAt: DateTime(2026, 3, 1, 8),
      updatedAt: DateTime(2026, 3, 1, 9),
    );
  }
}

void main() {
  testWidgets('assist approval keeps remark after confirm', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = _FakeAssistApprovalService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionAssistApprovalPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canReview: true,
            service: service,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('PO-ASSIST-1'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '通过').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '  请尽快处理  ');
    await tester.tap(find.widgetWithText(FilledButton, '通过'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(service.lastAuthorizationId, 1);
    expect(service.lastApprove, isTrue);
    expect(service.lastReviewRemark, '请尽快处理');
    expect(find.text('已审批通过。'), findsOneWidget);
  });
}
