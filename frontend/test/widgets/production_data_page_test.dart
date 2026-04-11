import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/production/presentation/production_data_page.dart';
import 'package:mes_client/features/production/services/production_service.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/widgets/crud_page_header.dart';

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
  Future<List<ProductionProcessStatItem>> getProcessStats() async {
    return [
      ProductionProcessStatItem(
        processCode: '01-01',
        processName: '切割',
        totalOrders: 5,
        pendingOrders: 2,
        inProgressOrders: 2,
        partialOrders: 0,
        completedOrders: 1,
        totalVisibleQuantity: 100,
        totalCompletedQuantity: 40,
      ),
    ];
  }

  @override
  Future<List<ProductionOperatorStatItem>> getOperatorStats() async {
    return [
      ProductionOperatorStatItem(
        operatorUserId: 8,
        operatorUsername: 'worker',
        processCode: '01-01',
        processName: '切割',
        productionRecords: 3,
        productionQuantity: 40,
        lastProductionAt: DateTime.utc(2026, 3, 1, 0, 0, 0),
      ),
    ];
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
}

void main() {
  Widget buildPage(ProductionDataSection section) {
    return MaterialApp(
      home: Scaffold(
        body: ProductionDataPage(
          session: AppSession(baseUrl: '', accessToken: ''),
          onLogout: () {},
          section: section,
          service: _FakeProductionService(),
        ),
      ),
    );
  }

  testWidgets('process stats page renders trimmed layout', (tester) async {
    tester.view.physicalSize = const Size(1920, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildPage(ProductionDataSection.processStats));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('工序统计'), findsOneWidget);
    expect(find.byType(CrudPageHeader), findsOneWidget);
    expect(find.text('待生产'), findsWidgets);
    expect(find.text('生产中'), findsWidgets);
    expect(find.text('生产完成'), findsWidgets);
    expect(find.text('完成总量'), findsWidgets);
    expect(find.text('订单总数'), findsNothing);
    expect(find.text('计划总量'), findsNothing);
    expect(find.text('手动筛选'), findsNothing);
    expect(find.text('未完工进度'), findsNothing);
    expect(find.byType(CrudListTableSection), findsOneWidget);
    expect(find.text('切割'), findsWidgets);
  });

  testWidgets('today realtime page renders standalone view', (tester) async {
    tester.view.physicalSize = const Size(1920, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildPage(ProductionDataSection.todayRealtime));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('今日实时产量'), findsOneWidget);
    expect(find.text('刷新今日实时'), findsOneWidget);
    expect(find.text('产品数：1  今日总量：10'), findsOneWidget);
    expect(find.text('产品A'), findsWidgets);
  });

  testWidgets('operator stats page renders standalone view', (tester) async {
    tester.view.physicalSize = const Size(1920, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildPage(ProductionDataSection.operatorStats));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('人员统计'), findsOneWidget);
    expect(find.byType(CrudListTableSection), findsOneWidget);
    expect(find.text('worker'), findsOneWidget);
    expect(find.text('40'), findsWidgets);
  });
}
