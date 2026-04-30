import 'dart:convert';

import 'package:mes_client/core/network/http_client.dart' as http;

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/quality/services/repair_scrap_service.dart';

class QualityService implements RepairScrapService {
  QualityService(this.session);

  final AppSession session;

  String get _basePath => '${session.baseUrl}/quality';

  Map<String, String> get _authHeaders {
    return {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  String _normalizeResultCode(String value) {
    switch (value) {
      case 'pass':
        return 'passed';
      case 'fail':
        return 'failed';
      default:
        return value;
    }
  }

  Future<FirstArticleListResult> listFirstArticles({
    DateTime? date,
    String? keyword,
    String? result,
    String? productName,
    String? processCode,
    String? operatorUsername,
    int page = 1,
    int pageSize = 20,
  }) async {
    final normalizedPageSize = pageSize.clamp(1, 200).toInt();
    final query = <String, String>{
      'page': '$page',
      'page_size': '$normalizedPageSize',
    };
    if (date != null) {
      query['date'] = _formatDate(date);
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (result != null && result.isNotEmpty) {
      query['result'] = _normalizeResultCode(result);
    }
    if (productName != null && productName.trim().isNotEmpty) {
      query['product_name'] = productName.trim();
    }
    if (processCode != null && processCode.trim().isNotEmpty) {
      query['process_code'] = processCode.trim();
    }
    if (operatorUsername != null && operatorUsername.trim().isNotEmpty) {
      query['operator_username'] = operatorUsername.trim();
    }

    final uri = Uri.parse(
      '$_basePath/first-articles',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return FirstArticleListResult.fromJson(data);
  }

  Future<FirstArticleDetail> getFirstArticleDetail(int recordId) {
    return _getFirstArticleDetail('$_basePath/first-articles/$recordId');
  }

  Future<FirstArticleDetail> getFirstArticleDispositionDetail(int recordId) {
    return _getFirstArticleDetail(
      '$_basePath/first-articles/$recordId/disposition-detail',
    );
  }

  Future<FirstArticleDetail> _getFirstArticleDetail(String path) async {
    final uri = Uri.parse(path);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return FirstArticleDetail.fromJson(data);
  }

  Future<QualityExportFile> exportFirstArticles({
    DateTime? date,
    String? keyword,
    String? result,
    String? productName,
    String? processCode,
    String? operatorUsername,
  }) async {
    final payload = <String, dynamic>{};
    if (date != null) payload['query_date'] = _formatDate(date);
    if (keyword != null && keyword.trim().isNotEmpty) {
      payload['keyword'] = keyword.trim();
    }
    if (result != null && result.isNotEmpty) {
      payload['result'] = _normalizeResultCode(result);
    }
    if (productName != null && productName.trim().isNotEmpty) {
      payload['product_name'] = productName.trim();
    }
    if (processCode != null && processCode.trim().isNotEmpty) {
      payload['process_code'] = processCode.trim();
    }
    if (operatorUsername != null && operatorUsername.trim().isNotEmpty) {
      payload['operator_username'] = operatorUsername.trim();
    }

    final uri = Uri.parse('$_basePath/first-articles/export');
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
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return QualityExportFile.fromJson(
      data,
      fallbackFilename: 'first_articles.csv',
    );
  }

  Future<void> submitDisposition({
    required int recordId,
    required String dispositionOpinion,
    required String recheckResult,
    required String finalJudgment,
    String? operator_,
  }) async {
    final uri = Uri.parse('$_basePath/first-articles/$recordId/disposition');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'disposition_opinion': dispositionOpinion,
        'recheck_result': recheckResult,
        'final_judgment': finalJudgment,
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<List<QualityProductStatItem>> getQualityProductStats({
    DateTime? startDate,
    DateTime? endDate,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async {
    final query = <String, String>{};
    if (startDate != null) query['start_date'] = _formatDate(startDate);
    if (endDate != null) query['end_date'] = _formatDate(endDate);
    if (productName != null && productName.trim().isNotEmpty) {
      query['product_name'] = productName.trim();
    }
    if (processCode != null && processCode.trim().isNotEmpty) {
      query['process_code'] = processCode.trim();
    }
    if (operatorUsername != null && operatorUsername.trim().isNotEmpty) {
      query['operator_username'] = operatorUsername.trim();
    }
    if (result != null && result.isNotEmpty) {
      query['result'] = result;
    }
    final uri = Uri.parse(
      '$_basePath/stats/products',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return (data['items'] as List<dynamic>? ?? const [])
        .map((e) => QualityProductStatItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<QualityExportFile> exportQualityStats({
    DateTime? startDate,
    DateTime? endDate,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async {
    final payload = <String, dynamic>{};
    if (startDate != null) payload['start_date'] = _formatDate(startDate);
    if (endDate != null) payload['end_date'] = _formatDate(endDate);
    if (productName != null && productName.trim().isNotEmpty) {
      payload['product_name'] = productName.trim();
    }
    if (processCode != null && processCode.trim().isNotEmpty) {
      payload['process_code'] = processCode.trim();
    }
    if (operatorUsername != null && operatorUsername.trim().isNotEmpty) {
      payload['operator_username'] = operatorUsername.trim();
    }
    if (result != null && result.isNotEmpty) {
      payload['result'] = result;
    }

    final uri = Uri.parse('$_basePath/stats/export');
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
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return QualityExportFile.fromJson(
      data,
      fallbackFilename: 'quality_stats.csv',
    );
  }

  Future<List<QualityTrendItem>> getQualityTrend({
    DateTime? startDate,
    DateTime? endDate,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async {
    final query = <String, String>{};
    if (startDate != null) query['start_date'] = _formatDate(startDate);
    if (endDate != null) query['end_date'] = _formatDate(endDate);
    if (productName != null && productName.trim().isNotEmpty) {
      query['product_name'] = productName.trim();
    }
    if (processCode != null && processCode.trim().isNotEmpty) {
      query['process_code'] = processCode.trim();
    }
    if (operatorUsername != null && operatorUsername.trim().isNotEmpty) {
      query['operator_username'] = operatorUsername.trim();
    }
    if (result != null && result.isNotEmpty) {
      query['result'] = result;
    }
    final uri = Uri.parse(
      '$_basePath/trend',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return (data['items'] as List<dynamic>? ?? const [])
        .map((e) => QualityTrendItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<QualityExportFile> exportQualityTrend({
    DateTime? startDate,
    DateTime? endDate,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async {
    final payload = <String, dynamic>{};
    if (startDate != null) payload['start_date'] = _formatDate(startDate);
    if (endDate != null) payload['end_date'] = _formatDate(endDate);
    if (productName != null && productName.trim().isNotEmpty) {
      payload['product_name'] = productName.trim();
    }
    if (processCode != null && processCode.trim().isNotEmpty) {
      payload['process_code'] = processCode.trim();
    }
    if (operatorUsername != null && operatorUsername.trim().isNotEmpty) {
      payload['operator_username'] = operatorUsername.trim();
    }
    if (result != null && result.isNotEmpty) {
      payload['result'] = result;
    }
    final uri = Uri.parse('$_basePath/trend/export');
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
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return QualityExportFile.fromJson(
      data,
      fallbackFilename: 'quality_trend.csv',
    );
  }

  Future<QualityStatsOverview> getQualityOverview({
    DateTime? startDate,
    DateTime? endDate,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async {
    final query = <String, String>{};
    if (startDate != null) {
      query['start_date'] = _formatDate(startDate);
    }
    if (endDate != null) {
      query['end_date'] = _formatDate(endDate);
    }
    if (productName != null && productName.trim().isNotEmpty) {
      query['product_name'] = productName.trim();
    }
    if (processCode != null && processCode.trim().isNotEmpty) {
      query['process_code'] = processCode.trim();
    }
    if (operatorUsername != null && operatorUsername.trim().isNotEmpty) {
      query['operator_username'] = operatorUsername.trim();
    }
    if (result != null && result.isNotEmpty) {
      query['result'] = result;
    }
    final uri = Uri.parse(
      '$_basePath/stats/overview',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return QualityStatsOverview.fromJson(data);
  }

  Future<List<QualityProcessStatItem>> getQualityProcessStats({
    DateTime? startDate,
    DateTime? endDate,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async {
    final query = <String, String>{};
    if (startDate != null) {
      query['start_date'] = _formatDate(startDate);
    }
    if (endDate != null) {
      query['end_date'] = _formatDate(endDate);
    }
    if (productName != null && productName.trim().isNotEmpty) {
      query['product_name'] = productName.trim();
    }
    if (processCode != null && processCode.trim().isNotEmpty) {
      query['process_code'] = processCode.trim();
    }
    if (operatorUsername != null && operatorUsername.trim().isNotEmpty) {
      query['operator_username'] = operatorUsername.trim();
    }
    if (result != null && result.isNotEmpty) {
      query['result'] = result;
    }
    final uri = Uri.parse(
      '$_basePath/stats/processes',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) =>
              QualityProcessStatItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<QualityOperatorStatItem>> getQualityOperatorStats({
    DateTime? startDate,
    DateTime? endDate,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? result,
  }) async {
    final query = <String, String>{};
    if (startDate != null) {
      query['start_date'] = _formatDate(startDate);
    }
    if (endDate != null) {
      query['end_date'] = _formatDate(endDate);
    }
    if (productName != null && productName.trim().isNotEmpty) {
      query['product_name'] = productName.trim();
    }
    if (processCode != null && processCode.trim().isNotEmpty) {
      query['process_code'] = processCode.trim();
    }
    if (operatorUsername != null && operatorUsername.trim().isNotEmpty) {
      query['operator_username'] = operatorUsername.trim();
    }
    if (result != null && result.isNotEmpty) {
      query['result'] = result;
    }
    final uri = Uri.parse(
      '$_basePath/stats/operators',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) =>
              QualityOperatorStatItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
  }

  Future<ScrapStatisticsListResult> listQualityScrapStatistics({
    String? keyword,
    String? progress,
    String? productName,
    String? processCode,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'page_size': '${pageSize.clamp(1, 200)}',
    };
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (progress != null && progress.trim().isNotEmpty) {
      query['progress'] = progress.trim();
    }
    if (productName != null && productName.trim().isNotEmpty) {
      query['product_name'] = productName.trim();
    }
    if (processCode != null && processCode.trim().isNotEmpty) {
      query['process_code'] = processCode.trim();
    }
    if (startDate != null) {
      query['start_date'] = _formatDate(startDate);
    }
    if (endDate != null) {
      query['end_date'] = _formatDate(endDate);
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
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return ScrapStatisticsListResult(
      total: (data['total'] as int?) ?? 0,
      items: (data['items'] as List<dynamic>? ?? const [])
          .map((e) => ScrapStatisticsItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

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
  }) {
    return listQualityScrapStatistics(
      keyword: keyword,
      progress: progress,
      productName: productName,
      processCode: processCode,
      startDate: startDate,
      endDate: endDate,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<ScrapStatisticsItem> getQualityScrapStatisticsDetail({
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
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return ScrapStatisticsItem.fromJson(data);
  }

  @override
  Future<ScrapStatisticsItem> getScrapStatisticsDetail({required int scrapId}) {
    return getQualityScrapStatisticsDetail(scrapId: scrapId);
  }

  @override
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
        'start_date': startDate == null ? null : _formatDate(startDate),
        'end_date': endDate == null ? null : _formatDate(endDate),
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return ProductionExportResult.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<RepairOrderListResult> listQualityRepairOrders({
    String? keyword,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'page_size': '${pageSize.clamp(1, 200)}',
    };
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }
    if (startDate != null) {
      query['start_date'] = _formatDate(startDate);
    }
    if (endDate != null) {
      query['end_date'] = _formatDate(endDate);
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
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return RepairOrderListResult(
      total: (data['total'] as int?) ?? 0,
      items: (data['items'] as List<dynamic>? ?? const [])
          .map((e) => RepairOrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
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
  }) {
    return listQualityRepairOrders(
      keyword: keyword,
      status: status,
      startDate: startDate,
      endDate: endDate,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<RepairOrderDetailItem> getQualityRepairOrderDetail({
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
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return RepairOrderDetailItem.fromJson(data);
  }

  @override
  Future<RepairOrderDetailItem> getRepairOrderDetail({
    required int repairOrderId,
  }) {
    return getQualityRepairOrderDetail(repairOrderId: repairOrderId);
  }

  @override
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
    return RepairOrderPhenomenaSummaryResult.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  @override
  Future<ProductionOrderDetail> getOrderDetail({required int orderId}) async {
    final uri = Uri.parse('${session.baseUrl}/production/orders/$orderId');
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return ProductionOrderDetail.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  @override
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
    return RepairOrderItem.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  @override
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
        'start_date': startDate == null ? null : _formatDate(startDate),
        'end_date': endDate == null ? null : _formatDate(endDate),
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return ProductionExportResult.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
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
    final message = body['message'];
    if (message is String && message.isNotEmpty) {
      return message;
    }
    return '请求失败（状态码 $statusCode）';
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  Future<DefectAnalysisResult> getDefectAnalysis({
    DateTime? startDate,
    DateTime? endDate,
    int? productId,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? phenomenon,
    int topN = 10,
  }) async {
    final query = <String, String>{'top_n': '$topN'};
    if (startDate != null) query['start_date'] = _formatDate(startDate);
    if (endDate != null) query['end_date'] = _formatDate(endDate);
    if (productId != null) query['product_id'] = '$productId';
    if (productName != null && productName.isNotEmpty) {
      query['product_name'] = productName;
    }
    if (processCode != null && processCode.isNotEmpty) {
      query['process_code'] = processCode;
    }
    if (operatorUsername != null && operatorUsername.isNotEmpty) {
      query['operator_username'] = operatorUsername;
    }
    if (phenomenon != null && phenomenon.isNotEmpty) {
      query['phenomenon'] = phenomenon;
    }
    final uri = Uri.parse(
      '${session.baseUrl}/quality/defect-analysis',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    return DefectAnalysisResult.fromJson(
      (json['data'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Future<QualityExportFile> exportDefectAnalysis({
    DateTime? startDate,
    DateTime? endDate,
    int? productId,
    String? productName,
    String? processCode,
    String? operatorUsername,
    String? phenomenon,
  }) async {
    final query = <String, String>{};
    if (startDate != null) query['start_date'] = _formatDate(startDate);
    if (endDate != null) query['end_date'] = _formatDate(endDate);
    if (productId != null) query['product_id'] = '$productId';
    if (productName != null && productName.isNotEmpty) {
      query['product_name'] = productName;
    }
    if (processCode != null && processCode.isNotEmpty) {
      query['process_code'] = processCode;
    }
    if (operatorUsername != null && operatorUsername.isNotEmpty) {
      query['operator_username'] = operatorUsername;
    }
    if (phenomenon != null && phenomenon.isNotEmpty) {
      query['phenomenon'] = phenomenon;
    }
    final uri = Uri.parse(
      '${session.baseUrl}/quality/defect-analysis/export',
    ).replace(queryParameters: query);
    final response = await http.post(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return QualityExportFile.fromJson(
      data,
      fallbackFilename: 'defect_analysis.csv',
    );
  }
}
