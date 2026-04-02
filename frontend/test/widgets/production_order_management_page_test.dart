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

  String? lastListKeyword;
  String? lastListProductName;
  DateTime? lastListStartDateFrom;
  DateTime? lastListStartDateTo;
  DateTime? lastListDueDateFrom;
  DateTime? lastListDueDateTo;
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
    lastListKeyword = keyword;
    lastListProductName = productName;
    lastListStartDateFrom = startDateFrom;
    lastListStartDateTo = startDateTo;
    lastListDueDateFrom = dueDateFrom;
    lastListDueDateTo = dueDateTo;
    return ProductionOrderListResult(
      total: 1,
      items: [
        ProductionOrderItem(
          id: 1,
          orderCode: 'PO-1',
          productId: 1,
          productName: '产品A',
          supplierId: null,
          supplierName: null,
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
  testWidgets(
    'production order management uses keyword as single search entry',
    (tester) async {
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

      expect(find.text('总数：1'), findsOneWidget);
      expect(find.widgetWithText(TextField, '搜索订单号/产品'), findsOneWidget);
      expect(find.widgetWithText(TextField, '产品名称'), findsNothing);
      expect(find.text('订单编号'), findsOneWidget);
      expect(find.text('产品名称'), findsOneWidget);
      expect(find.text('供应商'), findsOneWidget);
      expect(find.text('交货日期'), findsOneWidget);
      expect(find.text('备注'), findsOneWidget);
      expect(find.text('产品版本'), findsNothing);
      expect(find.text('模板名称/版本'), findsNothing);
      expect(find.text('创建人'), findsNothing);
      expect(find.text('开始日期'), findsNothing);
      expect(find.text('更新时间'), findsNothing);
      expect(find.text('-'), findsWidgets);

      await tester.enterText(find.widgetWithText(TextField, '搜索订单号/产品'), '产品A');
      await tester.tap(find.widgetWithText(FilledButton, '查询'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(service.lastListKeyword, '产品A');
      expect(service.lastListProductName, isNull);
      expect(service.lastListStartDateFrom, isNull);
      expect(service.lastListStartDateTo, isNull);
      expect(service.lastListDueDateFrom, isNull);
      expect(service.lastListDueDateTo, isNull);
    },
  );
}
