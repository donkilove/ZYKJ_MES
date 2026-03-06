import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/craft_models.dart';
import 'package:mes_client/services/api_exception.dart';
import 'package:mes_client/services/craft_service.dart';

import '../support/http_test_server.dart';

Map<String, dynamic> _stageJson({
  int id = 1,
  String code = '01',
  String name = '切割段',
  int sortOrder = 1,
  bool isEnabled = true,
}) {
  return {
    'id': id,
    'code': code,
    'name': name,
    'sort_order': sortOrder,
    'is_enabled': isEnabled,
    'created_at': '2026-03-01T00:00:00Z',
    'updated_at': '2026-03-01T00:00:00Z',
  };
}

Map<String, dynamic> _processJson({
  int id = 2,
  String code = '01-01',
  String name = '切割',
  int stageId = 1,
  String stageCode = '01',
  String stageName = '切割段',
  bool isEnabled = true,
}) {
  return {
    'id': id,
    'code': code,
    'name': name,
    'stage_id': stageId,
    'stage_code': stageCode,
    'stage_name': stageName,
    'is_enabled': isEnabled,
    'created_at': '2026-03-01T00:00:00Z',
    'updated_at': '2026-03-01T00:00:00Z',
  };
}

Map<String, dynamic> _templateJson({
  int id = 3,
  int productId = 10,
  String productName = '产品A',
}) {
  return {
    'id': id,
    'product_id': productId,
    'product_name': productName,
    'template_name': '默认模板',
    'version': 1,
    'is_default': true,
    'is_enabled': true,
    'created_by_user_id': 1,
    'created_by_username': 'admin',
    'updated_by_user_id': 1,
    'updated_by_username': 'admin',
    'created_at': '2026-03-01T00:00:00Z',
    'updated_at': '2026-03-01T00:00:00Z',
  };
}

Map<String, dynamic> _templateStepJson({
  int id = 100,
  int stepOrder = 1,
  int stageId = 1,
  String stageCode = '01',
  String stageName = '切割段',
  int processId = 2,
  String processCode = '01-01',
  String processName = '切割',
}) {
  return {
    'id': id,
    'step_order': stepOrder,
    'stage_id': stageId,
    'stage_code': stageCode,
    'stage_name': stageName,
    'process_id': processId,
    'process_code': processCode,
    'process_name': processName,
    'created_at': '2026-03-01T00:00:00Z',
    'updated_at': '2026-03-01T00:00:00Z',
  };
}

void main() {
  group('CraftService', () {
    test('covers stage/process/template and system-master operations', () async {
      final server = await TestHttpServer.start({
        'GET /craft/stages': (request) {
          expect(request.uri.queryParameters['page'], '1');
          expect(request.uri.queryParameters['page_size'], '50');
          expect(request.uri.queryParameters['keyword'], '段');
          expect(request.uri.queryParameters['enabled'], 'true');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'items': [_stageJson()],
              },
            },
          );
        },
        'POST /craft/stages': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['code'], '02');
          expect(body['name'], '焊接段');
          expect(body['sort_order'], 2);
          return TestResponse.json(201, body: {'data': _stageJson(id: 2, code: '02', name: '焊接段', sortOrder: 2)});
        },
        'PUT /craft/stages/1': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['is_enabled'], false);
          return TestResponse.json(200, body: {'data': _stageJson(isEnabled: false)});
        },
        'DELETE /craft/stages/1': (_) => TestResponse.json(200, body: {'data': {}}),
        'GET /craft/processes': (request) {
          expect(request.uri.queryParameters['page_size'], '100');
          expect(request.uri.queryParameters['stage_id'], '1');
          expect(request.uri.queryParameters['enabled'], 'true');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'items': [_processJson()],
              },
            },
          );
        },
        'POST /craft/processes': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['code'], '02-01');
          expect(body['stage_id'], 2);
          return TestResponse.json(
            201,
            body: {
              'data': _processJson(id: 5, code: '02-01', stageId: 2, stageCode: '02', stageName: '焊接段'),
            },
          );
        },
        'PUT /craft/processes/2': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['is_enabled'], false);
          return TestResponse.json(200, body: {'data': _processJson(isEnabled: false)});
        },
        'DELETE /craft/processes/2': (_) => TestResponse.json(200, body: {'data': {}}),
        'GET /craft/templates': (request) {
          expect(request.uri.queryParameters['product_id'], '10');
          expect(request.uri.queryParameters['enabled'], 'true');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'items': [_templateJson()],
              },
            },
          );
        },
        'GET /craft/system-master-template': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'id': 1,
              'version': 3,
              'created_by_user_id': 1,
              'created_by_username': 'admin',
              'updated_by_user_id': 2,
              'updated_by_username': 'manager',
              'created_at': '2026-03-01T00:00:00Z',
              'updated_at': '2026-03-02T00:00:00Z',
              'steps': [_templateStepJson()],
            },
          },
        ),
        'POST /craft/system-master-template': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect((body['steps'] as List).length, 1);
          return TestResponse.json(
            201,
            body: {
              'data': {
                'id': 1,
                'version': 1,
                'created_by_user_id': 1,
                'created_by_username': 'admin',
                'updated_by_user_id': 1,
                'updated_by_username': 'admin',
                'created_at': '2026-03-01T00:00:00Z',
                'updated_at': '2026-03-01T00:00:00Z',
                'steps': [_templateStepJson()],
              },
            },
          );
        },
        'PUT /craft/system-master-template': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect((body['steps'] as List).length, 1);
          return TestResponse.json(
            200,
            body: {
              'data': {
                'id': 1,
                'version': 2,
                'created_by_user_id': 1,
                'created_by_username': 'admin',
                'updated_by_user_id': 2,
                'updated_by_username': 'manager',
                'created_at': '2026-03-01T00:00:00Z',
                'updated_at': '2026-03-02T00:00:00Z',
                'steps': [_templateStepJson()],
              },
            },
          );
        },
        'GET /craft/templates/3': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'template': _templateJson(),
              'steps': [_templateStepJson()],
            },
          },
        ),
        'POST /craft/templates': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['product_id'], 10);
          expect(body['template_name'], '默认模板');
          expect((body['steps'] as List).length, 1);
          return TestResponse.json(
            201,
            body: {
              'data': {
                'template': _templateJson(id: 9),
                'steps': [_templateStepJson()],
              },
            },
          );
        },
        'PUT /craft/templates/3': (request) {
          final body = jsonDecode(request.bodyText) as Map<String, dynamic>;
          expect(body['sync_orders'], false);
          return TestResponse.json(
            200,
            body: {
              'data': {
                'detail': {
                  'template': _templateJson(),
                  'steps': [_templateStepJson()],
                },
                'sync_result': {
                  'total': 2,
                  'synced': 1,
                  'skipped': 1,
                  'reasons': [
                    {
                      'order_id': 100,
                      'order_code': 'PO-100',
                      'reason': 'running',
                    },
                  ],
                },
              },
            },
          );
        },
        'DELETE /craft/templates/3': (_) => TestResponse.json(200, body: {'data': {}}),
      });
      addTearDown(server.close);

      final service = CraftService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-craft'),
      );
      const stepPayload = CraftTemplateStepPayload(
        stepOrder: 1,
        stageId: 1,
        processId: 2,
      );

      final stages = await service.listStages(
        page: 1,
        pageSize: 50,
        keyword: '  段 ',
        enabled: true,
      );
      final createdStage = await service.createStage(
        code: '02',
        name: '焊接段',
        sortOrder: 2,
      );
      final updatedStage = await service.updateStage(
        stageId: 1,
        code: '01',
        name: '切割段',
        sortOrder: 1,
        isEnabled: false,
      );
      await service.deleteStage(stageId: 1);

      final processes = await service.listProcesses(
        page: 1,
        pageSize: 100,
        keyword: '工序',
        stageId: 1,
        enabled: true,
      );
      final createdProcess = await service.createProcess(
        code: '02-01',
        name: '焊接',
        stageId: 2,
      );
      final updatedProcess = await service.updateProcess(
        processId: 2,
        code: '01-01',
        name: '切割',
        stageId: 1,
        isEnabled: false,
      );
      await service.deleteProcess(processId: 2);

      final templates = await service.listTemplates(
        page: 1,
        pageSize: 100,
        productId: 10,
        keyword: '模板',
      );
      final master = await service.getSystemMasterTemplate();
      final createdMaster = await service.createSystemMasterTemplate(
        steps: const [stepPayload],
      );
      final updatedMaster = await service.updateSystemMasterTemplate(
        steps: const [stepPayload],
      );
      final detail = await service.getTemplateDetail(templateId: 3);
      final createdTemplate = await service.createTemplate(
        productId: 10,
        templateName: '默认模板',
        isDefault: true,
        steps: const [stepPayload],
      );
      final updatedTemplate = await service.updateTemplate(
        templateId: 3,
        templateName: '默认模板',
        isDefault: true,
        isEnabled: true,
        steps: const [stepPayload],
        syncOrders: false,
      );
      await service.deleteTemplate(templateId: 3);

      expect(stages.items.single.code, '01');
      expect(createdStage.code, '02');
      expect(updatedStage.isEnabled, isFalse);
      expect(processes.items.single.code, '01-01');
      expect(createdProcess.code, '02-01');
      expect(updatedProcess.isEnabled, isFalse);
      expect(templates.items.single.templateName, '默认模板');
      expect(master, isNotNull);
      expect(master!.steps.single.processCode, '01-01');
      expect(createdMaster.version, 1);
      expect(updatedMaster.version, 2);
      expect(detail.steps.single.stepOrder, 1);
      expect(createdTemplate.template.id, 9);
      expect(updatedTemplate.syncResult.skipped, 1);
      expect(server.requests.length, 16);
    });

    test('returns null master template when backend data is null', () async {
      final server = await TestHttpServer.start({
        'GET /craft/system-master-template': (_) =>
            TestResponse.json(200, body: {'data': null}),
      });
      addTearDown(server.close);

      final service = CraftService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-craft'),
      );
      final result = await service.getSystemMasterTemplate();
      expect(result, isNull);
    });

    test('throws ApiException and supports non-json response parsing', () async {
      final server = await TestHttpServer.start({
        'DELETE /craft/templates/3': (_) => const TestResponse(
          statusCode: 500,
          body: 'plain text error',
        ),
      });
      addTearDown(server.close);

      final service = CraftService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-craft'),
      );

      await expectLater(
        () => service.deleteTemplate(templateId: 3),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message', 'plain text error'),
        ),
      );
    });
  });
}
