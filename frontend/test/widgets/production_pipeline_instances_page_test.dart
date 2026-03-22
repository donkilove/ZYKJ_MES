import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/app_session.dart';
import 'package:mes_client/models/production_models.dart';
import 'package:mes_client/pages/production_pipeline_instances_page.dart';
import 'package:mes_client/services/production_service.dart';

class _FakeProductionPipelineInstancesService extends ProductionService {
  _FakeProductionPipelineInstancesService()
    : super(AppSession(baseUrl: '', accessToken: ''));

  String? receivedProcessKeyword;
  String? receivedPipelineSubOrderNo;

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
    receivedProcessKeyword = processKeyword;
    receivedPipelineSubOrderNo = pipelineSubOrderNo;
    return PipelineInstanceListResult(
      total: 1,
      items: [
        PipelineInstanceItem(
          id: 1,
          subOrderId: 21,
          orderId: 9,
          orderCode: 'PO-TRACE-001',
          orderProcessId: 11,
          processCode: 'CUT-01',
          processName: '切割',
          pipelineSeq: 1,
          pipelineSubOrderNo: 'P9-21-1-ABCD1234',
          isActive: true,
          invalidReason: null,
          invalidatedAt: null,
          createdAt: DateTime.utc(2026, 3, 1, 8),
          updatedAt: DateTime.utc(2026, 3, 1, 9),
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
    expect(find.widgetWithText(TextField, '实例编号'), findsOneWidget);
    expect(find.text('切割 (CUT-01)'), findsOneWidget);
    expect(find.text('查看订单'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '工序'), '切割');
    await tester.enterText(find.widgetWithText(TextField, '实例编号'), 'ABCD1234');
    await tester.tap(find.byTooltip('查询'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(service.receivedProcessKeyword, '切割');
    expect(service.receivedPipelineSubOrderNo, 'ABCD1234');

    await tester.ensureVisible(find.text('查看订单'));
    await tester.tap(find.text('查看订单'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('订单详情 - PO-TRACE-001'), findsOneWidget);
    expect(find.text('编辑订单'), findsNothing);
    expect(find.text('删除订单'), findsNothing);
    expect(find.text('结束订单'), findsNothing);
  });
}
