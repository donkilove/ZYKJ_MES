import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/production_models.dart';
import 'package:mes_client/pages/production_data_page.dart';
import 'package:mes_client/services/production_service.dart';

class _FakeProductionService extends ProductionService {
  _FakeProductionService() : super(AppSession(baseUrl: '', accessToken: ''));

  @override
  Future<ProductionStatsOverview> getOverviewStats() async {
    return ProductionStatsOverview(
      totalOrders: 5,
      pendingOrders: 2,
      inProgressOrders: 2,
      completedOrders: 1,
      totalQuantity: 100,
      finishedQuantity: 40,
    );
  }

  @override
  Future<ProductionTodayRealtimeResult> getTodayRealtimeData({
    String statMode = 'main_order',
    List<int>? productIds,
    List<int>? stageIds,
    List<int>? processIds,
    List<int>? operatorUserIds,
    String orderStatus = 'all',
  }) async {
    return ProductionTodayRealtimeResult.fromJson({
      'stat_mode': statMode,
      'summary': {'total_products': 1, 'total_quantity': 10},
      'table_rows': [
        {
          'product_id': 1,
          'product_name': '产品A',
          'quantity': 10,
          'latest_time': '2026-03-01T00:00:00Z',
          'latest_time_text': '2026-03-01 08:00:00',
        },
      ],
      'chart_data': [
        {'label': '产品A', 'value': 10},
      ],
      'query_signature': '{"view":"today_realtime"}',
    });
  }

  @override
  Future<ProductionUnfinishedProgressResult> getUnfinishedProgressData({
    List<int>? productIds,
    List<int>? stageIds,
    List<int>? processIds,
    List<int>? operatorUserIds,
    String orderStatus = 'all',
  }) async {
    return ProductionUnfinishedProgressResult.fromJson({
      'summary': {'total_orders': 1, 'avg_progress_percent': 50.0},
      'table_rows': [
        {
          'order_id': 1,
          'order_code': 'PO-1',
          'product_id': 1,
          'product_name': '产品A',
          'order_status': 'in_progress',
          'process_count': 2,
          'produced_total': 10,
          'target_total': 20,
          'progress_percent': 50.0,
        },
      ],
      'query_signature': '{"view":"unfinished_progress"}',
    });
  }

  @override
  Future<ProductionManualQueryResult> getManualProductionData({
    String statMode = 'main_order',
    DateTime? startDate,
    DateTime? endDate,
    List<int>? productIds,
    List<int>? stageIds,
    List<int>? processIds,
    List<int>? operatorUserIds,
    String orderStatus = 'all',
  }) async {
    return ProductionManualQueryResult.fromJson({
      'stat_mode': statMode,
      'summary': {
        'rows': 1,
        'filtered_total': 10,
        'time_range_total': 12,
        'ratio_percent': 83.3,
      },
      'table_rows': [
        {
          'order_id': 1,
          'order_code': 'PO-1',
          'product_id': 1,
          'product_name': '产品A',
          'stage_id': 1,
          'stage_code': '01',
          'stage_name': '切割段',
          'process_id': 2,
          'process_code': '01-01',
          'process_name': '切割',
          'operator_user_id': 8,
          'operator_username': 'worker',
          'quantity': 10,
          'production_time': '2026-03-01T00:00:00Z',
          'production_time_text': '2026-03-01 08:00:00',
          'order_status': 'in_progress',
        },
      ],
      'chart_data': {
        'single_day': true,
        'model_output': [
          {'product_name': '产品A', 'quantity': 10},
        ],
        'trend_output': [
          {'bucket': '08:00', 'quantity': 10},
        ],
        'pie_output': [
          {'name': '筛选结果', 'quantity': 10},
          {'name': '其余产量', 'quantity': 2},
        ],
      },
      'query_signature': '{"view":"manual"}',
    });
  }

  @override
  Future<List<ProductionProductOption>> listProductOptions() async {
    return [ProductionProductOption(id: 1, name: '产品A')];
  }

  @override
  Future<List<ProductionProcessOption>> listProcessOptions() async {
    return [
      ProductionProcessOption(
        id: 2,
        code: '01-01',
        name: '切割',
        stageId: 1,
        stageCode: '01',
        stageName: '切割段',
      ),
    ];
  }

  @override
  Future<AssistUserOptionListResult> listAssistUserOptions({
    required int page,
    required int pageSize,
    String? keyword,
    String? roleCode,
  }) async {
    return AssistUserOptionListResult(
      total: 1,
      items: [
        AssistUserOptionItem(
          id: 8,
          username: 'worker',
          fullName: 'Worker A',
          roleCodes: const ['operator'],
        ),
      ],
    );
  }
}

void main() {
  testWidgets('production data page renders three tabs and basic actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionDataPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            canExport: true,
            service: _FakeProductionService(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('生产数据查询'), findsOneWidget);
    expect(find.text('今日实时产量'), findsOneWidget);
    expect(find.text('未完工进度'), findsOneWidget);
    expect(find.text('手动筛选'), findsOneWidget);

    await tester.tap(find.text('未完工进度'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('刷新进度'), findsOneWidget);

    await tester.tap(find.text('手动筛选'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('筛选'), findsOneWidget);
    expect(find.text('导出CSV'), findsOneWidget);
  });
}
