import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/services/quality_service.dart';

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
                    'scrap_total': 2,
                    'repair_order_count': 5,
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
                    'scrap_total': 2,
                    'repair_order_count': 5,
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
