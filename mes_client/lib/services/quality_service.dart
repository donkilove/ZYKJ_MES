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

  Future<FirstArticleListResult> listFirstArticles({
    DateTime? date,
    String? keyword,
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

  Future<QualityStatsOverview> getQualityOverview({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = <String, String>{};
    if (startDate != null) {
      query['start_date'] = _formatDate(startDate);
    }
    if (endDate != null) {
      query['end_date'] = _formatDate(endDate);
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
  }) async {
    final query = <String, String>{};
    if (startDate != null) {
      query['start_date'] = _formatDate(startDate);
    }
    if (endDate != null) {
      query['end_date'] = _formatDate(endDate);
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
  }) async {
    final query = <String, String>{};
    if (startDate != null) {
      query['start_date'] = _formatDate(startDate);
    }
    if (endDate != null) {
      query['end_date'] = _formatDate(endDate);
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
}
