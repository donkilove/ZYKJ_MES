import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/production_models.dart';
import 'package:mes_client/pages/production_repair_orders_page.dart';
import 'package:mes_client/pages/production_scrap_statistics_page.dart';
import 'package:mes_client/services/production_service.dart';

class _FakeRepairAndScrapService extends ProductionService {
  _FakeRepairAndScrapService()
    : super(AppSession(baseUrl: '', accessToken: ''));

  @override
  Future<ScrapStatisticsListResult> getScrapStatistics({
    required int page,
    required int pageSize,
    String? keyword,
    String progress = 'all',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
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
}

void main() {
  testWidgets('production scrap statistics page renders list content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionScrapStatisticsPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canExport: true,
            service: _FakeRepairAndScrapService(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('报废统计'), findsOneWidget);
    expect(find.text('PO-1'), findsOneWidget);
    expect(find.text('刀具磨损'), findsOneWidget);
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
}
