import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/production/presentation/production_assist_records_page.dart';
import 'package:mes_client/features/production/presentation/widgets/production_assist_record_detail_dialog.dart';
import 'package:mes_client/features/production/services/production_service.dart';

class _FakeAssistRecordsService extends ProductionService {
  _FakeAssistRecordsService() : super(AppSession(baseUrl: '', accessToken: ''));

  String? lastOrderCode;
  final List<String?> listStatusHistory = <String?>[];
  final List<int> listPageHistory = <int>[];

  @override
  Future<AssistAuthorizationListResult> listAssistAuthorizations({
    required int page,
    required int pageSize,
    String? status,
    DateTime? createdAtFrom,
    DateTime? createdAtTo,
    String? helperUsername,
    String? orderCode,
    String? processName,
    String? requesterUsername,
  }) async {
    listPageHistory.add(page);
    listStatusHistory.add(status);
    lastOrderCode = orderCode;
    if (status == null) {
      return AssistAuthorizationListResult(
        total: 401,
        items: [
          AssistAuthorizationItem(
            id: 2,
            orderId: 101,
            orderCode: 'PO-ASSIST-2',
            orderProcessId: 12,
            processCode: '01-02',
            processName: '焊接',
            targetOperatorUserId: 18,
            targetOperatorUsername: 'operator-b',
            requesterUserId: 19,
            requesterUsername: 'requester-b',
            helperUserId: 20,
            helperUsername: 'helper-b',
            status: 'approved',
            reason: '已审批记录',
            reviewRemark: '同意代班',
            reviewerUserId: 1,
            reviewerUsername: 'admin',
            reviewedAt: DateTime(2026, 3, 1, 9),
            firstArticleUsedAt: null,
            endProductionUsedAt: null,
            consumedAt: null,
            createdAt: DateTime(2026, 3, 1, 8),
            updatedAt: DateTime(2026, 3, 1, 9),
          ),
        ],
      );
    }
    return AssistAuthorizationListResult(
      total: 401,
      items: [
        AssistAuthorizationItem(
          id: page == 1 ? 1 : 200 + page,
          orderId: 100,
          orderCode: page == 1 ? 'PO-ASSIST-1' : 'PO-ASSIST-$page',
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
}

void main() {
  testWidgets('assist records consumes payload and auto opens detail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = _FakeAssistRecordsService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionAssistRecordsPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canViewRecords: true,
            routePayloadJson: '{"action":"detail","authorization_id":2}',
            service: service,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(service.listStatusHistory, <String?>[null, null]);
    expect(find.text('代班记录详情'), findsOneWidget);
    expect(find.text('PO-ASSIST-2'), findsWidgets);
    expect(find.text('已生效'), findsWidgets);
  });

  testWidgets('assist records page only keeps detail action', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionAssistRecordsPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canViewRecords: true,
            service: _FakeAssistRecordsService(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('状态筛选'), findsNothing);
    expect(find.text('代班审批已取消，发起后将直接生效。本页仅用于记录查询与详情查看。'), findsNothing);
    expect(find.widgetWithText(TextButton, '详情'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '通过'), findsNothing);
    expect(find.widgetWithText(TextButton, '拒绝'), findsNothing);
  });

  testWidgets('assist records pagination changes page and query resets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = _FakeAssistRecordsService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionAssistRecordsPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canViewRecords: true,
            service: service,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('第 1 / 3 页'), findsOneWidget);
    expect(service.listPageHistory.last, 1);

    await tester.tap(find.widgetWithText(OutlinedButton, '下一页'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('第 2 / 3 页'), findsOneWidget);
    expect(service.listPageHistory.last, 2);
    expect(find.text('PO-ASSIST-2'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '上一页'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('第 1 / 3 页'), findsOneWidget);
    expect(service.listPageHistory.last, 1);

    await tester.enterText(find.byType(TextField).first, 'PO-RESET');
    await tester.tap(find.widgetWithText(FilledButton, '查询'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(service.lastOrderCode, 'PO-RESET');
    expect(service.listPageHistory.last, 1);
    expect(find.text('第 1 / 3 页'), findsOneWidget);
  });

  testWidgets('代班记录详情弹窗展示统一骨架', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionAssistRecordDetailDialog(
            item: AssistAuthorizationItem(
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
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('production-assist-record-detail-dialog')),
      findsOneWidget,
    );
    expect(find.text('代班记录详情'), findsOneWidget);
    expect(find.text('PO-ASSIST-1'), findsWidgets);
  });
}
