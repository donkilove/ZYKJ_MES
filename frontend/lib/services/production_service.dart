import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_session.dart';
import '../models/production_models.dart';
import 'api_exception.dart';

class ProductionService {
  ProductionService(this.session);

  final AppSession session;

  String get _basePath => '${session.baseUrl}/production';

  Map<String, String> get _authHeaders {
    return {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  Future<ProductionOrderListResult> listOrders({
    required int page,
    required int pageSize,
    String? keyword,
    String? status,
    String? productName,
    bool? pipelineEnabled,
    DateTime? startDateFrom,
    DateTime? startDateTo,
    DateTime? dueDateFrom,
    DateTime? dueDateTo,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }
    if (productName != null && productName.trim().isNotEmpty) {
      query['product_name'] = productName.trim();
    }
    if (pipelineEnabled != null) {
      query['pipeline_enabled'] = pipelineEnabled ? 'true' : 'false';
    }
    final startDateFromText = _formatDateOrNull(startDateFrom);
    if (startDateFromText != null) query['start_date_from'] = startDateFromText;
    final startDateToText = _formatDateOrNull(startDateTo);
    if (startDateToText != null) query['start_date_to'] = startDateToText;
    final dueDateFromText = _formatDateOrNull(dueDateFrom);
    if (dueDateFromText != null) query['due_date_from'] = dueDateFromText;
    final dueDateToText = _formatDateOrNull(dueDateTo);
    if (dueDateToText != null) query['due_date_to'] = dueDateToText;
    final uri = Uri.parse('$_basePath/orders').replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }

    final data = body['data'] as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) =>
              ProductionOrderItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
    return ProductionOrderListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<Map<String, dynamic>> exportOrders({
    String? keyword,
    String? status,
    String? productName,
    bool? pipelineEnabled,
    DateTime? startDateFrom,
    DateTime? startDateTo,
    DateTime? dueDateFrom,
    DateTime? dueDateTo,
  }) async {
    final payload = <String, dynamic>{};
    if (keyword != null && keyword.trim().isNotEmpty) {
      payload['keyword'] = keyword.trim();
    }
    if (status != null && status.trim().isNotEmpty) {
      payload['status'] = status.trim();
    }
    if (productName != null && productName.trim().isNotEmpty) {
      payload['product_name'] = productName.trim();
    }
    if (pipelineEnabled != null) {
      payload['pipeline_enabled'] = pipelineEnabled;
    }
    final startDateFromText = _formatDateOrNull(startDateFrom);
    if (startDateFromText != null) {
      payload['start_date_from'] = startDateFromText;
    }
    final startDateToText = _formatDateOrNull(startDateTo);
    if (startDateToText != null) {
      payload['start_date_to'] = startDateToText;
    }
    final dueDateFromText = _formatDateOrNull(dueDateFrom);
    if (dueDateFromText != null) {
      payload['due_date_from'] = dueDateFromText;
    }
    final dueDateToText = _formatDateOrNull(dueDateTo);
    if (dueDateToText != null) {
      payload['due_date_to'] = dueDateToText;
    }
    final uri = Uri.parse('$_basePath/orders/export');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode(payload),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return body['data'] as Map<String, dynamic>;
  }

  Future<ProductionEventLogListResult> searchOrderEvents({
    required String orderCode,
    String? eventType,
    String? operatorUsername,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = <String, String>{'order_code': orderCode.trim()};
    if (eventType != null && eventType.trim().isNotEmpty) {
      query['event_type'] = eventType.trim();
    }
    if (operatorUsername != null && operatorUsername.trim().isNotEmpty) {
      query['operator_username'] = operatorUsername.trim();
    }
    final startDateText = _formatDateOrNull(startDate);
    if (startDateText != null) {
      query['start_date'] = startDateText;
    }
    final endDateText = _formatDateOrNull(endDate);
    if (endDateText != null) {
      query['end_date'] = endDateText;
    }
    final uri = Uri.parse(
      '$_basePath/order-events/search',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) =>
              ProductionEventLogItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
    return ProductionEventLogListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<ProductionOrderItem> createOrder({
    required String orderCode,
    required int productId,
    required int quantity,
    required List<String> processCodes,
    int? templateId,
    List<ProductionOrderProcessStepInput>? processSteps,
    bool saveAsTemplate = false,
    String? newTemplateName,
    bool newTemplateSetDefault = false,
    DateTime? startDate,
    DateTime? dueDate,
    String? remark,
  }) async {
    final uri = Uri.parse('$_basePath/orders');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'order_code': orderCode,
        'product_id': productId,
        'quantity': quantity,
        'process_codes': processCodes,
        'template_id': templateId,
        'process_steps': processSteps?.map((item) => item.toJson()).toList(),
        'save_as_template': saveAsTemplate,
        'new_template_name': newTemplateName,
        'new_template_set_default': newTemplateSetDefault,
        'start_date': _formatDateOrNull(startDate),
        'due_date': _formatDateOrNull(dueDate),
        'remark': remark,
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return ProductionOrderItem.fromJson(data);
  }

  Future<ProductionOrderItem> updateOrder({
    required int orderId,
    required int productId,
    required int quantity,
    required List<String> processCodes,
    int? templateId,
    List<ProductionOrderProcessStepInput>? processSteps,
    bool saveAsTemplate = false,
    String? newTemplateName,
    bool newTemplateSetDefault = false,
    DateTime? startDate,
    DateTime? dueDate,
    String? remark,
  }) async {
    final uri = Uri.parse('$_basePath/orders/$orderId');
    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'product_id': productId,
        'quantity': quantity,
        'process_codes': processCodes,
        'template_id': templateId,
        'process_steps': processSteps?.map((item) => item.toJson()).toList(),
        'save_as_template': saveAsTemplate,
        'new_template_name': newTemplateName,
        'new_template_set_default': newTemplateSetDefault,
        'start_date': _formatDateOrNull(startDate),
        'due_date': _formatDateOrNull(dueDate),
        'remark': remark,
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return ProductionOrderItem.fromJson(data);
  }

  Future<void> deleteOrder({required int orderId}) async {
    final uri = Uri.parse('$_basePath/orders/$orderId');
    final response = await http.delete(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<ProductionActionResult> completeOrder({required int orderId}) async {
    final uri = Uri.parse('$_basePath/orders/$orderId/complete');
    final response = await http.post(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return ProductionActionResult.fromJson(data);
  }

  Future<ProductionOrderDetail> getOrderDetail({required int orderId}) async {
    final uri = Uri.parse('$_basePath/orders/$orderId');
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return ProductionOrderDetail.fromJson(data);
  }

  Future<OrderPipelineModeItem> getOrderPipelineMode({
    required int orderId,
  }) async {
    final uri = Uri.parse('$_basePath/orders/$orderId/pipeline-mode');
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return OrderPipelineModeItem.fromJson(data);
  }

  Future<OrderPipelineModeItem> updateOrderPipelineMode({
    required int orderId,
    required bool enabled,
    required List<String> processCodes,
  }) async {
    final uri = Uri.parse('$_basePath/orders/$orderId/pipeline-mode');
    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'enabled': enabled, 'process_codes': processCodes}),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return OrderPipelineModeItem.fromJson(data);
  }

  Future<MyOrderListResult> listMyOrders({
    required int page,
    required int pageSize,
    String? keyword,
    String? viewMode,
    int? proxyOperatorUserId,
    String? orderStatus,
    int? currentProcessId,
  }) async {
    final normalizedPageSize = pageSize.clamp(1, 200).toInt();
    final query = <String, String>{
      'page': '$page',
      'page_size': '$normalizedPageSize',
    };
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (viewMode != null && viewMode.trim().isNotEmpty) {
      query['view_mode'] = viewMode.trim();
    }
    if (proxyOperatorUserId != null && proxyOperatorUserId > 0) {
      query['proxy_operator_user_id'] = '$proxyOperatorUserId';
    }
    if (orderStatus != null &&
        orderStatus.trim().isNotEmpty &&
        orderStatus.trim() != 'all') {
      query['order_status'] = orderStatus.trim();
    }
    if (currentProcessId != null && currentProcessId > 0) {
      query['current_process_id'] = '$currentProcessId';
    }
    final uri = Uri.parse(
      '$_basePath/my-orders',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map((entry) => MyOrderItem.fromJson(entry as Map<String, dynamic>))
        .toList();
    return MyOrderListResult(total: (data['total'] as int?) ?? 0, items: items);
  }

  Future<MyOrderContextResult> getMyOrderContext({
    required int orderId,
    int? orderProcessId,
    String? viewMode,
    int? proxyOperatorUserId,
  }) async {
    final query = <String, String>{};
    if (orderProcessId != null && orderProcessId > 0) {
      query['order_process_id'] = '$orderProcessId';
    }
    if (viewMode != null && viewMode.trim().isNotEmpty) {
      query['view_mode'] = viewMode.trim();
    }
    if (proxyOperatorUserId != null && proxyOperatorUserId > 0) {
      query['proxy_operator_user_id'] = '$proxyOperatorUserId';
    }
    final uri = Uri.parse(
      '$_basePath/my-orders/$orderId/context',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return MyOrderContextResult.fromJson(data);
  }

  Future<ProductionActionResult> submitFirstArticle({
    required int orderId,
    required int orderProcessId,
    required String verificationCode,
    String? remark,
    int? effectiveOperatorUserId,
    int? assistAuthorizationId,
  }) async {
    final uri = Uri.parse('$_basePath/orders/$orderId/first-article');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'order_process_id': orderProcessId,
        'verification_code': verificationCode,
        'remark': remark,
        'effective_operator_user_id': effectiveOperatorUserId,
        'assist_authorization_id': assistAuthorizationId,
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return ProductionActionResult.fromJson(data);
  }

  Future<ProductionActionResult> endProduction({
    required int orderId,
    required int orderProcessId,
    required int quantity,
    String? remark,
    int? effectiveOperatorUserId,
    int? assistAuthorizationId,
    List<ProductionDefectItemInput>? defectItems,
  }) async {
    final uri = Uri.parse('$_basePath/orders/$orderId/end-production');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'order_process_id': orderProcessId,
        'quantity': quantity,
        'remark': remark,
        'effective_operator_user_id': effectiveOperatorUserId,
        'assist_authorization_id': assistAuthorizationId,
        'defect_items': (defectItems ?? const <ProductionDefectItemInput>[])
            .map((item) => item.toJson())
            .toList(),
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return ProductionActionResult.fromJson(data);
  }

  Future<ProductionStatsOverview> getOverviewStats() async {
    final uri = Uri.parse('$_basePath/stats/overview');
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return ProductionStatsOverview.fromJson(data);
  }

  Future<List<ProductionProcessStatItem>> getProcessStats() async {
    final uri = Uri.parse('$_basePath/stats/processes');
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) =>
              ProductionProcessStatItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<ProductionOperatorStatItem>> getOperatorStats() async {
    final uri = Uri.parse('$_basePath/stats/operators');
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) => ProductionOperatorStatItem.fromJson(
            entry as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<ProductionTodayRealtimeResult> getTodayRealtimeData({
    String statMode = 'main_order',
    List<int>? productIds,
    List<int>? stageIds,
    List<int>? processIds,
    List<int>? operatorUserIds,
    String orderStatus = 'all',
  }) async {
    final query = <String, String>{
      'stat_mode': statMode,
      'order_status': orderStatus,
    };
    _appendIntListQuery(query, 'product_ids', productIds);
    _appendIntListQuery(query, 'stage_ids', stageIds);
    _appendIntListQuery(query, 'process_ids', processIds);
    _appendIntListQuery(query, 'operator_user_ids', operatorUserIds);

    final uri = Uri.parse(
      '$_basePath/data/today-realtime',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return ProductionTodayRealtimeResult.fromJson(data);
  }

  Future<ProductionUnfinishedProgressResult> getUnfinishedProgressData({
    List<int>? productIds,
    List<int>? stageIds,
    List<int>? processIds,
    List<int>? operatorUserIds,
    String orderStatus = 'all',
  }) async {
    final query = <String, String>{'order_status': orderStatus};
    _appendIntListQuery(query, 'product_ids', productIds);
    _appendIntListQuery(query, 'stage_ids', stageIds);
    _appendIntListQuery(query, 'process_ids', processIds);
    _appendIntListQuery(query, 'operator_user_ids', operatorUserIds);

    final uri = Uri.parse(
      '$_basePath/data/unfinished-progress',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return ProductionUnfinishedProgressResult.fromJson(data);
  }

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
    final query = <String, String>{
      'stat_mode': statMode,
      'order_status': orderStatus,
    };
    final startDateText = _formatDateOrNull(startDate);
    if (startDateText != null) {
      query['start_date'] = startDateText;
    }
    final endDateText = _formatDateOrNull(endDate);
    if (endDateText != null) {
      query['end_date'] = endDateText;
    }
    _appendIntListQuery(query, 'product_ids', productIds);
    _appendIntListQuery(query, 'stage_ids', stageIds);
    _appendIntListQuery(query, 'process_ids', processIds);
    _appendIntListQuery(query, 'operator_user_ids', operatorUserIds);

    final uri = Uri.parse(
      '$_basePath/data/manual',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return ProductionManualQueryResult.fromJson(data);
  }

  Future<ProductionManualExportResult> exportManualProductionData({
    String statMode = 'main_order',
    DateTime? startDate,
    DateTime? endDate,
    List<int>? productIds,
    List<int>? stageIds,
    List<int>? processIds,
    List<int>? operatorUserIds,
    String orderStatus = 'all',
  }) async {
    final uri = Uri.parse('$_basePath/data/manual/export');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'stat_mode': statMode,
        'start_date': _formatDateOrNull(startDate),
        'end_date': _formatDateOrNull(endDate),
        'product_ids': productIds ?? const <int>[],
        'stage_ids': stageIds ?? const <int>[],
        'process_ids': processIds ?? const <int>[],
        'operator_user_ids': operatorUserIds ?? const <int>[],
        'order_status': orderStatus,
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return ProductionManualExportResult.fromJson(data);
  }

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
    final query = <String, String>{
      'page': '$page',
      'page_size': '${pageSize.clamp(1, 500)}',
      'progress': progress,
    };
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (productName != null && productName.trim().isNotEmpty) {
      query['product_name'] = productName.trim();
    }
    if (processCode != null && processCode.trim().isNotEmpty) {
      query['process_code'] = processCode.trim();
    }
    final startDateText = _formatDateOrNull(startDate);
    if (startDateText != null) {
      query['start_date'] = startDateText;
    }
    final endDateText = _formatDateOrNull(endDate);
    if (endDateText != null) {
      query['end_date'] = endDateText;
    }
    final uri = Uri.parse(
      '$_basePath/scrap-statistics',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) =>
              ScrapStatisticsItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
    return ScrapStatisticsListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<ProductionExportResult> exportScrapStatistics({
    String? keyword,
    String? productName,
    String? processCode,
    String progress = 'all',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final uri = Uri.parse('$_basePath/scrap-statistics/export');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'keyword': keyword,
        'product_name': productName,
        'process_code': processCode,
        'progress': progress,
        'start_date': _formatDateOrNull(startDate),
        'end_date': _formatDateOrNull(endDate),
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return ProductionExportResult.fromJson(data);
  }

  Future<ScrapStatisticsItem> getScrapStatisticsDetail({
    required int scrapId,
  }) async {
    final uri = Uri.parse('$_basePath/scrap-statistics/$scrapId');
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return ScrapStatisticsItem.fromJson(data);
  }

  Future<RepairOrderDetailItem> getRepairOrderDetail({
    required int repairOrderId,
  }) async {
    final uri = Uri.parse('$_basePath/repair-orders/$repairOrderId/detail');
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return RepairOrderDetailItem.fromJson(data);
  }

  Future<RepairOrderListResult> getRepairOrders({
    required int page,
    required int pageSize,
    String? keyword,
    String status = 'all',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'page_size': '${pageSize.clamp(1, 500)}',
      'status': status,
    };
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    final startDateText = _formatDateOrNull(startDate);
    if (startDateText != null) {
      query['start_date'] = startDateText;
    }
    final endDateText = _formatDateOrNull(endDate);
    if (endDateText != null) {
      query['end_date'] = endDateText;
    }
    final uri = Uri.parse(
      '$_basePath/repair-orders',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map((entry) => RepairOrderItem.fromJson(entry as Map<String, dynamic>))
        .toList();
    return RepairOrderListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<RepairOrderItem> createManualRepairOrder({
    required int orderId,
    required int orderProcessId,
    required int productionQuantity,
    required List<ProductionDefectItemInput> defectItems,
  }) async {
    final uri = Uri.parse('$_basePath/orders/$orderId/repair-orders');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'order_process_id': orderProcessId,
        'production_quantity': productionQuantity,
        'defect_items': defectItems.map((item) => item.toJson()).toList(),
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return RepairOrderItem.fromJson(data);
  }

  Future<RepairOrderPhenomenaSummaryResult> getRepairOrderPhenomenaSummary({
    required int repairOrderId,
  }) async {
    final uri = Uri.parse(
      '$_basePath/repair-orders/$repairOrderId/phenomena-summary',
    );
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return RepairOrderPhenomenaSummaryResult.fromJson(data);
  }

  Future<RepairOrderItem> completeRepairOrder({
    required int repairOrderId,
    required List<RepairCauseItemInput> causeItems,
    required bool scrapReplenished,
    required List<RepairReturnAllocationInput> returnAllocations,
  }) async {
    final uri = Uri.parse('$_basePath/repair-orders/$repairOrderId/complete');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'cause_items': causeItems.map((item) => item.toJson()).toList(),
        'scrap_replenished': scrapReplenished,
        'return_allocations': returnAllocations
            .map((item) => item.toJson())
            .toList(),
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return RepairOrderItem.fromJson(data);
  }

  Future<ProductionExportResult> exportRepairOrders({
    String? keyword,
    String status = 'all',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final uri = Uri.parse('$_basePath/repair-orders/export');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'keyword': keyword,
        'status': status,
        'start_date': _formatDateOrNull(startDate),
        'end_date': _formatDateOrNull(endDate),
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return ProductionExportResult.fromJson(data);
  }

  Future<List<ProductionProductOption>> listProductOptions() async {
    final uri = Uri.parse(
      '${session.baseUrl}/products',
    ).replace(queryParameters: {'page': '1', 'page_size': '200'});
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) =>
              ProductionProductOption.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<ProductionProcessOption>> listProcessOptions() async {
    final uri = Uri.parse(
      '${session.baseUrl}/processes',
    ).replace(queryParameters: {'page': '1', 'page_size': '200'});
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) =>
              ProductionProcessOption.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
  }

  Future<AssistAuthorizationListResult> listAssistAuthorizations({
    required int page,
    required int pageSize,
    String? status,
    String? orderCode,
    String? processName,
    String? requesterUsername,
    String? helperUsername,
    DateTime? createdAtFrom,
    DateTime? createdAtTo,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'page_size': '${pageSize.clamp(1, 200)}',
    };
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }
    if (orderCode != null && orderCode.trim().isNotEmpty) {
      query['order_code'] = orderCode.trim();
    }
    if (processName != null && processName.trim().isNotEmpty) {
      query['process_name'] = processName.trim();
    }
    if (requesterUsername != null && requesterUsername.trim().isNotEmpty) {
      query['requester_username'] = requesterUsername.trim();
    }
    if (helperUsername != null && helperUsername.trim().isNotEmpty) {
      query['helper_username'] = helperUsername.trim();
    }
    final createdAtFromText = _formatDateOrNull(createdAtFrom);
    if (createdAtFromText != null) query['created_at_from'] = createdAtFromText;
    final createdAtToText = _formatDateOrNull(createdAtTo);
    if (createdAtToText != null) query['created_at_to'] = createdAtToText;
    final uri = Uri.parse(
      '$_basePath/assist-authorizations',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) =>
              AssistAuthorizationItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
    return AssistAuthorizationListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<AssistAuthorizationItem> createAssistAuthorization({
    required int orderId,
    required int orderProcessId,
    required int targetOperatorUserId,
    required int helperUserId,
    String? reason,
  }) async {
    final uri = Uri.parse('$_basePath/orders/$orderId/assist-authorizations');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'order_process_id': orderProcessId,
        'target_operator_user_id': targetOperatorUserId,
        'helper_user_id': helperUserId,
        'reason': reason,
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return AssistAuthorizationItem.fromJson(data);
  }

  Future<AssistAuthorizationItem> reviewAssistAuthorization({
    required int authorizationId,
    required bool approve,
    String? reviewRemark,
  }) async {
    final uri = Uri.parse(
      '$_basePath/assist-authorizations/$authorizationId/review',
    );
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'approve': approve, 'review_remark': reviewRemark}),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    return AssistAuthorizationItem.fromJson(data);
  }

  Future<AssistUserOptionListResult> listAssistUserOptions({
    required int page,
    required int pageSize,
    String? keyword,
    String? roleCode,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'page_size': '${pageSize.clamp(1, 200)}',
    };
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (roleCode != null && roleCode.trim().isNotEmpty) {
      query['role_code'] = roleCode.trim();
    }
    final uri = Uri.parse(
      '$_basePath/assist-user-options',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) =>
              AssistUserOptionItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
    return AssistUserOptionListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

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
    final query = <String, String>{
      'page': '$page',
      'page_size': '${pageSize.clamp(1, 500)}',
    };
    if (orderId != null) query['order_id'] = '$orderId';
    if (orderCode != null && orderCode.trim().isNotEmpty) {
      query['order_code'] = orderCode.trim();
    }
    if (orderProcessId != null) query['order_process_id'] = '$orderProcessId';
    if (subOrderId != null) query['sub_order_id'] = '$subOrderId';
    if (processKeyword != null && processKeyword.trim().isNotEmpty) {
      query['process_keyword'] = processKeyword.trim();
    }
    if (pipelineSubOrderNo != null && pipelineSubOrderNo.trim().isNotEmpty) {
      query['pipeline_sub_order_no'] = pipelineSubOrderNo.trim();
    }
    if (isActive != null) query['is_active'] = isActive ? 'true' : 'false';
    final uri = Uri.parse(
      '$_basePath/pipeline-instances',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) =>
              PipelineInstanceItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
    return PipelineInstanceListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    if (response.body.isEmpty) {
      return {};
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _extractErrorMessage(Map<String, dynamic> body, int statusCode) {
    final detail = body['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
    if (detail is List) {
      final validationMessage = _extractValidationDetailMessage(detail);
      if (validationMessage != null) {
        return validationMessage;
      }
    }
    final message = body['message'];
    if (message is String && message.isNotEmpty) {
      return message;
    }
    return 'Request failed (status $statusCode)';
  }

  String? _extractValidationDetailMessage(List<dynamic> detail) {
    if (detail.isEmpty) {
      return null;
    }

    final messages = <String>[];
    for (final item in detail.take(3)) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final msg = (item['msg'] as String?)?.trim();
      if (msg == null || msg.isEmpty) {
        continue;
      }

      final locRaw = item['loc'];
      String? fieldLabel;
      if (locRaw is List) {
        final locParts = locRaw
            .map((entry) => entry.toString())
            .where((entry) => entry.isNotEmpty && entry != 'body')
            .toList();
        if (locParts.isNotEmpty) {
          fieldLabel = _fieldLabelForValidation(locParts.last);
        }
      }

      messages.add(fieldLabel == null ? msg : '$fieldLabel: $msg');
    }

    if (messages.isEmpty) {
      return null;
    }
    return messages.join('; ');
  }

  String? _fieldLabelForValidation(String field) {
    switch (field) {
      case 'order_code':
        return 'Order Code';
      case 'product_id':
        return 'Product';
      case 'quantity':
        return 'Quantity';
      case 'start_date':
        return 'Start Date';
      case 'due_date':
        return 'Due Date';
      case 'remark':
        return 'Remark';
      case 'template_id':
        return 'Template';
      case 'process_codes':
        return 'Process Codes';
      case 'process_steps':
        return 'Process Steps';
      case 'step_order':
        return 'Step Order';
      case 'stage_id':
        return 'Stage';
      case 'process_id':
        return 'Process';
      case 'new_template_name':
        return 'Template Name';
      case 'new_template_set_default':
        return 'Set Default';
      case 'order_process_id':
        return 'Order Process';
      case 'target_operator_user_id':
        return 'Target Operator';
      case 'helper_user_id':
        return 'Helper';
      case 'effective_operator_user_id':
        return 'Effective Operator';
      case 'assist_authorization_id':
        return 'Assist Authorization';
      case 'defect_items':
        return 'Defect Items';
      case 'phenomenon':
        return 'Phenomenon';
      case 'reason':
        return 'Reason';
      case 'scrap_replenished':
        return 'Scrap Replenished';
      case 'cause_items':
        return 'Cause Items';
      case 'return_allocations':
        return 'Return Allocations';
      case 'target_order_process_id':
        return 'Target Process';
      case 'progress':
        return 'Progress';
      case 'enabled':
        return 'Enabled';
      case 'pipeline_enabled':
        return 'Pipeline Enabled';
      case 'pipeline_process_codes':
        return 'Pipeline Processes';
      case 'review_remark':
        return 'Review Remark';
      case 'stat_mode':
        return 'Stat Mode';
      case 'end_date':
        return 'End Date';
      case 'product_ids':
        return 'Products';
      case 'stage_ids':
        return 'Stages';
      case 'process_ids':
        return 'Processes';
      case 'operator_user_ids':
        return 'Operators';
      case 'order_status':
        return 'Order Status';
      default:
        return null;
    }
  }

  void _appendIntListQuery(
    Map<String, String> query,
    String key,
    List<int>? values,
  ) {
    if (values == null || values.isEmpty) {
      return;
    }
    final tokens = values
        .where((value) => value > 0)
        .map((value) => value.toString())
        .toList();
    if (tokens.isEmpty) {
      return;
    }
    query[key] = tokens.join(',');
  }

  String? _formatDateOrNull(DateTime? value) {
    if (value == null) {
      return null;
    }
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }
}
