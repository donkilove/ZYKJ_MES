import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/quality/services/quality_supplier_service.dart';

import '../support/http_test_server.dart';

void main() {
  group('QualitySupplierService', () {
    test('支持供应商列表与增删改契约', () async {
      final server = await TestHttpServer.start({
        'GET /quality/suppliers': (request) {
          expect(request.uri.queryParameters['keyword'], '华东');
          expect(request.uri.queryParameters['enabled'], 'true');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'items': [
                  {
                    'id': 1,
                    'name': '华东供应商',
                    'remark': '稳定供货',
                    'is_enabled': true,
                    'created_at': '2026-04-02T08:00:00Z',
                    'updated_at': '2026-04-02T09:00:00Z',
                  },
                ],
              },
            },
          );
        },
        'POST /quality/suppliers': (request) {
          expect(request.headers['authorization'], 'Bearer token-supplier');
          expect(request.decodedBody, {
            'name': '新增供应商',
            'remark': '新增备注',
            'is_enabled': true,
          });
          return TestResponse.json(
            201,
            body: {
              'data': {
                'id': 2,
                'name': '新增供应商',
                'remark': '新增备注',
                'is_enabled': true,
                'created_at': '2026-04-02T10:00:00Z',
                'updated_at': '2026-04-02T10:00:00Z',
              },
            },
          );
        },
        'PUT /quality/suppliers/2': (request) {
          expect(request.decodedBody, {
            'name': '更新供应商',
            'remark': null,
            'is_enabled': false,
          });
          return TestResponse.json(
            200,
            body: {
              'data': {
                'id': 2,
                'name': '更新供应商',
                'remark': null,
                'is_enabled': false,
                'created_at': '2026-04-02T10:00:00Z',
                'updated_at': '2026-04-02T11:00:00Z',
              },
            },
          );
        },
        'DELETE /quality/suppliers/2': (_) => TestResponse.json(
          200,
          body: {
            'data': {'message': '供应商已删除'},
          },
        ),
      });
      addTearDown(server.close);

      final service = QualitySupplierService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-supplier'),
      );

      final list = await service.listSuppliers(keyword: '  华东 ', enabled: true);
      final created = await service.createSupplier(
        const QualitySupplierUpsertPayload(
          name: '新增供应商',
          remark: '新增备注',
          isEnabled: true,
        ),
      );
      final updated = await service.updateSupplier(
        2,
        const QualitySupplierUpsertPayload(
          name: '更新供应商',
          remark: null,
          isEnabled: false,
        ),
      );
      await service.deleteSupplier(2);

      expect(list.total, 1);
      expect(list.items.single.name, '华东供应商');
      expect(created.id, 2);
      expect(updated.isEnabled, isFalse);
    });

    test('删除被引用供应商时透传后端中文错误', () async {
      final server = await TestHttpServer.start({
        'DELETE /quality/suppliers/7': (_) =>
            TestResponse.json(409, body: {'detail': '供应商已被生产订单引用，无法删除'}),
      });
      addTearDown(server.close);

      final service = QualitySupplierService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-supplier'),
      );

      await expectLater(
        () => service.deleteSupplier(7),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.message, 'message', '供应商已被生产订单引用，无法删除'),
        ),
      );
    });
  });
}
