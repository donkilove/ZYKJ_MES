import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_metric_card.dart';
import 'package:mes_client/core/ui/patterns/mes_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/features/production/models/defect_catalog.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/production/presentation/production_repair_order_detail_page.dart';
import 'package:mes_client/features/production/presentation/production_repair_orders_page.dart';
import 'package:mes_client/features/production/presentation/production_scrap_statistics_detail_page.dart';
import 'package:mes_client/features/production/presentation/production_scrap_statistics_page.dart';
import 'package:mes_client/features/production/presentation/widgets/production_repair_complete_dialog.dart';
import 'package:mes_client/features/production/presentation/widgets/production_repair_phenomena_summary_dialog.dart';
import 'package:mes_client/features/production/presentation/widgets/production_repair_return_to_production_dialog.dart';
import 'package:mes_client/features/production/services/production_service.dart';

class _FakeRepairAndScrapService extends ProductionService {
  _FakeRepairAndScrapService()
    : super(AppSession(baseUrl: '', accessToken: ''));

  String? lastScrapKeyword;
  String? lastScrapProductName;
  String? lastScrapProcessCode;
  String lastScrapProgress = 'all';
  int? lastScrapPage;
  String? lastRepairKeyword;
  String lastRepairStatus = 'all';
  int? lastRepairPage;
  int returnToProductionCallCount = 0;
  int? lastReturnedRepairOrderId;
  String? lastReturnPassword;
  bool returnedToProduction = false;

  @override
  Future<ScrapStatisticsListResult> getScrapStatistics({
    required int page,
    required int pageSize,
    String? keyword,
    String? productName,
    String? processCode,
    String progress = 'all',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    lastScrapPage = page;
    lastScrapKeyword = keyword;
    lastScrapProductName = productName;
    lastScrapProcessCode = processCode;
    lastScrapProgress = progress;
    return ScrapStatisticsListResult(
      total: 61,
      items: [
        ScrapStatisticsItem.fromJson({
          'id': page,
          'order_id': 1,
          'order_code': 'PO-$page',
          'product_id': 1,
          'product_name': '产品A',
          'process_id': 11,
          'process_code': '01-01',
          'process_name': '切割',
          'scrap_reason': '刀具磨损',
          'scrap_quantity': 1,
          'last_scrap_time': '2026-03-01T00:00:00Z',
          'progress': 'pending_apply',
          'applied_at': null,
          'created_at': '2026-03-01T00:00:00Z',
          'updated_at': '2026-03-01T00:00:00Z',
        }),
      ],
    );
  }

  @override
  Future<RepairOrderListResult> getRepairOrders({
    required int page,
    required int pageSize,
    String? keyword,
    String status = 'all',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    lastRepairPage = page;
    lastRepairKeyword = keyword;
    lastRepairStatus = status;
    return RepairOrderListResult(
      total: 61,
      items: [
        RepairOrderItem.fromJson({
          'id': page,
          'repair_order_code': 'RW-$page',
          'source_order_id': 1,
          'source_order_code': 'PO-1',
          'product_id': 1,
          'product_name': '产品A',
          'source_order_process_id': 11,
          'source_process_code': '01-01',
          'source_process_name': '切割',
          'sender_user_id': 8,
          'sender_username': 'worker',
          'production_quantity': 6,
          'repair_quantity': 1,
          'repaired_quantity': 0,
          'scrap_quantity': 0,
          'scrap_replenished': false,
          'repair_time': '2026-03-01T00:00:00Z',
          'status': returnedToProduction
              ? 'returned_to_production'
              : 'in_repair',
          'completed_at': returnedToProduction ? '2026-03-01T01:00:00Z' : null,
          'repair_operator_user_id': null,
          'repair_operator_username': returnedToProduction ? 'admin' : null,
          'created_at': '2026-03-01T00:00:00Z',
          'updated_at': '2026-03-01T00:00:00Z',
        }),
      ],
    );
  }

  @override
  Future<RepairOrderDetailItem> getRepairOrderDetail({
    required int repairOrderId,
  }) async {
    return RepairOrderDetailItem.fromJson({
      'id': repairOrderId,
      'repair_order_code': 'RW-$repairOrderId',
      'source_order_id': 1,
      'source_order_code': 'PO-1',
      'product_id': 1,
      'product_name': '产品A',
      'source_order_process_id': 11,
      'source_process_code': '01-01',
      'source_process_name': '切割',
      'sender_user_id': 8,
      'sender_username': 'worker',
      'production_quantity': 6,
      'repair_quantity': 2,
      'repaired_quantity': 1,
      'scrap_quantity': 1,
      'scrap_replenished': false,
      'repair_time': '2026-03-01T00:00:00Z',
      'status': 'in_repair',
      'completed_at': null,
      'repair_operator_user_id': 18,
      'repair_operator_username': 'fixer',
      'defect_rows': [
        {
          'id': 1,
          'phenomenon': '毛刺',
          'quantity': 2,
          'production_record_id': 91,
          'production_sub_order_id': 12,
          'production_record_type': 'production',
          'production_record_quantity': 6,
          'production_record_created_at': '2026-03-01T00:30:00Z',
        },
      ],
      'cause_rows': [
        {
          'id': 2,
          'phenomenon': '毛刺',
          'reason': '刀具偏移',
          'quantity': 1,
          'is_scrap': true,
        },
      ],
      'return_routes': [
        {
          'id': 5,
          'target_process_id': 12,
          'target_process_code': '02-01',
          'target_process_name': '复检',
          'return_quantity': 1,
        },
      ],
      'event_logs': [
        {
          'id': 3,
          'order_code': 'PO-1',
          'order_status': 'in_progress',
          'product_name': '产品A',
          'process_code': '01-01',
          'event_type': 'repair_created',
          'event_title': '维修单已创建',
          'event_detail': '维修处理中',
          'payload_json': '{"repair_order_id":1}',
          'created_at': '2026-03-01T01:00:00Z',
        },
      ],
    });
  }

  @override
  Future<ScrapStatisticsItem> getScrapStatisticsDetail({
    required int scrapId,
  }) async {
    return ScrapStatisticsItem.fromJson({
      'id': scrapId,
      'order_id': 1,
      'order_code': 'PO-1',
      'product_id': 1,
      'product_name': '产品A',
      'process_id': 11,
      'process_code': '01-01',
      'process_name': '切割',
      'scrap_reason': '刀具磨损',
      'scrap_quantity': 1,
      'last_scrap_time': '2026-03-01T02:00:00Z',
      'progress': 'pending_apply',
      'applied_at': null,
      'created_at': '2026-03-01T00:00:00Z',
      'updated_at': '2026-03-01T02:00:00Z',
      'related_repair_orders': [
        {
          'id': 1,
          'repair_order_code': 'RW-1',
          'status': 'in_repair',
          'repair_quantity': 1,
          'repaired_quantity': 0,
          'scrap_quantity': 1,
          'repair_time': '2026-03-01T00:00:00Z',
          'completed_at': null,
        },
      ],
      'related_event_logs': [
        {
          'id': 4,
          'order_code': 'PO-1',
          'order_status': 'in_progress',
          'product_name': '产品A',
          'process_code': '01-01',
          'event_type': 'scrap_created',
          'event_title': '报废已登记',
          'event_detail': '待处理',
          'payload_json': '{"scrap_id":1}',
          'created_at': '2026-03-01T02:30:00Z',
        },
      ],
    });
  }

  @override
  Future<RepairOrderItem> returnRepairOrderToProduction({
    required int repairOrderId,
    required String password,
  }) async {
    returnToProductionCallCount += 1;
    lastReturnedRepairOrderId = repairOrderId;
    lastReturnPassword = password;
    returnedToProduction = true;
    return (await getRepairOrders(page: 1, pageSize: 1)).items.first;
  }
}

void main() {
  void setDesktopViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
  }

  testWidgets('production scrap statistics page renders list content', (
    tester,
  ) async {
    setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeRepairAndScrapService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionScrapStatisticsPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canExport: true,
            service: service,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(const ValueKey('productionScrapStatisticsListCard')),
      findsOneWidget,
    );
    expect(find.byType(MesRefreshPageHeader), findsOneWidget);
    expect(find.text('PO-1'), findsOneWidget);
    expect(find.text('刀具磨损'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('production-scrap-keyword-field')),
      findsOneWidget,
    );
    expect(find.text('搜索订单编号/报废原因/产品型号'), findsOneWidget);
    expect(find.text('产品名称（精确）'), findsNothing);
    expect(find.text('工序编码（精确）'), findsNothing);
    expect(
      find.byKey(const ValueKey('production-scrap-statistics-operation-menu')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('production-scrap-keyword-field')),
      'PO-1',
    );
    await tester.tap(find.text('查询'));
    await tester.pump();

    expect(service.lastScrapKeyword, 'PO-1');
    expect(service.lastScrapProductName, isNull);
    expect(service.lastScrapProcessCode, isNull);
  });

  testWidgets('production scrap statistics page uses workbench skeleton', (
    tester,
  ) async {
    setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeRepairAndScrapService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionScrapStatisticsPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canExport: true,
            service: service,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(MesFilterBar), findsNothing);
    expect(find.byType(MesMetricCard), findsAtLeastNWidgets(4));
    expect(
      find.byKey(const ValueKey('production-scrap-keyword-field')),
      findsOneWidget,
    );
    expect(find.text('质量总览'), findsOneWidget);
    expect(find.text('报废记录'), findsOneWidget);
    expect(find.byType(MesSectionCard), findsAtLeastNWidgets(2));
  });

  testWidgets('production scrap statistics pagination updates request page', (
    tester,
  ) async {
    setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeRepairAndScrapService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionScrapStatisticsPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canExport: true,
            service: service,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('第 1 / 3 页'), findsOneWidget);
    expect(service.lastScrapPage, 1);

    await tester.tap(find.widgetWithText(OutlinedButton, '下一页'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('第 2 / 3 页'), findsOneWidget);
    expect(service.lastScrapPage, 2);
    expect(find.text('PO-2'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('production-scrap-keyword-field')),
      'PO-RESET',
    );
    await tester.tap(find.text('查询'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(service.lastScrapKeyword, 'PO-RESET');
    expect(service.lastScrapPage, 1);
    expect(find.text('第 1 / 3 页'), findsOneWidget);
  });

  testWidgets('production repair orders page renders list content', (
    tester,
  ) async {
    setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeRepairAndScrapService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionRepairOrdersPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canComplete: true,
            canReturnToProduction: true,
            canExport: true,
            service: service,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(const ValueKey('productionRepairOrdersListCard')),
      findsOneWidget,
    );
    expect(find.byType(MesRefreshPageHeader), findsOneWidget);
    expect(find.text('RW-1'), findsOneWidget);
    expect(find.text('切割'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('production-repair-keyword-field')),
      findsOneWidget,
    );
    expect(find.text('搜索维修单/订单/产品'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('production-repair-orders-operation-menu')),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, '下一页'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(service.lastRepairPage, 2);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已完成').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('查询'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(service.lastRepairStatus, 'completed');
    expect(service.lastRepairPage, 1);
    expect(find.text('第 1 / 3 页'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已退回生产').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('查询'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(service.lastRepairStatus, 'returned_to_production');
  });

  testWidgets('production repair orders page can return order to production', (
    tester,
  ) async {
    setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeRepairAndScrapService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionRepairOrdersPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canComplete: true,
            canReturnToProduction: true,
            canExport: false,
            service: service,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('操作').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('退回生产').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey('production-repair-return-to-production-dialog'),
      ),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).last, 'Pass123');
    await tester.tap(find.widgetWithText(FilledButton, '退回生产').last);
    await tester.pumpAndSettle();

    expect(service.returnToProductionCallCount, 1);
    expect(service.lastReturnedRepairOrderId, 1);
    expect(service.lastReturnPassword, 'Pass123');
    expect(find.text('已退回生产'), findsWidgets);
  });

  testWidgets('production repair orders page uses task workbench skeleton', (
    tester,
  ) async {
    setDesktopViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeRepairAndScrapService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionRepairOrdersPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canComplete: true,
            canReturnToProduction: true,
            canExport: true,
            service: service,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(MesFilterBar), findsNothing);
    expect(find.byType(MesMetricCard), findsAtLeastNWidgets(4));
    expect(
      find.byKey(const ValueKey('production-repair-keyword-field')),
      findsOneWidget,
    );
    expect(find.text('任务总览'), findsOneWidget);
    expect(find.text('维修工单'), findsOneWidget);
    expect(find.byType(MesSectionCard), findsAtLeastNWidgets(2));
  });

  testWidgets(
    'production repair order detail page renders defect and return routes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProductionRepairOrderDetailPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            repairOrderId: 1,
            service: _FakeRepairAndScrapService(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('维修详情 - RW-1'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('production-repair-order-detail-page-header'),
        ),
        findsOneWidget,
      );
      expect(find.byType(MesPageHeader), findsOneWidget);
      expect(find.textContaining('毛刺'), findsWidgets);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.textContaining('刀具偏移'), findsOneWidget);
      expect(find.textContaining('关联报工记录#91'), findsOneWidget);
    },
  );

  testWidgets('production scrap detail page can open related repair detail', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProductionScrapStatisticsDetailPage(
          session: AppSession(baseUrl: '', accessToken: ''),
          onLogout: () {},
          scrapId: 1,
          service: _FakeRepairAndScrapService(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('报废详情 - PO-1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('production-scrap-detail-page-header')),
      findsOneWidget,
    );
    expect(find.byType(MesPageHeader), findsOneWidget);
    expect(find.text('刀具磨损'), findsOneWidget);
    expect(find.text('关联维修工单'), findsOneWidget);
    expect(find.text('RW-1'), findsOneWidget);

    await tester.tap(find.text('RW-1'));
    await tester.pumpAndSettle();

    expect(find.text('维修详情 - RW-1'), findsOneWidget);
  });

  testWidgets('维修现象汇总弹窗展示统一骨架', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionRepairPhenomenaSummaryDialog(
            repairOrderCode: 'RW-1',
            items: [
              RepairOrderPhenomenonSummaryItem(phenomenon: '毛刺', quantity: 2),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('production-repair-phenomena-summary-dialog')),
      findsOneWidget,
    );
    expect(find.textContaining('现象汇总'), findsOneWidget);
    expect(find.text('毛刺'), findsOneWidget);
  });

  testWidgets('维修完成弹窗展示统一骨架', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionRepairCompleteDialog(
            repairOrder: RepairOrderItem.fromJson({
              'id': 1,
              'repair_order_code': 'RW-1',
              'source_order_id': 1,
              'source_order_code': 'PO-1',
              'product_id': 1,
              'product_name': '产品A',
              'source_order_process_id': 11,
              'source_process_code': '01-01',
              'source_process_name': '切割',
              'sender_user_id': 8,
              'sender_username': 'worker',
              'production_quantity': 6,
              'repair_quantity': 2,
              'repaired_quantity': 0,
              'scrap_quantity': 0,
              'scrap_replenished': false,
              'repair_time': '2026-03-01T00:00:00Z',
              'status': 'in_repair',
              'completed_at': null,
              'repair_operator_user_id': null,
              'repair_operator_username': null,
              'created_at': '2026-03-01T00:00:00Z',
              'updated_at': '2026-03-01T00:00:00Z',
            }),
            phenomena: [
              RepairOrderPhenomenonSummaryItem(phenomenon: '毛刺', quantity: 2),
            ],
            processOptions: const [
              ProductionRepairReturnProcessOption(
                id: 11,
                code: '01-01',
                name: '切割',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('production-repair-complete-dialog')),
      findsOneWidget,
    );
    expect(find.textContaining('完成维修'), findsOneWidget);
    expect(find.text('不良原因明细'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '新增原因项'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('production-repair-cause-phenomenon-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('production-repair-cause-category-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        ValueKey(
          'production-repair-cause-reason-0-${productionDefectReasonCategories().first}',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('一级原因'), findsOneWidget);
    expect(find.text('二级原因'), findsOneWidget);
    expect(find.text('回流分配（合计需等于送修数量-未补充报废数量）'), findsOneWidget);
    expect(find.text('报废已补充'), findsOneWidget);

    final scrapReplenishedFinder = find.byKey(
      const ValueKey('production-repair-scrap-replenished'),
    );
    var scrapReplenished = tester.widget<Checkbox>(scrapReplenishedFinder);
    expect(scrapReplenished.value, isFalse);
    expect(scrapReplenished.onChanged, isNull);

    await tester.tap(
      find.byKey(const ValueKey('production-repair-cause-scrap-0')),
    );
    await tester.pumpAndSettle();

    scrapReplenished = tester.widget<Checkbox>(scrapReplenishedFinder);
    expect(scrapReplenished.onChanged, isNotNull);

    await tester.tap(scrapReplenishedFinder);
    await tester.pumpAndSettle();
    scrapReplenished = tester.widget<Checkbox>(scrapReplenishedFinder);
    expect(scrapReplenished.value, isTrue);

    await tester.tap(
      find.byKey(const ValueKey('production-repair-cause-scrap-0')),
    );
    await tester.pumpAndSettle();
    scrapReplenished = tester.widget<Checkbox>(scrapReplenishedFinder);
    expect(scrapReplenished.value, isFalse);
    expect(scrapReplenished.onChanged, isNull);

    await tester.tap(find.widgetWithText(OutlinedButton, '新增原因项'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('production-repair-cause-phenomenon-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('production-repair-cause-category-1')),
      findsOneWidget,
    );
    expect(find.text('毛刺'), findsNWidgets(2));
  });

  testWidgets('维修完成弹窗按报废已补充校验回流总量', (tester) async {
    ProductionRepairCompleteDialogResult? dialogResult;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                showDialog<ProductionRepairCompleteDialogResult?>(
                  context: context,
                  builder: (_) => ProductionRepairCompleteDialog(
                    repairOrder: RepairOrderItem.fromJson({
                      'id': 1,
                      'repair_order_code': 'RW-1',
                      'source_order_id': 1,
                      'source_order_code': 'PO-1',
                      'product_id': 1,
                      'product_name': '产品A',
                      'source_order_process_id': 11,
                      'source_process_code': '01-01',
                      'source_process_name': '切割',
                      'sender_user_id': 8,
                      'sender_username': 'worker',
                      'production_quantity': 6,
                      'repair_quantity': 2,
                      'repaired_quantity': 0,
                      'scrap_quantity': 0,
                      'scrap_replenished': false,
                      'repair_time': '2026-03-01T00:00:00Z',
                      'status': 'in_repair',
                      'completed_at': null,
                      'repair_operator_user_id': null,
                      'repair_operator_username': null,
                      'created_at': '2026-03-01T00:00:00Z',
                      'updated_at': '2026-03-01T00:00:00Z',
                    }),
                    phenomena: [
                      RepairOrderPhenomenonSummaryItem(
                        phenomenon: '毛刺',
                        quantity: 2,
                      ),
                    ],
                    processOptions: const [
                      ProductionRepairReturnProcessOption(
                        id: 11,
                        code: '01-01',
                        name: '切割',
                      ),
                    ],
                  ),
                ).then((value) => dialogResult = value);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('production-repair-cause-quantity-0')),
      '1',
    );
    await tester.tap(find.widgetWithText(OutlinedButton, '新增原因项'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('production-repair-cause-quantity-1')),
      '1',
    );
    await tester.tap(
      find.byKey(const ValueKey('production-repair-cause-scrap-1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '提交完成'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('回流数量合计必须等于送修数量 2 - 未补充报废数量 1 = 1'),
      findsOneWidget,
    );
    expect(dialogResult, isNull);

    await tester.tap(
      find.byKey(const ValueKey('production-repair-scrap-replenished')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '提交完成'));
    await tester.pumpAndSettle();

    expect(dialogResult, isNotNull);
    expect(dialogResult!.scrapReplenished, isTrue);
    expect(dialogResult!.returnAllocations.single.quantity, 2);
  });

  testWidgets('退回生产弹窗展示密码确认和影响说明', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionRepairReturnToProductionDialog(
            repairOrder: RepairOrderItem.fromJson({
              'id': 1,
              'repair_order_code': 'RW-1',
              'source_order_id': 1,
              'source_order_code': 'PO-1',
              'product_id': 1,
              'product_name': '产品A',
              'source_order_process_id': 11,
              'source_process_code': '01-01',
              'source_process_name': '切割',
              'sender_user_id': 8,
              'sender_username': 'worker',
              'production_quantity': 6,
              'repair_quantity': 2,
              'repaired_quantity': 0,
              'scrap_quantity': 0,
              'scrap_replenished': false,
              'repair_time': '2026-03-01T00:00:00Z',
              'status': 'in_repair',
              'completed_at': null,
              'repair_operator_user_id': null,
              'repair_operator_username': null,
              'created_at': '2026-03-01T00:00:00Z',
              'updated_at': '2026-03-01T00:00:00Z',
            }),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey('production-repair-return-to-production-dialog'),
      ),
      findsOneWidget,
    );
    expect(find.text('退回生产'), findsWidgets);
    expect(find.text('当前登录密码'), findsOneWidget);
    expect(find.textContaining('不进入质量统计'), findsOneWidget);
  });
}
