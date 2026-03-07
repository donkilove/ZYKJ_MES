import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_session.dart';
import '../models/product_models.dart';
import 'api_exception.dart';

class ProductService {
  ProductService(this.session);

  final AppSession session;

  Map<String, String> get _authHeaders {
    return {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  Future<ProductListResult> listProducts({
    required int page,
    required int pageSize,
    String? keyword,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    final uri = Uri.parse(
      '${session.baseUrl}/products',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }

    final data = json['data'] as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map((entry) => ProductItem.fromJson(entry as Map<String, dynamic>))
        .toList();
    return ProductListResult(total: (data['total'] as int?) ?? 0, items: items);
  }

  Future<void> createProduct({required String name}) async {
    final uri = Uri.parse('${session.baseUrl}/products');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'name': name}),
    );
    final json = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<void> deleteProduct({
    required int productId,
    required String password,
  }) async {
    final uri = Uri.parse('${session.baseUrl}/products/$productId/delete');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'password': password}),
    );
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<ProductParameterListResult> listProductParameters({
    required int productId,
  }) async {
    final uri = Uri.parse('${session.baseUrl}/products/$productId/parameters');
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = json['data'] as Map<String, dynamic>;
    return ProductParameterListResult.fromJson(data);
  }

  Future<ProductParameterUpdateResult> updateProductParameters({
    required int productId,
    required String remark,
    required List<ProductParameterUpdateItem> items,
    bool confirmed = false,
  }) async {
    final uri = Uri.parse('${session.baseUrl}/products/$productId/parameters');
    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'remark': remark,
        'items': items.map((entry) => entry.toJson()).toList(),
        'confirmed': confirmed,
      }),
    );
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = json['data'] as Map<String, dynamic>;
    return ProductParameterUpdateResult.fromJson(data);
  }

  Future<ProductParameterHistoryListResult> listProductParameterHistory({
    required int productId,
    required int page,
    required int pageSize,
  }) async {
    final uri = Uri.parse(
      '${session.baseUrl}/products/$productId/parameter-history',
    ).replace(queryParameters: {'page': '$page', 'page_size': '$pageSize'});
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = json['data'] as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) => ProductParameterHistoryItem.fromJson(
            entry as Map<String, dynamic>,
          ),
        )
        .toList();
    return ProductParameterHistoryListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<ProductItem> updateProductLifecycle({
    required int productId,
    required ProductLifecycleUpdateRequest payload,
  }) async {
    final uri = Uri.parse('${session.baseUrl}/products/$productId/lifecycle');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode(payload.toJson()),
    );
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = json['data'] as Map<String, dynamic>;
    return ProductItem.fromJson(data);
  }

  Future<ProductImpactAnalysisResult> getProductImpactAnalysis({
    required int productId,
    required String operation,
    String? targetStatus,
    int? targetVersion,
  }) async {
    final query = <String, String>{'operation': operation};
    if (targetStatus != null && targetStatus.trim().isNotEmpty) {
      query['target_status'] = targetStatus.trim();
    }
    if (targetVersion != null) {
      query['target_version'] = '$targetVersion';
    }
    final uri = Uri.parse(
      '${session.baseUrl}/products/$productId/impact-analysis',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = json['data'] as Map<String, dynamic>;
    return ProductImpactAnalysisResult.fromJson(data);
  }

  Future<ProductVersionListResult> listProductVersions({
    required int productId,
  }) async {
    final uri = Uri.parse('${session.baseUrl}/products/$productId/versions');
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = json['data'] as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) => ProductVersionItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
    return ProductVersionListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<ProductVersionCompareResult> compareProductVersions({
    required int productId,
    required int fromVersion,
    required int toVersion,
  }) async {
    final uri =
        Uri.parse(
          '${session.baseUrl}/products/$productId/versions/compare',
        ).replace(
          queryParameters: {
            'from_version': '$fromVersion',
            'to_version': '$toVersion',
          },
        );
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = json['data'] as Map<String, dynamic>;
    return ProductVersionCompareResult.fromJson(data);
  }

  Future<ProductRollbackResult> rollbackProduct({
    required int productId,
    required int targetVersion,
    required bool confirmed,
    String? note,
  }) async {
    final uri = Uri.parse('${session.baseUrl}/products/$productId/rollback');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'target_version': targetVersion,
        'confirmed': confirmed,
        'note': note,
      }),
    );
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = json['data'] as Map<String, dynamic>;
    return ProductRollbackResult.fromJson(data);
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
    return '请求失败，状态码 $statusCode';
  }
}
