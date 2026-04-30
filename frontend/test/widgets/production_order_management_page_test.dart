import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';
import 'package:mes_client/features/production/presentation/production_order_management_page.dart';
import 'package:mes_client/features/production/presentation/widgets/production_complete_order_dialog.dart';
import 'package:mes_client/features/production/presentation/widgets/production_delete_order_dialog.dart';
import 'package:mes_client/features/production/presentation/widgets/production_pipeline_mode_dialog.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/production/services/production_service.dart';
import 'package:mes_client/features/quality/services/quality_supplier_service.dart';

class _FakeProductionOrderManagementService extends ProductionService {
  _FakeProductionOrderManagementService()
    : super(AppSession(baseUrl: '', accessToken: ''));

  final List<ProductionOrderItem> _items = <ProductionOrderItem>[
    _buildItemStatic(1),
    _buildItemStatic(2, status: 'in_progress'),
  ];
  final List<int> requestedPages = [];
  final List<int> requestedPageSizes = [];
  String? lastListKeyword;
  String? lastListProductName;
  DateTime? lastListStartDateFrom;
  DateTime? lastListStartDateTo;
  DateTime? lastListDueDateFrom;
  DateTime? lastListDueDateTo;
  int createOrderCallCount = 0;
  int updateOrderCallCount = 0;
  int deleteOrderCallCount = 0;
  int completeOrderCallCount = 0;
  int pipelineUpdateCallCount = 0;
  String? lastCompletedPassword;
  List<String> lastPipelineProcessCodes = const <String>[];
  bool? lastPipelineEnabled;

  static ProductionOrderItem _buildItemStatic(
    int id, {
    String status = 'pending',
    bool pipelineEnabled = false,
    List<String> pipelineProcessCodes = const <String>[],
    int quantity = 10,
  }) {
    return ProductionOrderItem(
      id: id,
      orderCode: 'PO-$id',
      productId: 1,
      productName: '产品$id',
      supplierId: 3,
      supplierName: '供应商A',
      productVersion: null,
      quantity: quantity,
      status: status,
      currentProcessCode: '01-01',
      currentProcessName: '切割',
      startDate: DateTime(2026, 3, 1),
      dueDate: DateTime(2026, 3, 10),
      remark: null,
      processTemplateId: null,
      processTemplateName: null,
      processTemplateVersion: null,
      pipelineEnabled: pipelineEnabled,
      pipelineProcessCodes: pipelineProcessCodes,
      createdByUserId: 1,
      createdByUsername: 'admin',
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1, 12),
    );
  }

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
    lastListKeyword = keyword;
    lastListProductName = productName;
    lastListStartDateFrom = startDateFrom;
    lastListStartDateTo = startDateTo;
    lastListDueDateFrom = dueDateFrom;
    lastListDueDateTo = dueDateTo;
    final normalizedKeyword = keyword?.trim() ?? '';
    if (normalizedKeyword.isNotEmpty) {
      final filtered = _items
          .where((item) => item.orderCode.contains(normalizedKeyword))
          .toList();
      return ProductionOrderListResult(total: filtered.length, items: filtered);
    }
    if (page == 2) {
      final secondPageItems = _items.length > 1
          ? [_items[1]]
          : <ProductionOrderItem>[];
      return ProductionOrderListResult(total: 401, items: secondPageItems);
    }
    return ProductionOrderListResult(
      total: 401,
      items: _items.take(2).toList(),
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
      ProductionProcessOption(
        id: 12,
        code: '02-01',
        name: '抛光',
        stageId: 2,
        stageCode: '02',
        stageName: '抛光段',
      ),
    ];
  }

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
    final created = _buildItemStatic(
      99,
      quantity: quantity,
      pipelineProcessCodes: processCodes,
    );
    _items.insert(0, created);
    return created;
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
    updateOrderCallCount += 1;
    final index = _items.indexWhere((item) => item.id == orderId);
    final updated = _buildItemStatic(
      orderId,
      quantity: quantity,
      pipelineProcessCodes: processCodes,
    );
    if (index >= 0) {
      _items[index] = updated;
    }
    return updated;
  }

  @override
  Future<void> deleteOrder({required int orderId}) async {
    deleteOrderCallCount += 1;
    _items.removeWhere((item) => item.id == orderId);
  }

  @override
  Future<ProductionActionResult> completeOrder({
    required int orderId,
    required String password,
  }) async {
    completeOrderCallCount += 1;
    lastCompletedPassword = password;
    return ProductionActionResult(
      orderId: orderId,
      status: 'completed',
      message: 'ok',
    );
  }

  @override
  Future<ProductionOrderDetail> getOrderDetail({required int orderId}) async {
    return ProductionOrderDetail.fromJson({
      'order': {
        'id': orderId,
        'order_code': 'PO-$orderId',
        'product_id': 1,
        'product_name': '产品$orderId',
        'supplier_id': 3,
        'supplier_name': '供应商A',
        'quantity': 10,
        'status': orderId == 2 ? 'in_progress' : 'pending',
        'current_process_code': '01-01',
        'current_process_name': '切割',
        'created_at': '2026-03-01T00:00:00Z',
        'updated_at': '2026-03-01T12:00:00Z',
      },
      'processes': [
        {
          'id': 11,
          'stage_id': 1,
          'stage_code': '01',
          'stage_name': '切割段',
          'process_code': '01-01',
          'process_name': '切割',
          'process_order': 1,
          'status': 'pending',
          'visible_quantity': 0,
          'completed_quantity': 0,
          'created_at': '2026-03-01T00:00:00Z',
          'updated_at': '2026-03-01T12:00:00Z',
        },
        {
          'id': 12,
          'stage_id': 2,
          'stage_code': '02',
          'stage_name': '抛光段',
          'process_code': '02-01',
          'process_name': '抛光',
          'process_order': 2,
          'status': 'pending',
          'visible_quantity': 0,
          'completed_quantity': 0,
          'created_at': '2026-03-01T00:00:00Z',
          'updated_at': '2026-03-01T12:00:00Z',
        },
      ],
      'sub_orders': const [],
      'records': const [],
      'events': const [],
    });
  }

  @override
  Future<OrderPipelineModeItem> getOrderPipelineMode({
    required int orderId,
  }) async {
    return OrderPipelineModeItem.fromJson({
      'order_id': orderId,
      'enabled': false,
      'process_codes': const <String>[],
      'available_process_codes': const <String>['01-01', '02-01'],
    });
  }

  @override
  Future<OrderPipelineModeItem> updateOrderPipelineMode({
    required int orderId,
    required bool enabled,
    required List<String> processCodes,
  }) async {
    pipelineUpdateCallCount += 1;
    lastPipelineEnabled = enabled;
    lastPipelineProcessCodes = processCodes;
    return OrderPipelineModeItem.fromJson({
      'order_id': orderId,
      'enabled': enabled,
      'process_codes': processCodes,
      'available_process_codes': const <String>['01-01', '02-01'],
    });
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

class _FakeQualitySupplierService extends QualitySupplierService {
  _FakeQualitySupplierService()
    : super(AppSession(baseUrl: '', accessToken: ''));

  @override
  Future<QualitySupplierListResult> listSuppliers({
    String? keyword,
    bool? enabled,
  }) async {
    return QualitySupplierListResult(
      total: 1,
      items: [
        QualitySupplierItem(
          id: 3,
          name: '供应商A',
          remark: null,
          isEnabled: true,
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('生产订单管理页按分页参数加载并支持上下页与搜索回到第一页', (tester) async {
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
            supplierService: _FakeQualitySupplierService(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('productionOrderManagementListCard')),
      findsOneWidget,
    );
    expect(service.requestedPages, [1]);
    expect(service.requestedPageSizes, [200]);
    expect(find.text('总数：401'), findsWidgets);
    expect(find.text('第 1 / 3 页'), findsOneWidget);
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

    await tester.tap(find.widgetWithText(OutlinedButton, '下一页'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(service.requestedPages, [1, 2]);
    expect(find.text('第 2 / 3 页'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '上一页'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(service.requestedPages, [1, 2, 1]);
    expect(find.text('第 1 / 3 页'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '搜索订单号/产品'), '产品A');
    await tester.tap(find.widgetWithText(FilledButton, '查询'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(service.requestedPages, [1, 2, 1, 1]);
    expect(service.lastListKeyword, '产品A');
    expect(service.lastListProductName, isNull);
    expect(service.lastListStartDateFrom, isNull);
    expect(service.lastListStartDateTo, isNull);
    expect(service.lastListDueDateFrom, isNull);
    expect(service.lastListDueDateTo, isNull);
    expect(find.text('第 1 / 1 页'), findsOneWidget);
  });

  testWidgets('生产订单管理页支持创建和编辑订单主链路', (tester) async {
    final service = _FakeProductionOrderManagementService();
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
            supplierService: _FakeQualitySupplierService(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '订单号'),
      'PO-NEW-001',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '数量'), '18');
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();

    expect(service.createOrderCallCount, 1);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑订单').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(service.updateOrderCallCount, 1);
  });

  testWidgets('生产订单管理页支持删除完工与并行模式设置', (tester) async {
    final service = _FakeProductionOrderManagementService();
    await tester.binding.setSurfaceSize(const Size(1600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
            supplierService: _FakeQualitySupplierService(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除订单').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(service.deleteOrderCallCount, 1);
    expect(find.text('订单已删除。'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('手工完工').last);
    await tester.pumpAndSettle();
    final completeDialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(completeDialogFields.first, 'Pass123');
    await tester.tap(find.widgetWithText(FilledButton, '结束'));
    await tester.pumpAndSettle();

    expect(service.completeOrderCallCount, 1);
    expect(service.lastCompletedPassword, 'Pass123');

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('并行模式设置').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, '切割 (01-01)'));
    await tester.pump();
    await tester.tap(find.widgetWithText(CheckboxListTile, '抛光 (02-01)'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(service.pipelineUpdateCallCount, 1);
    expect(service.lastPipelineEnabled, isTrue);
    expect(service.lastPipelineProcessCodes, ['01-01', '02-01']);
  });

  testWidgets('删除订单弹窗展示统一骨架', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionDeleteOrderDialog(
            order: _FakeProductionOrderManagementService._buildItemStatic(1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('production-delete-order-dialog')),
      findsOneWidget,
    );
    expect(find.text('删除订单'), findsOneWidget);
    expect(find.textContaining('PO-1'), findsOneWidget);
    expect(find.text('确认删除'), findsOneWidget);
  });

  testWidgets('手工完工弹窗展示统一骨架', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionCompleteOrderDialog(
            order: _FakeProductionOrderManagementService._buildItemStatic(
              2,
              status: 'in_progress',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('production-complete-order-dialog')),
      findsOneWidget,
    );
    expect(find.text('结束订单'), findsOneWidget);
    expect(find.text('完工确认'), findsOneWidget);
    expect(find.text('当前登录密码'), findsOneWidget);
  });

  testWidgets('并行模式设置弹窗展示统一骨架', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionPipelineModeDialog(
            order: _FakeProductionOrderManagementService._buildItemStatic(2),
            processOptions: const [
              ProductionPipelineModeProcessOption(
                code: '01-01',
                name: '切割',
                processOrder: 1,
                enabled: true,
              ),
              ProductionPipelineModeProcessOption(
                code: '02-01',
                name: '抛光',
                processOrder: 2,
                enabled: true,
              ),
            ],
            initialSelectedCodes: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('production-pipeline-mode-dialog')),
      findsOneWidget,
    );
    expect(find.textContaining('并行模式设置'), findsOneWidget);
    expect(find.text('请选择参与并行的工序（至少 2 道）。'), findsOneWidget);
    expect(find.text('切割 (01-01)'), findsOneWidget);
    expect(find.text('抛光 (02-01)'), findsOneWidget);
  });
}
