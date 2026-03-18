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

      final contentBase64 = await service.exportFirstArticles(
        date: DateTime(2026, 3, 5),
        keyword: '工单A',
        result: 'failed',
      );

      expect(contentBase64, 'ZGF0YQ==');
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

      final contentBase64 = await service.exportQualityStats(
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 3, 7),
      );

      expect(contentBase64, 'c3RhdHM=');
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
                    'scrap_total': 1,
                  },
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

      expect(productItems.single.repairTotal, 5);
      expect(trendItems.single.date, '2026-03-01');
    });
  });
}
