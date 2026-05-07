import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_metric_card.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';
import 'package:mes_client/features/quality/presentation/quality_trend_page.dart';
import 'package:mes_client/features/quality/services/quality_service.dart';

class _FakeQualityTrendService extends QualityService {
  _FakeQualityTrendService() : super(AppSession(baseUrl: '', accessToken: ''));

  int trendCalls = 0;
  int overviewCalls = 0;
  int productCalls = 0;
  int processCalls = 0;
  int operatorCalls = 0;
  int exportCalls = 0;
  String? lastKeyword;

  @override
  Future<List<QualityTrendItem>> getQualityTrend({
    DateTime? startDate,
    DateTime? endDate,
    String? keyword,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async {
    trendCalls += 1;
    lastKeyword = keyword;
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
    String? keyword,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async {
    overviewCalls += 1;
    lastKeyword = keyword;
    return QualityStatsOverview(
      firstArticleTotal: 15,
      passedTotal: 12,
      failedTotal: 3,
      passRatePercent: 80,
      defectTotal: 5,
      scrapTotal: 2,
      repairTotal: 3,
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
    String? keyword,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async {
    productCalls += 1;
    lastKeyword = keyword;
    return const [
      QualityProductStatItem(
        productId: 1,
        productCode: 'P-001',
        productName: '产品A',
        firstArticleTotal: 10,
        passedTotal: 8,
        failedTotal: 2,
        passRatePercent: 80,
        defectTotal: 3,
        scrapTotal: 1,
        repairTotal: 2,
      ),
    ];
  }

  @override
  Future<List<QualityProcessStatItem>> getQualityProcessStats({
    DateTime? startDate,
    DateTime? endDate,
    String? keyword,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async {
    processCalls += 1;
    lastKeyword = keyword;
    return [
      QualityProcessStatItem(
        processCode: 'GX-01',
        processName: '装配',
        firstArticleTotal: 8,
        passedTotal: 6,
        failedTotal: 2,
        passRatePercent: 75,
        defectTotal: 2,
        scrapTotal: 1,
        repairTotal: 1,
        latestFirstArticleAt: DateTime(2026, 3, 2, 8),
      ),
    ];
  }

  @override
  Future<List<QualityOperatorStatItem>> getQualityOperatorStats({
    DateTime? startDate,
    DateTime? endDate,
    String? keyword,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async {
    operatorCalls += 1;
    lastKeyword = keyword;
    return [
      QualityOperatorStatItem(
        operatorUserId: 7,
        operatorUsername: '张三',
        firstArticleTotal: 7,
        passedTotal: 6,
        failedTotal: 1,
        passRatePercent: 85.7,
        defectTotal: 4,
        scrapTotal: 1,
        repairTotal: 2,
        latestFirstArticleAt: DateTime(2026, 3, 2, 8),
      ),
    ];
  }

  @override
  Future<QualityExportFile> exportQualityTrend({
    DateTime? startDate,
    DateTime? endDate,
    String? keyword,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async {
    exportCalls += 1;
    lastKeyword = keyword;
    return const QualityExportFile(
      filename: 'quality_trend.csv',
      contentBase64: 'YQ==',
    );
  }
}

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    _FakeQualityTrendService service,
    {bool canExport = true,}
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
            canExport: canExport,
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

    expect(
      find.byKey(const ValueKey('quality-trend-page-header')),
      findsOneWidget,
    );
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

  testWidgets('质量趋势页首屏使用统一工作台骨架并突出趋势主体', (tester) async {
    final service = _FakeQualityTrendService();

    await pumpPage(tester, service);

    expect(find.byType(MesFilterBar), findsNothing);
    expect(find.byType(MesMetricCard), findsAtLeastNWidgets(4));
    expect(
      find.byKey(const ValueKey('quality-trend-keyword-field')),
      findsOneWidget,
    );
    expect(find.text('搜索产品/工序/操作员'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('quality-trend-operation-menu')),
      findsOneWidget,
    );
    expect(find.text('质量总览'), findsOneWidget);
    expect(find.text('趋势概览'), findsOneWidget);
    expect(find.byType(MesSectionCard), findsAtLeastNWidgets(4));
  });

  testWidgets('质量趋势页使用聚合搜索并把导出收进操作菜单', (tester) async {
    final service = _FakeQualityTrendService();

    await pumpPage(tester, service);

    await tester.enterText(
      find.byKey(const ValueKey('quality-trend-keyword-field')),
      '产品A',
    );
    await tester.tap(find.widgetWithText(FilledButton, '查询'));
    await tester.pumpAndSettle();

    expect(service.lastKeyword, '产品A');

    await tester.tap(
      find.byKey(const ValueKey('quality-trend-operation-menu')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出').last);
    await tester.pumpAndSettle();

    expect(service.exportCalls, 1);
    expect(service.lastKeyword, '产品A');
  });

  testWidgets('质量趋势页首屏先展示趋势主体再展示维度对比', (tester) async {
    final service = _FakeQualityTrendService();

    await pumpPage(tester, service);

    final trendTitle = find.text('趋势概览');
    final productTitle = find.text('按产品对比');
    expect(trendTitle, findsOneWidget);
    expect(productTitle, findsOneWidget);
    expect(
      tester.getTopLeft(trendTitle).dy,
      lessThan(tester.getTopLeft(productTitle).dy),
    );
  });
}
