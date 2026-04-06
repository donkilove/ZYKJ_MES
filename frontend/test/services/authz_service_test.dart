import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/authz_models.dart';
import 'package:mes_client/services/api_exception.dart';
import 'package:mes_client/services/authz_service.dart';

import '../support/http_test_server.dart';

void main() {
  group('AuthzService', () {
    test('loads matrix and rejects deprecated apply endpoint', () async {
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
                    'role_name': 'System admin',
                    'readonly': true,
                    'is_system_admin': true,
                    'granted_permission_codes': ['page.production.view'],
                  },
                  {
                    'role_code': 'production_admin',
                    'role_name': 'Production admin',
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
                      'role_name': 'Production admin',
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
            410,
            body: {'detail': 'legacy matrix apply endpoint is offline'},
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
      final saveRequest = service.updateRolePermissionMatrix(
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
      await expectLater(
        saveRequest,
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 410)
              .having(
                (e) => e.message,
                'message',
                'legacy matrix apply endpoint is offline',
              ),
        ),
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

    test('loads hierarchy endpoints and rejects deprecated apply', () async {
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
                'module_name': 'Production',
                'pages': [
                  {
                    'page_code': 'production_order_management',
                    'page_name': 'Order management',
                    'permission_code': 'page.production_order_management.view',
                    'parent_page_code': 'production',
                  },
                ],
                'features': [
                  {
                    'feature_code': 'order_management.manage',
                    'feature_name': 'Manage orders',
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
                'role_name': 'Production admin',
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
            410,
            body: {'detail': 'legacy hierarchy apply endpoint is offline'},
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
                    'role_name': 'Production admin',
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
      final updateRequest = service.updatePermissionHierarchyRoleConfig(
        roleCode: 'production_admin',
        moduleCode: 'production',
        moduleEnabled: true,
        pagePermissionCodes: ['page.production_order_management.view'],
        featurePermissionCodes: ['feature.production.order_management.manage'],
      );

      expect(catalog.modulePermissionCode, 'module.production.access');
      expect(roleConfig.moduleEnabled, isTrue);
      expect(preview.roleResults, hasLength(1));
      await expectLater(
        updateRequest,
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 410)
              .having(
                (e) => e.message,
                'message',
                'legacy hierarchy apply endpoint is offline',
              ),
        ),
      );
    });

    test('loads capability pack endpoints', () async {
      final server = await TestHttpServer.start({
        'GET /authz/snapshot': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'revision': 3,
              'role_codes': ['production_admin'],
              'visible_sidebar_codes': ['production'],
              'tab_codes_by_parent': {
                'production': ['production_order_query'],
              },
              'module_items': [
                {
                  'module_code': 'production',
                  'module_name': 'Production',
                  'module_revision': 3,
                  'module_enabled': true,
                  'effective_permission_codes': [
                    'page.production_order_query.view',
                  ],
                  'effective_page_permission_codes': [
                    'page.production_order_query.view',
                  ],
                  'effective_capability_codes': [
                    'feature.production.order_query.execute',
                  ],
                  'effective_action_permission_codes': [
                    'production.my_orders.list',
                  ],
                },
              ],
            },
          },
        ),
        'GET /authz/capability-packs/catalog': (request) {
          expect(request.uri.queryParameters['module'], 'production');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'module_code': 'production',
                'module_codes': [
                  'user',
                  'product',
                  'craft',
                  'production',
                  'quality',
                  'equipment',
                  'message',
                ],
                'module_name': 'Production',
                'module_revision': 3,
                'module_permission_code': 'module.production.access',
                'capability_packs': [
                  {
                    'capability_code': 'feature.production.order_query.execute',
                    'capability_name': 'Execute order query',
                    'group_code': 'production.execution',
                    'group_name': 'Production execution',
                    'page_code': 'production_order_query',
                    'page_name': 'Order query',
                    'description': 'Execute order query',
                    'dependency_capability_codes': [],
                    'linked_action_permission_codes': [
                      'production.execution.first_article',
                    ],
                  },
                ],
                'role_templates': [
                  {
                    'role_code': 'production_admin',
                    'role_name': 'Production admin',
                    'capability_codes': [
                      'feature.production.order_query.execute',
                    ],
                    'description': 'Recommended template',
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
                'role_name': 'Production admin',
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
          final dryRun = body['dry_run'] == true;
          expect(body['module_code'], 'production');
          expect(body['module_enabled'], true);
          expect(
            body['capability_codes'],
            contains('feature.production.order_query.execute'),
          );
          if (dryRun) {
            expect(body['remark'], 'preview');
          }
          return TestResponse.json(
            200,
            body: {
              'data': {
                'role_code': 'production_admin',
                'role_name': 'Production admin',
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
                'dry_run': dryRun,
              },
            },
          );
        },
        'PUT /authz/capability-packs/batch-apply': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['module_code'], 'production');
          expect(body['expected_revision'], 3);
          return TestResponse.json(
            200,
            body: {
              'data': {
                'module_code': 'production',
                'module_revision': 4,
                'role_results': [
                  {
                    'role_code': 'production_admin',
                    'role_name': 'Production admin',
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
                'role_name': 'Production admin',
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
                    'capability_name': 'Execute order query',
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

      final snapshot = await service.loadAuthzSnapshot();
      final catalog = await service.loadCapabilityPackCatalog(
        moduleCode: 'production',
      );
      final roleConfig = await service.loadCapabilityPackRoleConfig(
        roleCode: 'production_admin',
        moduleCode: 'production',
      );
      final preview = await service.updateCapabilityPackRoleConfig(
        roleCode: 'production_admin',
        moduleCode: 'production',
        moduleEnabled: true,
        capabilityCodes: ['feature.production.order_query.execute'],
        dryRun: true,
        remark: 'preview',
      );
      final batchApplied = await service.applyCapabilityPacks(
        moduleCode: 'production',
        roleItems: const [
          CapabilityPackRoleDraftItem(
            roleCode: 'production_admin',
            moduleEnabled: true,
            capabilityCodes: ['feature.production.order_query.execute'],
          ),
        ],
        expectedRevision: 3,
        remark: 'batch apply',
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

      expect(snapshot.revision, 3);
      expect(
        snapshot.capabilityCodesForModule('production'),
        contains('feature.production.order_query.execute'),
      );
      expect(catalog.moduleCode, 'production');
      expect(catalog.moduleRevision, 3);
      expect(catalog.capabilityPacks, hasLength(1));
      expect(catalog.moduleCodes, isNot(contains('system')));
      expect(roleConfig.moduleEnabled, isTrue);
      expect(preview.dryRun, isTrue);
      expect(preview.afterCapabilityCodes, [
        'feature.production.order_query.execute',
      ]);
      expect(batchApplied.moduleRevision, 4);
      expect(updated.updatedCount, 1);
      expect(
        updated.afterCapabilityCodes,
        contains('feature.production.order_query.execute'),
      );
      expect(explain.capabilityItems.first.available, isTrue);
    });

    test('covers user module permission and capability pack APIs', () async {
      final server = await TestHttpServer.start({
        'GET /authz/permissions/me': (request) {
          expect(request.uri.queryParameters['module'], 'user');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'permission_codes': [
                  'page.user_management.view',
                  'page.role_management.view',
                ],
              },
            },
          );
        },
        'GET /authz/permissions/catalog': (request) {
          expect(request.uri.queryParameters['module'], 'user');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'items': [
                  {
                    'permission_code': 'page.user_management.view',
                    'permission_name': '查看用户管理',
                    'module_code': 'user',
                    'resource_type': 'page',
                    'parent_permission_code': null,
                    'is_enabled': true,
                  },
                ],
              },
            },
          );
        },
        'GET /authz/role-permissions': (request) {
          expect(request.uri.queryParameters['role_code'], 'quality_admin');
          expect(request.uri.queryParameters['module'], 'user');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'role_code': 'quality_admin',
                'role_name': '品质管理员',
                'module_code': 'user',
                'items': [
                  {
                    'role_code': 'quality_admin',
                    'role_name': '品质管理员',
                    'permission_code': 'page.user_management.view',
                    'permission_name': '查看用户管理',
                    'module_code': 'user',
                    'resource_type': 'page',
                    'parent_permission_code': null,
                    'granted': true,
                    'is_enabled': true,
                  },
                ],
              },
            },
          );
        },
        'PUT /authz/role-permissions/quality_admin': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['module_code'], 'user');
          expect(body['granted_permission_codes'], [
            'page.user_management.view',
            'page.role_management.view',
          ]);
          expect(body['remark'], 'sync user permissions');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'role_code': 'quality_admin',
                'module_code': 'user',
                'updated_count': 2,
                'before_permission_codes': ['page.user_management.view'],
                'after_permission_codes': [
                  'page.user_management.view',
                  'page.role_management.view',
                ],
              },
            },
          );
        },
        'GET /authz/capability-packs/catalog': (request) {
          expect(request.uri.queryParameters['module'], 'user');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'module_code': 'user',
                'module_codes': ['user', 'product', 'system'],
                'module_name': '用户管理',
                'module_revision': 9,
                'module_permission_code': 'module.user.access',
                'capability_packs': [
                  {
                    'capability_code': 'feature.user.role_management.view',
                    'capability_name': '查看角色管理',
                    'group_code': 'user.roles',
                    'group_name': '角色管理',
                    'page_code': 'role_management',
                    'page_name': '角色管理',
                    'description': '查看角色权限配置',
                    'dependency_capability_codes': [],
                    'linked_action_permission_codes': ['user.roles.read'],
                  },
                ],
                'role_templates': [],
              },
            },
          );
        },
        'GET /authz/capability-packs/role-config': (request) {
          expect(request.uri.queryParameters['role_code'], 'quality_admin');
          expect(request.uri.queryParameters['module'], 'user');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'role_code': 'quality_admin',
                'role_name': '品质管理员',
                'readonly': false,
                'module_code': 'user',
                'module_enabled': true,
                'granted_capability_codes': [
                  'feature.user.role_management.view',
                ],
                'effective_capability_codes': [
                  'feature.user.role_management.view',
                ],
                'effective_page_permission_codes': [
                  'page.role_management.view',
                ],
                'auto_linked_dependencies': [],
              },
            },
          );
        },
        'PUT /authz/capability-packs/batch-apply': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['module_code'], 'user');
          expect(body['expected_revision'], 9);
          expect(body['remark'], 'apply user module');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'module_code': 'user',
                'module_revision': 10,
                'role_results': [
                  {
                    'role_code': 'quality_admin',
                    'role_name': '品质管理员',
                    'readonly': false,
                    'ignored_input': false,
                    'module_code': 'user',
                    'before_capability_codes': [],
                    'after_capability_codes': [
                      'feature.user.role_management.view',
                    ],
                    'added_capability_codes': [
                      'feature.user.role_management.view',
                    ],
                    'removed_capability_codes': [],
                    'auto_linked_dependencies': [],
                    'effective_capability_codes': [
                      'feature.user.role_management.view',
                    ],
                    'effective_page_permission_codes': [
                      'page.role_management.view',
                    ],
                    'updated_count': 1,
                    'dry_run': false,
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

      final permissionCodes = await service.getMyPermissionCodes(
        moduleCode: 'user',
      );
      final catalogItems = await service.listPermissionCatalog(
        moduleCode: 'user',
      );
      final rolePermissions = await service.getRolePermissions(
        roleCode: 'quality_admin',
        moduleCode: 'user',
      );
      final updateResult = await service.updateRolePermissions(
        roleCode: 'quality_admin',
        moduleCode: 'user',
        grantedPermissionCodes: [
          'page.user_management.view',
          'page.role_management.view',
        ],
        remark: 'sync user permissions',
      );
      final capabilityCatalog = await service.loadCapabilityPackCatalog(
        moduleCode: 'user',
      );
      final capabilityRoleConfig = await service.loadCapabilityPackRoleConfig(
        roleCode: 'quality_admin',
        moduleCode: 'user',
      );
      final applyResult = await service.applyCapabilityPacks(
        moduleCode: 'user',
        roleItems: const [
          CapabilityPackRoleDraftItem(
            roleCode: 'quality_admin',
            moduleEnabled: true,
            capabilityCodes: ['feature.user.role_management.view'],
          ),
        ],
        expectedRevision: 9,
        remark: 'apply user module',
      );

      expect(permissionCodes, contains('page.user_management.view'));
      expect(catalogItems.single.moduleCode, 'user');
      expect(rolePermissions.items.single.granted, isTrue);
      expect(updateResult.updatedCount, 2);
      expect(capabilityCatalog.moduleCodes, contains('system'));
      expect(capabilityRoleConfig.moduleEnabled, isTrue);
      expect(applyResult.moduleRevision, 10);
      expect(
        applyResult.roleResults.single.afterCapabilityCodes,
        contains('feature.user.role_management.view'),
      );
    });
  });
}
