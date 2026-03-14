import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_session.dart';
import '../models/craft_models.dart';
import 'api_exception.dart';

class CraftService {
  CraftService(this.session);

  final AppSession session;

  String get _basePath => '${session.baseUrl}/craft';

  Map<String, String> get _authHeaders {
    return {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  Future<CraftStageListResult> listStages({
    int page = 1,
    int pageSize = 200,
    String? keyword,
    bool? enabled,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (enabled != null) {
      query['enabled'] = '$enabled';
    }
    final uri = Uri.parse('$_basePath/stages').replace(queryParameters: query);
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
        .map((entry) => CraftStageItem.fromJson(entry as Map<String, dynamic>))
        .toList();
    return CraftStageListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<CraftStageItem> createStage({
    required String code,
    required String name,
    required int sortOrder,
  }) async {
    final uri = Uri.parse('$_basePath/stages');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'code': code, 'name': name, 'sort_order': sortOrder}),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftStageItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<CraftStageItem> updateStage({
    required int stageId,
    required String code,
    required String name,
    required int sortOrder,
    required bool isEnabled,
  }) async {
    final uri = Uri.parse('$_basePath/stages/$stageId');
    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'code': code,
        'name': name,
        'sort_order': sortOrder,
        'is_enabled': isEnabled,
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftStageItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> deleteStage({required int stageId}) async {
    final uri = Uri.parse('$_basePath/stages/$stageId');
    final response = await http.delete(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<CraftProcessListResult> listProcesses({
    int page = 1,
    int pageSize = 500,
    String? keyword,
    int? stageId,
    bool? enabled,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (stageId != null) {
      query['stage_id'] = '$stageId';
    }
    if (enabled != null) {
      query['enabled'] = '$enabled';
    }
    final uri = Uri.parse(
      '$_basePath/processes',
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
          (entry) => CraftProcessItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
    return CraftProcessListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<CraftProcessItem> createProcess({
    required String code,
    required String name,
    required int stageId,
  }) async {
    final uri = Uri.parse('$_basePath/processes');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'code': code, 'name': name, 'stage_id': stageId}),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftProcessItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<CraftProcessItem> updateProcess({
    required int processId,
    required String code,
    required String name,
    required int stageId,
    required bool isEnabled,
  }) async {
    final uri = Uri.parse('$_basePath/processes/$processId');
    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'code': code,
        'name': name,
        'stage_id': stageId,
        'is_enabled': isEnabled,
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftProcessItem.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> deleteProcess({required int processId}) async {
    final uri = Uri.parse('$_basePath/processes/$processId');
    final response = await http.delete(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<CraftTemplateListResult> listTemplates({
    int page = 1,
    int pageSize = 500,
    int? productId,
    String? keyword,
    bool? enabled = true,
    String? lifecycleStatus,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (productId != null) {
      query['product_id'] = '$productId';
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (enabled != null) {
      query['enabled'] = '$enabled';
    }
    if (lifecycleStatus != null && lifecycleStatus.trim().isNotEmpty) {
      query['lifecycle_status'] = lifecycleStatus.trim().toLowerCase();
    }
    final uri = Uri.parse(
      '$_basePath/templates',
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
          (entry) => CraftTemplateItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
    return CraftTemplateListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<CraftSystemMasterTemplateItem?> getSystemMasterTemplate() async {
    final uri = Uri.parse('$_basePath/system-master-template');
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return CraftSystemMasterTemplateItem.fromJson(data);
    }
    return null;
  }

  Future<CraftSystemMasterTemplateItem> createSystemMasterTemplate({
    required List<CraftTemplateStepPayload> steps,
  }) async {
    final uri = Uri.parse('$_basePath/system-master-template');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'steps': steps.map((item) => item.toJson()).toList()}),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftSystemMasterTemplateItem.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<CraftSystemMasterTemplateItem> updateSystemMasterTemplate({
    required List<CraftTemplateStepPayload> steps,
  }) async {
    final uri = Uri.parse('$_basePath/system-master-template');
    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'steps': steps.map((item) => item.toJson()).toList()}),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftSystemMasterTemplateItem.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<CraftTemplateDetail> getTemplateDetail({
    required int templateId,
  }) async {
    final uri = Uri.parse('$_basePath/templates/$templateId');
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateDetail.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<CraftTemplateDetail> createTemplate({
    required int productId,
    required String templateName,
    required bool isDefault,
    required List<CraftTemplateStepPayload> steps,
    String lifecycleStatus = 'draft',
  }) async {
    final uri = Uri.parse('$_basePath/templates');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'product_id': productId,
        'template_name': templateName,
        'is_default': isDefault,
        'lifecycle_status': lifecycleStatus,
        'steps': steps.map((item) => item.toJson()).toList(),
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateDetail.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<CraftTemplateUpdateResult> updateTemplate({
    required int templateId,
    required String templateName,
    required bool isDefault,
    required bool isEnabled,
    required List<CraftTemplateStepPayload> steps,
    bool syncOrders = true,
  }) async {
    final uri = Uri.parse('$_basePath/templates/$templateId');
    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'template_name': templateName,
        'is_default': isDefault,
        'is_enabled': isEnabled,
        'steps': steps.map((item) => item.toJson()).toList(),
        'sync_orders': syncOrders,
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateUpdateResult.fromJson(
      body['data'] as Map<String, dynamic>,
    );
  }

  Future<CraftTemplateImpactAnalysis> getTemplateImpactAnalysis({
    required int templateId,
  }) async {
    final uri = Uri.parse('$_basePath/templates/$templateId/impact-analysis');
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateImpactAnalysis.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<CraftTemplateUpdateResult> publishTemplate({
    required int templateId,
    required bool applyOrderSync,
    required bool confirmed,
    String? note,
  }) async {
    final uri = Uri.parse('$_basePath/templates/$templateId/publish');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'apply_order_sync': applyOrderSync,
        'confirmed': confirmed,
        'note': note,
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateUpdateResult.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<CraftTemplateVersionListResult> listTemplateVersions({
    required int templateId,
  }) async {
    final uri = Uri.parse('$_basePath/templates/$templateId/versions');
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) =>
              CraftTemplateVersionItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
    return CraftTemplateVersionListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<CraftTemplateVersionCompareResult> compareTemplateVersions({
    required int templateId,
    required int fromVersion,
    required int toVersion,
  }) async {
    final uri = Uri.parse('$_basePath/templates/$templateId/versions/compare')
        .replace(
          queryParameters: {
            'from_version': '$fromVersion',
            'to_version': '$toVersion',
          },
        );
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateVersionCompareResult.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<CraftTemplateUpdateResult> rollbackTemplate({
    required int templateId,
    required int targetVersion,
    required bool applyOrderSync,
    required bool confirmed,
    String? note,
  }) async {
    final uri = Uri.parse('$_basePath/templates/$templateId/rollback');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'target_version': targetVersion,
        'apply_order_sync': applyOrderSync,
        'confirmed': confirmed,
        'note': note,
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateUpdateResult.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<CraftTemplateBatchExportResult> exportTemplates({
    int? productId,
    bool? enabled,
    String? lifecycleStatus,
  }) async {
    final query = <String, String>{};
    if (productId != null) {
      query['product_id'] = '$productId';
    }
    if (enabled != null) {
      query['enabled'] = '$enabled';
    }
    if (lifecycleStatus != null && lifecycleStatus.trim().isNotEmpty) {
      query['lifecycle_status'] = lifecycleStatus.trim().toLowerCase();
    }
    final uri = Uri.parse(
      '$_basePath/templates/export',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateBatchExportResult.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<CraftTemplateBatchImportResult> importTemplates({
    required List<CraftTemplateBatchImportItem> items,
    bool overwriteExisting = false,
    bool publishAfterImport = false,
  }) async {
    final uri = Uri.parse('$_basePath/templates/import');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'overwrite_existing': overwriteExisting,
        'publish_after_import': publishAfterImport,
        'items': items.map((item) => item.toJson()).toList(),
      }),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateBatchImportResult.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<void> deleteTemplate({required int templateId}) async {
    final uri = Uri.parse('$_basePath/templates/$templateId');
    final response = await http.delete(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<CraftTemplateDetail> copyTemplate({
    required int templateId,
    required String newName,
  }) async {
    final uri = Uri.parse('$_basePath/templates/$templateId/copy');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'new_name': newName}),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateDetail.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<CraftTemplateDetail> copyTemplateToProduct({
    required int templateId,
    required int targetProductId,
    required String newName,
  }) async {
    final uri = Uri.parse('$_basePath/templates/$templateId/copy-to-product');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'target_product_id': targetProductId, 'new_name': newName}),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateDetail.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<CraftTemplateDetail> copySystemMasterToProduct({
    required int productId,
    required String newName,
  }) async {
    final uri = Uri.parse('$_basePath/system-master-template/copy-to-product');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'product_id': productId, 'new_name': newName}),
    );
    final body = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateDetail.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<CraftTemplateDetail> archiveTemplate({required int templateId}) async {
    final uri = Uri.parse('$_basePath/templates/$templateId/archive');
    final response = await http.post(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateDetail.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<CraftTemplateDetail> unarchiveTemplate({required int templateId}) async {
    final uri = Uri.parse('$_basePath/templates/$templateId/unarchive');
    final response = await http.post(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateDetail.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<CraftKanbanProcessMetricsResult> getCraftKanbanProcessMetrics({
    required int productId,
    int limit = 5,
    int? stageId,
    int? processId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = <String, String>{
      'product_id': '$productId',
      'limit': '$limit',
    };
    if (stageId != null) query['stage_id'] = '$stageId';
    if (processId != null) query['process_id'] = '$processId';
    if (startDate != null) query['start_date'] = startDate.toUtc().toIso8601String();
    if (endDate != null) query['end_date'] = endDate.toUtc().toIso8601String();
    final uri = Uri.parse(
      '$_basePath/kanban/process-metrics',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftKanbanProcessMetricsResult.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }


  Future<CraftStageReferenceResult> getStageReferences({
    required int stageId,
  }) async {
    final uri = Uri.parse('$_basePath/stages/$stageId/references');
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftStageReferenceResult.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<CraftProcessReferenceResult> getProcessReferences({
    required int processId,
  }) async {
    final uri = Uri.parse('$_basePath/processes/$processId/references');
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftProcessReferenceResult.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<CraftTemplateReferenceResult> getTemplateReferences({
    required int templateId,
  }) async {
    final uri = Uri.parse('$_basePath/templates/$templateId/references');
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateReferenceResult.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<String> exportStages({String? keyword, bool? enabled}) async {
    final query = <String, String>{};
    if (keyword != null && keyword.trim().isNotEmpty) query['keyword'] = keyword.trim();
    if (enabled != null) query['enabled'] = '$enabled';
    final uri = Uri.parse('$_basePath/stages/export').replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(_extractErrorMessage(body, response.statusCode), response.statusCode);
    }
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return (data['content_base64'] as String?) ?? '';
  }

  Future<String> exportProcesses({String? keyword, int? stageId, bool? enabled}) async {
    final query = <String, String>{};
    if (keyword != null && keyword.trim().isNotEmpty) query['keyword'] = keyword.trim();
    if (stageId != null) query['stage_id'] = '$stageId';
    if (enabled != null) query['enabled'] = '$enabled';
    final uri = Uri.parse('$_basePath/processes/export').replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(_extractErrorMessage(body, response.statusCode), response.statusCode);
    }
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return (data['content_base64'] as String?) ?? '';
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    if (response.body.isEmpty) {
      return {};
    }
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {'detail': response.body};
    }
  }

  String _extractErrorMessage(Map<String, dynamic> body, int statusCode) {
    final detail = body['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
    if (detail is Map<String, dynamic>) {
      final message = detail['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
    final message = body['message'];
    if (message is String && message.isNotEmpty) {
      return message;
    }
    return '请求失败，状态码 $statusCode';
  }
}
