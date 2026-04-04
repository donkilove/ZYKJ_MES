import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/production_models.dart';
import 'package:mes_client/pages/production_pipeline_instances_page.dart';
import 'package:mes_client/services/production_service.dart';
import 'package:mes_client/widgets/crud_list_table_section.dart';
import 'package:mes_client/widgets/crud_page_header.dart';

class _FakeProductionPipelineInstancesService extends ProductionService {
  _FakeProductionPipelineInstancesService()
    : super(AppSession(baseUrl: '', accessToken: ''));

  String? receivedProcessKeyword;
  String? receivedPipelineSubOrderNo;
  int? receivedSubOrderId;
  final List<int> requestedPages = <int>[];

  @override
  Future<PipelineInstanceListResult> listPipelineInstances({
    int? orderId,
    String? orderCode,
    int? orderProcessId,
    int? subOrderId,
    String? processKeyword,
    String? pipelineSubOrderNo,
    bool? isActive,
    int page = 1,
    int pageSize = 200,
  }) async {
    requestedPages.add(page);
    receivedProcessKeyword = processKeyword;
    receivedPipelineSubOrderNo = pipelineSubOrderNo;
    receivedSubOrderId = subOrderId;
    return PipelineInstanceListResult(
      total: 1001,
      items: [
        PipelineInstanceItem(
          id: page * 10 + 1,
          pipelineLinkId: 'PL9-$page-ABCDE12345',
          subOrderId: page * 100 + 21,
          orderId: 9,
          orderCode: 'PO-TRACE-00$page',
          orderProcessId: 11,
          processCode: 'CUT-01',
          processName: '切割',
          pipelineSeq: 1,
          pipelineSubOrderNo: 'P9-${page}21-1-ABCD1234',
          isActive: true,
          invalidReason: null,
          invalidatedAt: null,
          createdAt: DateTime.utc(2026, 3, 1, 8),
          updatedAt: DateTime.utc(2026, 3, 1, 9),
        ),
        PipelineInstanceItem(
          id: page * 10 + 2,
          pipelineLinkId: 'PL9-$page-ABCDE12345',
          subOrderId: page * 100 + 22,
          orderId: 9,
          orderCode: 'PO-TRACE-00$page',
          orderProcessId: 12,
          processCode: 'WELD-01',
          processName: '焊接',
          pipelineSeq: 1,
          pipelineSubOrderNo: 'P9-${page}22-1-ABCD1234',
          isActive: true,
          invalidReason: null,
          invalidatedAt: null,
          createdAt: DateTime.utc(2026, 3, 1, 8, 10),
          updatedAt: DateTime.utc(2026, 3, 1, 9, 10),
        ),
      ],
    );
  }

  @override
  Future<ProductionOrderDetail> getOrderDetail({required int orderId}) async {
    return ProductionOrderDetail.fromJson({
      'order': {
        'id': orderId,
        'order_code': 'PO-TRACE-001',
        'product_id': 1,
        'product_name': '产品A',
        'quantity': 10,
        'status': 'pending',
        'current_process_code': 'CUT-01',
        'current_process_name': '切割',
        'start_date': '2026-03-01',
        'due_date': '2026-03-10',
        'remark': null,
        'process_template_id': null,
        'process_template_name': null,
        'process_template_version': null,
        'pipeline_enabled': true,
        'pipeline_process_codes': ['CUT-01'],
        'created_by_user_id': 1,
        'created_by_username': 'admin',
        'created_at': '2026-03-01T00:00:00Z',
        'updated_at': '2026-03-01T00:00:00Z',
      },
      'processes': const [],
      'sub_orders': const [],
      'records': const [],
      'events': const [],
    });
  }
}

void main() {
  testWidgets('并行实例页支持业务筛选并可进入只读订单详情', (tester) async {
    final service = _FakeProductionPipelineInstancesService();
    tester.view.physicalSize = const Size(2200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionPipelineInstancesPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            service: service,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.widgetWithText(TextField, '工序'), findsOneWidget);
    expect(find.widgetWithText(TextField, '子订单ID'), findsOneWidget);
    expect(find.widgetWithText(TextField, '实例编号'), findsOneWidget);
    expect(find.byType(CrudPageHeader), findsOneWidget);
    expect(find.byType(CrudListTableSection), findsOneWidget);
    expect(find.text('121'), findsWidgets);
    expect(find.text('切割 (CUT-01)'), findsNWidgets(2));
    expect(find.text('焊接 (WELD-01)'), findsNWidgets(2));
    expect(find.text('链路追踪视图'), findsOneWidget);
    expect(find.text('跨工序路径：切割 (CUT-01) -> 焊接 (WELD-01)'), findsOneWidget);
    expect(find.text('链路 PL9-1-ABCDE12345'), findsNWidgets(3));
    expect(find.text('查看订单'), findsNWidgets(4));
    expect(find.text('查看事件日志'), findsNWidgets(4));
    expect(find.text('第 1 / 3 页'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '子订单ID'), '21');
    await tester.enterText(find.widgetWithText(TextField, '工序'), '切割');
    await tester.enterText(find.widgetWithText(TextField, '实例编号'), 'ABCD1234');
    await tester.tap(find.byTooltip('查询'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(service.receivedSubOrderId, 21);
    expect(service.receivedProcessKeyword, '切割');
    expect(service.receivedPipelineSubOrderNo, 'ABCD1234');
    expect(service.requestedPages, [1, 1]);

    await tester.ensureVisible(find.text('查看事件日志').first);
    await tester.tap(find.text('查看事件日志').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('订单详情 - PO-TRACE-001'), findsOneWidget);

    Navigator.of(tester.element(find.text('订单详情 - PO-TRACE-001'))).pop();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('查看订单').first);
    await tester.tap(find.text('查看订单').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('订单详情 - PO-TRACE-001'), findsOneWidget);
    expect(find.text('编辑订单'), findsNothing);
    expect(find.text('删除订单'), findsNothing);
    expect(find.text('结束订单'), findsNothing);
  });

  testWidgets('并行实例页支持上一页下一页翻页', (tester) async {
    final service = _FakeProductionPipelineInstancesService();
    tester.view.physicalSize = const Size(2200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductionPipelineInstancesPage(
            session: AppSession(baseUrl: '', accessToken: ''),
            onLogout: () {},
            service: service,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('PO-TRACE-001'), findsWidgets);
    expect(find.text('第 1 / 3 页'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '下一页'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(service.requestedPages, [1, 2]);
    expect(find.text('第 2 / 3 页'), findsOneWidget);
    expect(find.text('PO-TRACE-002'), findsWidgets);

    await tester.tap(find.widgetWithText(OutlinedButton, '上一页'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(service.requestedPages, [1, 2, 1]);
    expect(find.text('第 1 / 3 页'), findsOneWidget);
    expect(find.text('PO-TRACE-001'), findsWidgets);
  });
}
