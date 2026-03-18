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
            expect(body['password'], 'new-pass');
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
          password: 'new-pass',
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
  });
}
