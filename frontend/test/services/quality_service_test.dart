import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/quality/services/quality_service.dart';

import '../support/http_test_server.dart';

void main() {
  group('QualityService', () {
    test(
      'lists first-article data and stats with formatted query params',
      () async {
        final server = await TestHttpServer.start({
          'GET /quality/first-articles': (request) {
            expect(request.uri.queryParameters['page'], '2');
            expect(request.uri.queryParameters['page_size'], '200');
            expect(request.uri.queryParameters['date'], '2026-03-05');
            expect(request.uri.queryParameters['keyword'], '工单A');
            return TestResponse.json(
              200,
              body: {
                'data': {
                  'query_date': '2026-03-05',
                  'verification_code': 'V1',
                  'verification_code_source': 'stored',
                  'total': 1,
                  'items': [
                    {
                      'id': 1,
                      'order_id': 10,
                      'order_code': 'PO-1',
                      'product_id': 2,
                      'product_name': '产品A',
                      'order_process_id': 3,
                      'process_code': '01-01',
                      'process_name': '切割',
                      'operator_user_id': 4,
                      'operator_username': 'worker',
                      'result': 'passed',
                      'verification_date': '2026-03-05T10:00:00Z',
                      'created_at': '2026-03-05T10:00:01Z',
                    },
                  ],
                },
              },
            );
          },
          'GET /quality/first-articles/1': (request) {
            expect(request.headers['authorization'], 'Bearer token-quality');
            return TestResponse.json(
              200,
              body: {
                'data': {
                  'id': 1,
                  'order_id': 10,
                  'order_code': 'PO-1',
                  'product_id': 2,
                  'product_name': '产品A',
                  'order_process_id': 3,
                  'process_name': '切割',
                  'operator_user_id': 4,
                  'operator_username': 'worker',
                  'result': 'failed',
                  'verification_code': 'V1',
                  'template_id': 5,
                  'template_name': '品质模板A',
                  'check_content': '外观确认',
                  'test_value': '9.86',
                  'participants': [
                    {'user_id': 4, 'username': 'worker', 'full_name': '操作员甲'},
                  ],
                  'remark': '存在毛刺',
                  'created_at': '2026-03-05T10:00:01Z',
                },
              },
            );
          },
          'GET /quality/first-articles/1/disposition-detail': (request) {
            expect(request.headers['authorization'], 'Bearer token-quality');
            return TestResponse.json(
              200,
              body: {
                'data': {
                  'id': 1,
                  'order_id': 10,
                  'order_code': 'PO-1',
                  'product_id': 2,
                  'product_name': '产品A',
                  'order_process_id': 3,
                  'process_name': '切割',
                  'operator_user_id': 4,
                  'operator_username': 'worker',
                  'result': 'failed',
                  'verification_code': 'V1',
                  'template_name': '品质模板A',
                  'check_content': '外观确认',
                  'test_value': '9.86',
                  'participants': [
                    {'user_id': 5, 'username': 'assistant'},
                  ],
                  'disposition_opinion': '返工处理',
                  'created_at': '2026-03-05T10:00:01Z',
                },
              },
            );
          },
          'GET /quality/stats/overview': (request) {
            expect(request.uri.queryParameters['start_date'], '2026-03-01');
            expect(request.uri.queryParameters['end_date'], '2026-03-06');
            return TestResponse.json(
              200,
              body: {
                'data': {
                  'first_article_total': 5,
                  'passed_total': 4,
                  'failed_total': 1,
                  'pass_rate_percent': 80,
                  'covered_order_count': 3,
                  'covered_process_count': 2,
                  'covered_operator_count': 2,
                  'latest_first_article_at': '2026-03-05T10:00:01Z',
                },
              },
            );
          },
          'GET /quality/stats/processes': (request) {
            expect(request.uri.queryParameters['start_date'], '2026-03-01');
            expect(request.uri.queryParameters['end_date'], '2026-03-06');
            return TestResponse.json(
              200,
              body: {
                'data': {
                  'items': [
                    {
                      'process_code': '01-01',
                      'process_name': '切割',
                      'first_article_total': 2,
                      'passed_total': 2,
                      'failed_total': 0,
                      'pass_rate_percent': 100,
                      'latest_first_article_at': '2026-03-05T10:00:01Z',
                    },
                  ],
                },
              },
            );
          },
          'GET /quality/stats/operators': (request) {
            expect(request.uri.queryParameters['start_date'], '2026-03-01');
            expect(request.uri.queryParameters['end_date'], '2026-03-06');
            return TestResponse.json(
              200,
              body: {
                'data': {
                  'items': [
                    {
                      'operator_user_id': 1,
                      'operator_username': 'worker',
                      'first_article_total': 2,
                      'passed_total': 2,
                      'failed_total': 0,
                      'pass_rate_percent': 100,
                      'latest_first_article_at': '2026-03-05T10:00:01Z',
                    },
                  ],
                },
              },
            );
          },
        });
        addTearDown(server.close);

        final service = QualityService(
          AppSession(baseUrl: server.baseUrl, accessToken: 'token-quality'),
        );

        final firstArticles = await service.listFirstArticles(
          date: DateTime(2026, 3, 5),
          keyword: '  工单A ',
          page: 2,
          pageSize: 500,
        );
        final overview = await service.getQualityOverview(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 6),
        );
        final processStats = await service.getQualityProcessStats(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 6),
        );
        final detail = await service.getFirstArticleDetail(1);
        final dispositionDetail = await service
            .getFirstArticleDispositionDetail(1);
        final operatorStats = await service.getQualityOperatorStats(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 6),
        );

        expect(firstArticles.total, 1);
        expect(overview.passRatePercent, 80);
        expect(processStats.single.processCode, '01-01');
        expect(detail.productionOrderCode, 'PO-1');
        expect(detail.templateName, '品质模板A');
        expect(detail.checkContent, '外观确认');
        expect(detail.participants.single.displayName, 'worker (操作员甲)');
        expect(dispositionDetail.disposition?.dispositionOpinion, '返工处理');
        expect(dispositionDetail.testValue, '9.86');
        expect(dispositionDetail.participants.single.displayName, 'assistant');
        expect(operatorStats.single.operatorUsername, 'worker');
      },
    );

    test('throws ApiException on failed response', () async {
      final server = await TestHttpServer.start({
        'GET /quality/stats/overview': (_) =>
            const TestResponse(statusCode: 500, body: null),
      });
      addTearDown(server.close);

      final service = QualityService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-quality'),
      );

      await expectLater(
        () => service.getQualityOverview(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });
}
