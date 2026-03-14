import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_session.dart';
import '../models/quality_models.dart';
import 'api_exception.dart';

class QualityService {
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

  Future<FirstArticleDetail> getFirstArticleDetail(int recordId) async {
    final uri = Uri.parse('$_basePath/first-articles/$recordId');
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

  Future<String> exportFirstArticles({
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
    return (data['content_base64'] as String?) ?? '';
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

  Future<String> exportQualityStats({
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
    return (data['content_base64'] as String?) ?? '';
  }

  Future<List<QualityTrendItem>> getQualityTrend({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = <String, String>{};
    if (startDate != null) query['start_date'] = _formatDate(startDate);
    if (endDate != null) query['end_date'] = _formatDate(endDate);
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
    String? processCode,
    int topN = 10,
  }) async {
    final query = <String, String>{'top_n': '$topN'};
    if (startDate != null) query['start_date'] = _formatDate(startDate);
    if (endDate != null) query['end_date'] = _formatDate(endDate);
    if (productId != null) query['product_id'] = '$productId';
    if (processCode != null && processCode.isNotEmpty) {
      query['process_code'] = processCode;
    }
    final uri = Uri.parse('${session.baseUrl}/quality/defect-analysis')
        .replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    return DefectAnalysisResult.fromJson(
      json['data'] as Map<String, dynamic>,
    );
  }
}
