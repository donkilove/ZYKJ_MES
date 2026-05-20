import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/production/presentation/production_order_form_page.dart';
import 'package:mes_client/features/production/services/production_service.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';
import 'package:mes_client/features/quality/services/quality_supplier_service.dart';

class _FakeProductionOrderFormService extends ProductionService {
  _FakeProductionOrderFormService()
    : super(AppSession(baseUrl: '', accessToken: ''));

  @override
  Future<ProductionOrderDetail> getOrderDetail({required int orderId}) async {
    throw UnimplementedError();
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

class _FakeReorderCraftService extends CraftService {
  _FakeReorderCraftService() : super(AppSession(baseUrl: '', accessToken: ''));

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
        productName: 'Product A',
        templateName: 'Route Template',
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
          stageName: 'Stage A',
          processId: 101,
          processCode: 'CUT-01',
          processName: 'Process A',
          createdAt: now,
          updatedAt: now,
        ),
        CraftTemplateStepItem(
          id: 2,
          stepOrder: 2,
          stageId: 12,
          stageCode: 'POL',
          stageName: 'Stage B',
          processId: 201,
          processCode: 'POL-01',
          processName: 'Process B',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
  }
}

void main() {
  testWidgets('desktop drag handle reorders route steps', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: ProductionOrderFormPage(
          session: AppSession(baseUrl: '', accessToken: ''),
          onLogout: () {},
          initialProducts: [ProductionProductOption(id: 1, name: 'Product A')],
          initialProcesses: [
            ProductionProcessOption(
              id: 101,
              code: 'CUT-01',
              name: 'Process A',
              stageId: 11,
              stageCode: 'CUT',
              stageName: 'Stage A',
            ),
            ProductionProcessOption(
              id: 201,
              code: 'POL-01',
              name: 'Process B',
              stageId: 12,
              stageCode: 'POL',
              stageName: 'Stage B',
            ),
          ],
          initialTemplates: [
            CraftTemplateItem(
              id: 7,
              productId: 1,
              productName: 'Product A',
              templateName: 'Route Template',
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
          service: _FakeProductionOrderFormService(),
          craftService: _FakeReorderCraftService(),
          supplierService: _FakeQualitySupplierService([
            QualitySupplierItem(
              id: 3,
              name: 'Supplier A',
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

    expect(
      tester.getTopLeft(find.text('Process A (CUT-01)')).dy,
      lessThan(tester.getTopLeft(find.text('Process B (POL-01)')).dy),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('route-step-drag-handle-0'))),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, 220));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Process B (POL-01)')).dy,
      lessThan(tester.getTopLeft(find.text('Process A (CUT-01)')).dy),
    );
  });
}
