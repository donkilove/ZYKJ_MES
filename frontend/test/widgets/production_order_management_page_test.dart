import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/craft_models.dart';
import 'package:mes_client/models/production_models.dart';
import 'package:mes_client/pages/production_order_management_page.dart';
import 'package:mes_client/services/craft_service.dart';
import 'package:mes_client/services/production_service.dart';
import 'package:mes_client/widgets/simple_pagination_bar.dart';

class _FakeProductionOrderManagementService extends ProductionService {
  _FakeProductionOrderManagementService({this.total = 1})
    : super(AppSession(baseUrl: '', accessToken: ''));

  final int total;
  final List<int> requestedPages = <int>[];
  final List<int> requestedPageSizes = <int>[];

  @override
  Future<ProductionOrderListResult> listOrders({
    required int page,
    required int pageSize,
    String? keyword,
    String? status,
    String? productName,
    bool? pipelineEnabled,
    DateTime? startDateFrom,
    DateTime? startDateTo,
    DateTime? dueDateFrom,
    DateTime? dueDateTo,
  }) async {
    requestedPages.add(page);
    requestedPageSizes.add(pageSize);
    return ProductionOrderListResult(
      total: total,
      items: [
        ProductionOrderItem(
          id: page,
          orderCode: 'PO-$page',
          productId: 1,
          productName: '产品A',
          productVersion: null,
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
          createdAt: DateTime(2026, 3, page),
          updatedAt: DateTime(2026, 3, page, 12),
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
    DateTime? startDateFrom,
    DateTime? startDateTo,
    DateTime? dueDateFrom,
    DateTime? dueDateTo,
  }) async {
    return {
      'file_name': 'orders_export.csv',
      'content_base64': base64Encode(utf8.encode('订单号,产品\nPO-1,产品A')),
    };
  }

  @override
  Future<ProductionEventLogListResult> searchOrderEvents({
    required String orderCode,
    String? eventType,
    String? operatorUsername,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    expect(eventType, 'order_deleted');
    return ProductionEventLogListResult(
      total: 1,
      items: [
        ProductionEventLogItem(
          id: 1,
          orderId: null,
          orderCode: orderCode,
          orderStatus: 'pending',
          productName: '产品A',
          processCode: '01-01',
          eventType: 'order_deleted',
          eventTitle: '订单已删除',
          eventDetail: '删除订单 PO-1',
          operatorUserId: 1,
          operatorUsername: 'admin',
          payloadJson: '{"deleted":true}',
          createdAt: DateTime(2026, 3, 1, 10),
        ),
      ],
    );
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
}

void main() {
  testWidgets('production order management export action does not crash', (
    tester,
  ) async {
    final service = _FakeProductionOrderManagementService();

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
            service: service,
            craftService: _FakeCraftService(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(SimplePaginationBar), findsOneWidget);
    expect(find.text('第 1 / 1 页'), findsOneWidget);
    expect(find.text('每页 50 条'), findsOneWidget);
    expect(find.text('总数：1'), findsOneWidget);
    expect(service.requestedPages, [1]);
    expect(service.requestedPageSizes, [50]);

    await tester.tap(find.widgetWithText(OutlinedButton, '导出'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('第 1 / 1 页'), findsOneWidget);
    expect(find.text('每页 50 条'), findsOneWidget);
  });

  testWidgets('production order management can query deleted order trace', (
    tester,
  ) async {
    final service = _FakeProductionOrderManagementService();

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
            service: service,
            craftService: _FakeCraftService(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.widgetWithText(TextField, '删除追溯订单号'), 'PO-1');
    await tester.tap(find.widgetWithText(OutlinedButton, '删除追溯'));
    await tester.pumpAndSettle();

    expect(find.text('删除追溯 - PO-1'), findsOneWidget);
    expect(find.textContaining('订单已删除'), findsOneWidget);
    expect(service.requestedPages, [1]);
  });

  testWidgets(
    'production order management desktop layout keeps pagination stable',
    (tester) async {
      final service = _FakeProductionOrderManagementService(total: 120);

      tester.view.physicalSize = const Size(1920, 1080);
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
              service: service,
              craftService: _FakeCraftService(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SimplePaginationBar), findsOneWidget);
      expect(find.text('第 1 / 3 页'), findsOneWidget);
      expect(find.text('每页 50 条'), findsOneWidget);
      expect(find.text('总数：120'), findsOneWidget);
      expect(find.text('PO-1'), findsOneWidget);
      expect(find.text('删除追溯订单号'), findsOneWidget);
      expect(find.text('操作'), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(const Key('simple-pagination-page-selector')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('第 2 页').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(service.requestedPages, [1, 2]);
      expect(find.text('第 2 / 3 页'), findsOneWidget);
      expect(find.text('PO-2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('production order management can change page size', (
    tester,
  ) async {
    final service = _FakeProductionOrderManagementService(total: 120);

    tester.view.physicalSize = const Size(1920, 1080);
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
            service: service,
            craftService: _FakeCraftService(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(
      find.byKey(const Key('simple-pagination-page-size-selector')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('100 条/页').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(service.requestedPages, [1, 1]);
    expect(service.requestedPageSizes, [50, 100]);
    expect(find.text('每页 100 条'), findsOneWidget);
    expect(find.text('第 1 / 2 页'), findsOneWidget);
  });
}
