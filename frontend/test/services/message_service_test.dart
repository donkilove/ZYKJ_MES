import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/message_models.dart';
import 'package:mes_client/services/message_service.dart';
import 'package:mes_client/services/message_ws_service.dart';

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
                    'status': 'no_permission',
                    'inactive_reason': 'no_permission',
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
          return TestResponse.json(
            200,
            body: {
              'data': {'updated': 2},
            },
          );
        },
        'POST /messages/announcements': (request) {
          final body = request.decodedBody as Map<String, dynamic>? ?? const {};
          expect(body['title'], '新的系统公告');
          expect(body['range_type'], 'roles');
          expect(body['role_codes'], ['system_admin']);
          expect(body['user_ids'], isEmpty);
          return TestResponse.json(
            200,
            body: {
              'data': {'message_id': 9, 'recipient_count': 3},
            },
          );
        },
      });
      addTearDown(server.close);

      final service = MessageService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'msg-token'),
      );

      final summary = await service.getSummary();
      final list = await service.listMessages(todoOnly: true);
      final updated = await service.markBatchRead([1, 2]);
      final publishResult = await service.publishAnnouncement(
        const AnnouncementPublishRequest(
          title: '新的系统公告',
          content: '请全员知悉',
          priority: 'important',
          rangeType: 'roles',
          roleCodes: ['system_admin'],
          userIds: [],
          expiresAt: null,
        ),
      );

      expect(summary.totalCount, 5);
      expect(summary.todoUnreadCount, 2);
      expect(list.items.single.inactiveReason, 'no_permission');
      expect(list.items.single.inactiveReasonName, '暂无目标页面访问权限');
      expect(list.items.single.targetTabCode, 'production_repair_orders');
      expect(updated, 2);
      expect(publishResult.messageId, 9);
      expect(publishResult.recipientCount, 3);
    });
  });

  group('MessageWsService', () {
    test('receives unread event through websocket channel', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      unawaited(() async {
        await for (final request in server) {
          if (!WebSocketTransformer.isUpgradeRequest(request)) {
            request.response.statusCode = HttpStatus.badRequest;
            await request.response.close();
            continue;
          }
          final socket = await WebSocketTransformer.upgrade(request);
          socket.add(
            '{"event":"message_created","user_id":1,"message_id":9,"unread_count":4}',
          );
        }
      }());

      final events = <WsEvent>[];
      final service = MessageWsService(
        baseUrl: 'http://${server.address.address}:${server.port}',
        accessToken: 'ws-token',
        onEvent: events.add,
        onDisconnected: () {},
      );

      service.connect();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(events, hasLength(1));
      expect(events.single.event, 'message_created');
      expect(events.single.unreadCount, 4);
      expect(events.single.messageId, 9);

      service.disconnect();
    });
  });
}
