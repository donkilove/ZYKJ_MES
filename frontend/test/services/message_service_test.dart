import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/message/models/message_models.dart';
import 'package:mes_client/features/message/services/message_service.dart';
import 'package:mes_client/features/message/services/message_ws_service.dart';

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
      final list = await service.listMessages(
        page: 2,
        pageSize: 10,
        todoOnly: true,
      );
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

    test(
      'supports public announcements without authorization header',
      () async {
        final server = await TestHttpServer.start({
          'GET /messages/public-announcements': (request) {
            expect(request.uri.queryParameters['page'], '1');
            expect(request.uri.queryParameters['page_size'], '10');
            expect(request.headers.containsKey('authorization'), isFalse);
            return TestResponse.json(
              200,
              body: {
                'data': {
                  'items': [
                    {
                      'id': 11,
                      'message_type': 'announcement',
                      'priority': 'important',
                      'title': '全员停机公告',
                      'summary': '今晚停机维护',
                      'content': '今晚 20:00 至 21:00 执行维护。',
                      'source_module': 'message',
                      'source_type': 'announcement',
                      'source_code': 'all',
                      'target_page_code': null,
                      'target_tab_code': null,
                      'target_route_payload_json': null,
                      'status': 'active',
                      'inactive_reason': null,
                      'published_at': '2026-04-22T12:00:00Z',
                      'expires_at': '2026-04-23T12:00:00Z',
                      'is_read': false,
                      'read_at': null,
                      'delivered_at': null,
                      'delivery_status': 'pending',
                      'delivery_attempt_count': 0,
                      'last_push_at': null,
                      'next_retry_at': null,
                    },
                  ],
                  'total': 1,
                  'page': 1,
                  'page_size': 10,
                },
              },
            );
          },
        });
        addTearDown(server.close);

        final service = MessageService.public(server.baseUrl);
        final items = await service.getPublicAnnouncements(pageSize: 10);

        expect(items, hasLength(1));
        expect(items.single.title, '全员停机公告');
        expect(items.single.sourceCode, 'all');
        expect(items.single.expiresAt, DateTime.parse('2026-04-23T12:00:00Z'));
      },
    );

    test('supports active announcement query and offline action', () async {
      final server = await TestHttpServer.start({
        'GET /messages/announcements/active': (request) {
          expect(request.uri.queryParameters['page'], '1');
          expect(request.uri.queryParameters['page_size'], '50');
          expect(request.uri.queryParameters['priority'], 'important');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'items': [
                  {
                    'id': 21,
                    'message_type': 'announcement',
                    'priority': 'important',
                    'title': '当前生效公告',
                    'summary': '用于公告管理页',
                    'content': '公告正文',
                    'source_module': 'message',
                    'source_type': 'announcement',
                    'source_code': 'roles',
                    'target_page_code': null,
                    'target_tab_code': null,
                    'target_route_payload_json': null,
                    'status': 'active',
                    'inactive_reason': null,
                    'published_at': '2026-05-01T09:00:00Z',
                    'expires_at': '2026-05-31T09:00:00Z',
                    'is_read': false,
                    'read_at': null,
                    'delivered_at': null,
                    'delivery_status': 'pending',
                    'delivery_attempt_count': 0,
                    'last_push_at': null,
                    'next_retry_at': null,
                  },
                ],
                'total': 1,
                'page': 1,
                'page_size': 50,
              },
            },
          );
        },
        'POST /messages/announcements/21/offline': (_) => TestResponse.json(
          200,
          body: {
            'data': {'message_id': 21, 'status': 'offline'},
          },
        ),
      });
      addTearDown(server.close);

      final service = MessageService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'msg-token'),
      );

      final result = await service.getActiveAnnouncements(
        page: 1,
        pageSize: 50,
        priority: 'important',
      );
      final offlineResult = await service.offlineAnnouncement(21);

      expect(result.items, hasLength(1));
      expect(result.items.single.title, '当前生效公告');
      expect(result.total, 1);
      expect(result.pageSize, 50);
      expect(offlineResult.messageId, 21);
      expect(offlineResult.status, 'offline');
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
