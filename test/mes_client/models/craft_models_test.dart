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
}
