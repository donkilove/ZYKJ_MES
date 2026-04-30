import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/features/production/models/production_models.dart';

void main() {
  test('production status helpers map known statuses and keep unknown', () {
    expect(productionOrderStatusLabel('pending'), isNot('pending'));
    expect(productionOrderStatusLabel('in_progress'), isNot('in_progress'));
    expect(productionOrderStatusLabel('completed'), '生产完成');
    expect(productionOrderStatusLabel('custom'), 'custom');

    expect(productionProcessStatusLabel('partial'), isNot('partial'));
    expect(productionProcessStatusLabel('x'), 'x');

    expect(productionProcessStatusLabel('completed'), '生产完成');
    expect(productionSubOrderStatusLabel('pending'), '待执行');
    expect(productionSubOrderStatusLabel('in_progress'), '执行中');
    expect(productionSubOrderStatusLabel('done'), isNot('done'));
    expect(productionSubOrderStatusLabel('y'), 'y');
    expect(repairOrderStatusLabel('in_repair'), isNot('in_repair'));
    expect(repairOrderStatusLabel('completed'), isNot('completed'));
    expect(scrapProgressLabel('pending_apply'), isNot('pending_apply'));
    expect(scrapProgressLabel('applied'), isNot('applied'));
    expect(assistAuthorizationStatusLabel('approved'), '已生效');
    expect(scrapProgressLabel('pending_apply'), '待处理');
    expect(scrapProgressLabel('applied'), '已处理');
  });

  test('order and detail models parse nested payload', () {
    final order = ProductionOrderItem.fromJson({
      'id': 1,
      'order_code': 'PO-1',
      'product_id': 10,
      'product_name': '产品A',
      'supplier_id': 8,
      'supplier_name': '供应商甲',
      'quantity': 100,
      'status': 'pending',
      'current_process_code': null,
      'current_process_name': null,
      'start_date': '',
      'due_date': null,
      'remark': '备注',
      'process_template_id': 5,
      'process_template_name': '默认模板',
      'process_template_version': 2,
      'pipeline_enabled': true,
      'pipeline_process_codes': ['01-01', '02-01'],
      'created_by_user_id': 1,
      'created_by_username': 'admin',
      'created_at': '2026-03-01T00:00:00Z',
      'updated_at': '2026-03-01T00:00:00Z',
    });
    final detail = ProductionOrderDetail.fromJson({
      'order': {
        'id': 1,
        'order_code': 'PO-1',
        'product_id': 10,
        'product_name': '产品A',
        'supplier_id': 9,
        'supplier_name': '供应商乙',
        'quantity': 100,
        'status': 'pending',
        'created_at': '2026-03-01T00:00:00Z',
        'updated_at': '2026-03-01T00:00:00Z',
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
          'status': 'in_progress',
          'visible_quantity': 80,
          'completed_quantity': 20,
          'created_at': '2026-03-01T00:00:00Z',
          'updated_at': '2026-03-01T00:00:00Z',
        },
      ],
      'sub_orders': [
        {
          'id': 22,
          'order_process_id': 11,
          'process_code': '01-01',
          'process_name': '切割',
          'operator_user_id': 7,
          'operator_username': 'worker',
          'assigned_quantity': 20,
          'completed_quantity': 10,
          'status': 'in_progress',
          'is_visible': true,
          'created_at': '2026-03-01T00:00:00Z',
          'updated_at': '2026-03-01T00:00:00Z',
        },
      ],
      'records': [
        {
          'id': 33,
          'order_process_id': 11,
          'process_code': '01-01',
          'process_name': '切割',
          'operator_user_id': 7,
          'operator_username': 'worker',
          'production_quantity': 5,
          'record_type': 'production',
          'created_at': '2026-03-01T00:00:00Z',
        },
      ],
      'events': [
        {
          'id': 44,
          'order_id': 1,
          'order_code': 'PO-1',
          'order_status': 'pending',
          'product_name': '产品A',
          'process_code': '01-01',
          'event_type': 'created',
          'event_title': '创建订单',
          'event_detail': null,
          'operator_user_id': 1,
          'operator_username': 'admin',
          'payload_json': '{}',
          'created_at': '2026-03-01T00:00:00Z',
        },
      ],
    });

    expect(order.startDate, isNull);
    expect(order.dueDate, isNull);
    expect(order.supplierId, 8);
    expect(order.supplierName, '供应商甲');
    expect(order.pipelineEnabled, isTrue);
    expect(order.pipelineProcessCodes, ['01-01', '02-01']);
    expect(detail.processes.single.processCode, '01-01');
    expect(detail.subOrders.single.isVisible, isTrue);
    expect(detail.records.single.productionQuantity, 5);
    expect(detail.events.single.eventType, 'created');
    expect(detail.events.single.orderCode, 'PO-1');
    expect(detail.order.supplierName, '供应商乙');
    expect(ProductionOrderListResult(total: 1, items: [order]).items.length, 1);
  });

  test('production models handle missing or invalid timestamps safely', () {
    final order = ProductionOrderItem.fromJson({
      'id': 1,
      'order_code': 'PO-NULL-DATE',
      'product_id': 10,
      'product_name': '产品A',
      'supplier_id': 8,
      'supplier_name': '供应商甲',
      'quantity': 100,
      'status': 'pending',
      'created_at': null,
      'updated_at': 'not-a-date',
    });

    expect(order.createdAt, DateTime(1970, 1, 1));
    expect(order.updatedAt, DateTime(1970, 1, 1));
  });

  test('my-order/stats/options models parse and payload serializes', () {
    final myOrder = MyOrderItem.fromJson({
      'order_id': 9,
      'order_code': 'PO-9',
      'product_id': 2,
      'product_name': '产品X',
      'supplier_name': '供应商甲',
      'quantity': 300,
      'order_status': 'in_progress',
      'current_process_id': 8,
      'current_stage_id': 1,
      'current_stage_code': '01',
      'current_stage_name': '切割段',
      'current_process_code': '01-01',
      'current_process_name': '切割',
      'current_process_order': 1,
      'process_status': 'pending',
      'visible_quantity': 200,
      'process_completed_quantity': 100,
      'user_sub_order_id': 10,
      'user_assigned_quantity': 50,
      'user_completed_quantity': 20,
      'pipeline_mode_enabled': true,
      'pipeline_instance_id': 88,
      'pipeline_instance_no': 'P9-10-2-ABCD1234',
      'pipeline_start_allowed': true,
      'pipeline_end_allowed': false,
      'max_producible_quantity': 30,
      'can_first_article': true,
      'can_end_production': false,
      'due_date': '2026-03-20',
      'remark': '订单备注',
      'updated_at': '2026-03-01T00:00:00Z',
    });
    final action = ProductionActionResult.fromJson({
      'order_id': 9,
      'status': 'ok',
      'message': 'done',
    });
    final pipelineMode = OrderPipelineModeItem.fromJson({
      'order_id': 9,
      'enabled': true,
      'process_codes': ['01-01', '02-01'],
      'available_process_codes': ['01-01', '02-01', '03-01'],
    });
    final overview = ProductionStatsOverview.fromJson({
      'total_orders': 10,
      'pending_orders': 2,
      'in_progress_orders': 5,
      'completed_orders': 3,
      'total_quantity': 1000,
      'finished_quantity': 800,
    });
    final processStat = ProductionProcessStatItem.fromJson({
      'process_code': '01-01',
      'process_name': '切割',
      'total_orders': 3,
      'pending_orders': 1,
      'in_progress_orders': 1,
      'partial_orders': 1,
      'completed_orders': 0,
      'total_visible_quantity': 100,
      'total_completed_quantity': 60,
    });
    final operatorStat = ProductionOperatorStatItem.fromJson({
      'operator_user_id': 1,
      'operator_username': 'op',
      'process_code': '01-01',
      'process_name': '切割',
      'production_records': 12,
      'production_quantity': 50,
      'last_production_at': '',
    });
    final productOption = ProductionProductOption.fromJson({
      'id': 2,
      'name': '产品X',
    });
    final processOption = ProductionProcessOption.fromJson({
      'id': 3,
      'code': '01-01',
      'name': '切割',
      'stage_id': 1,
      'stage_code': '01',
      'stage_name': '切割段',
    });
    const step = ProductionOrderProcessStepInput(
      stepOrder: 1,
      stageId: 1,
      processId: 3,
    );

    expect(myOrder.canFirstArticle, isTrue);
    expect(myOrder.pipelineModeEnabled, isTrue);
    expect(myOrder.pipelineInstanceId, 88);
    expect(myOrder.pipelineInstanceNo, 'P9-10-2-ABCD1234');
    expect(myOrder.pipelineStartAllowed, isTrue);
    expect(myOrder.pipelineEndAllowed, isFalse);
    expect(myOrder.supplierName, '供应商甲');
    expect(myOrder.dueDate, isNotNull);
    expect(myOrder.remark, '订单备注');
    expect(pipelineMode.availableProcessCodes.length, 3);
    expect(action.message, 'done');
    expect(overview.finishedQuantity, 800);
    expect(processStat.totalVisibleQuantity, 100);
    expect(operatorStat.lastProductionAt, isNull);
    expect(productOption.id, 2);
    expect(processOption.stageCode, '01');
    expect(step.toJson(), {'step_order': 1, 'stage_id': 1, 'process_id': 3});
    expect(
      MyOrderListResult(total: 1, items: [myOrder]).items.single.orderId,
      9,
    );
  });

  test('首件富表单模型支持模板参数参与人与提交序列化', () {
    final template = FirstArticleTemplateItem.fromJson({
      'id': 11,
      'product_id': 2,
      'process_code': '01-01',
      'template_name': '默认首件模板',
      'check_content': '外观检查',
      'test_value': '9.86',
    });
    final participant = FirstArticleParticipantOptionItem.fromJson({
      'id': 8,
      'username': 'worker',
      'full_name': '张三',
    });
    final parameters = FirstArticleParameterListResult.fromJson({
      'product_id': 2,
      'product_name': '产品X',
      'parameter_scope': 'effective',
      'version': 3,
      'version_label': 'v3',
      'lifecycle_status': 'active',
      'total': 1,
      'items': [
        {
          'name': '长度',
          'category': '尺寸',
          'type': 'text',
          'value': '10mm',
          'description': '模板参数',
          'sort_order': 1,
          'is_preset': true,
        },
      ],
    });
    const request = FirstArticleSubmitRequestInput(
      orderProcessId: 21,
      pipelineInstanceId: 301,
      templateId: 11,
      checkContent: '实测外观',
      testValue: '9.80',
      result: 'passed',
      participantUserIds: [8, 9],
      verificationCode: 'code-fa2',
      remark: '备注',
      effectiveOperatorUserId: 8,
      assistAuthorizationId: 99,
    );

    expect(template.displayLabel, '默认首件模板 (01-01)');
    expect(participant.displayName, 'worker (张三)');
    expect(parameters.items.single.value, '10mm');
    expect(request.toJson()['template_id'], 11);
    expect(request.toJson()['participant_user_ids'], [8, 9]);
  });

  test('首件扫码复核模型解析会话结果与详情', () {
    final result = FirstArticleReviewSessionResult.fromJson({
      'session_id': 7,
      'review_url': '/first-article-review?token=abc',
      'expires_at': '2026-04-25T12:05:00Z',
      'status': 'pending',
      'first_article_record_id': null,
      'reviewer_user_id': null,
      'reviewed_at': null,
      'review_remark': null,
    });
    final reviewed = FirstArticleReviewSessionResult.fromJson({
      'session_id': 8,
      'review_url': null,
      'expires_at': '2026-04-25T12:05:00Z',
      'status': 'approved',
      'first_article_record_id': 99,
      'reviewer_user_id': 3,
      'reviewed_at': '2026-04-25T12:02:00Z',
      'review_remark': '参数一致',
    });
    final detail = FirstArticleReviewSessionDetail.fromJson({
      'session_id': 7,
      'status': 'pending',
      'expires_at': '2026-04-25T12:05:00Z',
      'order_id': 1,
      'order_code': 'PO-1',
      'product_name': '产品A',
      'order_process_id': 11,
      'process_name': '切割',
      'operator_user_id': 8,
      'operator_username': 'worker',
      'template_id': 501,
      'check_content': '外观无划伤',
      'test_value': '长度 10.01',
      'participant_user_ids': [8, 9],
      'review_remark': null,
    });
    const refresh = FirstArticleReviewSessionRefreshInput(
      checkContent: '外观无划伤',
      testValue: '长度 10.01',
      participantUserIds: [8, 9],
    );
    const submit = FirstArticleReviewSubmitInput(
      token: 'scan-token',
      reviewResult: 'failed',
      reviewRemark: '长度偏差',
    );

    expect(result.sessionId, 7);
    expect(result.reviewUrl, '/first-article-review?token=abc');
    expect(result.status, 'pending');
    expect(reviewed.firstArticleRecordId, 99);
    expect(reviewed.reviewerUserId, 3);
    expect(reviewed.reviewedAt, isNotNull);
    expect(detail.orderCode, 'PO-1');
    expect(detail.processName, '切割');
    expect(detail.participantUserIds, [8, 9]);
    expect(refresh.toJson()['participant_user_ids'], [8, 9]);
    expect(submit.toJson()['review_result'], 'failed');
  });

  test(
    'production data query models parse today/unfinished/manual payloads',
    () {
      final today = ProductionTodayRealtimeResult.fromJson({
        'stat_mode': 'main_order',
        'summary': {'total_products': 1, 'total_quantity': 20},
        'table_rows': [
          {
            'product_id': 1,
            'product_name': '产品A',
            'quantity': 20,
            'latest_time': '2026-03-02T08:00:00Z',
            'latest_time_text': '2026-03-02 16:00:00',
          },
        ],
        'chart_data': [
          {'label': '产品A', 'value': 20},
        ],
        'query_signature': '{"view":"today_realtime"}',
      });

      final unfinished = ProductionUnfinishedProgressResult.fromJson({
        'summary': {'total_orders': 2, 'avg_progress_percent': 34.5},
        'table_rows': [
          {
            'order_id': 11,
            'order_code': 'PO-11',
            'product_id': 1,
            'product_name': '产品A',
            'order_status': 'in_progress',
            'process_count': 3,
            'produced_total': 120,
            'target_total': 300,
            'progress_percent': 40.0,
          },
        ],
        'query_signature': '{"view":"unfinished_progress"}',
      });

      final manual = ProductionManualQueryResult.fromJson({
        'stat_mode': 'sub_order',
        'summary': {
          'rows': 1,
          'filtered_total': 15,
          'time_range_total': 20,
          'ratio_percent': 75,
        },
        'table_rows': [
          {
            'order_id': 12,
            'order_code': 'PO-12',
            'product_id': 2,
            'product_name': '产品B',
            'stage_id': 1,
            'stage_code': '01',
            'stage_name': '切割段',
            'process_id': 3,
            'process_code': '01-01',
            'process_name': '切割',
            'operator_user_id': 9,
            'operator_username': 'worker',
            'quantity': 15,
            'production_time': '2026-03-02T10:00:00Z',
            'production_time_text': '2026-03-02 18:00:00',
            'order_status': 'in_progress',
          },
        ],
        'chart_data': {
          'single_day': true,
          'model_output': [
            {'product_name': '产品B', 'quantity': 15},
          ],
          'trend_output': [
            {'bucket': '10:00', 'quantity': 15},
          ],
          'pie_output': [
            {'name': '筛选结果', 'quantity': 15},
            {'name': '其余产量', 'quantity': 5},
          ],
        },
        'query_signature': '{"view":"manual"}',
      });

      final export = ProductionManualExportResult.fromJson({
        'file_name': 'production_manual_20260302_100000.csv',
        'mime_type': 'text/csv',
        'content_base64': 'YWJj',
      });

      expect(today.summary.totalQuantity, 20);
      expect(today.tableRows.single.latestTimeText, contains('2026-03-02'));
      expect(unfinished.tableRows.single.targetTotal, 300);
      expect(manual.chartData.pieOutput.length, 2);
      expect(export.fileName, contains('.csv'));
    },
  );

  test('d-batch repair and scrap models parse payloads', () {
    const defectInput = ProductionDefectItemInput(
      phenomenon: '毛刺',
      quantity: 1,
    );
    const causeInput = RepairCauseItemInput(
      phenomenon: '毛刺',
      reason: '刀具磨损',
      quantity: 1,
      isScrap: true,
    );
    const allocationInput = RepairReturnAllocationInput(
      targetOrderProcessId: 11,
      quantity: 2,
    );
    final repair = RepairOrderItem.fromJson({
      'id': 1,
      'repair_order_code': 'RW-1',
      'source_order_id': 2,
      'source_order_code': 'PO-2',
      'product_id': 3,
      'product_name': '产品A',
      'source_order_process_id': 4,
      'source_process_code': '01-01',
      'source_process_name': '切割',
      'sender_user_id': 5,
      'sender_username': 'worker',
      'production_quantity': 10,
      'repair_quantity': 2,
      'repaired_quantity': 1,
      'scrap_quantity': 1,
      'scrap_replenished': true,
      'repair_time': '2026-03-01T00:00:00Z',
      'status': 'completed',
      'completed_at': '2026-03-01T01:00:00Z',
      'repair_operator_user_id': 1,
      'repair_operator_username': 'admin',
      'created_at': '2026-03-01T00:00:00Z',
      'updated_at': '2026-03-01T00:00:00Z',
    });
    final summary = RepairOrderPhenomenaSummaryResult.fromJson({
      'repair_order_id': 1,
      'items': [
        {'phenomenon': '毛刺', 'quantity': 1},
      ],
    });
    final scrap = ScrapStatisticsItem.fromJson({
      'id': 1,
      'order_id': 2,
      'order_code': 'PO-2',
      'product_id': 3,
      'product_name': '产品A',
      'process_id': 4,
      'process_code': '01-01',
      'process_name': '切割',
      'scrap_reason': '刀具磨损',
      'scrap_quantity': 1,
      'last_scrap_time': '2026-03-01T01:00:00Z',
      'progress': 'pending_apply',
      'applied_at': null,
      'created_at': '2026-03-01T00:00:00Z',
      'updated_at': '2026-03-01T00:00:00Z',
    });
    final export = ProductionExportResult.fromJson({
      'file_name': 'repair.csv',
      'mime_type': 'text/csv',
      'content_base64': 'YWJj',
      'exported_count': 12,
    });
    final detail = RepairOrderDetailItem.fromJson({
      'id': 1,
      'repair_order_code': 'RW-1',
      'source_process_code': '01-01',
      'source_process_name': '切割',
      'production_quantity': 10,
      'repair_quantity': 2,
      'repaired_quantity': 1,
      'scrap_quantity': 1,
      'scrap_replenished': true,
      'repair_time': '2026-03-01T00:00:00Z',
      'status': 'completed',
      'created_at': '2026-03-01T00:00:00Z',
      'updated_at': '2026-03-01T00:00:00Z',
      'defect_rows': [
        {
          'id': 1,
          'phenomenon': '毛刺',
          'quantity': 1,
          'production_record_id': 88,
          'production_sub_order_id': 7,
          'production_record_type': 'production',
          'production_record_quantity': 6,
          'production_record_created_at': '2026-03-01T00:30:00Z',
        },
      ],
    });

    expect(defectInput.toJson()['quantity'], 1);
    expect(causeInput.toJson()['is_scrap'], isTrue);
    expect(allocationInput.toJson()['target_order_process_id'], 11);
    expect(repair.status, 'completed');
    expect(summary.items.single.phenomenon, '毛刺');
    expect(scrap.scrapReason, '刀具磨损');
    expect(export.exportedCount, 12);
    expect(detail.defectRows.single.productionRecordId, 88);
    expect(detail.defectRows.single.productionRecordQuantity, 6);
    expect(RepairOrderListResult(total: 1, items: [repair]).items.single.id, 1);
    expect(
      ScrapStatisticsListResult(total: 1, items: [scrap]).items.single.id,
      1,
    );
  });
}
