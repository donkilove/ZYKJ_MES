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
    test('supports summary, pagination, todo filter and batch read', () async {
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
          expect(request.uri.queryParameters['page'], '2');
          expect(request.uri.queryParameters['page_size'], '10');
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
                    'delivery_status': 'failed',
                    'delivery_attempt_count': 2,
                    'last_push_at': '2026-03-19T08:05:00Z',
                    'next_retry_at': '2026-03-19T08:10:00Z',
                  },
                ],
                'total': 1,
                'page': 2,
                'page_size': 10,
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
        'POST /messages/maintenance/run': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'pending_compensated': 2,
              'failed_retried': 1,
              'source_unavailable_updated': 3,
              'archived_messages': 4,
            },
          },
        ),
        'GET /messages/1': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'id': 1,
              'message_type': 'todo',
              'priority': 'urgent',
              'title': '待办提醒',
              'summary': '请处理',
              'content': '完整正文',
              'source_module': 'production',
              'source_type': 'repair_order',
              'source_id': '88',
              'source_code': 'RW-1',
              'target_page_code': 'production',
              'target_tab_code': 'production_repair_orders',
              'target_route_payload_json': '{"action":"detail"}',
              'status': 'active',
              'inactive_reason': null,
              'published_at': '2026-03-19T08:00:00Z',
              'is_read': false,
              'read_at': null,
              'delivered_at': '2026-03-19T08:00:00Z',
              'delivery_status': 'failed',
              'delivery_attempt_count': 2,
              'last_push_at': '2026-03-19T08:05:00Z',
              'next_retry_at': '2026-03-19T08:10:00Z',
              'failure_reason_hint': '实时推送失败，系统将按计划继续重试。',
            },
          },
        ),
        'GET /messages/1/jump-target': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'can_jump': true,
              'disabled_reason': null,
              'target_page_code': 'production',
              'target_tab_code': 'production_repair_orders',
              'target_route_payload_json': '{"action":"detail"}',
            },
          },
        ),
      });
      addTearDown(server.close);

      final service = MessageService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'msg-token'),
      );

      final summary = await service.getSummary();
      final list = await service.listMessages(page: 2, pageSize: 10, todoOnly: true);
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
      final maintenanceResult = await service.runMaintenance();
      final detail = await service.getMessageDetail(1);
      final jumpTarget = await service.getMessageJumpTarget(1);

      expect(summary.totalCount, 5);
      expect(summary.todoUnreadCount, 2);
      expect(list.items.single.inactiveReason, 'no_permission');
      expect(list.items.single.inactiveReasonName, '暂无目标页面访问权限');
      expect(list.items.single.targetTabCode, 'production_repair_orders');
      expect(list.items.single.deliveryStatusName, '投递失败');
      expect(list.items.single.deliveryAttemptCount, 2);
      expect(list.page, 2);
      expect(list.pageSize, 10);
      expect(updated, 2);
      expect(publishResult.messageId, 9);
      expect(publishResult.recipientCount, 3);
      expect(maintenanceResult.pendingCompensated, 2);
      expect(maintenanceResult.failedRetried, 1);
      expect(detail.sourceId, '88');
      expect(detail.failureReasonHint, contains('按计划继续重试'));
      expect(jumpTarget.canJump, isTrue);
      expect(jumpTarget.targetPageCode, 'production');
    });
  });

  group('MessageWsService', () {
    test('suppresses duplicate websocket events', () async {
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
            '{"event":"message_created","user_id":1,"message_id":9,"unread_count":4,"occurred_at":"2026-03-22T10:00:00Z"}',
          );
          socket.add(
            '{"event":"message_created","user_id":1,"message_id":9,"unread_count":4,"occurred_at":"2026-03-22T10:00:01Z"}',
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
