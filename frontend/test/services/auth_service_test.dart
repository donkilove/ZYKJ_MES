import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/services/api_exception.dart';
import 'package:mes_client/services/auth_service.dart';

import '../support/http_test_server.dart';

void main() {
  group('AuthService', () {
    test('handles login/register/account/me/logout success flow', () async {
      final server = await TestHttpServer.start({
        'POST /auth/login': (request) {
          expect(
            request.headers['content-type'] ?? '',
            contains('application/x-www-form-urlencoded'),
          );
          expect(request.bodyText, contains('username=admin'));
          expect(request.bodyText, contains('password=pass123'));
          return TestResponse.json(
            200,
            body: {
              'data': {'access_token': 'token-abc'},
            },
          );
        },
        'POST /auth/register': (_) => TestResponse.json(201, body: {'ok': true}),
        'GET /auth/accounts': (_) => TestResponse.json(
          200,
          body: {
            'data': {'accounts': ['admin', 'worker']},
          },
        ),
        'GET /auth/me': (request) {
          expect(request.headers['authorization'], 'Bearer token-abc');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'id': 1,
                'username': 'admin',
                'full_name': '管理员',
                'role_code': 'system_admin',
                'role_name': '系统管理员',
                'stage_id': 1,
                'stage_name': '切割段',
              },
            },
          );
        },
        'POST /auth/logout': (request) {
          expect(request.headers['authorization'], 'Bearer token-abc');
          return TestResponse.json(200, body: {'data': {}});
        },
      });
      addTearDown(server.close);

      final service = AuthService();
      final token = await service.login(
        baseUrl: server.baseUrl,
        username: 'admin',
        password: 'pass123',
      );
      await service.register(
        baseUrl: server.baseUrl,
        account: 'new_user',
        password: 'new_password',
      );
      final accounts = await service.listAccounts(baseUrl: server.baseUrl);
      final currentUser = await service.getCurrentUser(
        baseUrl: server.baseUrl,
        accessToken: token.token,
      );
      await service.logout(baseUrl: server.baseUrl, accessToken: token.token);

      expect(token.token, 'token-abc');
      expect(accounts, ['admin', 'worker']);
      expect(currentUser.displayName, '管理员');
      expect(currentUser.roleCode, 'system_admin');
      expect(currentUser.stageName, '切割段');
      expect(server.requests.length, 5);
    });

    test('throws ApiException when login failed or token missing', () async {
      final badLoginServer = await TestHttpServer.start({
        'POST /auth/login': (_) => TestResponse.json(
          401,
          body: {'detail': 'invalid credentials'},
        ),
      });
      addTearDown(badLoginServer.close);
      final service = AuthService();

      await expectLater(
        () => service.login(
          baseUrl: badLoginServer.baseUrl,
          username: 'admin',
          password: 'wrong',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'invalid credentials'),
        ),
      );

      final missingTokenServer = await TestHttpServer.start({
        'POST /auth/login': (_) => TestResponse.json(
          200,
          body: {
            'data': <String, dynamic>{},
          },
        ),
      });
      addTearDown(missingTokenServer.close);

      await expectLater(
        () => service.login(
          baseUrl: missingTokenServer.baseUrl,
          username: 'admin',
          password: 'pass123',
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 200)),
      );
    });
  });
}
