import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_metric_card.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';
import 'package:mes_client/features/misc/presentation/daily_first_article_page.dart';
import 'package:mes_client/features/quality/presentation/quality_page.dart';
import 'package:mes_client/features/quality/services/quality_service.dart';

class _FakeQualityService extends QualityService {
  _FakeQualityService() : super(AppSession(baseUrl: '', accessToken: ''));

  int listCalls = 0;
  int submitCalls = 0;

  @override
  Future<FirstArticleListResult> listFirstArticles({
    DateTime? date,
    String? keyword,
    String? result,
    String? productName,
    String? processCode,
    String? operatorUsername,
    int page = 1,
    int pageSize = 20,
  }) async {
    listCalls += 1;
    return FirstArticleListResult(
      queryDate: DateTime(2026, 3, 21),
      verificationCode: 'FA-001',
      verificationCodeSource: 'stored',
      total: 1,
      items: [
        FirstArticleListItem(
          id: 1,
          orderId: 10,
          orderCode: 'PO-001',
          productId: 20,
          productName: '产品A',
          orderProcessId: 30,
          processCode: 'GX-01',
          processName: '装配',
          operatorUserId: 40,
          operatorUsername: 'tester',
          result: 'failed',
          verificationDate: DateTime(2026, 3, 21),
          remark: '首件异常',
          createdAt: DateTime(2026, 3, 21, 8, 0),
        ),
      ],
    );
  }

  @override
  Future<FirstArticleDetail> getFirstArticleDetail(int recordId) async {
    return _buildDetail();
  }

  @override
  Future<FirstArticleDetail> getFirstArticleDispositionDetail(
    int recordId,
  ) async {
    return _buildDetail();
  }

  @override
  Future<void> submitDisposition({
    required int recordId,
    required String dispositionOpinion,
    required String recheckResult,
    required String finalJudgment,
    String? operator_,
  }) async {
    submitCalls += 1;
  }

  FirstArticleDetail _buildDetail() {
    return FirstArticleDetail(
      id: 1,
      verificationCode: 'FA-001',
      productionOrderId: 10,
      productionOrderCode: 'PO-001',
      productId: 20,
      productCode: 'P-001',
      productName: '产品A',
      processId: 30,
      processName: '装配',
      operatorUserId: 40,
      operatorUsername: 'tester',
      checkResult: 'failed',
      defectDescription: '尺寸偏差',
      checkAt: DateTime(2026, 3, 21, 8, 0),
      templateId: 501,
      templateName: '默认首件模板',
      checkContent: '外观、尺寸、装配确认',
      testValue: '9.86',
      participants: const [
        FirstArticleParticipantItem(
          userId: 41,
          username: 'helper_a',
          fullName: '张三',
        ),
        FirstArticleParticipantItem(userId: 42, username: 'helper_b'),
      ],
      disposition: const FirstArticleDispositionInfo(
        dispositionOpinion: '已复核',
        dispositionUsername: 'quality',
        dispositionAt: null,
        recheckResult: 'passed',
        finalJudgment: 'accept',
      ),
      dispositionHistory: const [
        FirstArticleDispositionHistoryItem(
          id: 100,
          version: 1,
          dispositionOpinion: '初次处置',
          dispositionUsername: 'quality',
          dispositionAt: null,
          recheckResult: 'failed',
          finalJudgment: 'rework',
        ),
      ],
    );
  }
}

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    _FakeQualityService service,
  ) async {
    tester.view.physicalSize = const Size(1920, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyFirstArticlePage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canViewDetail: true,
            canDispose: true,
            service: service,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('每日首件列表点击详情进入独立页面', (tester) async {
    final service = _FakeQualityService();
    await pumpPage(tester, service);

    expect(find.text('每日首件'), findsOneWidget);

    await tester.tap(find.text('详情'));
    await tester.pumpAndSettle();

    expect(find.text('首件详情 #1'), findsOneWidget);
    expect(find.text('首件基础信息'), findsOneWidget);
    expect(find.text('默认首件模板'), findsOneWidget);
    expect(find.text('外观、尺寸、装配确认'), findsOneWidget);
    expect(find.text('9.86'), findsOneWidget);
    expect(find.text('helper_a (张三)、helper_b'), findsOneWidget);
    expect(find.text('提交处置'), findsNothing);
  });

  testWidgets('每日首件页首屏使用任务工作台骨架', (tester) async {
    final service = _FakeQualityService();
    await pumpPage(tester, service);

    expect(find.byType(MesFilterBar), findsOneWidget);
    expect(find.byType(MesMetricCard), findsAtLeastNWidgets(4));
    expect(find.text('筛选控制台'), findsOneWidget);
    expect(find.text('任务总览'), findsOneWidget);
    expect(find.text('首件记录'), findsOneWidget);
    expect(find.byType(MesSectionCard), findsAtLeastNWidgets(2));
  });

  testWidgets('提交处置后返回列表并刷新', (tester) async {
    final service = _FakeQualityService();
    await pumpPage(tester, service);

    expect(service.listCalls, 1);

    final disposeButton = find.widgetWithText(TextButton, '处置');
    tester.widget<TextButton>(disposeButton).onPressed!.call();
    await tester.pumpAndSettle();

    expect(find.text('首件处置 #1'), findsOneWidget);
    expect(find.text('默认首件模板'), findsOneWidget);
    expect(find.text('helper_a (张三)、helper_b'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '提交处置'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '提交处置'));
    await tester.pumpAndSettle();

    expect(service.submitCalls, 1);
    expect(service.listCalls, 2);
    expect(find.text('每日首件'), findsOneWidget);
    expect(find.text('首件处置 #1'), findsNothing);
  });

  testWidgets('质量页透传消息 payload 后自动打开首件详情页', (tester) async {
    tester.view.physicalSize = const Size(1920, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final service = _FakeQualityService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QualityPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            visibleTabCodes: const [firstArticleManagementTabCode],
            capabilityCodes: const {
              'quality.first_articles.detail',
              'quality.first_articles.disposition',
            },
            preferredTabCode: firstArticleManagementTabCode,
            routePayloadJson: '{"action":"detail","record_id":1}',
            firstArticleService: service,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('quality-page-shell'), skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('首件详情 #1'), findsOneWidget);
    expect(find.text('首件基础信息'), findsOneWidget);
    expect(find.text('默认首件模板'), findsOneWidget);
    expect(find.text('提交处置'), findsNothing);
  });
}
