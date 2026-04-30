import 'dart:convert';

import 'package:mes_client/core/network/http_client.dart' as http;

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/core/network/api_exception.dart';

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
    String? category,
    String? lifecycleStatus,
    bool? hasEffectiveVersion,
    DateTime? updatedAfter,
    DateTime? updatedBefore,
    String? currentVersionKeyword,
    String? currentParamNameKeyword,
    String? currentParamCategoryKeyword,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (category != null && category.trim().isNotEmpty) {
      query['category'] = category.trim();
    }
    if (lifecycleStatus != null && lifecycleStatus.trim().isNotEmpty) {
      query['lifecycle_status'] = lifecycleStatus.trim();
    }
    if (hasEffectiveVersion != null) {
      query['has_effective_version'] = hasEffectiveVersion ? 'true' : 'false';
    }
    if (updatedAfter != null) {
      query['updated_after'] = updatedAfter.toUtc().toIso8601String();
    }
    if (updatedBefore != null) {
      query['updated_before'] = updatedBefore.toUtc().toIso8601String();
    }
    if (currentVersionKeyword != null &&
        currentVersionKeyword.trim().isNotEmpty) {
      query['current_version_keyword'] = currentVersionKeyword.trim();
    }
    if (currentParamNameKeyword != null &&
        currentParamNameKeyword.trim().isNotEmpty) {
      query['current_param_name_keyword'] = currentParamNameKeyword.trim();
    }
    if (currentParamCategoryKeyword != null &&
        currentParamCategoryKeyword.trim().isNotEmpty) {
      query['current_param_category_keyword'] = currentParamCategoryKeyword
          .trim();
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

    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map((entry) => ProductItem.fromJson(entry as Map<String, dynamic>))
        .toList();
    return ProductListResult(total: (data['total'] as int?) ?? 0, items: items);
  }

  Future<ProductListResult> listProductsForParameterQuery({
    required int page,
    required int pageSize,
    String? keyword,
    String? category,
    String? lifecycleStatus,
    bool? hasEffectiveVersion,
    String? effectiveVersionKeyword,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (category != null && category.trim().isNotEmpty) {
      query['category'] = category.trim();
    }
    if (lifecycleStatus != null && lifecycleStatus.trim().isNotEmpty) {
      query['lifecycle_status'] = lifecycleStatus.trim();
    }
    if (hasEffectiveVersion != null) {
      query['has_effective_version'] = hasEffectiveVersion ? 'true' : 'false';
    }
    if (effectiveVersionKeyword != null &&
        effectiveVersionKeyword.trim().isNotEmpty) {
      query['effective_version_keyword'] = effectiveVersionKeyword.trim();
    }
    final uri = Uri.parse(
      '${session.baseUrl}/products/parameter-query',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }

    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map((entry) => ProductItem.fromJson(entry as Map<String, dynamic>))
        .toList();
    return ProductListResult(total: (data['total'] as int?) ?? 0, items: items);
  }

  Future<void> createProduct({
    required String name,
    required String category,
    String remark = '',
  }) async {
    final uri = Uri.parse('${session.baseUrl}/products');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'name': name,
        'category': category.trim(),
        'remark': remark.trim(),
      }),
    );
    final json = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<ProductItem> getProduct({required int productId}) async {
    final uri = Uri.parse('${session.baseUrl}/products/$productId');
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    return ProductItem.fromJson(data);
  }

  Future<ProductDetailResult> getProductDetail({required int productId}) async {
    final uri = Uri.parse('${session.baseUrl}/products/$productId/detail');
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    return ProductDetailResult.fromJson(data);
  }

  Future<ProductItem> updateProduct({
    required int productId,
    required String name,
    required String category,
    String remark = '',
  }) async {
    final uri = Uri.parse('${session.baseUrl}/products/$productId');
    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'name': name.trim(),
        'category': category.trim(),
        'remark': remark.trim(),
      }),
    );
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    return ProductItem.fromJson(data);
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
    int? version,
    bool effectiveOnly = false,
  }) {
    if (effectiveOnly) {
      return getEffectiveProductParameters(productId: productId);
    }
    if (version != null) {
      return getProductVersionParameters(
        productId: productId,
        version: version,
      );
    }
    throw ArgumentError(
      '参数查询必须显式指定 version，或设置 effectiveOnly=true。',
      'version',
    );
  }

  Future<ProductParameterVersionListResult> listProductParameterVersions({
    required int page,
    required int pageSize,
    String? keyword,
    String? category,
    String? versionKeyword,
    String? paramNameKeyword,
    String? paramCategoryKeyword,
    String? lifecycleStatus,
    DateTime? updatedAfter,
    DateTime? updatedBefore,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (category != null && category.trim().isNotEmpty) {
      query['category'] = category.trim();
    }
    if (versionKeyword != null && versionKeyword.trim().isNotEmpty) {
      query['version_keyword'] = versionKeyword.trim();
    }
    if (paramNameKeyword != null && paramNameKeyword.trim().isNotEmpty) {
      query['param_name_keyword'] = paramNameKeyword.trim();
    }
    if (paramCategoryKeyword != null &&
        paramCategoryKeyword.trim().isNotEmpty) {
      query['param_category_keyword'] = paramCategoryKeyword.trim();
    }
    if (lifecycleStatus != null && lifecycleStatus.trim().isNotEmpty) {
      query['lifecycle_status'] = lifecycleStatus.trim();
    }
    if (updatedAfter != null) {
      query['updated_after'] = updatedAfter.toUtc().toIso8601String();
    }
    if (updatedBefore != null) {
      query['updated_before'] = updatedBefore.toUtc().toIso8601String();
    }
    final uri = Uri.parse(
      '${session.baseUrl}/products/parameter-versions',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) => ProductParameterVersionListItem.fromJson(
            entry as Map<String, dynamic>,
          ),
        )
        .toList();
    return ProductParameterVersionListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<ProductParameterListResult> getProductVersionParameters({
    required int productId,
    required int version,
  }) async {
    final uri = Uri.parse(
      '${session.baseUrl}/products/$productId/versions/$version/parameters',
    );
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    return ProductParameterListResult.fromJson(data);
  }

  Future<ProductParameterListResult> getEffectiveProductParameters({
    required int productId,
  }) async {
    final uri = Uri.parse(
      '${session.baseUrl}/products/$productId/effective-parameters',
    );
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    return ProductParameterListResult.fromJson(data);
  }

  Future<ProductParameterUpdateResult> updateProductParameters({
    required int productId,
    required int version,
    required String remark,
    required List<ProductParameterUpdateItem> items,
    bool confirmed = false,
  }) async {
    final uri = Uri.parse(
      '${session.baseUrl}/products/$productId/versions/$version/parameters',
    );
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
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    return ProductParameterUpdateResult.fromJson(data);
  }

  Future<ProductParameterHistoryListResult> listProductParameterHistory({
    required int productId,
    int? version,
    required int page,
    required int pageSize,
  }) async {
    final uri = Uri.parse(
      version != null
          ? '${session.baseUrl}/products/$productId/versions/$version/parameter-history'
          : '${session.baseUrl}/products/$productId/parameter-history',
    ).replace(queryParameters: {'page': '$page', 'page_size': '$pageSize'});
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) => ProductParameterHistoryItem.fromJson(
            entry as Map<String, dynamic>,
          ),
        )
        .toList();
    return ProductParameterHistoryListResult(
      version: data['version'] as int?,
      versionLabel: data['version_label'] as String?,
      lifecycleStatus: data['lifecycle_status'] as String?,
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
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
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
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
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
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
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

  Future<ProductVersionItem> createProductVersion({
    required int productId,
  }) async {
    final uri = Uri.parse('${session.baseUrl}/products/$productId/versions');
    final response = await http.post(uri, headers: _authHeaders, body: '{}');
    final json = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    return ProductVersionItem.fromJson(data);
  }

  Future<ProductVersionItem> copyProductVersion({
    required int productId,
    required int sourceVersion,
  }) async {
    final uri = Uri.parse(
      '${session.baseUrl}/products/$productId/versions/$sourceVersion/copy',
    );
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'source_version': sourceVersion}),
    );
    final json = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    return ProductVersionItem.fromJson(data);
  }

  Future<ProductVersionItem> activateProductVersion({
    required int productId,
    required int version,
    bool confirmed = false,
    int? expectedEffectiveVersion,
  }) async {
    final uri = Uri.parse(
      '${session.baseUrl}/products/$productId/versions/$version/activate',
    );
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'confirmed': confirmed,
        'expected_effective_version': expectedEffectiveVersion,
      }),
    );
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    return ProductVersionItem.fromJson(data);
  }

  Future<ProductVersionItem> disableProductVersion({
    required int productId,
    required int version,
  }) async {
    final uri = Uri.parse(
      '${session.baseUrl}/products/$productId/versions/$version/disable',
    );
    final response = await http.post(uri, headers: _authHeaders, body: '{}');
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    return ProductVersionItem.fromJson(data);
  }

  Future<void> deleteProductVersion({
    required int productId,
    required int version,
  }) async {
    final uri = Uri.parse(
      '${session.baseUrl}/products/$productId/versions/$version',
    );
    final response = await http.delete(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<ProductVersionItem> updateProductVersionNote({
    required int productId,
    required int version,
    required String note,
  }) async {
    final uri = Uri.parse(
      '${session.baseUrl}/products/$productId/versions/$version/note',
    );
    final response = await http.patch(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'note': note}),
    );
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    return ProductVersionItem.fromJson(
      (json['data'] as Map<String, dynamic>?) ?? const {},
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
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
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
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
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

  Future<List<int>> exportProducts({
    String? keyword,
    String? category,
    String? lifecycleStatus,
    bool? hasEffectiveVersion,
    DateTime? updatedAfter,
    DateTime? updatedBefore,
  }) async {
    final query = <String, String>{};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (category != null && category.trim().isNotEmpty) {
      query['category'] = category.trim();
    }
    if (lifecycleStatus != null && lifecycleStatus.trim().isNotEmpty) {
      query['lifecycle_status'] = lifecycleStatus.trim();
    }
    if (hasEffectiveVersion != null) {
      query['has_effective_version'] = hasEffectiveVersion ? 'true' : 'false';
    }
    if (updatedAfter != null) {
      query['updated_after'] = updatedAfter.toUtc().toIso8601String();
    }
    if (updatedBefore != null) {
      query['updated_before'] = updatedBefore.toUtc().toIso8601String();
    }
    final uri = Uri.parse(
      '${session.baseUrl}/products/export/list',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders);
    if (response.statusCode != 200) {
      final json = _decodeBody(response);
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    return response.bodyBytes;
  }

  Future<List<int>> exportProductVersionParameters({
    required int productId,
    required int version,
  }) async {
    final uri = Uri.parse(
      '${session.baseUrl}/products/$productId/versions/$version/export',
    );
    final response = await http.get(uri, headers: _authHeaders);
    if (response.statusCode != 200) {
      final json = _decodeBody(response);
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    return response.bodyBytes;
  }

  Future<List<int>> exportProductParameters({
    String? keyword,
    String? category,
    String? lifecycleStatus,
    String? versionKeyword,
    String? paramKeyword,
    String? paramCategoryKeyword,
    DateTime? updatedAfter,
    DateTime? updatedBefore,
    bool effectiveOnly = false,
  }) async {
    final query = <String, String>{};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (category != null && category.trim().isNotEmpty) {
      query['category'] = category.trim();
    }
    if (lifecycleStatus != null && lifecycleStatus.trim().isNotEmpty) {
      query['lifecycle_status'] = lifecycleStatus.trim();
    }
    if (versionKeyword != null && versionKeyword.trim().isNotEmpty) {
      query['version_keyword'] = versionKeyword.trim();
    }
    if (paramKeyword != null && paramKeyword.trim().isNotEmpty) {
      query['param_keyword'] = paramKeyword.trim();
    }
    if (paramCategoryKeyword != null &&
        paramCategoryKeyword.trim().isNotEmpty) {
      query['param_category_keyword'] = paramCategoryKeyword.trim();
    }
    if (updatedAfter != null) {
      query['updated_after'] = updatedAfter.toUtc().toIso8601String();
    }
    if (updatedBefore != null) {
      query['updated_before'] = updatedBefore.toUtc().toIso8601String();
    }
    if (effectiveOnly) {
      query['effective_only'] = 'true';
    }
    final uri = Uri.parse(
      '${session.baseUrl}/products/parameters/export',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders);
    if (response.statusCode != 200) {
      final json = _decodeBody(response);
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    return response.bodyBytes;
  }
}
