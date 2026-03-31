import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/craft_models.dart';
import 'package:mes_client/models/production_models.dart';
import 'package:mes_client/pages/production_order_form_page.dart';
import 'package:mes_client/services/craft_service.dart';
import 'package:mes_client/services/production_service.dart';

class _FakeProductionOrderFormService extends ProductionService {
  _FakeProductionOrderFormService()
    : super(AppSession(baseUrl: '', accessToken: ''));

  int? receivedTemplateId;
  List<String> receivedProcessCodes = const [];

  @override
  Future<ProductionOrderItem> createOrder({
    required String orderCode,
    required int productId,
    required int quantity,
    required List<String> processCodes,
    int? templateId,
    List<ProductionOrderProcessStepInput>? processSteps,
    bool saveAsTemplate = false,
    String? newTemplateName,
    bool newTemplateSetDefault = false,
    DateTime? startDate,
    DateTime? dueDate,
    String? remark,
  }) async {
    receivedTemplateId = templateId;
    receivedProcessCodes = processCodes;
    return ProductionOrderItem.fromJson({
      'id': 1,
      'order_code': orderCode,
      'product_id': productId,
      'product_name': '产线试产件',
      'product_version': 1,
      'quantity': quantity,
      'status': 'pending',
      'current_process_code': processCodes.first,
      'current_process_name': '抛光',
      'start_date': '2026-03-01',
      'due_date': '2026-03-03',
      'remark': remark,
      'process_template_id': templateId,
      'process_template_name': '标准模板',
      'process_template_version': 2,
      'pipeline_enabled': false,
      'pipeline_process_codes': processCodes,
      'created_by_user_id': 1,
      'created_by_username': 'admin',
      'created_at': '2026-03-01T00:00:00Z',
      'updated_at': '2026-03-01T00:00:00Z',
    });
  }
}

class _FakeCraftService extends CraftService {
  _FakeCraftService() : super(AppSession(baseUrl: '', accessToken: ''));

  @override
  Future<CraftTemplateDetail> getTemplateDetail({
    required int templateId,
  }) async {
    final now = DateTime.parse('2026-03-01T00:00:00Z');
    return CraftTemplateDetail(
      template: CraftTemplateItem(
        id: templateId,
        productId: 1,
        productName: '产线试产件',
        templateName: '标准模板',
        version: 2,
        lifecycleStatus: 'published',
        publishedVersion: 2,
        isDefault: true,
        isEnabled: true,
        createdByUserId: 1,
        createdByUsername: 'admin',
        updatedByUserId: 1,
        updatedByUsername: 'admin',
        createdAt: now,
        updatedAt: now,
      ),
      steps: [
        CraftTemplateStepItem(
          id: 1,
          stepOrder: 1,
          stageId: 11,
          stageCode: 'CUT',
          stageName: '切割段',
          processId: 101,
          processCode: 'CUT-01',
          processName: '切割',
          isKeyProcess: false,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
  }
}

void main() {
  testWidgets('订单表单页明确提示模板与手工调整优先规则', (tester) async {
    final service = _FakeProductionOrderFormService();
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ProductionOrderFormPage(
          session: AppSession(baseUrl: '', accessToken: ''),
          onLogout: () {},
          initialProducts: [ProductionProductOption(id: 1, name: '产线试产件')],
          initialProcesses: [
            ProductionProcessOption(
              id: 101,
              code: 'CUT-01',
              name: '切割',
              stageId: 11,
              stageCode: 'CUT',
              stageName: '切割段',
            ),
            ProductionProcessOption(
              id: 102,
              code: 'POL-01',
              name: '抛光',
              stageId: 11,
              stageCode: 'CUT',
              stageName: '切割段',
            ),
          ],
          initialTemplates: [
            CraftTemplateItem(
              id: 7,
              productId: 1,
              productName: '产线试产件',
              templateName: '标准模板',
              version: 2,
              lifecycleStatus: 'published',
              publishedVersion: 2,
              isDefault: true,
              isEnabled: true,
              createdByUserId: 1,
              createdByUsername: 'admin',
              updatedByUserId: 1,
              updatedByUsername: 'admin',
              createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
              updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
            ),
          ],
          service: service,
          craftService: _FakeCraftService(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('手工调整优先'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, '订单号'),
      'PO-FORM-001',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '数量'), '15');

    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();

    expect(service.receivedTemplateId, 7);
    expect(service.receivedProcessCodes, ['CUT-01']);
  });
}
