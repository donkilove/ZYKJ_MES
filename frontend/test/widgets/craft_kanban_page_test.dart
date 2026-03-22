import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/craft_models.dart';
import 'package:mes_client/models/production_models.dart';
import 'package:mes_client/pages/craft_kanban_page.dart';
import 'package:mes_client/services/craft_service.dart';
import 'package:mes_client/services/production_service.dart';

class _FakeCraftService extends CraftService {
  _FakeCraftService() : super(AppSession(baseUrl: '', accessToken: ''));

  int? lastExportLimit;

  @override
  Future<CraftStageListResult> listStages({
    int page = 1,
    int pageSize = 200,
    String? keyword,
    bool? enabled,
  }) async {
    return CraftStageListResult(
      total: 1,
      items: [
        CraftStageItem(
          id: 1,
          code: 'CUT',
          name: '切割段',
          sortOrder: 1,
          isEnabled: true,
          processCount: 1,
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<CraftProcessListResult> listProcesses({
    int page = 1,
    int pageSize = 500,
    String? keyword,
    int? stageId,
    bool? enabled,
  }) async {
    return CraftProcessListResult(
      total: 1,
      items: [
        CraftProcessItem(
          id: 11,
          code: 'CUT-01',
          name: '激光切割',
          stageId: 1,
          stageCode: 'CUT',
          stageName: '切割段',
          isEnabled: true,
          createdAt: DateTime.parse('2026-03-01T00:00:00Z'),
          updatedAt: DateTime.parse('2026-03-01T00:00:00Z'),
        ),
      ],
    );
  }

  @override
  Future<CraftKanbanProcessMetricsResult> getCraftKanbanProcessMetrics({
    required int productId,
    int limit = 5,
    int? stageId,
    int? processId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return CraftKanbanProcessMetricsResult(
      productId: productId,
      productName: '产品A',
      items: [
        CraftKanbanProcessItem(
          stageId: 1,
          stageCode: 'CUT',
          stageName: '切割段',
          processId: 11,
          processCode: 'CUT-01',
          processName: '激光切割',
          samples: [
            CraftKanbanSampleItem(
              orderProcessId: 101,
              orderId: 1001,
              orderCode: 'MO-1001',
              startAt: DateTime.parse('2026-03-01T08:00:00Z'),
              endAt: DateTime.parse('2026-03-01T09:00:00Z'),
              workMinutes: 60,
              productionQty: 120,
              capacityPerHour: 120,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<String> exportCraftKanbanProcessMetrics({
    required int productId,
    int limit = 5,
    int? stageId,
    int? processId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    lastExportLimit = limit;
    return '';
  }
}

class _FakeProductionService extends ProductionService {
  _FakeProductionService() : super(AppSession(baseUrl: '', accessToken: ''));

  @override
  Future<List<ProductionProductOption>> listProductOptions() async {
    return [ProductionProductOption(id: 1, name: '产品A')];
  }
}

void main() {
  testWidgets('工艺看板展示筛选项与趋势结果', (tester) async {
    final craftService = _FakeCraftService();
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CraftKanbanPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            craftService: craftService,
            productionService: _FakeProductionService(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('工段筛选'), findsOneWidget);
    expect(find.text('工序趋势对比（平均工时/产能）'), findsOneWidget);
    expect(find.textContaining('CUT 切割段  /  CUT-01 激光切割'), findsOneWidget);
    expect(find.textContaining('样本 1'), findsOneWidget);

    await tester.tap(find.text('导出数据'));
    await tester.pump();

    expect(craftService.lastExportLimit, 100);
  });
}
