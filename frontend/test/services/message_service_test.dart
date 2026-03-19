import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/services/message_service.dart';

import '../support/http_test_server.dart';

void main() {
  group('MessageService', () {
    test('supports summary, todo filter and batch read', () async {
      final server = await TestHttpServer.start({
        'GET /messages/summary': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'total_count': 5,
              'unread_count': 3,
              'todo_unread_count': 2,
              'urgent_unread_count': 1,
            },
          },
        ),
        'GET /messages': (request) {
          expect(request.uri.queryParameters['todo_only'], 'true');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'items': [
                  {
                    'id': 1,
                    'message_type': 'todo',
                    'priority': 'urgent',
                    'title': '待办提醒',
                    'summary': '请处理',
                    'content': '正文',
                    'source_module': 'production',
                    'source_type': 'repair_order',
                    'source_code': 'RW-1',
                    'target_page_code': 'production',
                    'target_tab_code': 'production_repair_orders',
                    'target_route_payload_json': null,
                    'status': 'active',
                    'published_at': '2026-03-19T08:00:00Z',
                    'is_read': false,
                    'read_at': null,
                    'delivered_at': '2026-03-19T08:00:00Z',
                  },
                ],
                'total': 1,
                'page': 1,
                'page_size': 20,
              },
            },
          );
        },
        'POST /messages/read-batch': (request) {
          final body = request.decodedBody as Map<String, dynamic>? ?? const {};
          expect(body['message_ids'], [1, 2]);
          return TestResponse.json(200, body: {'data': {'updated': 2}});
        },
      });
      addTearDown(server.close);

      final service = MessageService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'msg-token'),
      );

      final summary = await service.getSummary();
      final list = await service.listMessages(todoOnly: true);
      final updated = await service.markBatchRead([1, 2]);

      expect(summary.totalCount, 5);
      expect(summary.todoUnreadCount, 2);
      expect(list.items.single.targetTabCode, 'production_repair_orders');
      expect(updated, 2);
    });
  });
}
