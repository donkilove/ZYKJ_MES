import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/quality_models.dart';
import 'package:mes_client/pages/quality_trend_page.dart';
import 'package:mes_client/services/quality_service.dart';

class _FakeQualityTrendService extends QualityService {
  _FakeQualityTrendService() : super(AppSession(baseUrl: '', accessToken: ''));

  int trendCalls = 0;
  int overviewCalls = 0;
  int productCalls = 0;
  int processCalls = 0;
  int operatorCalls = 0;

  @override
  Future<List<QualityTrendItem>> getQualityTrend({
    DateTime? startDate,
    DateTime? endDate,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async {
    trendCalls += 1;
    return const [
      QualityTrendItem(
        date: '2026-03-01',
        firstArticleTotal: 10,
        passedTotal: 8,
        failedTotal: 2,
        passRatePercent: 80,
        defectTotal: 3,
        scrapTotal: 1,
        repairTotal: 1,
      ),
      QualityTrendItem(
        date: '2026-03-02',
        firstArticleTotal: 5,
        passedTotal: 4,
        failedTotal: 1,
        passRatePercent: 80,
        defectTotal: 2,
        scrapTotal: 1,
        repairTotal: 2,
      ),
    ];
  }

  @override
  Future<QualityStatsOverview> getQualityOverview({
    DateTime? startDate,
    DateTime? endDate,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async {
    overviewCalls += 1;
    return QualityStatsOverview(
      firstArticleTotal: 15,
      passedTotal: 12,
      failedTotal: 3,
      passRatePercent: 80,
      coveredOrderCount: 3,
      coveredProcessCount: 2,
      coveredOperatorCount: 2,
      latestFirstArticleAt: DateTime(2026, 3, 2, 8),
    );
  }

  @override
  Future<List<QualityProductStatItem>> getQualityProductStats({
    DateTime? startDate,
    DateTime? endDate,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async {
    productCalls += 1;
    return const [
      QualityProductStatItem(
        productId: 1,
        productCode: 'P-001',
        productName: '产品A',
        firstArticleTotal: 10,
        passedTotal: 8,
        failedTotal: 2,
        passRatePercent: 80,
        scrapTotal: 1,
        repairTotal: 2,
      ),
    ];
  }

  @override
  Future<List<QualityProcessStatItem>> getQualityProcessStats({
    DateTime? startDate,
    DateTime? endDate,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async {
    processCalls += 1;
    return [
      QualityProcessStatItem(
        processCode: 'GX-01',
        processName: '装配',
        firstArticleTotal: 8,
        passedTotal: 6,
        failedTotal: 2,
        passRatePercent: 75,
        latestFirstArticleAt: DateTime(2026, 3, 2, 8),
      ),
    ];
  }

  @override
  Future<List<QualityOperatorStatItem>> getQualityOperatorStats({
    DateTime? startDate,
    DateTime? endDate,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async {
    operatorCalls += 1;
    return [
      QualityOperatorStatItem(
        operatorUserId: 7,
        operatorUsername: '张三',
        firstArticleTotal: 7,
        passedTotal: 6,
        failedTotal: 1,
        passRatePercent: 85.7,
        latestFirstArticleAt: DateTime(2026, 3, 2, 8),
      ),
    ];
  }
}

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    _FakeQualityTrendService service,
  ) async {
    tester.view.physicalSize = const Size(1600, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QualityTrendPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            service: service,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('质量趋势页展示摘要卡与维度对比', (tester) async {
    final service = _FakeQualityTrendService();

    await pumpPage(tester, service);

    expect(service.trendCalls, 1);
    expect(service.overviewCalls, 1);
    expect(service.productCalls, 1);
    expect(service.processCalls, 1);
    expect(service.operatorCalls, 1);

    expect(find.text('整体通过率'), findsOneWidget);
    expect(find.text('80.0%'), findsWidgets);
    expect(find.text('不良总数'), findsOneWidget);
    expect(find.text('5'), findsWidgets);
    expect(find.text('报废率'), findsOneWidget);
    expect(find.text('13.3%'), findsOneWidget);
    expect(find.text('维修占比'), findsOneWidget);
    expect(find.text('20.0%'), findsOneWidget);

    expect(find.text('按产品对比'), findsOneWidget);
    expect(find.text('产品A'), findsWidgets);
    expect(find.text('按工序对比'), findsOneWidget);
    expect(find.text('装配'), findsOneWidget);
    expect(find.text('按人员对比'), findsOneWidget);
    expect(find.text('张三'), findsOneWidget);
    expect(find.text('维修'), findsOneWidget);
  });
}
