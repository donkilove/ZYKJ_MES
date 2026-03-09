import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/authz_models.dart';
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

    test('loads and updates permission hierarchy endpoints', () async {
      final server = await TestHttpServer.start({
        'GET /authz/hierarchy/catalog': (request) {
          expect(request.uri.queryParameters['module'], 'production');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'module_code': 'production',
                'module_codes': ['production', 'system'],
                'module_permission_code': 'module.production.access',
                'module_name': '生产管理',
                'pages': [
                  {
                    'page_code': 'production_order_management',
                    'page_name': '订单管理',
                    'permission_code': 'page.production_order_management.view',
                    'parent_page_code': 'production',
                  },
                ],
                'features': [
                  {
                    'feature_code': 'order_management.manage',
                    'feature_name': '维护生产订单',
                    'permission_code':
                        'feature.production.order_management.manage',
                    'page_permission_code':
                        'page.production_order_management.view',
                    'linked_action_permission_codes': [
                      'production.orders.create',
                    ],
                    'dependency_permission_codes': [],
                  },
                ],
              },
            },
          );
        },
        'GET /authz/hierarchy/role-config': (request) {
          expect(request.uri.queryParameters['role_code'], 'production_admin');
          expect(request.uri.queryParameters['module'], 'production');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'role_code': 'production_admin',
                'role_name': '生产管理员',
                'readonly': false,
                'module_code': 'production',
                'module_enabled': true,
                'granted_page_permission_codes': [
                  'page.production_order_management.view',
                ],
                'granted_feature_permission_codes': [
                  'feature.production.order_management.manage',
                ],
                'effective_page_permission_codes': [
                  'page.production_order_management.view',
                ],
                'effective_feature_permission_codes': [
                  'feature.production.order_management.manage',
                ],
              },
            },
          );
        },
        'PUT /authz/hierarchy/role-config/production_admin': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['module_code'], 'production');
          expect(body['module_enabled'], true);
          expect(
            body['feature_permission_codes'],
            contains('feature.production.order_management.manage'),
          );
          return TestResponse.json(
            200,
            body: {
              'data': {
                'role_code': 'production_admin',
                'role_name': '生产管理员',
                'readonly': false,
                'ignored_input': false,
                'module_code': 'production',
                'before_permission_codes': ['module.production.access'],
                'after_permission_codes': [
                  'module.production.access',
                  'page.production_order_management.view',
                  'feature.production.order_management.manage',
                ],
                'added_permission_codes': [
                  'page.production_order_management.view',
                ],
                'removed_permission_codes': [],
                'auto_linked_dependencies': [],
                'effective_page_permission_codes': [
                  'page.production_order_management.view',
                ],
                'effective_feature_permission_codes': [
                  'feature.production.order_management.manage',
                ],
                'updated_count': 1,
                'dry_run': false,
              },
            },
          );
        },
        'POST /authz/hierarchy/preview': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['module_code'], 'production');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'module_code': 'production',
                'role_results': [
                  {
                    'role_code': 'production_admin',
                    'role_name': '生产管理员',
                    'readonly': false,
                    'ignored_input': false,
                    'module_code': 'production',
                    'before_permission_codes': ['module.production.access'],
                    'after_permission_codes': [
                      'module.production.access',
                      'page.production_order_management.view',
                    ],
                    'added_permission_codes': [
                      'page.production_order_management.view',
                    ],
                    'removed_permission_codes': [],
                    'auto_linked_dependencies': [],
                    'effective_page_permission_codes': [
                      'page.production_order_management.view',
                    ],
                    'effective_feature_permission_codes': [],
                    'updated_count': 1,
                    'dry_run': true,
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

      final catalog = await service.loadPermissionHierarchyCatalog(
        moduleCode: 'production',
      );
      final roleConfig = await service.loadPermissionHierarchyRoleConfig(
        roleCode: 'production_admin',
        moduleCode: 'production',
      );
      final preview = await service.previewPermissionHierarchy(
        moduleCode: 'production',
        roleItems: const [
          PermissionHierarchyRoleDraftItem(
            roleCode: 'production_admin',
            moduleEnabled: true,
            pagePermissionCodes: ['page.production_order_management.view'],
            featurePermissionCodes: [],
          ),
        ],
      );
      final updated = await service.updatePermissionHierarchyRoleConfig(
        roleCode: 'production_admin',
        moduleCode: 'production',
        moduleEnabled: true,
        pagePermissionCodes: ['page.production_order_management.view'],
        featurePermissionCodes: ['feature.production.order_management.manage'],
      );

      expect(catalog.modulePermissionCode, 'module.production.access');
      expect(roleConfig.moduleEnabled, isTrue);
      expect(preview.roleResults, hasLength(1));
      expect(updated.updatedCount, 1);
      expect(
        updated.afterPermissionCodes,
        contains('feature.production.order_management.manage'),
      );
    });

    test('loads capability pack endpoints', () async {
      final server = await TestHttpServer.start({
        'GET /authz/capability-packs/catalog': (request) {
          expect(request.uri.queryParameters['module'], 'production');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'module_code': 'production',
                'module_codes': ['production', 'system'],
                'module_name': '生产管理',
                'module_permission_code': 'module.production.access',
                'capability_packs': [
                  {
                    'capability_code': 'feature.production.order_query.execute',
                    'capability_name': '执行首件与报工',
                    'group_code': 'production.execution',
                    'group_name': '生产执行',
                    'page_code': 'production_order_query',
                    'page_name': '订单查询',
                    'description': '执行首件与报工',
                    'dependency_capability_codes': [],
                    'linked_action_permission_codes': [
                      'production.execution.first_article',
                    ],
                  },
                ],
                'role_templates': [
                  {
                    'role_code': 'production_admin',
                    'role_name': '生产管理员',
                    'capability_codes': [
                      'feature.production.order_query.execute',
                    ],
                    'description': '推荐模板',
                  },
                ],
              },
            },
          );
        },
        'GET /authz/capability-packs/role-config': (request) {
          expect(request.uri.queryParameters['role_code'], 'production_admin');
          expect(request.uri.queryParameters['module'], 'production');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'role_code': 'production_admin',
                'role_name': '生产管理员',
                'readonly': false,
                'module_code': 'production',
                'module_enabled': true,
                'granted_capability_codes': [
                  'feature.production.order_query.execute',
                ],
                'effective_capability_codes': [
                  'feature.production.order_query.execute',
                ],
                'effective_page_permission_codes': [
                  'page.production_order_query.view',
                ],
                'auto_linked_dependencies': [],
              },
            },
          );
        },
        'PUT /authz/capability-packs/role-config/production_admin': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['module_code'], 'production');
          expect(body['module_enabled'], true);
          expect(
            body['capability_codes'],
            contains('feature.production.order_query.execute'),
          );
          return TestResponse.json(
            200,
            body: {
              'data': {
                'role_code': 'production_admin',
                'role_name': '生产管理员',
                'readonly': false,
                'ignored_input': false,
                'module_code': 'production',
                'before_capability_codes': [],
                'after_capability_codes': [
                  'feature.production.order_query.execute',
                ],
                'added_capability_codes': [
                  'feature.production.order_query.execute',
                ],
                'removed_capability_codes': [],
                'auto_linked_dependencies': [],
                'effective_capability_codes': [
                  'feature.production.order_query.execute',
                ],
                'effective_page_permission_codes': [
                  'page.production_order_query.view',
                ],
                'updated_count': 1,
                'dry_run': false,
              },
            },
          );
        },
        'POST /authz/capability-packs/preview': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['module_code'], 'production');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'module_code': 'production',
                'role_results': [
                  {
                    'role_code': 'production_admin',
                    'role_name': '生产管理员',
                    'readonly': false,
                    'ignored_input': false,
                    'module_code': 'production',
                    'before_capability_codes': [],
                    'after_capability_codes': [
                      'feature.production.order_query.execute',
                    ],
                    'added_capability_codes': [
                      'feature.production.order_query.execute',
                    ],
                    'removed_capability_codes': [],
                    'auto_linked_dependencies': [],
                    'effective_capability_codes': [
                      'feature.production.order_query.execute',
                    ],
                    'effective_page_permission_codes': [
                      'page.production_order_query.view',
                    ],
                    'updated_count': 1,
                    'dry_run': true,
                  },
                ],
              },
            },
          );
        },
        'GET /authz/capability-packs/effective': (request) {
          expect(request.uri.queryParameters['role_code'], 'production_admin');
          expect(request.uri.queryParameters['module'], 'production');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'role_code': 'production_admin',
                'role_name': '生产管理员',
                'module_code': 'production',
                'module_enabled': true,
                'effective_page_permission_codes': [
                  'page.production_order_query.view',
                ],
                'effective_capability_codes': [
                  'feature.production.order_query.execute',
                ],
                'capability_items': [
                  {
                    'capability_code': 'feature.production.order_query.execute',
                    'capability_name': '执行首件与报工',
                    'available': true,
                    'reason_codes': [],
                    'reason_messages': [],
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

      final catalog = await service.loadCapabilityPackCatalog(
        moduleCode: 'production',
      );
      final roleConfig = await service.loadCapabilityPackRoleConfig(
        roleCode: 'production_admin',
        moduleCode: 'production',
      );
      final preview = await service.previewCapabilityPacks(
        moduleCode: 'production',
        roleItems: const [
          CapabilityPackRoleDraftItem(
            roleCode: 'production_admin',
            moduleEnabled: true,
            capabilityCodes: ['feature.production.order_query.execute'],
          ),
        ],
      );
      final updated = await service.updateCapabilityPackRoleConfig(
        roleCode: 'production_admin',
        moduleCode: 'production',
        moduleEnabled: true,
        capabilityCodes: ['feature.production.order_query.execute'],
      );
      final explain = await service.loadCapabilityPackEffective(
        roleCode: 'production_admin',
        moduleCode: 'production',
      );

      expect(catalog.moduleCode, 'production');
      expect(catalog.capabilityPacks, hasLength(1));
      expect(roleConfig.moduleEnabled, isTrue);
      expect(preview.roleResults, hasLength(1));
      expect(updated.updatedCount, 1);
      expect(
        updated.afterCapabilityCodes,
        contains('feature.production.order_query.execute'),
      );
      expect(explain.capabilityItems.first.available, isTrue);
    });
  });
}
