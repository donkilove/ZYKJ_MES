import 'dart:convert';

import 'package:mes_client/core/network/http_client.dart' as http;

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';
import 'package:mes_client/core/network/api_exception.dart';

class EquipmentService {
  EquipmentService(this.session);

  final AppSession session;

  Map<String, String> get _authHeaders {
    return {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  String get _basePath => '${session.baseUrl}/equipment';

  Future<List<EquipmentOwnerOption>> listAllOwners() async {
    final uri = Uri.parse('$_basePath/owners');
    final response = await http
        .get(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    return (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) =>
              EquipmentOwnerOption.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
  }

  Future<EquipmentDetailResult> getEquipmentDetail({
    required int equipmentId,
  }) async {
    final uri = Uri.parse('$_basePath/ledger/$equipmentId/detail');
    final response = await http
        .get(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    return EquipmentDetailResult.fromJson(
      (json['data'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Future<MaintenanceWorkOrderDetail> getWorkOrderDetail({
    required int workOrderId,
  }) async {
    final uri = Uri.parse('$_basePath/executions/$workOrderId/detail');
    final response = await http
        .get(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    return MaintenanceWorkOrderDetail.fromJson(
      (json['data'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Future<void> cancelExecution({required int workOrderId}) async {
    final uri = Uri.parse('$_basePath/executions/$workOrderId/cancel');
    final response = await http
        .post(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<MaintenanceRecordDetail> getRecordDetail({
    required int recordId,
  }) async {
    final uri = Uri.parse('$_basePath/records/$recordId/detail');
    final response = await http
        .get(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    return MaintenanceRecordDetail.fromJson(
      (json['data'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Future<EquipmentLedgerListResult> listEquipment({
    required int page,
    required int pageSize,
    String? keyword,
    bool? enabled,
    String? locationKeyword,
    String? ownerName,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (enabled != null) {
      query['enabled'] = '$enabled';
    }
    if (locationKeyword != null && locationKeyword.trim().isNotEmpty) {
      query['location_keyword'] = locationKeyword.trim();
    }
    if (ownerName != null && ownerName.trim().isNotEmpty) {
      query['owner_name'] = ownerName.trim();
    }
    final uri = Uri.parse('$_basePath/ledger').replace(queryParameters: query);
    final response = await http
        .get(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
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
          (entry) =>
              EquipmentLedgerItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
    return EquipmentLedgerListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<void> createEquipment({
    required String code,
    required String name,
    required String model,
    required String location,
    required String ownerName,
    String remark = '',
  }) async {
    final uri = Uri.parse('$_basePath/ledger');
    final response = await http
        .post(
          uri,
          headers: _authHeaders,
          body: jsonEncode({
            'code': code,
            'name': name,
            'model': model,
            'location': location,
            'owner_name': ownerName,
            'remark': remark,
          }),
        )
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<void> updateEquipment({
    required int equipmentId,
    required String code,
    required String name,
    required String model,
    required String location,
    required String ownerName,
    String remark = '',
  }) async {
    final uri = Uri.parse('$_basePath/ledger/$equipmentId');
    final response = await http
        .put(
          uri,
          headers: _authHeaders,
          body: jsonEncode({
            'code': code,
            'name': name,
            'model': model,
            'location': location,
            'owner_name': ownerName,
            'remark': remark,
          }),
        )
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<void> toggleEquipment({
    required int equipmentId,
    required bool enabled,
  }) async {
    final uri = Uri.parse('$_basePath/ledger/$equipmentId/toggle');
    final response = await http
        .post(
          uri,
          headers: _authHeaders,
          body: jsonEncode({'enabled': enabled}),
        )
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<void> disableEquipment({required int equipmentId}) async {
    await toggleEquipment(equipmentId: equipmentId, enabled: false);
  }

  Future<void> deleteEquipment({required int equipmentId}) async {
    final uri = Uri.parse('$_basePath/ledger/$equipmentId');
    final response = await http
        .delete(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<MaintenanceItemListResult> listMaintenanceItems({
    required int page,
    required int pageSize,
    String? keyword,
    bool? enabled,
    String? category,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (enabled != null) {
      query['enabled'] = '$enabled';
    }
    if (category != null && category.trim().isNotEmpty) {
      query['category'] = category.trim();
    }
    final uri = Uri.parse('$_basePath/items').replace(queryParameters: query);
    final response = await http
        .get(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
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
          (entry) =>
              MaintenanceItemEntry.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
    return MaintenanceItemListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<void> createMaintenanceItem({
    required String name,
    required int defaultCycleDays,
    String category = '',
    int? defaultDurationMinutes,
    String standardDescription = '',
  }) async {
    final uri = Uri.parse('$_basePath/items');
    final response = await http
        .post(
          uri,
          headers: _authHeaders,
          body: jsonEncode({
            'name': name,
            'default_cycle_days': defaultCycleDays,
            'category': category,
            'default_duration_minutes': defaultDurationMinutes,
            'standard_description': standardDescription,
          }),
        )
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<void> updateMaintenanceItem({
    required int itemId,
    required String name,
    required int defaultCycleDays,
    String category = '',
    int? defaultDurationMinutes,
    String standardDescription = '',
  }) async {
    final uri = Uri.parse('$_basePath/items/$itemId');
    final response = await http
        .put(
          uri,
          headers: _authHeaders,
          body: jsonEncode({
            'name': name,
            'default_cycle_days': defaultCycleDays,
            'category': category,
            'default_duration_minutes': defaultDurationMinutes,
            'standard_description': standardDescription,
          }),
        )
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<void> toggleMaintenanceItem({
    required int itemId,
    required bool enabled,
  }) async {
    final uri = Uri.parse('$_basePath/items/$itemId/toggle');
    final response = await http
        .post(
          uri,
          headers: _authHeaders,
          body: jsonEncode({'enabled': enabled}),
        )
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<void> disableMaintenanceItem({required int itemId}) async {
    await toggleMaintenanceItem(itemId: itemId, enabled: false);
  }

  Future<void> deleteMaintenanceItem({required int itemId}) async {
    final uri = Uri.parse('$_basePath/items/$itemId');
    final response = await http
        .delete(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<MaintenancePlanListResult> listMaintenancePlans({
    required int page,
    required int pageSize,
    String? keyword,
    int? equipmentId,
    int? itemId,
    bool? enabled,
    String? executionProcessCode,
    int? defaultExecutorUserId,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (equipmentId != null) {
      query['equipment_id'] = '$equipmentId';
    }
    if (itemId != null) {
      query['item_id'] = '$itemId';
    }
    if (enabled != null) {
      query['enabled'] = '$enabled';
    }
    if (executionProcessCode != null &&
        executionProcessCode.trim().isNotEmpty) {
      query['execution_process_code'] = executionProcessCode.trim();
    }
    if (defaultExecutorUserId != null) {
      query['default_executor_user_id'] = '$defaultExecutorUserId';
    }
    final uri = Uri.parse('$_basePath/plans').replace(queryParameters: query);
    final response = await http
        .get(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
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
          (entry) =>
              MaintenancePlanItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
    return MaintenancePlanListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<void> createMaintenancePlan({
    required int equipmentId,
    required int itemId,
    required String executionProcessCode,
    required DateTime startDate,
    required int? estimatedDurationMinutes,
    required DateTime? nextDueDate,
    required int? defaultExecutorUserId,
    int? cycleDays,
  }) async {
    final uri = Uri.parse('$_basePath/plans');
    final response = await http
        .post(
          uri,
          headers: _authHeaders,
          body: jsonEncode({
            'equipment_id': equipmentId,
            'item_id': itemId,
            'execution_process_code': executionProcessCode,
            'estimated_duration_minutes': estimatedDurationMinutes,
            'start_date': _formatDate(startDate),
            'next_due_date': nextDueDate == null
                ? null
                : _formatDate(nextDueDate),
            'default_executor_user_id': defaultExecutorUserId,
            'cycle_days': cycleDays,
          }),
        )
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<void> updateMaintenancePlan({
    required int planId,
    required int equipmentId,
    required int itemId,
    required String executionProcessCode,
    required DateTime startDate,
    required int? estimatedDurationMinutes,
    required DateTime? nextDueDate,
    required int? defaultExecutorUserId,
    int? cycleDays,
  }) async {
    final uri = Uri.parse('$_basePath/plans/$planId');
    final response = await http
        .put(
          uri,
          headers: _authHeaders,
          body: jsonEncode({
            'equipment_id': equipmentId,
            'item_id': itemId,
            'execution_process_code': executionProcessCode,
            'estimated_duration_minutes': estimatedDurationMinutes,
            'start_date': _formatDate(startDate),
            'next_due_date': nextDueDate == null
                ? null
                : _formatDate(nextDueDate),
            'default_executor_user_id': defaultExecutorUserId,
            'cycle_days': cycleDays,
          }),
        )
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<void> toggleMaintenancePlan({
    required int planId,
    required bool enabled,
  }) async {
    final uri = Uri.parse('$_basePath/plans/$planId/toggle');
    final response = await http
        .post(
          uri,
          headers: _authHeaders,
          body: jsonEncode({'enabled': enabled}),
        )
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<void> deleteMaintenancePlan({required int planId}) async {
    final uri = Uri.parse('$_basePath/plans/$planId');
    final response = await http
        .delete(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<MaintenancePlanGenerateResult> generateMaintenancePlan({
    required int planId,
  }) async {
    final uri = Uri.parse('$_basePath/plans/$planId/generate');
    final response = await http
        .post(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    return MaintenancePlanGenerateResult.fromJson(data);
  }

  Future<MaintenanceWorkOrderListResult> listExecutions({
    required int page,
    required int pageSize,
    String? keyword,
    String? status,
    bool mineOnly = false,
    DateTime? dueDateStart,
    DateTime? dueDateEnd,
    String? stageCode,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (status != null) {
      query['status'] = status;
    }
    if (mineOnly) {
      query['mine'] = 'true';
    }
    if (dueDateStart != null) {
      query['due_date_start'] = _formatDate(dueDateStart);
    }
    if (dueDateEnd != null) {
      query['due_date_end'] = _formatDate(dueDateEnd);
    }
    if (stageCode != null) {
      query['stage_code'] = stageCode;
    }
    final uri = Uri.parse(
      '$_basePath/executions',
    ).replace(queryParameters: query);
    final response = await http
        .get(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
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
          (entry) =>
              MaintenanceWorkOrderItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
    return MaintenanceWorkOrderListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<void> startExecution({required int workOrderId}) async {
    final uri = Uri.parse('$_basePath/executions/$workOrderId/start');
    final response = await http
        .post(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<void> completeExecution({
    required int workOrderId,
    required String resultSummary,
    String? resultRemark,
    String? attachmentLink,
  }) async {
    final uri = Uri.parse('$_basePath/executions/$workOrderId/complete');
    final response = await http
        .post(
          uri,
          headers: _authHeaders,
          body: jsonEncode({
            'result_summary': resultSummary,
            'result_remark': resultRemark,
            'attachment_link': attachmentLink,
          }),
        )
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<MaintenanceRecordListResult> listRecords({
    required int page,
    required int pageSize,
    String? keyword,
    int? executorId,
    DateTime? startDate,
    DateTime? endDate,
    String? resultSummary,
    int? equipmentId,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (executorId != null) {
      query['executor_id'] = '$executorId';
    }
    if (startDate != null) {
      query['start_date'] = _formatDate(startDate);
    }
    if (endDate != null) {
      query['end_date'] = _formatDate(endDate);
    }
    if (resultSummary != null) {
      query['result_summary'] = resultSummary;
    }
    if (equipmentId != null) {
      query['equipment_id'] = '$equipmentId';
    }
    final uri = Uri.parse('$_basePath/records').replace(queryParameters: query);
    final response = await http
        .get(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
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
          (entry) =>
              MaintenanceRecordItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
    return MaintenanceRecordListResult(
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
    return 'Request failed ($statusCode)';
  }

  String _formatDate(DateTime value) {
    final date = value.toLocal();
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  String _formatDateTimeIso(DateTime value) {
    return value.toUtc().toIso8601String();
  }

  // ── 设备规则 ────────────────────────────────────────────────────────────────

  Future<EquipmentRuleListResult> listEquipmentRules({
    int? equipmentId,
    String? keyword,
    bool? isEnabled,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (equipmentId != null) query['equipment_id'] = '$equipmentId';
    if (keyword != null && keyword.isNotEmpty) query['keyword'] = keyword;
    if (isEnabled != null) query['is_enabled'] = '$isEnabled';
    final uri = Uri.parse('$_basePath/rules').replace(queryParameters: query);
    final response = await http
        .get(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    final items = (data['items'] as List? ?? const [])
        .map((e) => EquipmentRuleItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return EquipmentRuleListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<void> createEquipmentRule({
    int? equipmentId,
    String? equipmentType,
    required String ruleCode,
    required String ruleName,
    String ruleType = '',
    String conditionDesc = '',
    bool isEnabled = true,
    DateTime? effectiveAt,
    String remark = '',
  }) async {
    final uri = Uri.parse('$_basePath/rules');
    final body = jsonEncode({
      'equipment_id': equipmentId,
      'equipment_type': equipmentType,
      'rule_code': ruleCode,
      'rule_name': ruleName,
      'rule_type': ruleType,
      'condition_desc': conditionDesc,
      'is_enabled': isEnabled,
      'effective_at': effectiveAt == null
          ? null
          : _formatDateTimeIso(effectiveAt),
      'remark': remark,
    });
    final response = await http
        .post(uri, headers: _authHeaders, body: body)
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<void> updateEquipmentRule({
    required int ruleId,
    int? equipmentId,
    String? equipmentType,
    required String ruleCode,
    required String ruleName,
    String ruleType = '',
    String conditionDesc = '',
    required bool isEnabled,
    DateTime? effectiveAt,
    String remark = '',
  }) async {
    final uri = Uri.parse('$_basePath/rules/$ruleId');
    final body = jsonEncode({
      'equipment_id': equipmentId,
      'equipment_type': equipmentType,
      'rule_code': ruleCode,
      'rule_name': ruleName,
      'rule_type': ruleType,
      'condition_desc': conditionDesc,
      'is_enabled': isEnabled,
      'effective_at': effectiveAt == null
          ? null
          : _formatDateTimeIso(effectiveAt),
      'remark': remark,
    });
    final response = await http
        .put(uri, headers: _authHeaders, body: body)
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<void> toggleEquipmentRule({
    required int ruleId,
    required bool isEnabled,
  }) async {
    final uri = Uri.parse('$_basePath/rules/$ruleId/toggle');
    final body = jsonEncode({'enabled': isEnabled});
    final response = await http
        .patch(uri, headers: _authHeaders, body: body)
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<void> deleteEquipmentRule(int ruleId) async {
    final uri = Uri.parse('$_basePath/rules/$ruleId');
    final response = await http
        .delete(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  // ── 运行参数 ────────────────────────────────────────────────────────────────

  Future<EquipmentRuntimeParameterListResult> listRuntimeParameters({
    int? equipmentId,
    String? equipmentType,
    String? keyword,
    bool? isEnabled,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (equipmentId != null) query['equipment_id'] = '$equipmentId';
    if (equipmentType != null && equipmentType.trim().isNotEmpty) {
      query['equipment_type'] = equipmentType.trim();
    }
    if (keyword != null && keyword.isNotEmpty) query['keyword'] = keyword;
    if (isEnabled != null) query['is_enabled'] = '$isEnabled';
    final uri = Uri.parse(
      '$_basePath/runtime-parameters',
    ).replace(queryParameters: query);
    final response = await http
        .get(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    final items = (data['items'] as List? ?? const [])
        .map(
          (e) =>
              EquipmentRuntimeParameterItem.fromJson(e as Map<String, dynamic>),
        )
        .toList();
    return EquipmentRuntimeParameterListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<void> createRuntimeParameter({
    int? equipmentId,
    String? equipmentType,
    required String paramCode,
    required String paramName,
    String unit = '',
    String? standardValue,
    String? upperLimit,
    String? lowerLimit,
    DateTime? effectiveAt,
    bool isEnabled = true,
    String remark = '',
  }) async {
    final uri = Uri.parse('$_basePath/runtime-parameters');
    final body = jsonEncode({
      'equipment_id': equipmentId,
      'equipment_type': equipmentType,
      'param_code': paramCode,
      'param_name': paramName,
      'unit': unit,
      'standard_value': standardValue != null && standardValue.isNotEmpty
          ? double.tryParse(standardValue)
          : null,
      'upper_limit': upperLimit != null && upperLimit.isNotEmpty
          ? double.tryParse(upperLimit)
          : null,
      'lower_limit': lowerLimit != null && lowerLimit.isNotEmpty
          ? double.tryParse(lowerLimit)
          : null,
      'effective_at': effectiveAt == null
          ? null
          : _formatDateTimeIso(effectiveAt),
      'is_enabled': isEnabled,
      'remark': remark,
    });
    final response = await http
        .post(uri, headers: _authHeaders, body: body)
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<void> updateRuntimeParameter({
    required int paramId,
    int? equipmentId,
    String? equipmentType,
    required String paramCode,
    required String paramName,
    String unit = '',
    String? standardValue,
    String? upperLimit,
    String? lowerLimit,
    DateTime? effectiveAt,
    bool isEnabled = true,
    String remark = '',
  }) async {
    final uri = Uri.parse('$_basePath/runtime-parameters/$paramId');
    final body = jsonEncode({
      'equipment_id': equipmentId,
      'equipment_type': equipmentType,
      'param_code': paramCode,
      'param_name': paramName,
      'unit': unit,
      'standard_value': standardValue != null && standardValue.isNotEmpty
          ? double.tryParse(standardValue)
          : null,
      'upper_limit': upperLimit != null && upperLimit.isNotEmpty
          ? double.tryParse(upperLimit)
          : null,
      'lower_limit': lowerLimit != null && lowerLimit.isNotEmpty
          ? double.tryParse(lowerLimit)
          : null,
      'effective_at': effectiveAt == null
          ? null
          : _formatDateTimeIso(effectiveAt),
      'is_enabled': isEnabled,
      'remark': remark,
    });
    final response = await http
        .put(uri, headers: _authHeaders, body: body)
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<void> deleteRuntimeParameter(int paramId) async {
    final uri = Uri.parse('$_basePath/runtime-parameters/$paramId');
    final response = await http
        .delete(uri, headers: _authHeaders)
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<void> toggleRuntimeParameter({
    required int paramId,
    required bool enabled,
  }) async {
    final uri = Uri.parse('$_basePath/runtime-parameters/$paramId/toggle');
    final response = await http
        .patch(
          uri,
          headers: _authHeaders,
          body: jsonEncode({'enabled': enabled}),
        )
        .timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
  }
}
