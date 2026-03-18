import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/services/api_exception.dart';
import 'package:mes_client/services/craft_service.dart';

import '../support/http_test_server.dart';

void main() {
  group('CraftService', () {
    test('covers light query、草稿创建与模板导出能力', () async {
      final server = await TestHttpServer.start({
        'GET /craft/stages/light': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'total': 1,
              'items': [
                {
                  'id': 1,
                  'code': 'ST-01',
                  'name': '切割段',
                  'sort_order': 0,
                  'is_enabled': true,
                },
              ],
            },
          },
        ),
        'GET /craft/processes/light': (request) {
          expect(request.uri.queryParameters['stage_id'], '1');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'items': [
                  {
                    'id': 11,
                    'code': 'ST-01-01',
                    'name': '切割',
                    'stage_id': 1,
                    'stage_code': 'ST-01',
                    'stage_name': '切割段',
                    'is_enabled': true,
                  },
                ],
              },
            },
          );
        },
        'POST /craft/templates/7/draft': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'template': {
                'id': 7,
                'product_id': 8,
                'product_name': '产品A',
                'product_category': '贴片',
                'template_name': '模板A',
                'version': 2,
                'lifecycle_status': 'draft',
                'published_version': 1,
                'is_default': true,
                'is_enabled': true,
                'source_type': 'template',
                'source_template_id': 3,
                'source_template_name': '模板来源',
                'source_template_version': 1,
                'source_product_id': 8,
                'source_system_master_version': null,
                'created_at': '2026-03-19T00:00:00Z',
                'updated_at': '2026-03-19T00:00:00Z',
              },
              'steps': [
                {
                  'id': 1,
                  'step_order': 1,
                  'stage_id': 1,
                  'stage_code': 'ST-01',
                  'stage_name': '切割段',
                  'process_id': 11,
                  'process_code': 'ST-01-01',
                  'process_name': '切割',
                  'standard_minutes': 10,
                  'is_key_process': true,
                  'step_remark': '关键步骤',
                  'created_at': '2026-03-19T00:00:00Z',
                  'updated_at': '2026-03-19T00:00:00Z',
                },
              ],
            },
          },
        ),
        'GET /craft/templates/7/export': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'content_base64': base64Encode(utf8.encode('{"type":"template"}')),
            },
          },
        ),
        'GET /craft/templates/7/versions/1/export': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'content_base64': base64Encode(utf8.encode('{"type":"version"}')),
            },
          },
        ),
      });
      addTearDown(server.close);

      final service = CraftService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-craft'),
      );

      final stageLight = await service.listStageLightOptions();
      final processLight = await service.listProcessLightOptions(stageId: 1);
      final draftDetail = await service.createTemplateDraft(templateId: 7);
      final currentExport = await service.exportTemplateDetail(templateId: 7);
      final versionExport = await service.exportTemplateVersion(
        templateId: 7,
        version: 1,
      );

      expect(stageLight.items.single.name, '切割段');
      expect(processLight.items.single.code, 'ST-01-01');
      expect(draftDetail.template.sourceType, 'template');
      expect(draftDetail.steps.single.standardMinutes, 10);
      expect(utf8.decode(base64Decode(currentExport)), '{"type":"template"}');
      expect(utf8.decode(base64Decode(versionExport)), '{"type":"version"}');
    });

    test('throws ApiException when creating draft fails', () async {
      final server = await TestHttpServer.start({
        'POST /craft/templates/9/draft': (_) =>
            TestResponse.json(400, body: {'detail': '模板当前已是草稿版本'}),
      });
      addTearDown(server.close);

      final service = CraftService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-craft'),
      );

      await expectLater(
        () => service.createTemplateDraft(templateId: 9),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', '模板当前已是草稿版本'),
        ),
      );
    });
  });
}
