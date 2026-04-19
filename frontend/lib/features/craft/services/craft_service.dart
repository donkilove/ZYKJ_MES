import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/core/network/api_exception.dart';

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
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }

    final data = (body['data'] as Map<String, dynamic>?) ?? const {};
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map((entry) => CraftStageItem.fromJson(entry as Map<String, dynamic>))
        .toList();
    return CraftStageListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<CraftStageLightListResult> listStageLightOptions({
    bool? enabled = true,
  }) async {
    final query = <String, String>{};
    if (enabled != null) {
      query['enabled'] = '$enabled';
    }
    final uri = Uri.parse(
      '$_basePath/stages/light',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = (body['data'] as Map<String, dynamic>?) ?? const {};
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) =>
              CraftStageLightItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
    return CraftStageLightListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<CraftStageItem> createStage({
    required String code,
    required String name,
    required int sortOrder,
    String remark = '',
  }) async {
    final uri = Uri.parse('$_basePath/stages');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'code': code,
        'name': name,
        'sort_order': sortOrder,
        'remark': remark,
      }),
    ).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftStageItem.fromJson((body['data'] as Map<String, dynamic>?) ?? const {});
  }

  Future<CraftStageItem> updateStage({
    required int stageId,
    required String code,
    required String name,
    required int sortOrder,
    required bool isEnabled,
    String? remark,
  }) async {
    final uri = Uri.parse('$_basePath/stages/$stageId');
    final payload = <String, dynamic>{
      'code': code,
      'name': name,
      'sort_order': sortOrder,
      'is_enabled': isEnabled,
    };
    if (remark != null) {
      payload['remark'] = remark;
    }
    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftStageItem.fromJson((body['data'] as Map<String, dynamic>?) ?? const {});
  }

  Future<void> deleteStage({required int stageId}) async {
    final uri = Uri.parse('$_basePath/stages/$stageId');
    final response = await http.delete(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<CraftStageItem> getStageDetail({
    int? stageId,
    String? stageCode,
  }) async {
    final query = <String, String>{};
    if (stageId != null) {
      query['stage_id'] = '$stageId';
    }
    if (stageCode != null && stageCode.trim().isNotEmpty) {
      query['stage_code'] = stageCode.trim();
    }
    final uri = Uri.parse(
      '$_basePath/stages/detail',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftStageItem.fromJson((body['data'] as Map<String, dynamic>?) ?? const {});
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
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }

    final data = (body['data'] as Map<String, dynamic>?) ?? const {};
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

  Future<CraftProcessLightListResult> listProcessLightOptions({
    int? stageId,
    bool? enabled = true,
  }) async {
    final query = <String, String>{};
    if (stageId != null) {
      query['stage_id'] = '$stageId';
    }
    if (enabled != null) {
      query['enabled'] = '$enabled';
    }
    final uri = Uri.parse(
      '$_basePath/processes/light',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    final data = (body['data'] as Map<String, dynamic>?) ?? const {};
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) =>
              CraftProcessLightItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
    return CraftProcessLightListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<CraftProcessItem> createProcess({
    required String code,
    required String name,
    required int stageId,
    String remark = '',
  }) async {
    final uri = Uri.parse('$_basePath/processes');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'code': code,
        'name': name,
        'stage_id': stageId,
        'remark': remark,
      }),
    ).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftProcessItem.fromJson((body['data'] as Map<String, dynamic>?) ?? const {});
  }

  Future<CraftProcessItem> updateProcess({
    required int processId,
    required String code,
    required String name,
    required int stageId,
    required bool isEnabled,
    String? remark,
  }) async {
    final uri = Uri.parse('$_basePath/processes/$processId');
    final payload = <String, dynamic>{
      'code': code,
      'name': name,
      'stage_id': stageId,
      'is_enabled': isEnabled,
    };
    if (remark != null) {
      payload['remark'] = remark;
    }
    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftProcessItem.fromJson((body['data'] as Map<String, dynamic>?) ?? const {});
  }

  Future<void> deleteProcess({required int processId}) async {
    final uri = Uri.parse('$_basePath/processes/$processId');
    final response = await http.delete(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<CraftProcessItem> getProcessDetail({
    int? processId,
    String? processCode,
  }) async {
    final query = <String, String>{};
    if (processId != null) {
      query['process_id'] = '$processId';
    }
    if (processCode != null && processCode.trim().isNotEmpty) {
      query['process_code'] = processCode.trim();
    }
    final uri = Uri.parse(
      '$_basePath/processes/detail',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftProcessItem.fromJson((body['data'] as Map<String, dynamic>?) ?? const {});
  }

  Future<CraftTemplateListResult> listTemplates({
    int page = 1,
    int pageSize = 500,
    int? productId,
    String? keyword,
    String? productCategory,
    bool? isDefault,
    bool? enabled = true,
    String? lifecycleStatus,
    DateTime? updatedFrom,
    DateTime? updatedTo,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (productId != null) {
      query['product_id'] = '$productId';
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (productCategory != null && productCategory.trim().isNotEmpty) {
      query['product_category'] = productCategory.trim();
    }
    if (isDefault != null) {
      query['is_default'] = '$isDefault';
    }
    if (enabled != null) {
      query['enabled'] = '$enabled';
    }
    if (lifecycleStatus != null && lifecycleStatus.trim().isNotEmpty) {
      query['lifecycle_status'] = lifecycleStatus.trim().toLowerCase();
    }
    if (updatedFrom != null) {
      query['updated_from'] = updatedFrom.toUtc().toIso8601String();
    }
    if (updatedTo != null) {
      query['updated_to'] = updatedTo.toUtc().toIso8601String();
    }
    final uri = Uri.parse(
      '$_basePath/templates',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }

    final data = (body['data'] as Map<String, dynamic>?) ?? const {};
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
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
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
    ).timeout(const Duration(seconds: 30));
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
    ).timeout(const Duration(seconds: 30));
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

  Future<CraftSystemMasterTemplateVersionListResult>
  listSystemMasterTemplateVersions() async {
    final uri = Uri.parse('$_basePath/system-master-template/versions');
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftSystemMasterTemplateVersionListResult.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<CraftTemplateDetail> getTemplateDetail({
    required int templateId,
  }) async {
    final uri = Uri.parse('$_basePath/templates/$templateId');
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateDetail.fromJson((body['data'] as Map<String, dynamic>?) ?? const {});
  }

  Future<CraftTemplateDetail> createTemplate({
    required int productId,
    required String templateName,
    required bool isDefault,
    required List<CraftTemplateStepPayload> steps,
    String remark = '',
  }) async {
    final uri = Uri.parse('$_basePath/templates');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'product_id': productId,
        'template_name': templateName,
        'is_default': isDefault,
        'remark': remark,
        'steps': steps.map((item) => item.toJson()).toList(),
      }),
    ).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateDetail.fromJson((body['data'] as Map<String, dynamic>?) ?? const {});
  }

  Future<CraftTemplateUpdateResult> updateTemplate({
    required int templateId,
    required String templateName,
    required bool isDefault,
    required bool isEnabled,
    required List<CraftTemplateStepPayload> steps,
    bool syncOrders = true,
    String? remark,
  }) async {
    final uri = Uri.parse('$_basePath/templates/$templateId');
    final payload = <String, dynamic>{
      'template_name': templateName,
      'is_default': isDefault,
      'is_enabled': isEnabled,
      'steps': steps.map((item) => item.toJson()).toList(),
      'sync_orders': syncOrders,
    };
    if (remark != null) {
      payload['remark'] = remark;
    }
    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateUpdateResult.fromJson(
      (body['data'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Future<CraftTemplateImpactAnalysis> getTemplateImpactAnalysis({
    required int templateId,
    int? targetVersion,
  }) async {
    final query = <String, String>{};
    if (targetVersion != null) {
      query['target_version'] = '$targetVersion';
    }
    final uri = Uri.parse(
      '$_basePath/templates/$templateId/impact-analysis',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
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
    int? expectedVersion,
    String? note,
  }) async {
    final uri = Uri.parse('$_basePath/templates/$templateId/publish');
    final payload = <String, dynamic>{
      'apply_order_sync': applyOrderSync,
      'confirmed': confirmed,
      'note': note,
    };
    if (expectedVersion != null) {
      payload['expected_version'] = expectedVersion;
    }
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 30));
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
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
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
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
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
    ).timeout(const Duration(seconds: 30));
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
    String? keyword,
    String? productCategory,
    bool? isDefault,
    bool? enabled,
    String? lifecycleStatus,
    DateTime? updatedFrom,
    DateTime? updatedTo,
  }) async {
    final query = <String, String>{};
    if (productId != null) {
      query['product_id'] = '$productId';
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (productCategory != null && productCategory.trim().isNotEmpty) {
      query['product_category'] = productCategory.trim();
    }
    if (isDefault != null) {
      query['is_default'] = '$isDefault';
    }
    if (enabled != null) {
      query['enabled'] = '$enabled';
    }
    if (lifecycleStatus != null && lifecycleStatus.trim().isNotEmpty) {
      query['lifecycle_status'] = lifecycleStatus.trim().toLowerCase();
    }
    if (updatedFrom != null) {
      query['updated_from'] = updatedFrom.toUtc().toIso8601String();
    }
    if (updatedTo != null) {
      query['updated_to'] = updatedTo.toUtc().toIso8601String();
    }
    final uri = Uri.parse(
      '$_basePath/templates/export',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
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

  Future<String> exportTemplateDetail({required int templateId}) async {
    final uri = Uri.parse('$_basePath/templates/$templateId/export');
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
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

  Future<String> exportTemplateVersion({
    required int templateId,
    required int version,
  }) async {
    final uri = Uri.parse(
      '$_basePath/templates/$templateId/versions/$version/export',
    );
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
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

  Future<CraftTemplateBatchImportResult> importTemplates({
    required List<CraftTemplateBatchImportItem> items,
    bool overwriteExisting = false,
  }) async {
    final uri = Uri.parse('$_basePath/templates/import');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'overwrite_existing': overwriteExisting,
        'items': items.map((item) => item.toJson()).toList(),
      }),
    ).timeout(const Duration(seconds: 30));
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
    final response = await http.delete(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
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
    ).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateDetail.fromJson((body['data'] as Map<String, dynamic>?) ?? const {});
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
      body: jsonEncode({
        'target_product_id': targetProductId,
        'new_name': newName,
      }),
    ).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateDetail.fromJson((body['data'] as Map<String, dynamic>?) ?? const {});
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
    ).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateDetail.fromJson((body['data'] as Map<String, dynamic>?) ?? const {});
  }

  Future<CraftTemplateDetail> enableTemplate({required int templateId}) async {
    final uri = Uri.parse('$_basePath/templates/$templateId/enable');
    final response = await http.post(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateDetail.fromJson((body['data'] as Map<String, dynamic>?) ?? const {});
  }

  Future<CraftTemplateDetail> disableTemplate({required int templateId}) async {
    final uri = Uri.parse('$_basePath/templates/$templateId/disable');
    final response = await http.post(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateDetail.fromJson((body['data'] as Map<String, dynamic>?) ?? const {});
  }

  Future<CraftTemplateDetail> createTemplateDraft({
    required int templateId,
  }) async {
    final uri = Uri.parse('$_basePath/templates/$templateId/draft');
    final response = await http.post(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateDetail.fromJson((body['data'] as Map<String, dynamic>?) ?? const {});
  }

  Future<CraftTemplateDetail> archiveTemplate({required int templateId}) async {
    final uri = Uri.parse('$_basePath/templates/$templateId/archive');
    final response = await http.post(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateDetail.fromJson((body['data'] as Map<String, dynamic>?) ?? const {});
  }

  Future<CraftTemplateDetail> unarchiveTemplate({
    required int templateId,
  }) async {
    final uri = Uri.parse('$_basePath/templates/$templateId/unarchive');
    final response = await http.post(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftTemplateDetail.fromJson((body['data'] as Map<String, dynamic>?) ?? const {});
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
    if (stageId != null) {
      query['stage_id'] = '$stageId';
    }
    if (processId != null) {
      query['process_id'] = '$processId';
    }
    if (startDate != null) {
      query['start_date'] = startDate.toUtc().toIso8601String();
    }
    if (endDate != null) {
      query['end_date'] = endDate.toUtc().toIso8601String();
    }
    final uri = Uri.parse(
      '$_basePath/kanban/process-metrics',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
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

  Future<String> exportCraftKanbanProcessMetrics({
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
    if (stageId != null) {
      query['stage_id'] = '$stageId';
    }
    if (processId != null) {
      query['process_id'] = '$processId';
    }
    if (startDate != null) {
      query['start_date'] = startDate.toUtc().toIso8601String();
    }
    if (endDate != null) {
      query['end_date'] = endDate.toUtc().toIso8601String();
    }
    final uri = Uri.parse(
      '$_basePath/kanban/process-metrics/export',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
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

  Future<CraftStageReferenceResult> getStageReferences({
    required int stageId,
  }) async {
    final uri = Uri.parse('$_basePath/stages/$stageId/references');
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
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
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
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
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
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

  Future<CraftProductTemplateReferenceResult> getProductTemplateReferences({
    required int productId,
  }) async {
    final uri = Uri.parse('$_basePath/products/$productId/template-references');
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body, response.statusCode),
        response.statusCode,
      );
    }
    return CraftProductTemplateReferenceResult.fromJson(
      body['data'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<String> exportStages({String? keyword, bool? enabled}) async {
    final query = <String, String>{};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (enabled != null) {
      query['enabled'] = '$enabled';
    }
    final uri = Uri.parse(
      '$_basePath/stages/export',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
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

  Future<String> exportProcesses({
    String? keyword,
    int? stageId,
    bool? enabled,
  }) async {
    final query = <String, String>{};
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
      '$_basePath/processes/export',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
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
