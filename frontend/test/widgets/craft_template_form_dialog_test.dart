import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/craft/presentation/widgets/system_master_template_form_dialog.dart';
import 'package:mes_client/features/craft/presentation/widgets/template_form_dialog.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/production/models/production_models.dart';

class _FakeTemplateDialogCraftService extends CraftService {
  _FakeTemplateDialogCraftService({required this.templateDetail})
    : super(AppSession(baseUrl: '', accessToken: ''));

  final CraftTemplateDetail templateDetail;
  List<CraftTemplateStepPayload> updatedTemplateSteps = const [];
  List<CraftTemplateStepPayload> updatedSystemMasterSteps = const [];

  @override
  Future<CraftTemplateDetail> getTemplateDetail({
    required int templateId,
  }) async {
    return templateDetail;
  }

  @override
  Future<CraftTemplateUpdateResult> updateTemplate({
    required int templateId,
    required String templateName,
    required bool isDefault,
    required bool isEnabled,
    required List<CraftTemplateStepPayload> steps,
    bool syncOrders = true,
    String? remark,
  }) async {
    updatedTemplateSteps = steps;
    return CraftTemplateUpdateResult(
      detail: templateDetail,
      syncResult: CraftTemplateSyncResult(
        total: 0,
        synced: 0,
        skipped: 0,
        reasons: const [],
      ),
    );
  }

  @override
  Future<CraftSystemMasterTemplateItem> updateSystemMasterTemplate({
    required List<CraftTemplateStepPayload> steps,
  }) async {
    updatedSystemMasterSteps = steps;
    return _buildSystemMasterTemplate(steps: _systemStepsFromPayload(steps));
  }
}

CraftStageItem _stage() {
  return CraftStageItem(
    id: 1,
    code: 'CUT',
    name: '切割段',
    sortOrder: 1,
    isEnabled: true,
    processCount: 1,
    createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
    updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
  );
}

CraftProcessItem _process() {
  return CraftProcessItem(
    id: 11,
    code: 'CUT-01',
    name: '激光切割',
    stageId: 1,
    stageCode: 'CUT',
    stageName: '切割段',
    isEnabled: true,
    createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
    updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
  );
}

ProductionProductOption _product() {
  return ProductionProductOption(id: 1, name: '产品A');
}

CraftTemplateItem _template() {
  return CraftTemplateItem(
    id: 1,
    productId: 1,
    productName: '产品A',
    templateName: '切割模板',
    version: 1,
    lifecycleStatus: 'draft',
    publishedVersion: 0,
    isDefault: false,
    isEnabled: true,
    createdByUserId: 1,
    createdByUsername: 'admin',
    updatedByUserId: 1,
    updatedByUsername: 'admin',
    createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
    updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
  );
}

CraftTemplateStepItem _templateStep({required int processId}) {
  return CraftTemplateStepItem(
    id: 1,
    stepOrder: 1,
    stageId: 1,
    stageCode: 'CUT',
    stageName: '切割段',
    processId: processId,
    processCode: 'CUT-OLD',
    processName: '旧工序',
    createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
    updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
  );
}

CraftSystemMasterTemplateStepItem _systemStep({required int processId}) {
  return CraftSystemMasterTemplateStepItem(
    id: 1,
    stepOrder: 1,
    stageId: 1,
    stageCode: 'CUT',
    stageName: '切割段',
    processId: processId,
    processCode: 'CUT-OLD',
    processName: '旧工序',
    createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
    updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
  );
}

List<CraftSystemMasterTemplateStepItem> _systemStepsFromPayload(
  List<CraftTemplateStepPayload> steps,
) {
  return steps.map((item) => _systemStep(processId: item.processId)).toList();
}

CraftSystemMasterTemplateItem _buildSystemMasterTemplate({
  required List<CraftSystemMasterTemplateStepItem> steps,
}) {
  return CraftSystemMasterTemplateItem(
    id: 1,
    version: 1,
    createdByUserId: 1,
    createdByUsername: 'admin',
    updatedByUserId: 1,
    updatedByUsername: 'admin',
    createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
    updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
    steps: steps,
  );
}

Future<void> _pumpDialogLauncher(
  WidgetTester tester, {
  required Future<void> Function(BuildContext context) open,
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => open(context),
              child: const Text('打开'),
            );
          },
        ),
      ),
    ),
  );

  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
}

void main() {
  test('模板表单构建阶段不直接改写步骤草稿工序', () {
    final sources = [
      File('lib/features/craft/presentation/widgets/template_form_dialog.dart'),
      File(
        'lib/features/craft/presentation/widgets/system_master_template_form_dialog.dart',
      ),
    ];

    for (final source in sources) {
      expect(
        source.readAsStringSync(),
        isNot(contains('step.processId = processRows.first.id;')),
        reason: '${source.path} 的 build/itemBuilder 不应改写草稿状态',
      );
    }
  });

  testWidgets('编辑产品模板提交前会归一无效工序', (tester) async {
    final service = _FakeTemplateDialogCraftService(
      templateDetail: CraftTemplateDetail(
        template: _template(),
        steps: [_templateStep(processId: 999)],
      ),
    );

    await _pumpDialogLauncher(
      tester,
      open: (context) {
        return showTemplateFormDialog(
          context: context,
          craftService: service,
          products: [_product()],
          stages: [_stage()],
          processes: [_process()],
          onLogout: () {},
          onSuccess: () {},
          existing: _template(),
        ).then((_) {});
      },
    );

    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(service.updatedTemplateSteps.single.processId, 11);
  });

  testWidgets('编辑系统母版提交前会归一无效小工序', (tester) async {
    final service = _FakeTemplateDialogCraftService(
      templateDetail: CraftTemplateDetail(
        template: _template(),
        steps: const [],
      ),
    );

    await _pumpDialogLauncher(
      tester,
      open: (context) {
        return showSystemMasterTemplateFormDialog(
          context: context,
          craftService: service,
          stages: [_stage()],
          processes: [_process()],
          onLogout: () {},
          onSuccess: () {},
          existing: _buildSystemMasterTemplate(
            steps: [_systemStep(processId: 999)],
          ),
        ).then((_) {});
      },
    );

    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(service.updatedSystemMasterSteps.single.processId, 11);
  });
}
