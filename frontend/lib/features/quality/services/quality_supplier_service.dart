import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';
import 'package:mes_client/core/network/api_exception.dart';

class QualitySupplierService {
  QualitySupplierService(this.session);

  final AppSession session;

  String get _basePath => '${session.baseUrl}/quality/suppliers';

  Map<String, String> get _authHeaders {
    return {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  Future<QualitySupplierListResult> listSuppliers({
    String? keyword,
    bool? enabled,
  }) async {
    final query = <String, String>{};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (enabled != null) {
      query['enabled'] = '$enabled';
    }

    final uri = Uri.parse(
      _basePath,
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return QualitySupplierListResult.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<QualitySupplierItem> createSupplier(
    QualitySupplierUpsertPayload payload,
  ) async {
    final response = await http.post(
      Uri.parse(_basePath),
      headers: _authHeaders,
      body: jsonEncode(payload.toJson()),
    ).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return QualitySupplierItem.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<QualitySupplierItem> updateSupplier(
    int supplierId,
    QualitySupplierUpsertPayload payload,
  ) async {
    final response = await http.put(
      Uri.parse('$_basePath/$supplierId'),
      headers: _authHeaders,
      body: jsonEncode(payload.toJson()),
    ).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return QualitySupplierItem.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<void> deleteSupplier(int supplierId) async {
    final response = await http.delete(
      Uri.parse('$_basePath/$supplierId'),
      headers: _authHeaders,
    ).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
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
}
