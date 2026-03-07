import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/production_models.dart';
import 'package:mes_client/services/api_exception.dart';
import 'package:mes_client/services/production_service.dart';

import '../support/http_test_server.dart';

Map<String, dynamic> _orderJson() {
  return {
    'id': 1,
    'order_code': 'PO-1',
    'product_id': 10,
    'product_name': 'Product-A',
    'quantity': 100,
    'status': 'pending',
    'current_process_code': '01-01',
    'current_process_name': 'Cut',
    'start_date': '2026-03-01',
    'due_date': '2026-03-20',
    'remark': 'note',
    'process_template_id': 3,
    'process_template_name': 'default',
    'process_template_version': 1,
    'created_by_user_id': 1,
    'created_by_username': 'admin',
    'created_at': '2026-03-01T00:00:00Z',
    'updated_at': '2026-03-01T00:00:00Z',
  };
}

Map<String, dynamic> _myOrderJson({
  required String workView,
  required bool canFirstArticle,
  required bool canEndProduction,
  int? assistAuthorizationId,
}) {
  return {
    'order_id': 1,
    'order_code': 'PO-1',
    'product_id': 10,
    'product_name': 'Product-A',
    'quantity': 100,
    'order_status': 'pending',
    'current_process_id': 11,
    'current_stage_id': 1,
    'current_stage_code': '01',
    'current_stage_name': 'Cut-Stage',
    'current_process_code': '01-01',
    'current_process_name': 'Cut',
    'current_process_order': 1,
    'process_status': 'pending',
    'visible_quantity': 80,
    'process_completed_quantity': 20,
    'user_sub_order_id': 12,
    'user_assigned_quantity': 20,
    'user_completed_quantity': 10,
    'operator_user_id': 8,
    'operator_username': 'worker',
    'work_view': workView,
    'assist_authorization_id': assistAuthorizationId,
    'max_producible_quantity': 10,
    'can_first_article': canFirstArticle,
    'can_end_production': canEndProduction,
    'updated_at': '2026-03-01T00:00:00Z',
  };
}

Map<String, dynamic> _assistAuthorizationJson({
  required int id,
  required String status,
  String? reviewRemark,
}) {
  return {
    'id': id,
    'order_id': 1,
    'order_code': 'PO-1',
    'order_process_id': 11,
    'process_code': '01-01',
    'process_name': 'Cut',
    'target_operator_user_id': 8,
    'target_operator_username': 'worker',
    'requester_user_id': 2,
    'requester_username': 'manager',
    'helper_user_id': 9,
    'helper_username': 'assistant',
    'status': status,
    'reason': 'assist',
    'review_remark': reviewRemark,
    'reviewer_user_id': status == 'approved' ? 1 : null,
    'reviewer_username': status == 'approved' ? 'admin' : null,
    'reviewed_at': status == 'approved' ? '2026-03-01T00:00:00Z' : null,
    'first_article_used_at': null,
    'end_production_used_at': null,
    'consumed_at': null,
    'created_at': '2026-03-01T00:00:00Z',
    'updated_at': '2026-03-01T00:00:00Z',
  };
}

void main() {
  group('ProductionService', () {
    test('covers production api including assist authorization flows', () async {
      final server = await TestHttpServer.start({
        'GET /production/orders': (request) {
          expect(request.uri.queryParameters['page'], '1');
          expect(request.uri.queryParameters['page_size'], '20');
          expect(request.uri.queryParameters['keyword'], 'PO');
          expect(request.uri.queryParameters['status'], 'pending');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'items': [_orderJson()],
              },
            },
          );
        },
        'POST /production/orders': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['order_code'], 'PO-1');
          expect(body['product_id'], 10);
          expect(body['start_date'], '2026-03-01');
          expect(body['due_date'], '2026-03-20');
          expect(body['save_as_template'], true);
          expect((body['process_steps'] as List).length, 1);
          return TestResponse.json(201, body: {'data': _orderJson()});
        },
        'PUT /production/orders/1': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['quantity'], 120);
          expect(body['start_date'], '2026-03-02');
          expect(body['due_date'], '2026-03-22');
          return TestResponse.json(200, body: {'data': _orderJson()});
        },
        'DELETE /production/orders/1': (_) =>
            TestResponse.json(200, body: {'data': {}}),
        'POST /production/orders/1/complete': (_) => TestResponse.json(
          200,
          body: {
            'data': {'order_id': 1, 'status': 'completed', 'message': 'ok'},
          },
        ),
        'GET /production/orders/1': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'order': _orderJson(),
              'processes': [
                {
                  'id': 11,
                  'stage_id': 1,
                  'stage_code': '01',
                  'stage_name': 'Cut-Stage',
                  'process_code': '01-01',
                  'process_name': 'Cut',
                  'process_order': 1,
                  'status': 'pending',
                  'visible_quantity': 80,
                  'completed_quantity': 20,
                  'created_at': '2026-03-01T00:00:00Z',
                  'updated_at': '2026-03-01T00:00:00Z',
                },
              ],
              'sub_orders': [
                {
                  'id': 12,
                  'order_process_id': 11,
                  'process_code': '01-01',
                  'process_name': 'Cut',
                  'operator_user_id': 8,
                  'operator_username': 'worker',
                  'assigned_quantity': 20,
                  'completed_quantity': 10,
                  'status': 'pending',
                  'is_visible': true,
                  'created_at': '2026-03-01T00:00:00Z',
                  'updated_at': '2026-03-01T00:00:00Z',
                },
              ],
              'records': [
                {
                  'id': 13,
                  'order_process_id': 11,
                  'process_code': '01-01',
                  'process_name': 'Cut',
                  'operator_user_id': 8,
                  'operator_username': 'worker',
                  'production_quantity': 5,
                  'record_type': 'production',
                  'created_at': '2026-03-01T00:00:00Z',
                },
              ],
              'events': [
                {
                  'id': 14,
                  'event_type': 'created',
                  'event_title': 'created',
                  'event_detail': null,
                  'operator_user_id': 1,
                  'operator_username': 'admin',
                  'payload_json': '{}',
                  'created_at': '2026-03-01T00:00:00Z',
                },
              ],
            },
          },
        ),
        'GET /production/my-orders': (request) {
          final viewMode = request.uri.queryParameters['view_mode'];
          if (viewMode == 'proxy') {
            expect(request.uri.queryParameters['page'], '2');
            expect(request.uri.queryParameters['page_size'], '20');
            expect(request.uri.queryParameters['proxy_operator_user_id'], '8');
            return TestResponse.json(
              200,
              body: {
                'data': {
                  'total': 1,
                  'items': [
                    _myOrderJson(
                      workView: 'proxy',
                      canFirstArticle: false,
                      canEndProduction: false,
                    ),
                  ],
                },
              },
            );
          }
          expect(request.uri.queryParameters['page_size'], '200');
          expect(request.uri.queryParameters['keyword'], 'mine');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'items': [
                  _myOrderJson(
                    workView: 'own',
                    canFirstArticle: true,
                    canEndProduction: true,
                  ),
                ],
              },
            },
          );
        },
        'POST /production/orders/1/first-article': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['order_process_id'], 11);
          expect(body['verification_code'], 'code-1');
          expect(body['remark'], 'first');
          expect(body['effective_operator_user_id'], 8);
          expect(body['assist_authorization_id'], 99);
          return TestResponse.json(
            200,
            body: {
              'data': {
                'order_id': 1,
                'status': 'ok',
                'message': 'first article done',
              },
            },
          );
        },
        'POST /production/orders/1/end-production': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['order_process_id'], 11);
          expect(body['quantity'], 5);
          expect(body['remark'], 'done');
          expect(body['effective_operator_user_id'], 8);
          expect(body['assist_authorization_id'], 99);
          return TestResponse.json(
            200,
            body: {
              'data': {
                'order_id': 1,
                'status': 'ok',
                'message': 'end production done',
              },
            },
          );
        },
        'GET /production/stats/overview': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'total_orders': 10,
              'pending_orders': 2,
              'in_progress_orders': 3,
              'completed_orders': 5,
              'total_quantity': 1000,
              'finished_quantity': 900,
            },
          },
        ),
        'GET /production/stats/processes': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'items': [
                {
                  'process_code': '01-01',
                  'process_name': 'Cut',
                  'total_orders': 10,
                  'pending_orders': 2,
                  'in_progress_orders': 3,
                  'partial_orders': 1,
                  'completed_orders': 4,
                  'total_visible_quantity': 200,
                  'total_completed_quantity': 180,
                },
              ],
            },
          },
        ),
        'GET /production/stats/operators': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'items': [
                {
                  'operator_user_id': 8,
                  'operator_username': 'worker',
                  'process_code': '01-01',
                  'process_name': 'Cut',
                  'production_records': 20,
                  'production_quantity': 300,
                  'last_production_at': '2026-03-01T00:00:00Z',
                },
              ],
            },
          },
        ),
        'GET /products': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'items': [
                {'id': 10, 'name': 'Product-A'},
              ],
            },
          },
        ),
        'GET /processes': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'items': [
                {
                  'id': 2,
                  'code': '01-01',
                  'name': 'Cut',
                  'stage_id': 1,
                  'stage_code': '01',
                  'stage_name': 'Cut-Stage',
                },
              ],
            },
          },
        ),
        'GET /production/assist-user-options': (request) {
          expect(request.uri.queryParameters['page'], '1');
          expect(request.uri.queryParameters['page_size'], '200');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 2,
                'items': [
                  {
                    'id': 8,
                    'username': 'worker',
                    'full_name': 'Worker-A',
                    'role_codes': ['operator'],
                  },
                  {
                    'id': 2,
                    'username': 'manager',
                    'full_name': 'Manager',
                    'role_codes': ['production_admin'],
                  },
                ],
              },
            },
          );
        },
        'GET /production/assist-authorizations': (request) {
          expect(request.uri.queryParameters['page'], '1');
          expect(request.uri.queryParameters['page_size'], '20');
          expect(request.uri.queryParameters['status'], 'pending');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'items': [
                  _assistAuthorizationJson(id: 99, status: 'pending'),
                ],
              },
            },
          );
        },
        'POST /production/orders/1/assist-authorizations': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['order_process_id'], 11);
          expect(body['target_operator_user_id'], 8);
          expect(body['helper_user_id'], 9);
          expect(body['reason'], 'need assist');
          return TestResponse.json(
            201,
            body: {
              'data': _assistAuthorizationJson(id: 100, status: 'pending'),
            },
          );
        },
        'POST /production/assist-authorizations/99/review': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['approve'], true);
          expect(body['review_remark'], 'ok');
          return TestResponse.json(
            200,
            body: {
              'data': _assistAuthorizationJson(
                id: 99,
                status: 'approved',
                reviewRemark: 'ok',
              ),
            },
          );
        },
      });
      addTearDown(server.close);

      final service = ProductionService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-production'),
      );
      const steps = [
        ProductionOrderProcessStepInput(stepOrder: 1, stageId: 1, processId: 2),
      ];

      final orders = await service.listOrders(
        page: 1,
        pageSize: 20,
        keyword: '  PO ',
        status: ' pending ',
      );
      final createdOrder = await service.createOrder(
        orderCode: 'PO-1',
        productId: 10,
        quantity: 100,
        processCodes: const ['01-01'],
        templateId: 3,
        processSteps: steps,
        saveAsTemplate: true,
        newTemplateName: 'new-template',
        newTemplateSetDefault: true,
        startDate: DateTime(2026, 3, 1),
        dueDate: DateTime(2026, 3, 20),
        remark: 'note',
      );
      final updatedOrder = await service.updateOrder(
        orderId: 1,
        productId: 10,
        quantity: 120,
        processCodes: const ['01-01'],
        templateId: 3,
        processSteps: steps,
        saveAsTemplate: false,
        newTemplateName: null,
        startDate: DateTime(2026, 3, 2),
        dueDate: DateTime(2026, 3, 22),
        remark: 'updated',
      );
      await service.deleteOrder(orderId: 1);
      final complete = await service.completeOrder(orderId: 1);
      final detail = await service.getOrderDetail(orderId: 1);
      final myOrders = await service.listMyOrders(
        page: 1,
        pageSize: 999,
        keyword: '  mine ',
      );
      final proxyOrders = await service.listMyOrders(
        page: 2,
        pageSize: 20,
        viewMode: 'proxy',
        proxyOperatorUserId: 8,
      );
      final firstArticle = await service.submitFirstArticle(
        orderId: 1,
        orderProcessId: 11,
        verificationCode: 'code-1',
        remark: 'first',
        effectiveOperatorUserId: 8,
        assistAuthorizationId: 99,
      );
      final endProduction = await service.endProduction(
        orderId: 1,
        orderProcessId: 11,
        quantity: 5,
        remark: 'done',
        effectiveOperatorUserId: 8,
        assistAuthorizationId: 99,
      );
      final overview = await service.getOverviewStats();
      final processStats = await service.getProcessStats();
      final operatorStats = await service.getOperatorStats();
      final productOptions = await service.listProductOptions();
      final processOptions = await service.listProcessOptions();
      final assistUsers = await service.listAssistUserOptions(
        page: 1,
        pageSize: 200,
      );
      final assistList = await service.listAssistAuthorizations(
        page: 1,
        pageSize: 20,
        status: 'pending',
      );
      final assistCreated = await service.createAssistAuthorization(
        orderId: 1,
        orderProcessId: 11,
        targetOperatorUserId: 8,
        helperUserId: 9,
        reason: 'need assist',
      );
      final assistReviewed = await service.reviewAssistAuthorization(
        authorizationId: 99,
        approve: true,
        reviewRemark: 'ok',
      );

      expect(orders.items.single.orderCode, 'PO-1');
      expect(createdOrder.quantity, 100);
      expect(updatedOrder.quantity, 100);
      expect(complete.status, 'completed');
      expect(detail.processes.single.processCode, '01-01');
      expect(myOrders.items.single.canEndProduction, isTrue);
      expect(proxyOrders.items.single.workView, 'proxy');
      expect(firstArticle.message, 'first article done');
      expect(endProduction.message, 'end production done');
      expect(overview.totalOrders, 10);
      expect(processStats.single.processName, 'Cut');
      expect(operatorStats.single.operatorUsername, 'worker');
      expect(productOptions.single.id, 10);
      expect(processOptions.single.code, '01-01');
      expect(assistUsers.items.length, 2);
      expect(assistList.total, 1);
      expect(assistCreated.id, 100);
      expect(assistReviewed.status, 'approved');
      expect(server.requests.length, 19);
    });

    test('throws ApiException on backend errors', () async {
      final server = await TestHttpServer.start({
        'GET /production/orders': (_) =>
            TestResponse.json(500, body: {'detail': 'production list failed'}),
      });
      addTearDown(server.close);

      final service = ProductionService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-production'),
      );

      await expectLater(
        () => service.listOrders(page: 1, pageSize: 20),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message', 'production list failed'),
        ),
      );
    });

    test('parses 422 validation detail message', () async {
      final server = await TestHttpServer.start({
        'POST /production/orders': (_) => TestResponse.json(
          422,
          body: {
            'detail': [
              {
                'type': 'string_too_short',
                'loc': ['body', 'order_code'],
                'msg': 'String should have at least 2 characters',
                'input': 'A',
              },
            ],
          },
        ),
      });
      addTearDown(server.close);

      final service = ProductionService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-production'),
      );

      await expectLater(
        () => service.createOrder(
          orderCode: 'A',
          productId: 1,
          quantity: 1,
          processCodes: const ['01-01'],
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 422)
              .having(
                (e) => e.message,
                'message',
                contains('Order Code: String should have at least 2 characters'),
              ),
        ),
      );
    });
  });
}
