import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/product_models.dart';
import 'package:mes_client/services/api_exception.dart';
import 'package:mes_client/services/product_service.dart';

import '../support/http_test_server.dart';

void main() {
  group('ProductService', () {
    test('covers product and parameter related operations', () async {
      final server = await TestHttpServer.start({
        'GET /products': (request) {
          final page = request.uri.queryParameters['page'];
          final size = request.uri.queryParameters['page_size'];
          if (page == '1' && size == '20') {
            expect(request.uri.queryParameters['keyword'], 'abc');
            return TestResponse.json(
              200,
              body: {
                'data': {
                  'total': 1,
                  'items': [
                    {
                      'id': 8,
                      'name': '产品A',
                      'last_parameter_summary': 'A=1',
                      'created_at': '2026-03-01T00:00:00Z',
                      'updated_at': '2026-03-01T00:00:00Z',
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
                'total': 1,
                'items': [
                  {'id': 8, 'name': '产品A'},
                ],
              },
            },
          );
        },
        'POST /products': (request) {
          expect(jsonDecode(request.bodyText), {'name': '产品B'});
          return TestResponse.json(201, body: {'data': {}});
        },
        'POST /products/8/delete': (request) {
          expect(jsonDecode(request.bodyText), {'password': 'pwd123'});
          return TestResponse.json(200, body: {'data': {}});
        },
        'GET /products/8/parameters': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'product_id': 8,
              'product_name': '产品A',
              'total': 1,
              'items': [
                {
                  'name': '参数1',
                  'category': '分类',
                  'type': 'Text',
                  'value': 'v',
                  'sort_order': 1,
                  'is_preset': false,
                },
              ],
            },
          },
        ),
        'PUT /products/8/parameters': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['remark'], 'batch update');
          expect((body['items'] as List).length, 1);
          return TestResponse.json(
            200,
            body: {
              'data': {
                'updated_count': 1,
                'changed_keys': ['参数1'],
              },
            },
          );
        },
        'GET /products/8/parameter-history': (request) {
          expect(request.uri.queryParameters['page'], '2');
          expect(request.uri.queryParameters['page_size'], '5');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'items': [
                  {
                    'id': 9,
                    'remark': '变更',
                    'changed_keys': ['参数1'],
                    'operator_username': 'admin',
                    'created_at': '2026-03-01T00:00:00Z',
                  },
                ],
              },
            },
          );
        },
      });
      addTearDown(server.close);

      final service = ProductService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-product'),
      );

      final products = await service.listProducts(page: 1, pageSize: 20, keyword: '  abc ');
      await service.createProduct(name: '产品B');
      await service.deleteProduct(productId: 8, password: 'pwd123');
      final parameters = await service.listProductParameters(productId: 8);
      final updateResult = await service.updateProductParameters(
        productId: 8,
        remark: 'batch update',
        items: [
          ProductParameterUpdateItem(
            name: '参数1',
            category: '分类',
            type: 'Text',
            value: 'new',
          ),
        ],
      );
      final history = await service.listProductParameterHistory(
        productId: 8,
        page: 2,
        pageSize: 5,
      );

      expect(products.items.single.name, '产品A');
      expect(parameters.items.single.name, '参数1');
      expect(updateResult.updatedCount, 1);
      expect(history.items.single.remark, '变更');
      expect(server.requests.length, 6);
    });

    test('throws ApiException when create product fails', () async {
      final server = await TestHttpServer.start({
        'POST /products': (_) => TestResponse.json(
          400,
          body: {'detail': 'invalid product'},
        ),
      });
      addTearDown(server.close);

      final service = ProductService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-product'),
      );

      await expectLater(
        () => service.createProduct(name: 'bad'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', 'invalid product'),
        ),
      );
    });
  });
}
