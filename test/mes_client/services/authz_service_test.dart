import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/services/api_exception.dart';
import 'package:mes_client/services/authz_service.dart';

import '../support/http_test_server.dart';

void main() {
  group('AuthzService', () {
    test('loads matrix and updates matrix with dry_run and apply', () async {
      final server = await TestHttpServer.start({
        'GET /authz/role-permissions/matrix': (request) {
          expect(request.uri.queryParameters['module'], 'production');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'module_code': 'production',
                'module_codes': ['production', 'system'],
                'permissions': [
                  {
                    'permission_code': 'page.production.view',
                    'permission_name': 'Production module view',
                    'module_code': 'production',
                    'resource_type': 'page',
                    'parent_permission_code': null,
                    'is_enabled': true,
                  },
                ],
                'role_items': [
                  {
                    'role_code': 'system_admin',
                    'role_name': '系统管理员',
                    'readonly': true,
                    'is_system_admin': true,
                    'granted_permission_codes': ['page.production.view'],
                  },
                  {
                    'role_code': 'production_admin',
                    'role_name': '生产管理员',
                    'readonly': false,
                    'is_system_admin': false,
                    'granted_permission_codes': [],
                  },
                ],
              },
            },
          );
        },
        'PUT /authz/role-permissions/matrix': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['module_code'], 'production');
          expect(body['role_items'], isA<List<dynamic>>());
          final dryRun = body['dry_run'] == true;
          if (dryRun) {
            return TestResponse.json(
              200,
              body: {
                'data': {
                  'module_code': 'production',
                  'dry_run': true,
                  'role_results': [
                    {
                      'role_code': 'production_admin',
                      'role_name': '生产管理员',
                      'readonly': false,
                      'is_system_admin': false,
                      'ignored_input': false,
                      'before_permission_codes': [],
                      'after_permission_codes': ['page.production.view'],
                      'added_permission_codes': ['page.production.view'],
                      'removed_permission_codes': [],
                      'auto_granted_permission_codes': [],
                      'auto_revoked_permission_codes': [],
                      'updated_count': 1,
                    },
                  ],
                },
              },
            );
          }
          return TestResponse.json(
            200,
            body: {
              'data': {
                'module_code': 'production',
                'dry_run': false,
                'role_results': [
                  {
                    'role_code': 'production_admin',
                    'role_name': '生产管理员',
                    'readonly': false,
                    'is_system_admin': false,
                    'ignored_input': false,
                    'before_permission_codes': [],
                    'after_permission_codes': ['page.production.view'],
                    'added_permission_codes': ['page.production.view'],
                    'removed_permission_codes': [],
                    'auto_granted_permission_codes': [],
                    'auto_revoked_permission_codes': [],
                    'updated_count': 1,
                  },
                ],
              },
            },
          );
        },
      });
      addTearDown(server.close);

      final service = AuthzService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-abc'),
      );
      final matrix = await service.loadRolePermissionMatrix(
        moduleCode: 'production',
      );
      final preview = await service.updateRolePermissionMatrix(
        moduleCode: 'production',
        grantedByRoleCode: {
          'production_admin': ['page.production.view'],
        },
        dryRun: true,
        remark: 'preview',
      );
      final saved = await service.updateRolePermissionMatrix(
        moduleCode: 'production',
        grantedByRoleCode: {
          'production_admin': ['page.production.view'],
        },
        dryRun: false,
        remark: 'apply',
      );

      expect(matrix.moduleCode, 'production');
      expect(matrix.moduleCodes, contains('system'));
      expect(matrix.roleItems.length, 2);
      expect(preview.dryRun, isTrue);
      expect(preview.roleResults.first.updatedCount, 1);
      expect(saved.dryRun, isFalse);
      expect(
        saved.roleResults.first.afterPermissionCodes,
        contains('page.production.view'),
      );
    });

    test('throws ApiException when matrix endpoint returns non-200', () async {
      final server = await TestHttpServer.start({
        'GET /authz/role-permissions/matrix': (_) =>
            TestResponse.json(400, body: {'detail': 'module_code is invalid'}),
      });
      addTearDown(server.close);

      final service = AuthzService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-abc'),
      );

      await expectLater(
        () => service.loadRolePermissionMatrix(moduleCode: 'invalid'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', 'module_code is invalid'),
        ),
      );
    });
  });
}
