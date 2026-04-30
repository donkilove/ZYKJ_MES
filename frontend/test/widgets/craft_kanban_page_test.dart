import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/craft/presentation/craft_kanban_page.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/production/services/production_service.dart';

class _FakeCraftService extends CraftService {
  _FakeCraftService() : super(AppSession(baseUrl: '', accessToken: ''));

  int? lastExportLimit;
  int? lastMetricsProductId;
  int? lastMetricsStageId;
  int? lastMetricsProcessId;
  Object? metricsError;
  CraftKanbanProcessMetricsResult metricsResult =
      CraftKanbanProcessMetricsResult(
        productId: 1,
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
    lastMetricsProductId = productId;
    lastMetricsStageId = stageId;
    lastMetricsProcessId = processId;
    if (metricsError != null) {
      throw metricsError!;
    }
    return metricsResult;
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
  _FakeProductionService({List<ProductionProductOption>? products})
    : products = products ?? [ProductionProductOption(id: 1, name: '产品A')],
      super(AppSession(baseUrl: '', accessToken: ''));

  final List<ProductionProductOption> products;

  @override
  Future<List<ProductionProductOption>> listProductOptions() async {
    return products;
  }
}

void main() {
  Future<void> pumpCraftKanbanPage(
    WidgetTester tester, {
    required CraftService craftService,
    required ProductionService productionService,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CraftKanbanPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            craftService: craftService,
            productionService: productionService,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('工艺看板展示筛选项与趋势结果', (tester) async {
    final craftService = _FakeCraftService();
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpCraftKanbanPage(
      tester,
      craftService: craftService,
      productionService: _FakeProductionService(),
    );

    expect(find.text('工段筛选'), findsOneWidget);
    expect(find.text('工序趋势对比（平均工时/产能）'), findsOneWidget);
    expect(find.textContaining('CUT 切割段  /  CUT-01 激光切割'), findsOneWidget);
    expect(find.textContaining('样本 1'), findsOneWidget);

    await tester.tap(find.text('导出数据'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(craftService.lastExportLimit, 100);
    expect(
      find.byKey(const ValueKey('craft-kanban-export-preview-dialog')),
      findsOneWidget,
    );
    expect(find.text('暂无可导出数据'), findsOneWidget);
  });

  testWidgets('工艺看板顶部筛选区在窄桌面宽度下不溢出', (tester) async {
    tester.view.physicalSize = const Size(980, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpCraftKanbanPage(
      tester,
      craftService: _FakeCraftService(),
      productionService: _FakeProductionService(),
    );

    expect(find.text('选择产品'), findsOneWidget);
    expect(find.text('主筛选'), findsOneWidget);
    expect(find.text('日期范围'), findsOneWidget);
    expect(find.text('工段筛选'), findsOneWidget);
    expect(find.text('导出数据'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('工艺看板日期范围在选择日期后显示清除日期', (tester) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpCraftKanbanPage(
      tester,
      craftService: _FakeCraftService(),
      productionService: _FakeProductionService(),
    );

    expect(find.text('开始日期'), findsOneWidget);
    expect(find.text('结束日期'), findsOneWidget);
    expect(find.text('清除日期'), findsNothing);

    await tester.tap(find.text('开始日期'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('15').last);
    await tester.pumpAndSettle();
    final confirmButton = find.byWidgetPredicate(
      (widget) =>
          widget is TextButton &&
          widget.child is Text &&
          (((widget.child as Text).data ?? '') == '确定' ||
              ((widget.child as Text).data ?? '') == 'OK'),
    );
    await tester.tap(confirmButton.first);
    await tester.pumpAndSettle();

    expect(find.text('清除日期'), findsOneWidget);
    expect(find.text('开始日期'), findsNothing);
    expect(find.text('结束日期'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('工艺看板查询失败时展示错误态', (tester) async {
    final craftService = _FakeCraftService()
      ..metricsError = ApiException('统计接口异常', 500);

    await pumpCraftKanbanPage(
      tester,
      craftService: craftService,
      productionService: _FakeProductionService(),
    );

    expect(find.text('加载看板失败：统计接口异常'), findsOneWidget);
    expect(find.text('暂无可统计数据'), findsOneWidget);
  });

  testWidgets('工艺看板无产品时展示空态并隐藏筛选区', (tester) async {
    await pumpCraftKanbanPage(
      tester,
      craftService: _FakeCraftService(),
      productionService: _FakeProductionService(products: const []),
    );

    expect(find.text('暂无产品数据'), findsOneWidget);
    expect(find.text('主筛选'), findsNothing);
  });
}
