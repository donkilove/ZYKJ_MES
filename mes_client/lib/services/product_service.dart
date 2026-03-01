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
  }) async {
    final uri = Uri.parse('${session.baseUrl}/products/$productId/parameters');
    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'remark': remark,
        'items': items.map((entry) => entry.toJson()).toList(),
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
