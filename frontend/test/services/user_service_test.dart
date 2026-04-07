import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/services/api_exception.dart';
import 'package:mes_client/services/user_service.dart';

import '../support/http_test_server.dart';

void main() {
  group('UserService', () {
    test(
      'covers list/create/update/delete and registration review APIs',
      () async {
        final server = await TestHttpServer.start({
          'GET /users': (request) {
            expect(request.uri.queryParameters['page'], '2');
            expect(request.uri.queryParameters['page_size'], '20');
            expect(request.uri.queryParameters['keyword'], 'tester');
            return TestResponse.json(
              200,
              body: {
                'data': {
                  'total': 1,
                  'items': [
                    {
                      'id': 1,
                      'username': 'tester',
                      'full_name': 'Test User',
                      'is_online': true,
                      'last_seen_at': '2026-03-01T10:00:00Z',
                      'role_code': 'production_admin',
                      'role_name': 'Production admin',
                      'stage_name': 'Cutting stage',
                    },
                  ],
                },
              },
            );
          },
          'GET /roles': (request) {
            expect(request.uri.queryParameters['page'], '1');
            expect(request.uri.queryParameters['page_size'], '200');
            return TestResponse.json(
              200,
              body: {
                'data': {
                  'total': 1,
                  'items': [
                    {'id': 10, 'code': 'system_admin', 'name': 'System admin'},
                  ],
                },
              },
            );
          },
          'GET /processes': (request) {
            expect(request.uri.queryParameters['page'], '1');
            expect(request.uri.queryParameters['page_size'], '200');
            return TestResponse.json(
              200,
              body: {
                'data': {
                  'total': 1,
                  'items': [
                    {
                      'id': 5,
                      'code': '01-01',
                      'name': 'Cutting',
                      'stage_id': 1,
                      'stage_code': '01',
                      'stage_name': 'Cutting stage',
                    },
                  ],
                },
              },
            );
          },
          'GET /auth/register-requests': (request) {
            expect(request.uri.queryParameters['keyword'], 'new');
            return TestResponse.json(
              200,
              body: {
                'data': {
                  'total': 1,
                  'items': [
                    {
                      'id': 7,
                      'account': 'new_user',
                      'created_at': '2026-03-03T10:00:00Z',
                    },
                  ],
                },
              },
            );
          },
          'POST /auth/register-requests/7/approve': (request) {
            final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
            expect(body['account'], 'new_user');
            expect(body['role_code'], 'production_admin');
            return TestResponse.json(200, body: {'data': {}});
          },
          'POST /auth/register-requests/7/reject': (_) =>
              TestResponse.json(200, body: {'data': {}}),
          'POST /users': (request) {
            final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
            expect(body['username'], 'created_user');
            expect(body['full_name'], 'created_user');
            expect(body['role_code'], 'production_admin');
            expect(body['stage_id'], 1);
            return TestResponse.json(201, body: {'data': {}});
          },
          'PUT /users/9': (request) {
            final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
            expect(body['username'], 'updated_user');
            expect(body['full_name'], 'updated_user');
            expect(body.containsKey('password'), isFalse);
            expect(body['role_code'], 'system_admin');
            expect(body['stage_id'], 2);
            return TestResponse.json(200, body: {'data': {}});
          },
          'POST /users/9/reset-password': (request) {
            final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
            expect(
              request.uri.queryParameters.containsKey('password'),
              isFalse,
            );
            expect(body['password'], 'reset-pass-2');
            return TestResponse.json(200, body: {'data': {}});
          },
          'DELETE /users/9': (_) => TestResponse.json(200, body: {'data': {}}),
        });
        addTearDown(server.close);

        final service = UserService(
          AppSession(baseUrl: server.baseUrl, accessToken: 'token-user'),
        );

        final users = await service.listUsers(
          page: 2,
          pageSize: 20,
          keyword: '  tester ',
        );
        final roles = await service.listRoles();
        final processes = await service.listProcesses();
        final requests = await service.listRegistrationRequests(
          page: 1,
          pageSize: 10,
          keyword: '  new ',
        );
        await service.approveRegistrationRequest(
          requestId: 7,
          account: 'new_user',
          roleCode: 'production_admin',
        );
        await service.rejectRegistrationRequest(requestId: 7);
        await service.createUser(
          account: 'created_user',
          password: 'pass',
          roleCode: 'production_admin',
          stageId: 1,
        );
        await service.updateUser(
          userId: 9,
          account: 'updated_user',
          roleCode: 'system_admin',
          stageId: 2,
        );
        await service.resetUserPassword(userId: 9, password: 'reset-pass-2');
        await service.deleteUser(userId: 9);

        expect(users.total, 1);
        expect(users.items.single.username, 'tester');
        expect(roles.items.single.code, 'system_admin');
        expect(processes.items.single.code, '01-01');
        expect(requests.items.single.account, 'new_user');
        expect(server.requests.length, 10);
      },
    );

    test('throws ApiException on non-200 response', () async {
      final server = await TestHttpServer.start({
        'GET /roles': (_) =>
            TestResponse.json(500, body: {'message': 'roles failed'}),
      });
      addTearDown(server.close);

      final service = UserService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-user'),
      );

      await expectLater(
        service.listRoles,
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message', 'roles failed'),
        ),
      );
    });

    test(
      'supports lightweight online status API with repeated user_id query',
      () async {
        final server = await TestHttpServer.start({
          'GET /users/online-status': (request) {
            final userIds =
                request.uri.queryParametersAll['user_id'] ?? const [];
            expect(userIds, ['3', '9', '12']);
            return TestResponse.json(
              200,
              body: {
                'data': {
                  'user_ids': [3, '12'],
                },
              },
            );
          },
        });
        addTearDown(server.close);

        final service = UserService(
          AppSession(baseUrl: server.baseUrl, accessToken: 'token-user'),
        );

        final onlineUserIds = await service.listOnlineUserIds(
          userIds: const [9, 3, 9, 12],
        );
        final emptyResult = await service.listOnlineUserIds(userIds: const []);

        expect(onlineUserIds, {3, 12});
        expect(emptyResult, isEmpty);
        expect(server.requests.length, 1);
      },
    );

    test('covers user module audit session profile and export APIs', () async {
      final server = await TestHttpServer.start({
        'GET /users': (request) {
          expect(request.uri.queryParameters['page'], '1');
          expect(request.uri.queryParameters['page_size'], '50');
          expect(request.uri.queryParameters['role_code'], 'quality_admin');
          expect(request.uri.queryParameters['stage_id'], '9');
          expect(request.uri.queryParameters['is_online'], 'true');
          expect(request.uri.queryParameters['is_active'], 'false');
          expect(request.uri.queryParameters['include_deleted'], 'true');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'items': [
                  {
                    'id': 21,
                    'username': 'quality_user',
                    'full_name': 'Quality User',
                    'role_code': 'quality_admin',
                    'role_name': '品质管理员',
                    'stage_id': 9,
                    'stage_name': '检验',
                    'is_online': true,
                    'is_active': false,
                  },
                ],
              },
            },
          );
        },
        'GET /users/export': (request) {
          expect(request.uri.queryParameters['format'], 'xlsx');
          expect(request.uri.queryParameters['keyword'], 'quality');
          expect(request.uri.queryParameters['role_code'], 'quality_admin');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'filename': 'users.xlsx',
                'content_type':
                    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                'content_base64': 'dGVzdA==',
              },
            },
          );
        },
        'GET /audits': (request) {
          expect(request.uri.queryParameters['page'], '2');
          expect(request.uri.queryParameters['page_size'], '50');
          expect(request.uri.queryParameters['operator_username'], 'auditor');
          expect(request.uri.queryParameters['action_code'], 'user.disable');
          expect(request.uri.queryParameters['target_type'], 'user');
          expect(
            request.uri.queryParameters['start_time'],
            '2026-03-01T00:00:00.000',
          );
          expect(
            request.uri.queryParameters['end_time'],
            '2026-03-05T23:59:59.000',
          );
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'items': [
                  {
                    'id': 8,
                    'occurred_at': '2026-03-02T10:30:00Z',
                    'operator_user_id': 1,
                    'operator_username': 'auditor',
                    'action_code': 'user.disable',
                    'action_name': '停用用户',
                    'target_type': 'user',
                    'target_id': '21',
                    'target_name': 'quality_user',
                    'result': 'success',
                    'before_data': {'is_active': true},
                    'after_data': {'is_active': false},
                  },
                ],
              },
            },
          );
        },
        'GET /me/profile': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'id': 1,
              'username': 'tester',
              'full_name': '测试用户',
              'role_code': 'quality_admin',
              'role_name': '品质管理员',
              'stage_id': 9,
              'stage_name': '检验',
              'is_active': true,
            },
          },
        ),
        'GET /me/session': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'session_token_id': 'session-1',
              'login_time': '2026-03-03T08:00:00Z',
              'last_active_at': '2026-03-03T08:10:00Z',
              'expires_at': '2026-03-03T10:00:00Z',
              'status': 'active',
              'remaining_seconds': 3600,
            },
          },
        ),
        'POST /me/password': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['old_password'], 'OldPass123');
          expect(body['new_password'], 'NewPass456');
          expect(body['confirm_password'], 'NewPass456');
          return TestResponse.json(200, body: {'data': {}});
        },
        'GET /sessions/online': (request) {
          expect(request.uri.queryParameters['page'], '1');
          expect(request.uri.queryParameters['page_size'], '20');
          expect(request.uri.queryParameters['keyword'], 'tester');
          expect(request.uri.queryParameters['status_filter'], 'active');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'items': [
                  {
                    'id': 1,
                    'session_token_id': 'session-1',
                    'user_id': 1,
                    'username': 'tester',
                    'role_code': 'quality_admin',
                    'role_name': '品质管理员',
                    'login_time': '2026-03-03T08:00:00Z',
                    'last_active_at': '2026-03-03T08:10:00Z',
                    'expires_at': '2026-03-03T10:00:00Z',
                    'status': 'active',
                  },
                ],
              },
            },
          );
        },
        'POST /sessions/force-offline': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['session_token_id'], 'session-1');
          return TestResponse.json(
            200,
            body: {
              'data': {'affected': 1},
            },
          );
        },
        'POST /sessions/force-offline/batch': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['session_token_ids'], ['session-1', 'session-2']);
          return TestResponse.json(
            200,
            body: {
              'data': {'affected': 2},
            },
          );
        },
      });
      addTearDown(server.close);

      final service = UserService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-user'),
      );

      final filteredUsers = await service.listUsers(
        page: 1,
        pageSize: 50,
        roleCode: 'quality_admin',
        stageId: 9,
        isOnline: true,
        isActive: false,
        includeDeleted: true,
      );
      final exported = await service.exportUsers(
        keyword: ' quality ',
        roleCode: 'quality_admin',
        format: 'xlsx',
      );
      final audits = await service.listAuditLogs(
        page: 2,
        pageSize: 50,
        operatorUsername: ' auditor ',
        actionCode: ' user.disable ',
        targetType: ' user ',
        startTime: DateTime(2026, 3, 1),
        endTime: DateTime(2026, 3, 5, 23, 59, 59),
      );
      final profile = await service.getMyProfile();
      final session = await service.getMySession();
      await service.changeMyPassword(
        oldPassword: 'OldPass123',
        newPassword: 'NewPass456',
        confirmPassword: 'NewPass456',
      );
      final onlineSessions = await service.listOnlineSessions(
        page: 1,
        pageSize: 20,
        keyword: ' tester ',
        statusFilter: ' active ',
      );
      final singleOffline = await service.forceOffline(
        sessionTokenId: 'session-1',
      );
      final batchOffline = await service.batchForceOffline(
        sessionTokenIds: const ['session-1', 'session-2'],
      );

      expect(filteredUsers.items.single.roleCode, 'quality_admin');
      expect(exported.filename, 'users.xlsx');
      expect(exported.contentBase64, 'dGVzdA==');
      expect(audits.items.single.actionName, '停用用户');
      expect(profile.username, 'tester');
      expect(session.sessionTokenId, 'session-1');
      expect(onlineSessions.items.single.username, 'tester');
      expect(singleOffline.affected, 1);
      expect(batchOffline.affected, 2);
      expect(server.requests.length, 9);
    });
  });
}
