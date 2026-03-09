import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/page_visibility_models.dart';
import 'package:mes_client/services/api_exception.dart';
import 'package:mes_client/services/page_visibility_service.dart';

import '../support/http_test_server.dart';

void main() {
  group('PageVisibilityService', () {
    test('covers catalog/me/config read and deprecated update', () async {
      final server = await TestHttpServer.start({
        'GET /ui/page-catalog': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'items': [
                {
                  'code': 'home',
                  'name': '首页',
                  'page_type': 'sidebar',
                  'parent_code': null,
                  'always_visible': true,
                  'sort_order': 1,
                },
              ],
            },
          },
        ),
        'GET /ui/page-visibility/me': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'sidebar_codes': ['home'],
              'tab_codes_by_parent': {
                'home': ['sub'],
              },
            },
          },
        ),
        'GET /ui/page-visibility/config': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'items': [
                {
                  'role_code': 'system_admin',
                  'role_name': '系统管理员',
                  'page_code': 'home',
                  'page_name': '首页',
                  'page_type': 'sidebar',
                  'parent_code': null,
                  'editable': true,
                  'is_visible': true,
                  'always_visible': true,
                },
              ],
            },
          },
        ),
        'PUT /ui/page-visibility/config': (request) {
          return TestResponse.json(
            410,
            body: {'detail': '页面可见性配置已下线，请改用功能权限配置'},
          );
        },
      });
      addTearDown(server.close);

      final service = PageVisibilityService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-ui'),
      );

      final catalog = await service.listPageCatalog();
      final me = await service.getMyVisibility();
      final config = await service.getVisibilityConfig();
      final updateRequest = service.updateVisibilityConfig(
        items: const [
          PageVisibilityConfigUpdateItem(
            roleCode: 'system_admin',
            pageCode: 'home',
            isVisible: true,
          ),
        ],
      );

      expect(catalog.single.code, 'home');
      expect(me.sidebarCodes, ['home']);
      expect(config.single.roleCode, 'system_admin');
      await expectLater(
        updateRequest,
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 410)
              .having(
                (e) => e.message,
                'message',
                '页面可见性配置已下线，请改用功能权限配置',
              ),
        ),
      );
    });

    test('throws ApiException when request fails', () async {
      final server = await TestHttpServer.start({
        'GET /ui/page-catalog': (_) =>
            TestResponse.json(500, body: {'detail': 'catalog failed'}),
      });
      addTearDown(server.close);

      final service = PageVisibilityService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-ui'),
      );

      await expectLater(
        service.listPageCatalog,
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message', 'catalog failed'),
        ),
      );
    });
  });
}
