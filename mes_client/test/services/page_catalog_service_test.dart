import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/services/api_exception.dart';
import 'package:mes_client/services/page_catalog_service.dart';

import '../support/http_test_server.dart';

void main() {
  group('PageCatalogService', () {
    test('loads page catalog', () async {
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
      });
      addTearDown(server.close);

      final service = PageCatalogService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-ui'),
      );

      final catalog = await service.listPageCatalog();

      expect(catalog.single.code, 'home');
    });

    test('throws ApiException when request fails', () async {
      final server = await TestHttpServer.start({
        'GET /ui/page-catalog': (_) =>
            TestResponse.json(500, body: {'detail': 'catalog failed'}),
      });
      addTearDown(server.close);

      final service = PageCatalogService(
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
