import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/production_models.dart';
import 'package:mes_client/models/quality_models.dart';
import 'package:mes_client/pages/daily_first_article_page.dart';
import 'package:mes_client/pages/production_repair_order_detail_page.dart';
import 'package:mes_client/pages/production_scrap_statistics_detail_page.dart';
import 'package:mes_client/pages/quality_data_page.dart';
import 'package:mes_client/pages/quality_defect_analysis_page.dart';
import 'package:mes_client/services/production_service.dart';
import 'package:mes_client/services/quality_service.dart';

void main() {
  final session = AppSession(baseUrl: 'http://localhost', accessToken: 'token');

  Widget wrapBody(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('每日首件仅对不通过记录展示处置入口', (tester) async {
    await tester.pumpWidget(
      wrapBody(
        DailyFirstArticlePage(
          session: session,
          onLogout: () {},
          canViewDetail: true,
          canDispose: true,
          service: _FakeQualityService(
            firstArticleResult: FirstArticleListResult(
              queryDate: DateTime(2026, 3, 5),
              verificationCode: 'QA-1',
              verificationCodeSource: 'stored',
              total: 2,
              items: [
                FirstArticleListItem(
                  id: 1,
                  orderId: 1,
                  orderCode: 'PO-1',
                  productId: 1,
                  productName: '产品A',
                  orderProcessId: 1,
                  processCode: 'QA-01',
                  processName: '检验',
                  operatorUserId: 1,
                  operatorUsername: 'worker_a',
                  result: 'passed',
                  verificationDate: DateTime(2026, 3, 5),
                  remark: null,
                  createdAt: DateTime(2026, 3, 5, 8),
                ),
                FirstArticleListItem(
                  id: 2,
                  orderId: 2,
                  orderCode: 'PO-2',
                  productId: 2,
                  productName: '产品B',
                  orderProcessId: 2,
                  processCode: 'QA-02',
                  processName: '复检',
                  operatorUserId: 2,
                  operatorUsername: 'worker_b',
                  result: 'failed',
                  verificationDate: DateTime(2026, 3, 5),
                  remark: '毛刺',
                  createdAt: DateTime(2026, 3, 5, 9),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('详情'), findsNWidgets(2));
    expect(find.text('处置'), findsOneWidget);
  });

  testWidgets('质量数据页在非法日期范围时直接提示', (tester) async {
    final service = _FakeQualityService();
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapBody(
        QualityDataPage(
          session: session,
          onLogout: () {},
          service: service,
          initialStartDate: DateTime(2026, 3, 6),
          initialEndDate: DateTime(2026, 3, 5),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('开始日期不能晚于结束日期'), findsOneWidget);
    expect(service.overviewCallCount, 0);
  });

  testWidgets('不良分析页在非法日期范围时即时提示', (tester) async {
    final service = _FakeQualityService();
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapBody(
        QualityDefectAnalysisPage(
          session: session,
          onLogout: () {},
          canExport: false,
          service: service,
          initialStartDate: DateTime(2026, 3, 6),
          initialEndDate: DateTime(2026, 3, 5),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('开始日期不能晚于结束日期'), findsOneWidget);
    expect(service.defectCallCount, 0);
  });

  testWidgets('报废详情页展示关联维修摘要', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProductionScrapStatisticsDetailPage(
          session: session,
          onLogout: () {},
          scrapId: 21,
          service: _FakeProductionService(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('报废详情'), findsOneWidget);
    expect(find.text('关联维修工单'), findsOneWidget);
    expect(find.text('RW-21'), findsOneWidget);
  });

  testWidgets('维修详情页展示缺陷与原因区块', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProductionRepairOrderDetailPage(
          session: session,
          onLogout: () {},
          repairOrderId: 7,
          service: _FakeProductionService(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('缺陷现象'), findsOneWidget);
    expect(find.text('维修原因'), findsOneWidget);
    expect(find.textContaining('虚焊'), findsWidgets);
    expect(find.textContaining('治具偏移'), findsOneWidget);
  });
}

class _FakeQualityService extends QualityService {
  _FakeQualityService({this.firstArticleResult})
    : super(AppSession(baseUrl: 'http://localhost', accessToken: 'token'));

  final FirstArticleListResult? firstArticleResult;
  int overviewCallCount = 0;
  int defectCallCount = 0;

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
    return firstArticleResult ??
        FirstArticleListResult(
          queryDate: DateTime(2026, 3, 5),
          verificationCode: null,
          verificationCodeSource: 'none',
          total: 0,
          items: const [],
        );
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
    overviewCallCount += 1;
    return QualityStatsOverview(
      firstArticleTotal: 0,
      passedTotal: 0,
      failedTotal: 0,
      passRatePercent: 0,
      coveredOrderCount: 0,
      coveredProcessCount: 0,
      coveredOperatorCount: 0,
      latestFirstArticleAt: null,
    );
  }

  @override
  Future<List<QualityProcessStatItem>> getQualityProcessStats({
    DateTime? startDate,
    DateTime? endDate,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async => const [];

  @override
  Future<List<QualityOperatorStatItem>> getQualityOperatorStats({
    DateTime? startDate,
    DateTime? endDate,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async => const [];

  @override
  Future<List<QualityProductStatItem>> getQualityProductStats({
    DateTime? startDate,
    DateTime? endDate,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async => const [];

  @override
  Future<List<QualityTrendItem>> getQualityTrend({
    DateTime? startDate,
    DateTime? endDate,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async => const [];

  @override
  Future<DefectAnalysisResult> getDefectAnalysis({
    DateTime? startDate,
    DateTime? endDate,
    int? productId,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? phenomenon,
    int topN = 10,
  }) async {
    defectCallCount += 1;
    return DefectAnalysisResult(
      totalDefectQuantity: 0,
      topDefects: const [],
      topReasons: const [],
      productQualityComparison: const [],
      byProcess: const [],
      byProduct: const [],
      byOperator: const [],
      byDate: const [],
    );
  }
}

class _FakeProductionService extends ProductionService {
  _FakeProductionService()
    : super(AppSession(baseUrl: 'http://localhost', accessToken: 'token'));

  @override
  Future<ScrapStatisticsItem> getScrapStatisticsDetail({
    required int scrapId,
  }) async {
    return ScrapStatisticsItem.fromJson({
      'id': scrapId,
      'order_code': 'PO-21',
      'product_name': '产品Q',
      'process_name': '检验',
      'scrap_reason': '破损',
      'scrap_quantity': 3,
      'progress': 'pending_apply',
      'created_at': '2026-03-05T08:00:00Z',
      'updated_at': '2026-03-05T08:10:00Z',
      'related_repair_orders': [
        {
          'id': 7,
          'repair_order_code': 'RW-21',
          'status': 'completed',
          'repair_quantity': 3,
          'repaired_quantity': 2,
          'scrap_quantity': 1,
          'repair_time': '2026-03-05T09:00:00Z',
        },
      ],
    });
  }

  @override
  Future<RepairOrderDetailItem> getRepairOrderDetail({
    required int repairOrderId,
  }) async {
    return RepairOrderDetailItem.fromJson({
      'id': repairOrderId,
      'repair_order_code': 'RW-21',
      'source_order_code': 'PO-21',
      'product_name': '产品Q',
      'source_process_code': 'QA-01',
      'source_process_name': '检验',
      'production_quantity': 10,
      'repair_quantity': 3,
      'repaired_quantity': 2,
      'scrap_quantity': 1,
      'scrap_replenished': false,
      'repair_time': '2026-03-05T09:00:00Z',
      'status': 'completed',
      'created_at': '2026-03-05T09:00:00Z',
      'updated_at': '2026-03-05T10:00:00Z',
      'defect_rows': [
        {'id': 1, 'phenomenon': '虚焊', 'quantity': 3},
      ],
      'cause_rows': [
        {
          'id': 1,
          'phenomenon': '虚焊',
          'reason': '治具偏移',
          'quantity': 2,
          'is_scrap': false,
        },
      ],
      'return_routes': [
        {
          'id': 1,
          'target_process_code': 'QA-00',
          'target_process_name': '返修前段',
          'return_quantity': 2,
        },
      ],
    });
  }
}
