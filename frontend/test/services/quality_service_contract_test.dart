import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/quality/services/quality_service.dart';

import '../support/http_test_server.dart';

void main() {
  group('QualityService backend contract', () {
    test('exportFirstArticles uses result and content_base64 fields', () async {
      final server = await TestHttpServer.start({
        'POST /quality/first-articles/export': (request) {
          final body = request.decodedBody as Map<String, dynamic>? ?? const {};
          expect(body['query_date'], '2026-03-05');
          expect(body['keyword'], '工单A');
          expect(body['result'], 'failed');
          expect(body.containsKey('result_filter'), isFalse);
          return TestResponse.json(
            200,
            body: {
              'data': {
                'filename': 'first_articles.csv',
                'content_base64': 'ZGF0YQ==',
                'total_rows': 1,
              },
            },
          );
        },
      });
      addTearDown(server.close);

      final service = QualityService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'quality-token'),
      );

      final exportFile = await service.exportFirstArticles(
        date: DateTime(2026, 3, 5),
        keyword: '工单A',
        result: 'failed',
      );

      expect(exportFile.filename, 'first_articles.csv');
      expect(exportFile.contentBase64, 'ZGF0YQ==');
    });

    test('exportQualityStats reads content_base64 field', () async {
      final server = await TestHttpServer.start({
        'POST /quality/stats/export': (request) {
          final body = request.decodedBody as Map<String, dynamic>? ?? const {};
          expect(body['start_date'], '2026-03-01');
          expect(body['end_date'], '2026-03-07');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'filename': 'quality_stats.csv',
                'content_base64': 'c3RhdHM=',
                'total_rows': 2,
              },
            },
          );
        },
      });
      addTearDown(server.close);

      final service = QualityService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'quality-token'),
      );

      final exportFile = await service.exportQualityStats(
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 7),
      );

      expect(exportFile.filename, 'quality_stats.csv');
      expect(exportFile.contentBase64, 'c3RhdHM=');
    });

    test('submitDisposition payload matches backend schema', () async {
      final server = await TestHttpServer.start({
        'POST /quality/first-articles/9/disposition': (request) {
          final body = request.decodedBody as Map<String, dynamic>? ?? const {};
          expect(body['disposition_opinion'], '处置意见');
          expect(body['recheck_result'], 'failed');
          expect(body['final_judgment'], 'reject');
          expect(body.containsKey('operator'), isFalse);
          return TestResponse.json(200, body: {'data': {}});
        },
      });
      addTearDown(server.close);

      final service = QualityService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'quality-token'),
      );

      await service.submitDisposition(
        recordId: 9,
        dispositionOpinion: '处置意见',
        recheckResult: 'failed',
        finalJudgment: 'reject',
        operator_: 'quality_admin',
      );
    });

    test('detail and disposition detail use independent endpoints', () async {
      final server = await TestHttpServer.start({
        'GET /quality/first-articles/9': (_) {
          return TestResponse.json(
            200,
            body: {
              'data': {
                'id': 9,
                'order_code': 'PO-9',
                'product_name': '产品B',
                'process_name': '装配',
                'operator_username': 'worker_a',
                'result': 'failed',
                'verification_code': 'Q-9',
                'created_at': '2026-03-05T08:00:00Z',
              },
            },
          );
        },
        'GET /quality/first-articles/9/disposition-detail': (_) {
          return TestResponse.json(
            200,
            body: {
              'data': {
                'id': 9,
                'order_code': 'PO-9',
                'product_name': '产品B',
                'process_name': '装配',
                'operator_username': 'worker_a',
                'result': 'failed',
                'verification_code': 'Q-9',
                'disposition_opinion': '复检返工',
                'created_at': '2026-03-05T08:00:00Z',
              },
            },
          );
        },
      });
      addTearDown(server.close);

      final service = QualityService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'quality-token'),
      );

      final detail = await service.getFirstArticleDetail(9);
      final dispositionDetail = await service.getFirstArticleDispositionDetail(
        9,
      );

      expect(detail.productionOrderCode, 'PO-9');
      expect(dispositionDetail.disposition?.dispositionOpinion, '复检返工');
    });

    test('product stats and trend parse backend response fields', () async {
      final server = await TestHttpServer.start({
        'GET /quality/stats/products': (_) {
          return TestResponse.json(
            200,
            body: {
              'data': {
                'items': [
                  {
                    'product_id': 11,
                    'product_name': '产品A',
                    'first_article_total': 4,
                    'passed_total': 3,
                    'failed_total': 1,
                    'pass_rate_percent': 75,
                    'defect_total': 4,
                    'scrap_total': 2,
                    'repair_total': 5,
                  },
                ],
              },
            },
          );
        },
        'GET /quality/trend': (_) {
          return TestResponse.json(
            200,
            body: {
              'data': {
                'items': [
                  {
                    'stat_date': '2026-03-01',
                    'first_article_total': 3,
                    'passed_total': 2,
                    'failed_total': 1,
                    'pass_rate_percent': 66.67,
                    'defect_total': 4,
                    'scrap_total': 1,
                  },
                ],
              },
            },
          );
        },
        'GET /quality/defect-analysis': (_) {
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total_defect_quantity': 9,
                'top_defects': [
                  {'phenomenon': '虚焊', 'quantity': 5, 'ratio': 55.56},
                ],
                'top_reasons': [
                  {'reason': '治具偏移', 'quantity': 4, 'ratio': 44.44},
                ],
                'product_quality_comparison': [
                  {
                    'product_id': 11,
                    'product_name': '产品A',
                    'first_article_total': 4,
                    'passed_total': 3,
                    'failed_total': 1,
                    'pass_rate_percent': 75,
                    'defect_total': 4,
                    'scrap_total': 2,
                    'repair_total': 5,
                  },
                ],
                'by_process': [
                  {
                    'process_code': '01-01',
                    'process_name': '切割',
                    'quantity': 4,
                  },
                ],
                'by_product': [
                  {'product_id': 11, 'product_name': '产品A', 'quantity': 9},
                ],
                'by_operator': [
                  {
                    'operator_user_id': 7,
                    'operator_username': 'worker',
                    'quantity': 6,
                  },
                ],
                'by_date': [
                  {'stat_date': '2026-03-01', 'quantity': 9},
                ],
              },
            },
          );
        },
      });
      addTearDown(server.close);

      final service = QualityService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'quality-token'),
      );

      final productItems = await service.getQualityProductStats();
      final trendItems = await service.getQualityTrend();
      final defectResult = await service.getDefectAnalysis();

      expect(productItems.single.repairTotal, 5);
      expect(trendItems.single.date, '2026-03-01');
      expect(trendItems.single.defectTotal, 4);
      expect(defectResult.topReasons.single.reason, '治具偏移');
      expect(defectResult.productQualityComparison.single.productName, '产品A');
      expect(defectResult.byOperator.single.operatorUsername, 'worker');
      expect(defectResult.byDate.single.date, '2026-03-01');
    });

    test('quality scrap and repair contracts use quality namespace', () async {
      final server = await TestHttpServer.start({
        'GET /quality/scrap-statistics': (request) {
          expect(request.uri.queryParameters['keyword'], '报废');
          expect(request.uri.queryParameters['page'], '2');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'items': [
                  {
                    'id': 21,
                    'order_code': 'PO-21',
                    'product_name': '产品Q',
                    'process_name': '检验',
                    'scrap_reason': '破损',
                    'scrap_quantity': 3,
                    'progress': 'pending_apply',
                    'created_at': '2026-03-05T08:00:00Z',
                    'updated_at': '2026-03-05T08:10:00Z',
                  },
                ],
              },
            },
          );
        },
        'GET /quality/scrap-statistics/21': (_) {
          return TestResponse.json(
            200,
            body: {
              'data': {
                'id': 21,
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
              },
            },
          );
        },
        'GET /quality/repair-orders': (request) {
          expect(request.uri.queryParameters['status'], 'completed');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'items': [
                  {
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
                  },
                ],
              },
            },
          );
        },
        'GET /quality/repair-orders/7/detail': (_) {
          return TestResponse.json(
            200,
            body: {
              'data': {
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
                'defect_rows': [
                  {'id': 1, 'phenomenon': '虚焊', 'quantity': 3},
                ],
              },
            },
          );
        },
        'GET /quality/repair-orders/7/phenomena-summary': (_) {
          return TestResponse.json(
            200,
            body: {
              'data': {
                'repair_order_id': 7,
                'items': [
                  {'phenomenon': '虚焊', 'quantity': 3},
                ],
              },
            },
          );
        },
        'POST /quality/scrap-statistics/export': (_) {
          return TestResponse.json(
            200,
            body: {
              'data': {
                'file_name': 'quality_scrap.csv',
                'mime_type': 'text/csv',
                'content_base64': 'c2NyYXA=',
                'exported_count': 1,
              },
            },
          );
        },
        'POST /quality/repair-orders/7/complete': (request) {
          final body = request.decodedBody as Map<String, dynamic>? ?? const {};
          expect((body['cause_items'] as List).first['reason'], '治具偏移');
          return TestResponse.json(
            200,
            body: {
              'data': {
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
              },
            },
          );
        },
        'POST /quality/repair-orders/export': (_) {
          return TestResponse.json(
            200,
            body: {
              'data': {
                'file_name': 'quality_repair.csv',
                'mime_type': 'text/csv',
                'content_base64': 'cmVwYWly',
                'exported_count': 1,
              },
            },
          );
        },
      });
      addTearDown(server.close);

      final service = QualityService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'quality-token'),
      );

      final scrapList = await service.listQualityScrapStatistics(
        keyword: '报废',
        page: 2,
      );
      final scrapDetail = await service.getQualityScrapStatisticsDetail(
        scrapId: 21,
      );
      final repairList = await service.listQualityRepairOrders(
        status: 'completed',
      );
      final repairDetail = await service.getQualityRepairOrderDetail(
        repairOrderId: 7,
      );
      final phenomena = await service.getRepairOrderPhenomenaSummary(
        repairOrderId: 7,
      );
      final scrapExport = await service.exportScrapStatistics(keyword: '报废');
      final completed = await service.completeRepairOrder(
        repairOrderId: 7,
        causeItems: [
          const RepairCauseItemInput(
            phenomenon: '虚焊',
            reason: '治具偏移',
            quantity: 3,
            isScrap: false,
          ),
        ],
        scrapReplenished: false,
        returnAllocations: [
          const RepairReturnAllocationInput(targetOrderProcessId: 9, quantity: 3),
        ],
      );
      final repairExport = await service.exportRepairOrders(keyword: 'RW-7');

      expect(scrapList.total, 1);
      expect(scrapDetail.relatedRepairOrders.single.repairOrderCode, 'RW-7');
      expect(repairList.items.single.repairOrderCode, 'RW-7');
      expect(repairDetail.defectRows.single.phenomenon, '虚焊');
      expect(phenomena.items.single.quantity, 3);
      expect(scrapExport.fileName, 'quality_scrap.csv');
      expect(completed.status, 'completed');
      expect(repairExport.fileName, 'quality_repair.csv');
    });

    test('trend and defect exports keep backend filename fields', () async {
      final server = await TestHttpServer.start({
        'POST /quality/trend/export': (_) {
          return TestResponse.json(
            200,
            body: {
              'data': {
                'filename': 'quality_trend.csv',
                'content_base64': 'dHJlbmQ=',
              },
            },
          );
        },
        'POST /quality/defect-analysis/export': (_) {
          return TestResponse.json(
            200,
            body: {
              'data': {
                'filename': 'defect_analysis.csv',
                'content_base64': 'ZGVmZWN0',
              },
            },
          );
        },
      });
      addTearDown(server.close);

      final service = QualityService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'quality-token'),
      );

      final trendExport = await service.exportQualityTrend();
      final defectExport = await service.exportDefectAnalysis();

      expect(trendExport.filename, 'quality_trend.csv');
      expect(trendExport.contentBase64, 'dHJlbmQ=');
      expect(defectExport.filename, 'defect_analysis.csv');
      expect(defectExport.contentBase64, 'ZGVmZWN0');
    });
  });
}
