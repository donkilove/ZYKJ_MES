import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';
import 'package:mes_client/features/production/presentation/production_repair_orders_page.dart';
import 'package:mes_client/features/production/presentation/production_scrap_statistics_page.dart';
import 'package:mes_client/features/quality/presentation/quality_data_page.dart';
import 'package:mes_client/features/quality/presentation/quality_defect_analysis_page.dart';
import 'package:mes_client/features/quality/presentation/quality_page.dart';
import 'package:mes_client/features/production/presentation/quality_repair_orders_page.dart';
import 'package:mes_client/features/quality/presentation/quality_scrap_statistics_page.dart';
import 'package:mes_client/features/quality/presentation/quality_trend_page.dart';
import 'package:mes_client/features/production/presentation/widgets/quality_repair_orders_page_header.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/quality/services/quality_service.dart';
import 'package:mes_client/features/quality/services/quality_supplier_service.dart';

class _FakeFileSelectorPlatform extends FileSelectorPlatform {
  String? savePath;

  @override
  Future<String?> getSavePath({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? suggestedName,
    String? confirmButtonText,
  }) async {
    return savePath;
  }
}

class _FakeQualityHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _FakeQualityHttpClientRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _FakeQualityHttpClientRequest(url);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeQualityHttpClientRequest implements HttpClientRequest {
  _FakeQualityHttpClientRequest(this.url);

  final Uri url;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    final path = url.path;
    final okPaths = <String>{
      '/quality/stats/overview',
      '/quality/stats/processes',
      '/quality/stats/operators',
      '/quality/stats/products',
      '/quality/trend',
      '/quality/defect-analysis',
    };
    return _FakeQualityHttpClientResponse(
      statusCode: okPaths.contains(path) ? 200 : 404,
      body: jsonEncode(_buildResponseBody(path)),
    );
  }

  Map<String, Object> _buildResponseBody(String path) {
    if (path == '/quality/stats/overview') {
      return {
        'data': {
          'first_article_total': 0,
          'passed_total': 0,
          'failed_total': 0,
          'pass_rate_percent': 0,
          'defect_total': 0,
          'scrap_total': 0,
          'repair_total': 0,
          'covered_order_count': 0,
          'covered_process_count': 0,
          'covered_operator_count': 0,
        },
      };
    }
    if (path == '/quality/stats/processes' ||
        path == '/quality/stats/operators' ||
        path == '/quality/stats/products' ||
        path == '/quality/trend') {
      return {
        'data': {'items': <Object>[]},
      };
    }
    if (path == '/quality/defect-analysis') {
      return {
        'data': {
          'total_defect_quantity': 0,
          'top_defects': <Object>[],
          'top_reasons': <Object>[],
          'product_quality_comparison': <Object>[],
          'by_process': <Object>[],
          'by_product': <Object>[],
          'by_operator': <Object>[],
          'by_date': <Object>[],
        },
      };
    }
    return {'detail': 'not found'};
  }

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding value) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeQualityHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeQualityHttpClientResponse({
    required this.statusCode,
    required String body,
  }) : _bytes = utf8.encode(body);

  final List<int> _bytes;

  @override
  final int statusCode;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpHeaders get headers => _FakeHttpHeaders(contentType: ContentType.json);

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => statusCode == 200 ? 'OK' : 'Not Found';

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) {
    throw UnsupportedError('redirect is not supported in tests');
  }

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  Future<Socket> detachSocket() {
    throw UnsupportedError('detachSocket is not supported in tests');
  }

  bool get chunkedTransferEncoding => false;

  @override
  List<Cookie> get cookies => const <Cookie>[];

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _FakeHttpHeaders implements HttpHeaders {
  _FakeHttpHeaders({this.contentType});

  @override
  ContentType? contentType;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordedQualityStatsQuery {
  const _RecordedQualityStatsQuery({
    this.startDate,
    this.endDate,
    this.productName,
    this.processCode,
    this.operatorUsername,
    this.result,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final String? productName;
  final String? processCode;
  final String? operatorUsername;
  final String? result;
}

class _RecordedDefectQuery {
  const _RecordedDefectQuery({
    this.startDate,
    this.endDate,
    this.productName,
    this.processCode,
    this.operatorUsername,
    this.phenomenon,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final String? productName;
  final String? processCode;
  final String? operatorUsername;
  final String? phenomenon;
}

class _FakeQualityService extends QualityService {
  _FakeQualityService({
    this.overviewResult,
    this.processItems,
    this.operatorItems,
    this.productItems,
    this.trendItems,
    this.defectResult,
    this.exportQualityStatsResult,
    this.exportDefectAnalysisResult,
    this.overviewCompleter,
    this.processCompleter,
    this.operatorCompleter,
    this.productCompleter,
    this.trendCompleter,
  }) : super(AppSession(baseUrl: 'http://localhost', accessToken: 'token'));

  final QualityStatsOverview? overviewResult;
  final List<QualityProcessStatItem>? processItems;
  final List<QualityOperatorStatItem>? operatorItems;
  final List<QualityProductStatItem>? productItems;
  final List<QualityTrendItem>? trendItems;
  final DefectAnalysisResult? defectResult;
  final QualityExportFile? exportQualityStatsResult;
  final QualityExportFile? exportDefectAnalysisResult;
  final Completer<QualityStatsOverview>? overviewCompleter;
  final Completer<List<QualityProcessStatItem>>? processCompleter;
  final Completer<List<QualityOperatorStatItem>>? operatorCompleter;
  final Completer<List<QualityProductStatItem>>? productCompleter;
  final Completer<List<QualityTrendItem>>? trendCompleter;

  Object? qualityStatsError;
  Object? defectError;
  Object? exportQualityStatsError;
  Object? exportDefectAnalysisError;
  _RecordedQualityStatsQuery? lastQualityStatsQuery;
  _RecordedDefectQuery? lastDefectQuery;
  int exportQualityStatsCalls = 0;
  int exportDefectAnalysisCalls = 0;
  int overviewCalls = 0;
  int processCalls = 0;
  int operatorCalls = 0;
  int productCalls = 0;
  int trendCalls = 0;

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
    return FirstArticleListResult(
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
    overviewCalls += 1;
    lastQualityStatsQuery = _RecordedQualityStatsQuery(
      startDate: startDate,
      endDate: endDate,
      productName: productName,
      processCode: processCode,
      operatorUsername: operatorUsername,
      result: result,
    );
    final error = qualityStatsError;
    if (error != null) {
      throw error;
    }
    final completer = overviewCompleter;
    if (completer != null) {
      return completer.future;
    }
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
  }) async {
    processCalls += 1;
    final error = qualityStatsError;
    if (error != null) {
      throw error;
    }
    final completer = processCompleter;
    if (completer != null) {
      return completer.future;
    }
    return processItems ?? const [];
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
    final error = qualityStatsError;
    if (error != null) {
      throw error;
    }
    final completer = operatorCompleter;
    if (completer != null) {
      return completer.future;
    }
    return operatorItems ?? const [];
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
    final error = qualityStatsError;
    if (error != null) {
      throw error;
    }
    final completer = productCompleter;
    if (completer != null) {
      return completer.future;
    }
    return productItems ?? const [];
  }

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
    final error = qualityStatsError;
    if (error != null) {
      throw error;
    }
    final completer = trendCompleter;
    if (completer != null) {
      return completer.future;
    }
    return trendItems ?? const [];
  }

  @override
  Future<QualityExportFile> exportQualityStats({
    DateTime? startDate,
    DateTime? endDate,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async {
    exportQualityStatsCalls += 1;
    lastQualityStatsQuery = _RecordedQualityStatsQuery(
      startDate: startDate,
      endDate: endDate,
      productName: productName,
      processCode: processCode,
      operatorUsername: operatorUsername,
      result: result,
    );
    final error = exportQualityStatsError;
    if (error != null) {
      throw error;
    }
    return exportQualityStatsResult ??
        const QualityExportFile(
          filename: 'quality_stats.csv',
          contentBase64: 'YQ==',
        );
  }

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
    lastDefectQuery = _RecordedDefectQuery(
      startDate: startDate,
      endDate: endDate,
      productName: productName,
      processCode: processCode,
      operatorUsername: operatorUsername,
      phenomenon: phenomenon,
    );
    final error = defectError;
    if (error != null) {
      throw error;
    }
    return defectResult ??
        DefectAnalysisResult(
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

  @override
  Future<QualityExportFile> exportDefectAnalysis({
    DateTime? startDate,
    DateTime? endDate,
    int? productId,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? phenomenon,
    int topN = 10,
  }) async {
    exportDefectAnalysisCalls += 1;
    lastDefectQuery = _RecordedDefectQuery(
      startDate: startDate,
      endDate: endDate,
      productName: productName,
      processCode: processCode,
      operatorUsername: operatorUsername,
      phenomenon: phenomenon,
    );
    final error = exportDefectAnalysisError;
    if (error != null) {
      throw error;
    }
    return exportDefectAnalysisResult ??
        const QualityExportFile(filename: 'defect.csv', contentBase64: 'Yg==');
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
          'repair_order_code': 'RW-7',
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
          'repair_order_code': 'RW-7',
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
  }) async {
    return RepairOrderDetailItem.fromJson({
      'id': repairOrderId,
      'repair_order_code': 'RW-7',
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

class _FakeQualitySupplierService extends QualitySupplierService {
  _FakeQualitySupplierService(List<QualitySupplierItem> initialItems)
    : _items = List<QualitySupplierItem>.from(initialItems),
      super(AppSession(baseUrl: 'http://localhost', accessToken: 'token'));

  final List<QualitySupplierItem> _items;

  @override
  Future<QualitySupplierListResult> listSuppliers({
    String? keyword,
    bool? enabled,
  }) async {
    return QualitySupplierListResult(total: _items.length, items: [..._items]);
  }
}

QualitySupplierItem _buildSupplier({required int id, required String name}) {
  return QualitySupplierItem(
    id: id,
    name: name,
    remark: '备注$id',
    isEnabled: true,
    createdAt: DateTime(2026, 4, 2, 8),
    updatedAt: DateTime(2026, 4, 2, 9),
  );
}

Widget _wrapBody(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void _setDesktopViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
}

List<QualityTrendItem> _buildTrendItems(int total) {
  return List<QualityTrendItem>.generate(total, (index) {
    final day = (index % 28) + 1;
    final month = index == total - 1 ? 4 : 3;
    final date =
        '2026-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    return QualityTrendItem(
      date: date,
      firstArticleTotal: index + 1,
      passedTotal: index,
      failedTotal: 1,
      passRatePercent: 90,
      defectTotal: 2,
      scrapTotal: 1,
      repairTotal: 1,
    );
  });
}

List<QualityProcessStatItem> _buildProcessItems(int total) {
  return List<QualityProcessStatItem>.generate(total, (index) {
    return QualityProcessStatItem(
      processCode: 'QA-${index + 1}',
      processName: '工序${index + 1}',
      firstArticleTotal: 5,
      passedTotal: 4,
      failedTotal: 1,
      passRatePercent: 80,
      defectTotal: 2,
      scrapTotal: 1,
      repairTotal: 1,
      latestFirstArticleAt: DateTime(2026, 3, 5, 8),
    );
  });
}

List<QualityOperatorStatItem> _buildOperatorItems(int total) {
  return List<QualityOperatorStatItem>.generate(total, (index) {
    return QualityOperatorStatItem(
      operatorUserId: index + 1,
      operatorUsername: 'worker_${index + 1}',
      firstArticleTotal: 5,
      passedTotal: 4,
      failedTotal: 1,
      passRatePercent: 80,
      defectTotal: 2,
      scrapTotal: 1,
      repairTotal: 1,
      latestFirstArticleAt: DateTime(2026, 3, 5, 8),
    );
  });
}

List<QualityProductStatItem> _buildProductItems(int total) {
  return List<QualityProductStatItem>.generate(total, (index) {
    return QualityProductStatItem(
      productId: index + 1,
      productCode: 'P-${index + 1}',
      productName: '产品${index + 1}',
      firstArticleTotal: 5,
      passedTotal: 4,
      failedTotal: 1,
      passRatePercent: 80,
      defectTotal: 2,
      scrapTotal: 1,
      repairTotal: 1,
    );
  });
}

void main() {
  final session = AppSession(baseUrl: 'http://localhost', accessToken: 'token');

  testWidgets('质量总页支持全量页签挂载并尊重 preferredTabCode', (tester) async {
    _setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final firstArticleService = _FakeQualityService();
    final repairScrapService = _FakeQualityRepairScrapService();
    final supplierService = _FakeQualitySupplierService([
      _buildSupplier(id: 1, name: '核心供应商'),
    ]);

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        _wrapBody(
          QualityPage(
            session: session,
            onLogout: () {},
            visibleTabCodes: const [
              firstArticleManagementTabCode,
              qualityDataQueryTabCode,
              qualityScrapStatisticsTabCode,
              qualityRepairOrdersTabCode,
              qualityTrendTabCode,
              qualityDefectAnalysisTabCode,
              qualitySupplierManagementTabCode,
            ],
            capabilityCodes: const {
              'quality.first_articles.detail',
              'quality.first_articles.disposition',
              'quality.scrap_statistics.export',
              'quality.repair_orders.complete',
              'quality.repair_orders.export',
              'quality.defect_analysis.export',
            },
            preferredTabCode: qualitySupplierManagementTabCode,
            firstArticleService: firstArticleService,
            repairScrapService: repairScrapService,
            supplierService: supplierService,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('每日首件'), findsOneWidget);
      expect(find.text('质量数据'), findsOneWidget);
      expect(find.text('报废统计'), findsOneWidget);
      expect(find.text('维修订单'), findsOneWidget);
      expect(find.text('质量趋势'), findsOneWidget);
      expect(find.text('不良分析'), findsOneWidget);
      expect(find.text('供应商管理'), findsWidgets);
      expect(find.text('核心供应商'), findsOneWidget);
    }, createHttpClient: (_) => _FakeQualityHttpClient());
  });

  testWidgets('质量总页在无可见页签时展示空态', (tester) async {
    await tester.pumpWidget(
      _wrapBody(
        QualityPage(
          session: session,
          onLogout: () {},
          visibleTabCodes: const [],
          capabilityCodes: const <String>{},
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('当前账号无可见质量页面。'), findsOneWidget);
  });

  testWidgets('质量总页在 visibleTabCodes 动态变化后更新可见页签', (tester) async {
    _setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapBody(
        QualityPage(
          session: session,
          onLogout: () {},
          visibleTabCodes: const [
            firstArticleManagementTabCode,
            qualitySupplierManagementTabCode,
          ],
          capabilityCodes: const {'quality.first_articles.detail'},
          preferredTabCode: qualitySupplierManagementTabCode,
          firstArticleService: _FakeQualityService(),
          supplierService: _FakeQualitySupplierService([
            _buildSupplier(id: 2, name: '供应商A'),
          ]),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('供应商A'), findsOneWidget);

    await tester.pumpWidget(
      _wrapBody(
        QualityPage(
          session: session,
          onLogout: () {},
          visibleTabCodes: const [
            qualityScrapStatisticsTabCode,
            qualityRepairOrdersTabCode,
          ],
          capabilityCodes: const {
            'quality.repair_orders.complete',
            'quality.repair_orders.export',
          },
          preferredTabCode: qualityRepairOrdersTabCode,
          repairScrapService: _FakeQualityRepairScrapService(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('每日首件'), findsNothing);
    expect(find.text('供应商A'), findsNothing);
    expect(find.text('报废统计'), findsWidgets);
    expect(find.text('维修订单'), findsWidgets);
  });

  testWidgets('报废统计包装页不再额外嵌套页头', (tester) async {
    await tester.pumpWidget(
      _wrapBody(
        QualityScrapStatisticsPage(
          session: session,
          onLogout: () {},
          canExport: true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(MesRefreshPageHeader), findsOneWidget);
    expect(
      find.byKey(const ValueKey('quality-scrap-statistics-page-header')),
      findsNothing,
    );
    expect(find.text('报废统计'), findsOneWidget);
  });

  testWidgets('不良分析页接入统一页头锚点', (tester) async {
    await tester.pumpWidget(
      _wrapBody(
        QualityDefectAnalysisPage(
          session: session,
          onLogout: () {},
          canExport: true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('quality-defect-analysis-page-header')),
      findsOneWidget,
    );
    expect(find.byType(MesRefreshPageHeader), findsOneWidget);
    expect(find.text('刷新页面'), findsNothing);
    expect(find.text('统一查看缺陷分布与分析结果。'), findsNothing);
  });

  testWidgets('质量趋势页接入统一页头锚点', (tester) async {
    _setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapBody(
        QualityTrendPage(session: session, onLogout: () {}, canExport: true),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('quality-trend-page-header')),
      findsOneWidget,
    );
    expect(find.byType(MesRefreshPageHeader), findsOneWidget);
    expect(find.text('刷新页面'), findsNothing);
    expect(find.text('统一查看趋势图与时间范围统计。'), findsNothing);
  });

  testWidgets('质量数据页第一页批改版后仍接入统一页头和工作台骨架', (tester) async {
    _setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapBody(
        QualityDataPage(
          session: session,
          onLogout: () {},
          service: _FakeQualityService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MesRefreshPageHeader), findsOneWidget);
    expect(find.byType(MesFilterBar), findsOneWidget);
  });

  testWidgets('质量趋势页第一页批改版后仍接入统一页头和工作台骨架', (tester) async {
    _setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapBody(
        QualityTrendPage(
          session: session,
          onLogout: () {},
          service: _FakeQualityService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('quality-trend-page-header')),
      findsOneWidget,
    );
    expect(find.byType(MesFilterBar), findsOneWidget);
  });

  testWidgets('质量维修订单包装页不再额外嵌套页头', (tester) async {
    await tester.pumpWidget(
      _wrapBody(
        QualityRepairOrdersPage(
          session: session,
          onLogout: () {},
          canComplete: true,
          canExport: true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(MesRefreshPageHeader), findsOneWidget);
    expect(
      find.byKey(const ValueKey('quality-repair-orders-page-header')),
      findsNothing,
    );
    expect(find.text('维修订单'), findsOneWidget);
  });

  testWidgets('质量维修订单页头组件不再展示副标题', (tester) async {
    await tester.pumpWidget(
      _wrapBody(const QualityRepairOrdersPageHeader()),
    );

    await tester.pumpAndSettle();

    expect(find.byType(QualityRepairOrdersPageHeader), findsOneWidget);
    expect(find.text('统一查看质量维修订单与处理入口。'), findsNothing);
  });

  testWidgets('质量数据页支持 route payload 进入预警过滤态', (tester) async {
    _setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeQualityService();
    await tester.pumpWidget(
      _wrapBody(
        QualityDataPage(
          session: session,
          onLogout: () {},
          service: service,
          routePayloadJson: '{"dashboard_filter":"warning"}',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.lastQualityStatsQuery?.result, 'failed');
  });

  testWidgets('质量数据页 route payload 解析失败时展示错误提示', (tester) async {
    _setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapBody(
        QualityDataPage(
          session: session,
          onLogout: () {},
          service: _FakeQualityService(),
          routePayloadJson: '{"dashboard_filter":',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('路由参数解析失败'), findsOneWidget);
  });

  testWidgets('质量数据页支持查询筛选分页与导出', (tester) async {
    _setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeQualityService(
      overviewResult: QualityStatsOverview(
        firstArticleTotal: 31,
        passedTotal: 30,
        failedTotal: 1,
        passRatePercent: 96.77,
        defectTotal: 5,
        scrapTotal: 2,
        repairTotal: 1,
        coveredOrderCount: 3,
        coveredProcessCount: 3,
        coveredOperatorCount: 3,
        latestFirstArticleAt: DateTime(2026, 3, 5, 8),
      ),
      processItems: _buildProcessItems(31),
      operatorItems: _buildOperatorItems(31),
      productItems: _buildProductItems(31),
      trendItems: _buildTrendItems(31),
      exportQualityStatsResult: const QualityExportFile(
        filename: 'quality_stats.csv',
        contentBase64: 'Y29udGVudA==',
      ),
    );
    final originalFileSelector = FileSelectorPlatform.instance;
    final tempDir = Directory.systemTemp.createTempSync('quality-stats-test');
    final fakeFileSelector = _FakeFileSelectorPlatform()
      ..savePath = '${tempDir.path}${Platform.pathSeparator}quality_stats.csv';
    FileSelectorPlatform.instance = fakeFileSelector;
    addTearDown(() {
      FileSelectorPlatform.instance = originalFileSelector;
    });

    await tester.pumpWidget(
      _wrapBody(
        QualityDataPage(
          session: session,
          onLogout: () {},
          canExport: true,
          service: service,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '产品A');
    await tester.enterText(find.byType(TextField).at(1), 'QA-01');
    await tester.enterText(find.byType(TextField).at(2), 'worker_a');
    await tester.tap(
      find.byWidgetPredicate((widget) => widget is DropdownButton),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('不合格').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '查询'));
    await tester.pumpAndSettle();

    expect(service.lastQualityStatsQuery?.productName, '产品A');
    expect(service.lastQualityStatsQuery?.processCode, 'QA-01');
    expect(service.lastQualityStatsQuery?.operatorUsername, 'worker_a');
    expect(service.lastQualityStatsQuery?.result, 'failed');

    expect(find.text('2026-04-03'), findsNothing);
    await tester.tap(find.widgetWithText(OutlinedButton, '下一页').first);
    await tester.pumpAndSettle();
    expect(find.text('2026-04-03'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '导出'));
    await tester.pumpAndSettle();

    expect(service.exportQualityStatsCalls, 1);
  });

  testWidgets('质量数据页统计请求会并行启动', (tester) async {
    _setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final overviewCompleter = Completer<QualityStatsOverview>();
    final processCompleter = Completer<List<QualityProcessStatItem>>();
    final operatorCompleter = Completer<List<QualityOperatorStatItem>>();
    final productCompleter = Completer<List<QualityProductStatItem>>();
    final trendCompleter = Completer<List<QualityTrendItem>>();

    final service = _FakeQualityService(
      overviewCompleter: overviewCompleter,
      processCompleter: processCompleter,
      operatorCompleter: operatorCompleter,
      productCompleter: productCompleter,
      trendCompleter: trendCompleter,
    );

    await tester.pumpWidget(
      _wrapBody(
        QualityDataPage(session: session, onLogout: () {}, service: service),
      ),
    );
    await tester.pump();

    expect(service.overviewCalls, 1);
    expect(service.processCalls, 1);
    expect(service.operatorCalls, 1);
    expect(service.productCalls, 1);
    expect(service.trendCalls, 1);

    overviewCompleter.complete(
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
      ),
    );
    processCompleter.complete(const []);
    operatorCompleter.complete(const []);
    productCompleter.complete(const []);
    trendCompleter.complete(const []);
    await tester.pumpAndSettle();

    expect(find.text('暂无趋势数据'), findsOneWidget);
  });

  testWidgets('质量数据页处理空态 错误态 401 与导出日期校验', (tester) async {
    _setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final emptyService = _FakeQualityService();
    await tester.pumpWidget(
      _wrapBody(
        QualityDataPage(
          key: const ValueKey('quality-data-empty'),
          session: session,
          onLogout: () {},
          service: emptyService,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无趋势数据'), findsOneWidget);
    expect(find.text('暂无工序品质数据'), findsOneWidget);

    final errorService = _FakeQualityService()
      ..qualityStatsError = ApiException('服务异常', 500);
    await tester.pumpWidget(
      _wrapBody(
        QualityDataPage(
          key: const ValueKey('quality-data-error'),
          session: session,
          onLogout: () {},
          service: errorService,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('服务异常'), findsOneWidget);

    var logoutTriggered = false;
    final unauthorizedService = _FakeQualityService()
      ..qualityStatsError = ApiException('登录失效', 401);
    await tester.pumpWidget(
      _wrapBody(
        QualityDataPage(
          key: const ValueKey('quality-data-401'),
          session: session,
          onLogout: () {
            logoutTriggered = true;
          },
          service: unauthorizedService,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(logoutTriggered, isTrue);

    final invalidExportService = _FakeQualityService();
    await tester.pumpWidget(
      _wrapBody(
        QualityDataPage(
          key: const ValueKey('quality-data-invalid-export'),
          session: session,
          onLogout: () {},
          canExport: true,
          service: invalidExportService,
          initialStartDate: DateTime(2026, 3, 6),
          initialEndDate: DateTime(2026, 3, 5),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '导出'));
    await tester.pumpAndSettle();
    expect(invalidExportService.exportQualityStatsCalls, 0);
    expect(find.text('开始日期不能晚于结束日期'), findsOneWidget);
  });

  testWidgets('不良分析页支持筛选 日期变化与导出', (tester) async {
    _setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeQualityService(
      defectResult: DefectAnalysisResult(
        totalDefectQuantity: 9,
        topDefects: [
          DefectTopItem(phenomenon: '虚焊', quantity: 5, ratio: 55.56),
        ],
        topReasons: [
          DefectReasonItem(reason: '治具偏移', quantity: 4, ratio: 44.44),
        ],
        productQualityComparison: [
          QualityProductStatItem(
            productId: 11,
            productCode: 'P-11',
            productName: '产品A',
            firstArticleTotal: 4,
            passedTotal: 3,
            failedTotal: 1,
            passRatePercent: 75,
            defectTotal: 4,
            scrapTotal: 2,
            repairTotal: 1,
          ),
        ],
        byProcess: [
          DefectByProcessItem(
            processCode: 'QA-01',
            processName: '检验',
            quantity: 4,
          ),
        ],
        byProduct: [
          DefectByProductItem(productId: 11, productName: '产品A', quantity: 9),
        ],
        byOperator: [
          DefectByOperatorItem(
            operatorUserId: 7,
            operatorUsername: 'worker_a',
            quantity: 6,
          ),
        ],
        byDate: [DefectByDateItem(date: '2026-03-01', quantity: 9)],
      ),
      exportDefectAnalysisResult: const QualityExportFile(
        filename: 'defect.csv',
        contentBase64: 'ZGVmZWN0',
      ),
    );
    final originalFileSelector = FileSelectorPlatform.instance;
    final tempDir = Directory.systemTemp.createTempSync('quality-defect-test');
    final fakeFileSelector = _FakeFileSelectorPlatform()
      ..savePath = '${tempDir.path}${Platform.pathSeparator}defect.csv';
    FileSelectorPlatform.instance = fakeFileSelector;
    addTearDown(() {
      FileSelectorPlatform.instance = originalFileSelector;
    });

    await tester.pumpWidget(
      _wrapBody(
        QualityDefectAnalysisPage(
          session: session,
          onLogout: () {},
          canExport: true,
          service: service,
          initialStartDate: DateTime(2026, 3, 1),
          initialEndDate: DateTime(2026, 3, 7),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('不良总数'), findsOneWidget);
    expect(find.text('虚焊'), findsWidgets);
    expect(find.text('治具偏移'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'QA-01');
    await tester.enterText(find.byType(TextField).at(1), '产品A');
    await tester.enterText(find.byType(TextField).at(2), 'worker_a');
    await tester.enterText(find.byType(TextField).at(3), '虚焊');
    await tester.tap(find.byTooltip('查询'));
    await tester.pumpAndSettle();

    expect(service.lastDefectQuery?.processCode, 'QA-01');
    expect(service.lastDefectQuery?.productName, '产品A');
    expect(service.lastDefectQuery?.operatorUsername, 'worker_a');
    expect(service.lastDefectQuery?.phenomenon, '虚焊');
    expect(service.lastDefectQuery?.startDate, DateTime(2026, 3, 1));

    await tester.tap(find.text('清除日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('查询'));
    await tester.pumpAndSettle();
    expect(service.lastDefectQuery?.startDate, isNull);
    expect(service.lastDefectQuery?.endDate, isNull);

    await tester.tap(find.widgetWithText(OutlinedButton, '导出'));
    await tester.pumpAndSettle();

    expect(service.exportDefectAnalysisCalls, 1);
  });

  testWidgets('不良分析页处理空态 错误态 与 401', (tester) async {
    _setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapBody(
        QualityDefectAnalysisPage(
          key: const ValueKey('quality-defect-empty'),
          session: session,
          onLogout: () {},
          canExport: false,
          service: _FakeQualityService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('暂无数据'), findsWidgets);

    final errorService = _FakeQualityService()
      ..defectError = ApiException('分析失败', 500);
    await tester.pumpWidget(
      _wrapBody(
        QualityDefectAnalysisPage(
          key: const ValueKey('quality-defect-error'),
          session: session,
          onLogout: () {},
          canExport: false,
          service: errorService,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('分析失败'), findsOneWidget);

    var logoutTriggered = false;
    final unauthorizedService = _FakeQualityService()
      ..defectError = ApiException('登录失效', 401);
    await tester.pumpWidget(
      _wrapBody(
        QualityDefectAnalysisPage(
          key: const ValueKey('quality-defect-401'),
          session: session,
          onLogout: () {
            logoutTriggered = true;
          },
          canExport: false,
          service: unauthorizedService,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(logoutTriggered, isTrue);
  });

  testWidgets('质量域报废统计与维修订单包装页透传质量 service 权限与路由', (tester) async {
    final repairScrapService = _FakeQualityRepairScrapService();

    await tester.pumpWidget(
      _wrapBody(
        QualityScrapStatisticsPage(
          session: session,
          onLogout: () {},
          canExport: true,
          jumpPayloadJson: '{"action":"detail","scrap_id":21}',
          service: repairScrapService,
        ),
      ),
    );

    final scrapPage = tester.widget<ProductionScrapStatisticsPage>(
      find.byType(ProductionScrapStatisticsPage),
    );
    expect(scrapPage.canExport, isTrue);
    expect(scrapPage.jumpPayloadJson, '{"action":"detail","scrap_id":21}');
    expect(scrapPage.service, same(repairScrapService));

    await tester.pumpWidget(
      _wrapBody(
        QualityRepairOrdersPage(
          session: session,
          onLogout: () {},
          canComplete: true,
          canExport: true,
          jumpPayloadJson: '{"action":"detail","repair_order_id":7}',
          service: repairScrapService,
        ),
      ),
    );

    final repairPage = tester.widget<ProductionRepairOrdersPage>(
      find.byType(ProductionRepairOrdersPage),
    );
    expect(repairPage.canComplete, isTrue);
    expect(repairPage.canExport, isTrue);
    expect(
      repairPage.jumpPayloadJson,
      '{"action":"detail","repair_order_id":7}',
    );
    expect(repairPage.service, same(repairScrapService));
  });
}
