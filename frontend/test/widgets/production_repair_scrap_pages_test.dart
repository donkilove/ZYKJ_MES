import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/production_models.dart';
import 'package:mes_client/pages/production_repair_order_detail_page.dart';
import 'package:mes_client/pages/production_repair_orders_page.dart';
import 'package:mes_client/pages/production_scrap_statistics_detail_page.dart';
import 'package:mes_client/pages/production_scrap_statistics_page.dart';
import 'package:mes_client/services/production_service.dart';

class _FakeRepairAndScrapService extends ProductionService {
  _FakeRepairAndScrapService()
    : super(AppSession(baseUrl: '', accessToken: ''));

  String? lastScrapKeyword;
  String? lastScrapProductName;
  String? lastScrapProcessCode;
  String lastScrapProgress = 'all';

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
    lastScrapKeyword = keyword;
    lastScrapProductName = productName;
    lastScrapProcessCode = processCode;
    lastScrapProgress = progress;
    return ScrapStatisticsListResult(
      total: 1,
      items: [
        ScrapStatisticsItem.fromJson({
          'id': 1,
          'order_id': 1,
          'order_code': 'PO-1',
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
    return RepairOrderListResult(
      total: 1,
      items: [
        RepairOrderItem.fromJson({
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
          'repair_quantity': 1,
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
}

void main() {
  testWidgets('production scrap statistics page renders list content', (
    tester,
  ) async {
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

    expect(find.text('报废统计'), findsOneWidget);
    expect(find.text('PO-1'), findsOneWidget);
    expect(find.text('刀具磨损'), findsOneWidget);
    expect(find.text('产品名称（精确）'), findsOneWidget);
    expect(find.text('关键词（订单/原因/工序名称）'), findsOneWidget);
    expect(find.text('工序编码（精确）'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'PO-1');
    await tester.enterText(find.byType(TextField).at(1), '产品A');
    await tester.enterText(find.byType(TextField).at(2), '01-01');
    await tester.tap(find.text('查询'));
    await tester.pump();

    expect(service.lastScrapKeyword, 'PO-1');
    expect(service.lastScrapProductName, '产品A');
    expect(service.lastScrapProcessCode, '01-01');
  });

  testWidgets('production repair orders page renders list content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionRepairOrdersPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canComplete: true,
            canExport: true,
            service: _FakeRepairAndScrapService(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('维修订单'), findsOneWidget);
    expect(find.text('RW-1'), findsOneWidget);
    expect(find.text('切割'), findsOneWidget);
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
    expect(find.text('刀具磨损'), findsOneWidget);
    expect(find.text('关联维修工单'), findsOneWidget);
    expect(find.text('RW-1'), findsOneWidget);

    await tester.tap(find.text('RW-1'));
    await tester.pumpAndSettle();

    expect(find.text('维修详情 - RW-1'), findsOneWidget);
  });
}
