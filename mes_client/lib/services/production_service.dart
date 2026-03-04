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
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }
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

  Future<ProductionOrderItem> createOrder({
    required String orderCode,
    required int productId,
    required int quantity,
    required List<String> processCodes,
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

  Future<MyOrderListResult> listMyOrders({
    required int page,
    required int pageSize,
    String? keyword,
  }) async {
    final normalizedPageSize = pageSize.clamp(1, 200).toInt();
    final query = <String, String>{
      'page': '$page',
      'page_size': '$normalizedPageSize',
    };
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
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

  Future<ProductionActionResult> submitFirstArticle({
    required int orderId,
    required int orderProcessId,
    required String verificationCode,
    String? remark,
  }) async {
    final uri = Uri.parse('$_basePath/orders/$orderId/first-article');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'order_process_id': orderProcessId,
        'verification_code': verificationCode,
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
    return ProductionActionResult.fromJson(data);
  }

  Future<ProductionActionResult> endProduction({
    required int orderId,
    required int orderProcessId,
    required int quantity,
    String? remark,
  }) async {
    final uri = Uri.parse('$_basePath/orders/$orderId/end-production');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'order_process_id': orderProcessId,
        'quantity': quantity,
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
