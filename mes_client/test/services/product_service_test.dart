import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/product_models.dart';
import 'package:mes_client/services/api_exception.dart';
import 'package:mes_client/services/product_service.dart';

import '../support/http_test_server.dart';

void main() {
  group('ProductService', () {
    test('covers product and lifecycle/version related operations', () async {
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
                      'name': 'Product A',
                      'category': 'fixture',
                      'lifecycle_status': 'effective',
                      'current_version': 3,
                      'effective_version': 3,
                      'effective_at': '2026-03-01T00:00:00Z',
                      'inactive_reason': null,
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
                  {
                    'id': 8,
                    'name': 'Product A',
                    'category': 'fixture',
                    'created_at': '2026-03-01T00:00:00Z',
                    'updated_at': '2026-03-01T00:00:00Z',
                  },
                ],
              },
            },
          );
        },
        'POST /products': (request) {
          expect(jsonDecode(request.bodyText), {
            'name': 'Product B',
            'category': '',
          });
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
              'product_name': 'Product A',
              'total': 1,
              'items': [
                {
                  'name': 'Param 1',
                  'category': 'General',
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
                'changed_keys': ['Param 1'],
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
                    'remark': 'Changed',
                    'changed_keys': ['Param 1'],
                    'operator_username': 'admin',
                    'created_at': '2026-03-01T00:00:00Z',
                  },
                ],
              },
            },
          );
        },
        'POST /products/8/lifecycle': (request) {
          expect(jsonDecode(request.bodyText), {
            'target_status': 'inactive',
            'confirmed': true,
            'note': null,
            'inactive_reason': 'reason',
          });
          return TestResponse.json(
            200,
            body: {
              'data': {
                'id': 8,
                'name': 'Product A',
                'category': 'fixture',
                'lifecycle_status': 'inactive',
                'current_version': 3,
                'effective_version': 3,
                'effective_at': '2026-03-01T00:00:00Z',
                'inactive_reason': 'reason',
                'last_parameter_summary': null,
                'created_at': '2026-03-01T00:00:00Z',
                'updated_at': '2026-03-03T00:00:00Z',
              },
            },
          );
        },
        'GET /products/8/impact-analysis': (request) {
          expect(request.uri.queryParameters['operation'], 'rollback');
          expect(request.uri.queryParameters['target_version'], '1');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'operation': 'rollback',
                'target_status': null,
                'target_version': 1,
                'total_orders': 1,
                'pending_orders': 1,
                'in_progress_orders': 0,
                'requires_confirmation': true,
                'items': [
                  {
                    'order_id': 99,
                    'order_code': 'ORD-99',
                    'order_status': 'pending',
                    'reason': 'Rollback affects unfinished orders',
                  },
                ],
              },
            },
          );
        },
        'GET /products/8/versions': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'total': 2,
              'items': [
                {
                  'version': 2,
                  'lifecycle_status': 'effective',
                  'action': 'update_parameters',
                  'note': 'n2',
                  'source_version': null,
                  'created_by_user_id': 1,
                  'created_by_username': 'admin',
                  'created_at': '2026-03-02T00:00:00Z',
                },
                {
                  'version': 1,
                  'lifecycle_status': 'draft',
                  'action': 'create',
                  'note': 'n1',
                  'source_version': null,
                  'created_by_user_id': 1,
                  'created_by_username': 'admin',
                  'created_at': '2026-03-01T00:00:00Z',
                },
              ],
            },
          },
        ),
        'GET /products/8/versions/compare': (request) {
          expect(request.uri.queryParameters['from_version'], '1');
          expect(request.uri.queryParameters['to_version'], '2');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'from_version': 1,
                'to_version': 2,
                'added_items': 0,
                'removed_items': 0,
                'changed_items': 1,
                'items': [
                  {
                    'key': 'Param:Param 1',
                    'diff_type': 'changed',
                    'from_value': 'v1',
                    'to_value': 'v2',
                  },
                ],
              },
            },
          );
        },
        'POST /products/8/rollback': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['target_version'], 1);
          expect(body['confirmed'], true);
          expect(body['note'], 'rollback');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'product': {
                  'id': 8,
                  'name': 'Product A',
                  'category': 'fixture',
                  'lifecycle_status': 'effective',
                  'current_version': 4,
                  'effective_version': 4,
                  'effective_at': '2026-03-03T00:00:00Z',
                  'inactive_reason': null,
                  'last_parameter_summary': null,
                  'created_at': '2026-03-01T00:00:00Z',
                  'updated_at': '2026-03-03T00:00:00Z',
                },
                'changed_keys': ['Param 1'],
              },
            },
          );
        },
      });
      addTearDown(server.close);

      final service = ProductService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-product'),
      );

      final products = await service.listProducts(
        page: 1,
        pageSize: 20,
        keyword: '  abc ',
      );
      await service.createProduct(name: 'Product B');
      await service.deleteProduct(productId: 8, password: 'pwd123');
      final parameters = await service.listProductParameters(productId: 8);
      final updateResult = await service.updateProductParameters(
        productId: 8,
        remark: 'batch update',
        items: [
          ProductParameterUpdateItem(
            name: 'Param 1',
            category: 'General',
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
      final lifecycleUpdated = await service.updateProductLifecycle(
        productId: 8,
        payload: ProductLifecycleUpdateRequest(
          targetStatus: 'inactive',
          confirmed: true,
          inactiveReason: 'reason',
        ),
      );
      final impact = await service.getProductImpactAnalysis(
        productId: 8,
        operation: 'rollback',
        targetVersion: 1,
      );
      final versions = await service.listProductVersions(productId: 8);
      final compare = await service.compareProductVersions(
        productId: 8,
        fromVersion: 1,
        toVersion: 2,
      );
      final rollback = await service.rollbackProduct(
        productId: 8,
        targetVersion: 1,
        confirmed: true,
        note: 'rollback',
      );

      expect(products.items.single.name, 'Product A');
      expect(products.items.single.lifecycleStatus, 'effective');
      expect(parameters.items.single.name, 'Param 1');
      expect(updateResult.updatedCount, 1);
      expect(history.items.single.remark, 'Changed');
      expect(lifecycleUpdated.lifecycleStatus, 'inactive');
      expect(impact.requiresConfirmation, isTrue);
      expect(versions.total, 2);
      expect(versions.items.first.displayVersion, 'V1.2');
      expect(compare.changedItems, 1);
      expect(rollback.changedKeys.single, 'Param 1');
      expect(server.requests.length, 11);
    });

    test('throws ApiException when create product fails', () async {
      final server = await TestHttpServer.start({
        'POST /products': (_) =>
            TestResponse.json(400, body: {'detail': 'invalid product'}),
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
