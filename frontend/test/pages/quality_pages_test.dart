import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';
import 'package:mes_client/features/misc/presentation/daily_first_article_page.dart';
import 'package:mes_client/features/production/presentation/production_repair_order_detail_page.dart';
import 'package:mes_client/features/production/presentation/production_scrap_statistics_detail_page.dart';
import 'package:mes_client/features/quality/presentation/quality_page.dart';
import 'package:mes_client/features/quality/presentation/quality_data_page.dart';
import 'package:mes_client/features/quality/presentation/quality_defect_analysis_page.dart';
import 'package:mes_client/features/production/services/production_service.dart';
import 'package:mes_client/features/quality/services/quality_service.dart';

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

  testWidgets('质量数据页展示总览与工序人员质量口径', (tester) async {
    final service = _FakeQualityService(
      overviewResult: QualityStatsOverview(
        firstArticleTotal: 0,
        passedTotal: 0,
        failedTotal: 0,
        passRatePercent: 0,
        defectTotal: 2,
        scrapTotal: 2,
        repairTotal: 1,
        coveredOrderCount: 1,
        coveredProcessCount: 1,
        coveredOperatorCount: 1,
        latestFirstArticleAt: null,
      ),
      processItems: [
        QualityProcessStatItem(
          processCode: 'QA-01',
          processName: '检验',
          firstArticleTotal: 0,
          passedTotal: 0,
          failedTotal: 0,
          passRatePercent: 0,
          defectTotal: 2,
          scrapTotal: 2,
          repairTotal: 1,
          latestFirstArticleAt: null,
        ),
      ],
      operatorItems: [
        QualityOperatorStatItem(
          operatorUserId: 9,
          operatorUsername: 'quality_worker',
          firstArticleTotal: 0,
          passedTotal: 0,
          failedTotal: 0,
          passRatePercent: 0,
          defectTotal: 2,
          scrapTotal: 2,
          repairTotal: 1,
          latestFirstArticleAt: null,
        ),
      ],
      productItems: const [
        QualityProductStatItem(
          productId: 3,
          productCode: '',
          productName: '产品A',
          firstArticleTotal: 0,
          passedTotal: 0,
          failedTotal: 0,
          passRatePercent: 0,
          defectTotal: 2,
          scrapTotal: 2,
          repairTotal: 1,
        ),
      ],
      trendItems: const [
        QualityTrendItem(
          date: '2026-03-02',
          firstArticleTotal: 0,
          passedTotal: 0,
          failedTotal: 0,
          passRatePercent: 0,
          defectTotal: 2,
          scrapTotal: 2,
          repairTotal: 1,
        ),
      ],
    );
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapBody(
        QualityDataPage(session: session, onLogout: () {}, service: service),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('不良总数'), findsOneWidget);
    expect(find.text('报废总数'), findsOneWidget);
    expect(find.text('维修总数'), findsOneWidget);
    expect(find.text('2026-03-02'), findsOneWidget);
    expect(find.text('检验'), findsOneWidget);
    await tester.tap(find.text('按人员'));
    await tester.pumpAndSettle();
    expect(find.text('quality_worker'), findsOneWidget);
    await tester.tap(find.text('按产品'));
    await tester.pumpAndSettle();
    expect(find.text('产品A'), findsOneWidget);
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
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.textContaining('治具偏移'), findsOneWidget);
  });

  testWidgets('质量页透传报废消息后打开品质报废详情', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QualityPage(
            session: session,
            onLogout: () {},
            visibleTabCodes: const [qualityScrapStatisticsTabCode],
            capabilityCodes: const {'quality.scrap_statistics.export'},
            preferredTabCode: qualityScrapStatisticsTabCode,
            routePayloadJson: '{"action":"detail","scrap_id":21}',
            repairScrapService: _FakeQualityRepairScrapService(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('报废详情'), findsOneWidget);
    expect(find.text('关联维修工单'), findsOneWidget);
  });

  testWidgets('质量页透传维修消息后打开品质维修详情', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QualityPage(
            session: session,
            onLogout: () {},
            visibleTabCodes: const [qualityRepairOrdersTabCode],
            capabilityCodes: const {
              'quality.repair_orders.complete',
              'quality.repair_orders.export',
            },
            preferredTabCode: qualityRepairOrdersTabCode,
            routePayloadJson: '{"action":"detail","repair_order_id":7}',
            repairScrapService: _FakeQualityRepairScrapService(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('维修详情'), findsOneWidget);
    expect(find.text('缺陷现象'), findsOneWidget);
  });

  testWidgets('质量页透传首件消息后展示新增首件字段', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QualityPage(
            session: session,
            onLogout: () {},
            visibleTabCodes: const [firstArticleManagementTabCode],
            capabilityCodes: const {
              'quality.first_articles.detail',
              'quality.first_articles.disposition',
            },
            preferredTabCode: firstArticleManagementTabCode,
            routePayloadJson: '{"action":"detail","record_id":12}',
            firstArticleService: _FakeQualityService(
              firstArticleDetail: FirstArticleDetail(
                id: 12,
                verificationCode: 'Q-12',
                productionOrderId: 33,
                productionOrderCode: 'PO-12',
                productId: 9,
                productCode: 'P-12',
                productName: '产品首件',
                processId: 4,
                processName: '装配',
                operatorUserId: 7,
                operatorUsername: 'worker_a',
                checkResult: 'failed',
                defectDescription: '尺寸偏差',
                checkAt: DateTime(2026, 3, 5, 8),
                templateId: 100,
                templateName: '品质模板A',
                checkContent: '外观、尺寸复核',
                testValue: '10.2',
                participants: const [
                  FirstArticleParticipantItem(
                    userId: 8,
                    username: 'worker_b',
                    fullName: '李四',
                  ),
                ],
                dispositionHistory: const [],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('首件详情 #12'), findsOneWidget);
    expect(find.text('品质模板A'), findsOneWidget);
    expect(find.text('外观、尺寸复核'), findsOneWidget);
    expect(find.text('10.2'), findsOneWidget);
    expect(find.text('worker_b (李四)'), findsOneWidget);
  });
}

class _FakeQualityService extends QualityService {
  _FakeQualityService({
    this.firstArticleResult,
    this.firstArticleDetail,
    this.overviewResult,
    this.processItems,
    this.operatorItems,
    this.productItems,
    this.trendItems,
  }) : super(AppSession(baseUrl: 'http://localhost', accessToken: 'token'));

  final FirstArticleListResult? firstArticleResult;
  final FirstArticleDetail? firstArticleDetail;
  final QualityStatsOverview? overviewResult;
  final List<QualityProcessStatItem>? processItems;
  final List<QualityOperatorStatItem>? operatorItems;
  final List<QualityProductStatItem>? productItems;
  final List<QualityTrendItem>? trendItems;
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
  Future<FirstArticleDetail> getFirstArticleDetail(int recordId) async {
    return firstArticleDetail ??
        FirstArticleDetail(
          id: recordId,
          verificationCode: 'FA-$recordId',
          productionOrderId: 1,
          productionOrderCode: 'PO-$recordId',
          productId: 1,
          productCode: 'P-$recordId',
          productName: '产品A',
          processId: 1,
          processName: '检验',
          operatorUserId: 1,
          operatorUsername: 'worker',
          checkResult: 'failed',
          defectDescription: '默认缺陷',
          checkAt: DateTime(2026, 3, 5, 8),
          dispositionHistory: const [],
        );
  }

  @override
  Future<FirstArticleDetail> getFirstArticleDispositionDetail(
    int recordId,
  ) async {
    return getFirstArticleDetail(recordId);
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
    return overviewResult ??
        QualityStatsOverview(
          firstArticleTotal: 0,
          passedTotal: 0,
          failedTotal: 0,
          passRatePercent: 0,
          defectTotal: 0,
          scrapTotal: 0,
          repairTotal: 0,
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
  }) async => processItems ?? const [];

  @override
  Future<List<QualityOperatorStatItem>> getQualityOperatorStats({
    DateTime? startDate,
    DateTime? endDate,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async => operatorItems ?? const [];

  @override
  Future<List<QualityProductStatItem>> getQualityProductStats({
    DateTime? startDate,
    DateTime? endDate,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async => productItems ?? const [];

  @override
  Future<List<QualityTrendItem>> getQualityTrend({
    DateTime? startDate,
    DateTime? endDate,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async => trendItems ?? const [];

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
        {
          'id': 1,
          'phenomenon': '虚焊',
          'quantity': 3,
          'production_record_id': 31,
          'production_record_type': 'production',
          'production_record_quantity': 10,
          'production_record_created_at': '2026-03-05T08:50:00Z',
        },
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

class _FakeQualityRepairScrapService extends _FakeQualityService {
  @override
  Future<ScrapStatisticsListResult> getScrapStatistics({
    required int page,
    required int pageSize,
    String? keyword,
    String? productName,
    String? processCode,
    String progress = 'all',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return ScrapStatisticsListResult(
      total: 1,
      items: [await getScrapStatisticsDetail(scrapId: 21)],
    );
  }

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
  Future<RepairOrderListResult> getRepairOrders({
    required int page,
    required int pageSize,
    String? keyword,
    String status = 'all',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return RepairOrderListResult(
      total: 1,
      items: [
        RepairOrderItem.fromJson({
          'id': 7,
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
        }),
      ],
    );
  }

  @override
  Future<RepairOrderDetailItem> getRepairOrderDetail({
    required int repairOrderId,
  }) {
    return _FakeProductionService().getRepairOrderDetail(
      repairOrderId: repairOrderId,
    );
  }

  @override
  Future<RepairOrderPhenomenaSummaryResult> getRepairOrderPhenomenaSummary({
    required int repairOrderId,
  }) async {
    return RepairOrderPhenomenaSummaryResult(
      repairOrderId: repairOrderId,
      items: [RepairOrderPhenomenonSummaryItem(phenomenon: '虚焊', quantity: 3)],
    );
  }

  @override
  Future<ProductionOrderDetail> getOrderDetail({required int orderId}) async {
    return ProductionOrderDetail.fromJson({
      'order': {
        'id': orderId,
        'order_code': 'PO-21',
        'product_id': 1,
        'product_name': '产品Q',
        'quantity': 10,
        'status': 'in_progress',
        'created_at': '2026-03-05T09:00:00Z',
        'updated_at': '2026-03-05T10:00:00Z',
      },
      'processes': [
        {
          'id': 9,
          'process_code': 'QA-01',
          'process_name': '检验',
          'process_order': 1,
          'status': 'in_progress',
          'visible_quantity': 10,
          'completed_quantity': 0,
          'created_at': '2026-03-05T09:00:00Z',
          'updated_at': '2026-03-05T10:00:00Z',
        },
      ],
      'sub_orders': [],
      'records': [],
      'events': [],
    });
  }

  @override
  Future<RepairOrderItem> completeRepairOrder({
    required int repairOrderId,
    required List<RepairCauseItemInput> causeItems,
    required bool scrapReplenished,
    required List<RepairReturnAllocationInput> returnAllocations,
  }) async {
    return (await getRepairOrders(page: 1, pageSize: 1)).items.first;
  }

  @override
  Future<ProductionExportResult> exportRepairOrders({
    String? keyword,
    String status = 'all',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return ProductionExportResult(
      fileName: 'repair.csv',
      mimeType: 'text/csv',
      contentBase64: 'cmVwYWly',
      exportedCount: 1,
    );
  }

  @override
  Future<ProductionExportResult> exportScrapStatistics({
    String? keyword,
    String? productName,
    String? processCode,
    String progress = 'all',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return ProductionExportResult(
      fileName: 'scrap.csv',
      mimeType: 'text/csv',
      contentBase64: 'c2NyYXA=',
      exportedCount: 1,
    );
  }
}
