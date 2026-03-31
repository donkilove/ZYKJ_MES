import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/craft_models.dart';

void main() {
  test('craft stage/process models parse list wrappers', () {
    final stage = CraftStageItem.fromJson({
      'id': 1,
      'code': '01',
      'name': '切割段',
      'sort_order': 1,
      'is_enabled': true,
      'created_at': '2026-03-01T00:00:00Z',
      'updated_at': '2026-03-01T00:00:00Z',
    });
    final process = CraftProcessItem.fromJson({
      'id': 2,
      'code': '01-01',
      'name': '切割',
      'stage_id': 1,
      'stage_code': '01',
      'stage_name': '切割段',
      'is_enabled': true,
      'created_at': '2026-03-01T00:00:00Z',
      'updated_at': '2026-03-01T00:00:00Z',
    });

    expect(stage.code, '01');
    expect(process.stageId, 1);
    expect(CraftStageListResult(total: 1, items: [stage]).items.length, 1);
    expect(CraftProcessListResult(total: 1, items: [process]).items.length, 1);
  });

  test('craft template payload and item parsing', () {
    const payload = CraftTemplateStepPayload(
      stepOrder: 1,
      stageId: 10,
      processId: 20,
    );
    final step = CraftTemplateStepItem.fromJson({
      'id': 100,
      'step_order': 1,
      'stage_id': 10,
      'stage_code': '01',
      'stage_name': '切割段',
      'process_id': 20,
      'process_code': '01-01',
      'process_name': '切割',
      'created_at': '2026-03-01T00:00:00Z',
      'updated_at': '2026-03-01T00:00:00Z',
    });
    final template = CraftTemplateItem.fromJson({
      'id': 200,
      'product_id': 300,
      'product_name': '产品A',
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
    });
    final detail = CraftTemplateDetail.fromJson({
      'template': {
        'id': 200,
        'product_id': 300,
        'product_name': '产品A',
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
      },
      'steps': [
        {
          'id': 100,
          'step_order': 1,
          'stage_id': 10,
          'stage_code': '01',
          'stage_name': '切割段',
          'process_id': 20,
          'process_code': '01-01',
          'process_name': '切割',
          'created_at': '2026-03-01T00:00:00Z',
          'updated_at': '2026-03-01T00:00:00Z',
        },
      ],
    });

    expect(payload.toJson()['stage_id'], 10);
    expect(payload.toJson().containsKey('standard_minutes'), isFalse);
    expect(payload.toJson().containsKey('step_remark'), isFalse);
    expect(step.processCode, '01-01');
    expect(template.templateName, '默认模板');
    expect(detail.steps.single.processName, '切割');
    expect(CraftTemplateListResult(total: 1, items: [template]).total, 1);
  });

  test('system master template and sync result parse', () {
    final master = CraftSystemMasterTemplateItem.fromJson({
      'id': 1,
      'version': 2,
      'created_by_user_id': 1,
      'created_by_username': 'admin',
      'updated_by_user_id': 2,
      'updated_by_username': 'manager',
      'created_at': '2026-03-01T00:00:00Z',
      'updated_at': '2026-03-02T00:00:00Z',
      'steps': [
        {
          'id': 9,
          'step_order': 1,
          'stage_id': 10,
          'stage_code': '01',
          'stage_name': '切割段',
          'process_id': 20,
          'process_code': '01-01',
          'process_name': '切割',
          'created_at': '2026-03-01T00:00:00Z',
          'updated_at': '2026-03-02T00:00:00Z',
        },
      ],
    });
    final sync = CraftTemplateSyncResult.fromJson({
      'total': 10,
      'synced': 8,
      'skipped': 2,
      'reasons': [
        {'order_id': 100, 'order_code': 'PO-100', 'reason': 'already started'},
      ],
    });
    final update = CraftTemplateUpdateResult.fromJson({
      'detail': {
        'template': {
          'id': 200,
          'product_id': 300,
          'product_name': '产品A',
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
        },
        'steps': const [],
      },
      'sync_result': {
        'total': 10,
        'synced': 8,
        'skipped': 2,
        'reasons': const [],
      },
    });

    expect(master.version, 2);
    expect(master.steps.single.stepOrder, 1);
    expect(sync.reasons.single.orderCode, 'PO-100');
    expect(update.syncResult.synced, 8);
  });

  test('batch import result parses error details', () {
    final result = CraftTemplateBatchImportResult.fromJson({
      'total': 2,
      'created': 1,
      'updated': 0,
      'skipped': 1,
      'items': [
        {
          'template_id': 10,
          'product_id': 20,
          'product_name': '产品A',
          'template_name': '模板A',
          'action': 'created',
          'lifecycle_status': 'draft',
          'published_version': 0,
        },
      ],
      'errors': ['第2条：找不到产品 999999'],
    });

    expect(result.created, 1);
    expect(result.skipped, 1);
    expect(result.errors, hasLength(1));
    expect(result.errors.single, contains('第2条'));
  });

  test('引用分析与批量导出扩展字段解析完整', () {
    final ref = CraftReferenceItem.fromJson({
      'ref_type': 'template',
      'ref_id': 12,
      'ref_code': 'TPL-12',
      'ref_name': '模板A',
      'detail': 'published',
    });
    final export = CraftTemplateBatchExportItem.fromJson({
      'product_id': 1,
      'product_name': '产品A',
      'template_name': '模板A',
      'is_default': true,
      'is_enabled': true,
      'lifecycle_status': 'published',
      'source_type': 'system_master',
      'source_template_name': '系统母版',
      'source_system_master_version': 7,
      'steps': [
        {
          'step_order': 1,
          'stage_id': 10,
          'process_id': 20,
          'is_key_process': true,
        },
      ],
    });

    expect(ref.refCode, 'TPL-12');
    expect(export.sourceType, 'system_master');
    expect(export.sourceTemplateName, '系统母版');
    expect(export.sourceSystemMasterVersion, 7);
    expect(export.steps.single.isKeyProcess, isTrue);

    final templateRef = CraftTemplateReferenceResult.fromJson({
      'template_id': 12,
      'template_name': '模板A',
      'product_id': 1,
      'product_name': '产品A',
      'total': 2,
      'order_reference_count': 1,
      'user_stage_reference_count': 1,
      'template_reuse_reference_count': 1,
      'blocking_reference_count': 1,
      'has_blocking_references': true,
      'items': [
        {
          'ref_type': 'user_stage',
          'ref_id': 15,
          'ref_code': 'operator_a',
          'ref_name': '操作员A',
          'is_blocking': false,
        },
        {
          'ref_type': 'template_reuse',
          'ref_id': 18,
          'ref_name': '模板B',
          'is_blocking': true,
        },
      ],
    });

    expect(templateRef.orderReferenceCount, 1);
    expect(templateRef.userStageReferenceCount, 1);
    expect(templateRef.templateReuseReferenceCount, 1);
    expect(templateRef.blockingReferenceCount, 1);
    expect(templateRef.hasBlockingReferences, isTrue);
    expect(templateRef.items.first.isBlocking, isFalse);
    expect(templateRef.items.last.isBlocking, isTrue);
  });

  test('模板发布记录扩展语义字段可解析', () {
    final version = CraftTemplateVersionItem.fromJson({
      'version': 3,
      'action': 'rollback',
      'record_type': 'rollback_publish',
      'record_title': '回滚发布记录 P3',
      'record_summary': '基于历史版本 v2 重新发布并替换当前生效版本',
      'note': '恢复稳定版本',
      'source_version': 2,
      'created_by_username': 'planner',
      'created_at': '2026-03-20T00:00:00Z',
    });

    expect(version.recordType, 'rollback_publish');
    expect(version.recordTitle, '回滚发布记录 P3');
    expect(version.recordSummary, contains('当前生效版本'));
    expect(version.sourceVersion, 2);
  });
}
