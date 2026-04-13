import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/shell/models/home_dashboard_models.dart';
import 'package:mes_client/features/shell/services/home_dashboard_service.dart';

import '../support/http_test_server.dart';

void main() {
  group('HomeDashboardService', () {
    test('load 成功请求 /ui/home-dashboard 并解析首页数据', () async {
      final server = await TestHttpServer.start({
        'GET /ui/home-dashboard': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'generated_at': '2026-04-12T12:00:00Z',
              'notice_count': 2,
              'todo_summary': {
                'total_count': 12,
                'pending_approval_count': 2,
                'high_priority_count': 2,
                'exception_count': 6,
                'overdue_count': 1,
              },
              'todo_items': [
                {
                  'id': 1,
                  'title': '待办 A',
                  'category_label': '审批',
                  'priority_label': '高优',
                  'source_module': 'user',
                  'target_page_code': 'user',
                  'target_tab_code': 'registration_approval',
                  'target_route_payload_json': '{"request_id":1}',
                },
              ],
              'risk_items': [
                {'code': 'risk_a', 'label': '风险 A', 'value': 3},
              ],
              'kpi_items': [
                {'code': 'kpi_a', 'label': '产量', 'value': '95%'},
              ],
              'degraded_blocks': [
                {'code': 'kpi'},
              ],
            },
          },
        ),
      });
      addTearDown(server.close);

      final service = HomeDashboardService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-ui'),
      );

      final result = await service.load();

      expect(result.noticeCount, 2);
      expect(result.todoItems.single.title, '待办 A');
      expect(result.todoSummary.exceptionCount, 6);
      expect(result.riskItems.single.value, '3');
      expect(result.kpiItems.single.code, 'kpi_a');
      expect(result.degradedBlocks, ['kpi']);
    });

    test('load 在非 200 响应时抛出 ApiException', () async {
      final server = await TestHttpServer.start({
        'GET /ui/home-dashboard': (_) =>
            TestResponse.json(500, body: {'message': 'dashboard failed'}),
      });
      addTearDown(server.close);

      final service = HomeDashboardService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-ui'),
      );

      await expectLater(
        service.load,
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message', 'dashboard failed'),
        ),
      );
    });

    test('load 在非 200 且响应体非 JSON 时仍抛 ApiException', () async {
      final server = await TestHttpServer.start({
        'GET /ui/home-dashboard': (_) =>
            const TestResponse(statusCode: 500, body: 'server exploded'),
      });
      addTearDown(server.close);

      final service = HomeDashboardService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-ui'),
      );

      await expectLater(
        service.load,
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message', '加载首页工作台失败'),
        ),
      );
    });
  });

  test('HomeDashboardData.fromJson 轻量解析断言', () {
    final result = HomeDashboardData.fromJson({
      'notice_count': 1,
      'todo_summary': {'exception_count': 2},
      'degraded_blocks': ['todo'],
    });

    expect(result.noticeCount, 1);
    expect(result.todoSummary.exceptionCount, 2);
    expect(result.degradedBlocks, ['todo']);
  });
}
