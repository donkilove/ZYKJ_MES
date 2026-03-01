import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_session.dart';
import '../models/equipment_models.dart';
import 'api_exception.dart';

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

  Future<List<EquipmentOwnerOption>> listAdminOwners() async {
    final uri = Uri.parse('$_basePath/admin-owners');
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = json['data'] as Map<String, dynamic>;
    return (data['items'] as List<dynamic>? ?? const [])
        .map((entry) => EquipmentOwnerOption.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<EquipmentLedgerListResult> listEquipment({
    required int page,
    required int pageSize,
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
    final uri = Uri.parse('$_basePath/ledger').replace(queryParameters: query);
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
        .map((entry) => EquipmentLedgerItem.fromJson(entry as Map<String, dynamic>))
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
  }) async {
    final uri = Uri.parse('$_basePath/ledger');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'code': code,
        'name': name,
        'model': model,
        'location': location,
        'owner_name': ownerName,
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

  Future<void> updateEquipment({
    required int equipmentId,
    required String code,
    required String name,
    required String model,
    required String location,
    required String ownerName,
  }) async {
    final uri = Uri.parse('$_basePath/ledger/$equipmentId');
    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'code': code,
        'name': name,
        'model': model,
        'location': location,
        'owner_name': ownerName,
      }),
    );
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
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'enabled': enabled}),
    );
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
    final response = await http.delete(uri, headers: _authHeaders);
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
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (enabled != null) {
      query['enabled'] = '$enabled';
    }
    final uri = Uri.parse('$_basePath/items').replace(queryParameters: query);
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
        .map((entry) => MaintenanceItemEntry.fromJson(entry as Map<String, dynamic>))
        .toList();
    return MaintenanceItemListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<void> createMaintenanceItem({
    required String name,
    required int defaultCycleDays,
  }) async {
    final uri = Uri.parse('$_basePath/items');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'name': name,
        'default_cycle_days': defaultCycleDays,
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

  Future<void> updateMaintenanceItem({
    required int itemId,
    required String name,
    required int defaultCycleDays,
  }) async {
    final uri = Uri.parse('$_basePath/items/$itemId');
    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'name': name,
        'default_cycle_days': defaultCycleDays,
      }),
    );
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
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'enabled': enabled}),
    );
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
    final response = await http.delete(uri, headers: _authHeaders);
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
    int? equipmentId,
    int? itemId,
    bool? enabled,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (equipmentId != null) {
      query['equipment_id'] = '$equipmentId';
    }
    if (itemId != null) {
      query['item_id'] = '$itemId';
    }
    if (enabled != null) {
      query['enabled'] = '$enabled';
    }
    final uri = Uri.parse('$_basePath/plans').replace(queryParameters: query);
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
        .map((entry) => MaintenancePlanItem.fromJson(entry as Map<String, dynamic>))
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
  }) async {
    final uri = Uri.parse('$_basePath/plans');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'equipment_id': equipmentId,
        'item_id': itemId,
        'execution_process_code': executionProcessCode,
        'estimated_duration_minutes': estimatedDurationMinutes,
        'start_date': _formatDate(startDate),
        'next_due_date': nextDueDate == null ? null : _formatDate(nextDueDate),
        'default_executor_user_id': defaultExecutorUserId,
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

  Future<void> updateMaintenancePlan({
    required int planId,
    required int equipmentId,
    required int itemId,
    required String executionProcessCode,
    required DateTime startDate,
    required int? estimatedDurationMinutes,
    required DateTime? nextDueDate,
    required int? defaultExecutorUserId,
  }) async {
    final uri = Uri.parse('$_basePath/plans/$planId');
    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'equipment_id': equipmentId,
        'item_id': itemId,
        'execution_process_code': executionProcessCode,
        'estimated_duration_minutes': estimatedDurationMinutes,
        'start_date': _formatDate(startDate),
        'next_due_date': nextDueDate == null ? null : _formatDate(nextDueDate),
        'default_executor_user_id': defaultExecutorUserId,
      }),
    );
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
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'enabled': enabled}),
    );
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
    final response = await http.delete(uri, headers: _authHeaders);
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
    final response = await http.post(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = json['data'] as Map<String, dynamic>;
    return MaintenancePlanGenerateResult.fromJson(data);
  }

  Future<MaintenanceWorkOrderListResult> listExecutions({
    required int page,
    required int pageSize,
    String? keyword,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    final uri = Uri.parse('$_basePath/executions').replace(queryParameters: query);
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
        .map((entry) => MaintenanceWorkOrderItem.fromJson(entry as Map<String, dynamic>))
        .toList();
    return MaintenanceWorkOrderListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<void> startExecution({required int workOrderId}) async {
    final uri = Uri.parse('$_basePath/executions/$workOrderId/start');
    final response = await http.post(uri, headers: _authHeaders);
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
  }) async {
    final uri = Uri.parse('$_basePath/executions/$workOrderId/complete');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'result_summary': resultSummary,
        'result_remark': resultRemark,
      }),
    );
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
    final uri = Uri.parse('$_basePath/records').replace(queryParameters: query);
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
        .map((entry) => MaintenanceRecordItem.fromJson(entry as Map<String, dynamic>))
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
}
