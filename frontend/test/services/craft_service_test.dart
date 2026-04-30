import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';

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
              'content_base64': base64Encode(
                utf8.encode('{"type":"template"}'),
              ),
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
        'GET /craft/templates/7/versions': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'total': 1,
              'items': [
                {
                  'version': 1,
                  'action': 'publish',
                  'record_type': 'publish',
                  'record_title': '发布记录 P1',
                  'record_summary': '草稿经发布门禁确认后成为当前生效版本',
                  'note': '首次发布',
                  'source_version': null,
                  'created_by_username': 'planner',
                  'created_at': '2026-03-19T00:00:00Z',
                },
              ],
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
      final versionList = await service.listTemplateVersions(templateId: 7);

      expect(stageLight.items.single.name, '切割段');
      expect(processLight.items.single.code, 'ST-01-01');
      expect(draftDetail.template.sourceType, 'template');
      expect(draftDetail.steps.single.processCode, 'ST-01-01');
      expect(versionList.items.single.recordTitle, '发布记录 P1');
      expect(utf8.decode(base64Decode(currentExport)), '{"type":"template"}');
      expect(utf8.decode(base64Decode(versionExport)), '{"type":"version"}');
    });

    test('看板导出支持 100 条 limit 契约', () async {
      final server = await TestHttpServer.start({
        'GET /craft/kanban/process-metrics/export': (request) {
          expect(request.uri.queryParameters['product_id'], '8');
          expect(request.uri.queryParameters['limit'], '100');
          return TestResponse.json(
            200,
            body: {
              'data': {'content_base64': base64Encode(utf8.encode('csv'))},
            },
          );
        },
      });
      addTearDown(server.close);

      final service = CraftService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-craft'),
      );

      final exported = await service.exportCraftKanbanProcessMetrics(
        productId: 8,
        limit: 100,
      );

      expect(utf8.decode(base64Decode(exported)), 'csv');
    });

    test('按产品查询模板引用走独立服务契约并解析跳转字段', () async {
      final server = await TestHttpServer.start({
        'GET /craft/products/8/template-references': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'product_id': 8,
              'product_name': '产品A',
              'total_templates': 1,
              'total_references': 1,
              'items': [
                {
                  'template_id': 21,
                  'template_name': '模板A',
                  'lifecycle_status': 'published',
                  'ref_type': 'template_reuse',
                  'ref_id': 22,
                  'ref_code': 'TMP-22',
                  'ref_name': '模板B',
                  'detail': '复用到产品B',
                  'ref_status': '正在使用',
                  'jump_module': 'craft',
                  'jump_target': 'process-configuration?template_id=22',
                  'risk_level': 'medium',
                  'risk_note': '同步发布后处理',
                },
              ],
            },
          },
        ),
      });
      addTearDown(server.close);

      final service = CraftService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-craft'),
      );

      final result = await service.getProductTemplateReferences(productId: 8);

      expect(result.productName, '产品A');
      expect(result.totalTemplates, 1);
      expect(result.items.single.refCode, 'TMP-22');
      expect(result.items.single.jumpModule, 'craft');
      expect(
        result.items.single.jumpTarget,
        'process-configuration?template_id=22',
      );
    });

    test('模板列表优先走服务端完整筛选契约并解析关键引用影响', () async {
      final server = await TestHttpServer.start({
        'GET /craft/templates': (request) {
          expect(request.uri.queryParameters['product_id'], '8');
          expect(request.uri.queryParameters['keyword'], '模板A');
          expect(request.uri.queryParameters['product_category'], '贴片');
          expect(request.uri.queryParameters['is_default'], 'true');
          expect(request.uri.queryParameters['enabled'], 'false');
          expect(request.uri.queryParameters['lifecycle_status'], 'published');
          expect(
            request.uri.queryParameters['updated_from'],
            '2026-03-01T00:00:00.000Z',
          );
          expect(
            request.uri.queryParameters['updated_to'],
            '2026-03-02T23:59:59.999Z',
          );
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'items': [
                  {
                    'id': 7,
                    'product_id': 8,
                    'product_name': '产品A',
                    'product_category': '贴片',
                    'template_name': '模板A',
                    'version': 2,
                    'lifecycle_status': 'published',
                    'published_version': 2,
                    'is_default': true,
                    'is_enabled': false,
                    'created_at': '2026-03-02T00:00:00Z',
                    'updated_at': '2026-03-02T01:00:00Z',
                  },
                ],
              },
            },
          );
        },
        'GET /craft/templates/7/impact-analysis': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'target_version': 2,
              'total_orders': 1,
              'pending_orders': 0,
              'in_progress_orders': 1,
              'syncable_orders': 0,
              'blocked_orders': 1,
              'total_references': 2,
              'user_stage_reference_count': 1,
              'template_reuse_reference_count': 1,
              'items': [
                {
                  'order_id': 10,
                  'order_code': 'MO-10',
                  'order_status': 'in_progress',
                  'syncable': false,
                  'reason': '订单已开工',
                },
              ],
              'reference_items': [
                {
                  'ref_type': 'user_stage',
                  'ref_id': 31,
                  'ref_code': 'operator_a',
                  'ref_name': '操作员A',
                  'detail': '工段：切割段',
                  'ref_status': '正在使用',
                },
              ],
            },
          },
        ),
        'GET /craft/templates/7/references': (_) => TestResponse.json(
          200,
          body: {
            'data': {
              'template_id': 7,
              'template_name': '模板A',
              'product_id': 8,
              'product_name': '产品A',
              'total': 4,
              'order_reference_count': 1,
              'user_stage_reference_count': 1,
              'template_reuse_reference_count': 1,
              'blocking_reference_count': 1,
              'has_blocking_references': true,
              'items': [
                {'ref_type': 'product', 'ref_id': 8, 'ref_name': '产品A'},
                {
                  'ref_type': 'user_stage',
                  'ref_id': 31,
                  'ref_name': '操作员A',
                  'is_blocking': false,
                },
                {
                  'ref_type': 'order',
                  'ref_id': 10,
                  'ref_name': 'MO-10',
                  'is_blocking': true,
                },
                {
                  'ref_type': 'template_reuse',
                  'ref_id': 18,
                  'ref_name': '模板B',
                  'is_blocking': false,
                },
              ],
            },
          },
        ),
      });
      addTearDown(server.close);

      final service = CraftService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-craft'),
      );

      final templates = await service.listTemplates(
        productId: 8,
        keyword: '模板A',
        productCategory: '贴片',
        isDefault: true,
        enabled: false,
        lifecycleStatus: 'published',
        updatedFrom: DateTime.parse('2026-03-01T00:00:00Z'),
        updatedTo: DateTime.parse('2026-03-02T23:59:59.999Z'),
      );
      final impact = await service.getTemplateImpactAnalysis(templateId: 7);
      final references = await service.getTemplateReferences(templateId: 7);

      expect(templates.items.single.productCategory, '贴片');
      expect(templates.items.single.isEnabled, isFalse);
      expect(impact.totalReferences, 2);
      expect(impact.userStageReferenceCount, 1);
      expect(impact.referenceItems.single.refName, '操作员A');
      expect(references.orderReferenceCount, 1);
      expect(references.userStageReferenceCount, 1);
      expect(references.templateReuseReferenceCount, 1);
      expect(references.blockingReferenceCount, 1);
      expect(references.hasBlockingReferences, isTrue);
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

    test('服务端返回非 JSON 错误体时抛出解析失败提示', () async {
      final server = await TestHttpServer.start({
        'GET /craft/stages/light': (_) => const TestResponse(
          statusCode: 500,
          body: '<html>server error</html>',
        ),
      });
      addTearDown(server.close);

      final service = CraftService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-craft'),
      );

      await expectLater(
        () => service.listStageLightOptions(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message', contains('响应解析失败')),
        ),
      );
    });

    test('supports stage/process detail queries by id and code', () async {
      final server = await TestHttpServer.start({
        'GET /craft/stages/detail': (request) {
          expect(request.uri.queryParameters['stage_id'], '1');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'id': 1,
                'code': 'ST-01',
                'name': '切割段',
                'sort_order': 0,
                'is_enabled': true,
                'process_count': 2,
                'created_at': '2026-03-19T00:00:00Z',
                'updated_at': '2026-03-19T00:00:00Z',
              },
            },
          );
        },
        'GET /craft/processes/detail': (request) {
          expect(request.uri.queryParameters['process_code'], 'ST-01-01');
          return TestResponse.json(
            200,
            body: {
              'data': {
                'id': 11,
                'code': 'ST-01-01',
                'name': '切割',
                'stage_id': 1,
                'stage_code': 'ST-01',
                'stage_name': '切割段',
                'is_enabled': true,
                'created_at': '2026-03-19T00:00:00Z',
                'updated_at': '2026-03-19T00:00:00Z',
              },
            },
          );
        },
      });
      addTearDown(server.close);

      final service = CraftService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-craft'),
      );

      final stage = await service.getStageDetail(stageId: 1);
      final process = await service.getProcessDetail(processCode: 'ST-01-01');

      expect(stage.processCount, 2);
      expect(process.stageCode, 'ST-01');
    });

    test('create/import contract no longer bypasses draft gate', () async {
      final server = await TestHttpServer.start({
        'POST /craft/templates': (request) {
          final body = request.decodedBody as Map<String, dynamic>;
          expect(body.containsKey('lifecycle_status'), isFalse);
          return TestResponse.json(
            201,
            body: {
              'data': {
                'template': {
                  'id': 21,
                  'product_id': 8,
                  'product_name': '产品A',
                  'product_category': '贴片',
                  'template_name': '模板新建',
                  'version': 1,
                  'lifecycle_status': 'draft',
                  'published_version': 0,
                  'is_default': false,
                  'is_enabled': true,
                  'created_at': '2026-03-19T00:00:00Z',
                  'updated_at': '2026-03-19T00:00:00Z',
                },
                'steps': const [],
              },
            },
          );
        },
        'POST /craft/templates/import': (request) {
          final body = request.decodedBody as Map<String, dynamic>;
          expect(body.containsKey('publish_after_import'), isFalse);
          final items = body['items'] as List<dynamic>;
          final first = items.first as Map<String, dynamic>;
          expect(first['source_type'], 'system_master');
          expect(first['source_system_master_version'], 7);
          return TestResponse.json(
            200,
            body: {
              'data': {
                'total': 1,
                'created': 1,
                'updated': 0,
                'skipped': 0,
                'items': [
                  {
                    'template_id': 21,
                    'product_id': 8,
                    'product_name': '产品A',
                    'template_name': '模板新建',
                    'action': 'created',
                    'lifecycle_status': 'draft',
                    'published_version': 0,
                  },
                ],
                'errors': const [],
              },
            },
          );
        },
      });
      addTearDown(server.close);

      final service = CraftService(
        AppSession(baseUrl: server.baseUrl, accessToken: 'token-craft'),
      );

      final created = await service.createTemplate(
        productId: 8,
        templateName: '模板新建',
        isDefault: false,
        remark: '只创建草稿',
        steps: const [
          CraftTemplateStepPayload(stepOrder: 1, stageId: 1, processId: 11),
        ],
      );
      final imported = await service.importTemplates(
        items: const [
          CraftTemplateBatchImportItem(
            productId: 8,
            templateName: '模板新建',
            isDefault: false,
            isEnabled: true,
            lifecycleStatus: 'published',
            sourceType: 'system_master',
            sourceTemplateName: '系统母版',
            sourceSystemMasterVersion: 7,
            steps: [
              CraftTemplateStepPayload(stepOrder: 1, stageId: 1, processId: 11),
            ],
          ),
        ],
        overwriteExisting: true,
      );

      expect(created.template.lifecycleStatus, 'draft');
      expect(imported.items.single.lifecycleStatus, 'draft');
    });
  });
}
