import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/craft_models.dart';
import 'package:mes_client/models/production_models.dart';
import 'package:mes_client/pages/production_order_management_page.dart';
import 'package:mes_client/services/craft_service.dart';
import 'package:mes_client/services/production_service.dart';

class _FakeProductionOrderManagementService extends ProductionService {
  _FakeProductionOrderManagementService()
    : super(AppSession(baseUrl: '', accessToken: ''));

  @override
  Future<ProductionOrderListResult> listOrders({
    required int page,
    required int pageSize,
    String? keyword,
    String? status,
    String? productName,
    bool? pipelineEnabled,
  }) async {
    return ProductionOrderListResult(
      total: 1,
      items: [
        ProductionOrderItem(
          id: 1,
          orderCode: 'PO-1',
          productId: 1,
          productName: '产品A',
          quantity: 10,
          status: 'pending',
          currentProcessCode: '01-01',
          currentProcessName: '切割',
          startDate: DateTime(2026, 3, 1),
          dueDate: DateTime(2026, 3, 10),
          remark: null,
          processTemplateId: null,
          processTemplateName: null,
          processTemplateVersion: null,
          pipelineEnabled: false,
          pipelineProcessCodes: const [],
          createdByUserId: 1,
          createdByUsername: 'admin',
          createdAt: DateTime(2026, 3, 1),
          updatedAt: DateTime(2026, 3, 1, 12),
        ),
      ],
    );
  }

  @override
  Future<List<ProductionProductOption>> listProductOptions() async {
    return [ProductionProductOption(id: 1, name: '产品A')];
  }

  @override
  Future<List<ProductionProcessOption>> listProcessOptions() async {
    return [
      ProductionProcessOption(
        id: 11,
        code: '01-01',
        name: '切割',
        stageId: 1,
        stageCode: '01',
        stageName: '切割段',
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>> exportOrders({
    String? keyword,
    String? status,
    String? productName,
    bool? pipelineEnabled,
  }) async {
    return {
      'file_name': 'orders_export.csv',
      'content_base64': base64Encode(const [1, 2, 3]),
    };
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
    bool? enabled = true,
    String? lifecycleStatus,
  }) async {
    return CraftTemplateListResult(total: 0, items: const []);
  }
}

void main() {
  testWidgets('production order management export uses file_name fields', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionOrderManagementPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canCreateOrder: true,
            canEditOrder: true,
            canDeleteOrder: true,
            canCompleteOrder: true,
            canUpdatePipelineMode: true,
            service: _FakeProductionOrderManagementService(),
            craftService: _FakeCraftService(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('总数：1'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '导出'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('导出成功：orders_export.csv（3 字节）'), findsOneWidget);
  });
}
