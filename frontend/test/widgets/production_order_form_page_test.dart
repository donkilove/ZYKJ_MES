import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';
import 'package:mes_client/features/production/presentation/production_order_form_page.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/production/services/production_service.dart';
import 'package:mes_client/features/quality/services/quality_supplier_service.dart';

class _FakeProductionOrderFormService extends ProductionService {
  _FakeProductionOrderFormService({
    this.detailSupplierId = 9,
    this.detailSupplierName = '停用供应商',
  }) : super(AppSession(baseUrl: '', accessToken: ''));

  int? receivedTemplateId;
  int? receivedSupplierId;
  int createOrderCallCount = 0;
  List<String> receivedProcessCodes = const [];
  final int? detailSupplierId;
  final String? detailSupplierName;

  @override
  Future<ProductionOrderItem> createOrder({
    required String orderCode,
    required int productId,
    required int supplierId,
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
    createOrderCallCount += 1;
    receivedTemplateId = templateId;
    receivedSupplierId = supplierId;
    receivedProcessCodes = processCodes;
    return ProductionOrderItem.fromJson({
      'id': 1,
      'order_code': orderCode,
      'product_id': productId,
      'product_name': '产线试产件',
      'supplier_id': supplierId,
      'supplier_name': '启用供应商',
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

  @override
  Future<ProductionOrderItem> updateOrder({
    required int orderId,
    required int productId,
    required int supplierId,
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
    receivedSupplierId = supplierId;
    receivedProcessCodes = processCodes;
    return ProductionOrderItem.fromJson({
      'id': orderId,
      'order_code': 'PO-EDIT-001',
      'product_id': productId,
      'product_name': '产线试产件',
      'supplier_id': supplierId,
      'supplier_name': supplierId == 9 ? '停用供应商' : '启用供应商',
      'product_version': 1,
      'quantity': quantity,
      'status': 'pending',
      'current_process_code': processCodes.first,
      'current_process_name': '切割',
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

  @override
  Future<ProductionOrderDetail> getOrderDetail({required int orderId}) async {
    return ProductionOrderDetail.fromJson({
      'order': {
        'id': orderId,
        'order_code': 'PO-EDIT-001',
        'product_id': 1,
        'product_name': '产线试产件',
        'supplier_id': detailSupplierId,
        'supplier_name': detailSupplierName,
        'quantity': 15,
        'status': 'pending',
        'created_at': '2026-03-01T00:00:00Z',
        'updated_at': '2026-03-01T00:00:00Z',
      },
      'processes': [
        {
          'id': 1,
          'stage_id': 11,
          'stage_code': 'CUT',
          'stage_name': '切割段',
          'process_code': 'CUT-01',
          'process_name': '切割',
          'process_order': 1,
          'status': 'pending',
          'visible_quantity': 0,
          'completed_quantity': 0,
          'created_at': '2026-03-01T00:00:00Z',
          'updated_at': '2026-03-01T00:00:00Z',
        },
      ],
      'sub_orders': const [],
      'records': const [],
      'events': const [],
    });
  }
}

class _FakeQualitySupplierService extends QualitySupplierService {
  _FakeQualitySupplierService(this._items)
    : super(AppSession(baseUrl: '', accessToken: ''));

  final List<QualitySupplierItem> _items;

  @override
  Future<QualitySupplierListResult> listSuppliers({
    String? keyword,
    bool? enabled,
  }) async {
    var items = _items;
    if (enabled != null) {
      items = items.where((item) => item.isEnabled == enabled).toList();
    }
    return QualitySupplierListResult(total: items.length, items: items);
  }
}

class _FakeCraftService extends CraftService {
  _FakeCraftService() : super(AppSession(baseUrl: '', accessToken: ''));

  @override
  Future<CraftTemplateListResult> listTemplates({
    int page = 1,
    int pageSize = 500,
    int? productId,
    String? keyword,
    String? productCategory,
    bool? isDefault,
    bool? enabled = true,
    String? lifecycleStatus,
    DateTime? updatedFrom,
    DateTime? updatedTo,
  }) async {
    return CraftTemplateListResult(total: 0, items: const []);
  }

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
          supplierService: _FakeQualitySupplierService([
            QualitySupplierItem(
              id: 3,
              name: '启用供应商',
              remark: null,
              isEnabled: true,
              createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
              updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
            ),
          ]),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('手工调整优先'), findsOneWidget);
    expect(find.text('供应商'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, '订单号'),
      'PO-FORM-001',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '数量'), '15');

    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();

    expect(service.receivedTemplateId, 7);
    expect(service.receivedSupplierId, 3);
    expect(service.receivedProcessCodes, ['CUT-01']);
  });

  testWidgets('编辑历史订单时保留停用供应商回显并允许保存', (tester) async {
    final service = _FakeProductionOrderFormService();
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ProductionOrderFormPage(
          session: AppSession(baseUrl: '', accessToken: ''),
          onLogout: () {},
          existing: ProductionOrderItem.fromJson({
            'id': 1,
            'order_code': 'PO-EDIT-001',
            'product_id': 1,
            'product_name': '产线试产件',
            'supplier_id': 9,
            'supplier_name': '停用供应商',
            'quantity': 15,
            'status': 'pending',
            'created_at': '2026-03-01T00:00:00Z',
            'updated_at': '2026-03-01T00:00:00Z',
          }),
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
          ],
          initialTemplates: const [],
          service: service,
          craftService: _FakeCraftService(),
          supplierService: _FakeQualitySupplierService([
            QualitySupplierItem(
              id: 3,
              name: '启用供应商',
              remark: null,
              isEnabled: true,
              createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
              updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
            ),
          ]),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('停用供应商（已停用）'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, '数量'), '18');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(service.receivedSupplierId, 9);
    expect(service.receivedProcessCodes, ['CUT-01']);
  });

  testWidgets('编辑历史空供应商订单时不自动预选启用供应商', (tester) async {
    final service = _FakeProductionOrderFormService(
      detailSupplierId: null,
      detailSupplierName: null,
    );
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ProductionOrderFormPage(
          session: AppSession(baseUrl: '', accessToken: ''),
          onLogout: () {},
          existing: ProductionOrderItem.fromJson({
            'id': 2,
            'order_code': 'PO-EDIT-NULL-001',
            'product_id': 1,
            'product_name': '产线试产件',
            'supplier_id': null,
            'supplier_name': null,
            'quantity': 15,
            'status': 'pending',
            'created_at': '2026-03-01T00:00:00Z',
            'updated_at': '2026-03-01T00:00:00Z',
          }),
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
          ],
          initialTemplates: const [],
          service: service,
          craftService: _FakeCraftService(),
          supplierService: _FakeQualitySupplierService([
            QualitySupplierItem(
              id: 3,
              name: '启用供应商',
              remark: null,
              isEnabled: true,
              createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
              updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
            ),
          ]),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('供应商不能为空'), findsOneWidget);
    expect(service.receivedSupplierId, isNull);
  });

  testWidgets('重复选择小工序时允许提交并保留重复工序路线', (tester) async {
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
          initialTemplates: const [],
          service: service,
          craftService: _FakeCraftService(),
          supplierService: _FakeQualitySupplierService([
            QualitySupplierItem(
              id: 3,
              name: '启用供应商',
              remark: null,
              isEnabled: true,
              createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
              updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
            ),
          ]),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.enterText(
      find.widgetWithText(TextFormField, '订单号'),
      'PO-DUP-001',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '数量'), '15');

    await tester.tap(find.widgetWithText(OutlinedButton, '新增步骤'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();

    expect(service.createOrderCallCount, 1);
    expect(service.receivedProcessCodes, ['CUT-01', 'CUT-01']);
  });
}
