import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/user/models/user_models.dart';
import 'package:mes_client/core/network/api_exception.dart';

class UserService {
  UserService(this.session);

  final AppSession session;

  Map<String, String> get _authHeaders {
    return {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  Future<UserListResult> listUsers({
    required int page,
    required int pageSize,
    String? keyword,
    String? roleCode,
    int? stageId,
    bool? isOnline,
    bool? isActive,
    String deletedScope = 'active',
    bool includeDeleted = false,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (roleCode != null && roleCode.trim().isNotEmpty) {
      query['role_code'] = roleCode.trim();
    }
    if (stageId != null) {
      query['stage_id'] = '$stageId';
    }
    if (isOnline != null) {
      query['is_online'] = '$isOnline';
    }
    if (isActive != null) {
      query['is_active'] = '$isActive';
    }
    query['deleted_scope'] = deletedScope;
    query['include_deleted'] = '$includeDeleted';

    final uri = Uri.parse(
      '${session.baseUrl}/users',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);

    final data = _dataObject(json);
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map((entry) => UserItem.fromJson(entry as Map<String, dynamic>))
        .toList();
    return UserListResult(total: (data['total'] as int?) ?? 0, items: items);
  }

  Future<Set<int>> listOnlineUserIds({required List<int> userIds}) async {
    final normalizedUserIds = userIds.toSet().toList()..sort();
    if (normalizedUserIds.isEmpty) {
      return <int>{};
    }
    final query = normalizedUserIds
        .map((userId) => 'user_id=${Uri.encodeQueryComponent('$userId')}')
        .join('&');
    final uri = Uri.parse(
      '${session.baseUrl}/users/online-status',
    ).replace(query: query);
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
    final data = _dataObject(json);
    final raw = data['user_ids'] as List<dynamic>? ?? const [];
    final result = <int>{};
    for (final entry in raw) {
      if (entry is int) {
        result.add(entry);
        continue;
      }
      final parsed = int.tryParse('$entry');
      if (parsed != null) {
        result.add(parsed);
      }
    }
    return result;
  }

  Future<UserItem> getUserDetail({required int userId}) async {
    final uri = Uri.parse('${session.baseUrl}/users/$userId');
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
    return UserItem.fromJson(_dataObject(json));
  }

  Future<UserExportResult> exportUsers({
    String? keyword,
    String? roleCode,
    int? stageId,
    bool? isOnline,
    bool? isActive,
    String deletedScope = 'active',
    bool includeDeleted = false,
    String format = 'csv',
  }) async {
    final query = <String, String>{'format': format};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (roleCode != null && roleCode.trim().isNotEmpty) {
      query['role_code'] = roleCode.trim();
    }
    if (stageId != null) {
      query['stage_id'] = '$stageId';
    }
    if (isOnline != null) {
      query['is_online'] = '$isOnline';
    }
    if (isActive != null) {
      query['is_active'] = '$isActive';
    }
    query['deleted_scope'] = deletedScope;
    query['include_deleted'] = '$includeDeleted';

    final uri = Uri.parse(
      '${session.baseUrl}/users/export',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
    return UserExportResult.fromJson(_dataObject(json));
  }

  Future<UserExportTaskItem> createUserExportTask({
    required String format,
    String? keyword,
    String? roleCode,
    bool? isActive,
    String deletedScope = 'active',
  }) async {
    final uri = Uri.parse('${session.baseUrl}/users/export-tasks');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'format': format,
        'keyword': keyword?.trim(),
        'role_code': roleCode?.trim(),
        'is_active': isActive,
        'deleted_scope': deletedScope,
      }),
    );
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
    return UserExportTaskItem.fromJson(_dataObject(json));
  }

  Future<UserExportTaskListResult> listUserExportTasks() async {
    final uri = Uri.parse('${session.baseUrl}/users/export-tasks');
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
    final data = _dataObject(json);
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) => UserExportTaskItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
    return UserExportTaskListResult(
      total: (data['total'] as int?) ?? items.length,
      items: items,
    );
  }

  Future<UserExportTaskItem> getUserExportTask({required int taskId}) async {
    final uri = Uri.parse('${session.baseUrl}/users/export-tasks/$taskId');
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
    return UserExportTaskItem.fromJson(_dataObject(json));
  }

  Future<UserExportDownloadResult> downloadUserExportTask({
    required int taskId,
  }) async {
    final uri = Uri.parse(
      '${session.baseUrl}/users/export-tasks/$taskId/download',
    );
    final response = await http.get(uri, headers: _authHeaders);
    if (response.statusCode != 200) {
      final json = _decodeBody(response);
      _throwIfNotSuccess(response, json, expectedCode: 200);
    }
    final contentDisposition = response.headers['content-disposition'] ?? '';
    final filename =
        _resolveDownloadFilename(contentDisposition) ??
        'users_export.${_resolveFormatFromMime(response.headers['content-type'] ?? 'text/csv') == 'excel' ? 'xlsx' : 'csv'}';
    final mimeType =
        response.headers['content-type'] ?? 'application/octet-stream';
    return UserExportDownloadResult(
      filename: filename,
      mimeType: mimeType,
      bytes: response.bodyBytes,
    );
  }

  Future<RoleListResult> listRoles({
    int page = 1,
    int pageSize = 200,
    String? keyword,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    final uri = Uri.parse(
      '${session.baseUrl}/roles',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);

    final data = _dataObject(json);
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map((entry) => RoleItem.fromJson(entry as Map<String, dynamic>))
        .toList();
    return RoleListResult(total: (data['total'] as int?) ?? 0, items: items);
  }

  Future<RoleListResult> listAllRoles({String? keyword}) async {
    const pageSize = 200;
    var page = 1;
    var total = 0;
    final items = <RoleItem>[];

    while (true) {
      final result = await listRoles(
        page: page,
        pageSize: pageSize,
        keyword: keyword,
      );
      total = result.total;
      items.addAll(result.items);

      if (result.items.isEmpty) {
        break;
      }
      if (total > 0 && items.length >= total) {
        break;
      }
      page += 1;
    }

    return RoleListResult(total: total, items: items);
  }

  Future<RoleItem> createRole({
    required String code,
    required String name,
    String? description,
    String roleType = 'custom',
    bool isEnabled = true,
  }) async {
    final uri = Uri.parse('${session.baseUrl}/roles');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'code': code.trim(),
        'name': name.trim(),
        if (description != null) 'description': description.trim(),
        'role_type': roleType,
        'is_enabled': isEnabled,
      }),
    );
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 201);
    return RoleItem.fromJson(_dataObject(json));
  }

  Future<RoleItem> updateRole({
    required int roleId,
    String? code,
    String? name,
    String? description,
    bool? isEnabled,
  }) async {
    final payload = <String, dynamic>{};
    if (code != null) {
      payload['code'] = code.trim();
    }
    if (name != null) {
      payload['name'] = name.trim();
    }
    if (description != null) {
      payload['description'] = description.trim();
    }
    if (isEnabled != null) {
      payload['is_enabled'] = isEnabled;
    }

    final uri = Uri.parse('${session.baseUrl}/roles/$roleId');
    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode(payload),
    );
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
    return RoleItem.fromJson(_dataObject(json));
  }

  Future<RoleItem> enableRole({required int roleId}) async {
    final uri = Uri.parse('${session.baseUrl}/roles/$roleId/enable');
    final response = await http.post(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
    return RoleItem.fromJson(_dataObject(json));
  }

  Future<RoleItem> disableRole({required int roleId}) async {
    final uri = Uri.parse('${session.baseUrl}/roles/$roleId/disable');
    final response = await http.post(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
    return RoleItem.fromJson(_dataObject(json));
  }

  Future<void> deleteRole({required int roleId}) async {
    final uri = Uri.parse('${session.baseUrl}/roles/$roleId');
    final response = await http.delete(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
  }

  Future<ProcessListResult> listProcesses() async {
    const pageSize = 200;
    var page = 1;
    var total = 0;
    final items = <ProcessItem>[];

    while (true) {
      final uri = Uri.parse(
        '${session.baseUrl}/processes',
      ).replace(queryParameters: {'page': '$page', 'page_size': '$pageSize'});
      final response = await http.get(uri, headers: _authHeaders);
      final json = _decodeBody(response);
      _throwIfNotSuccess(response, json, expectedCode: 200);

      final data = _dataObject(json);
      total = (data['total'] as int?) ?? total;
      final pageItems = (data['items'] as List<dynamic>? ?? const [])
          .map((entry) => ProcessItem.fromJson(entry as Map<String, dynamic>))
          .toList();
      items.addAll(pageItems);

      if (pageItems.isEmpty) {
        break;
      }
      if (total > 0 && items.length >= total) {
        break;
      }
      page += 1;
    }

    return ProcessListResult(total: total, items: items);
  }

  Future<RegistrationRequestListResult> listRegistrationRequests({
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

    final uri = Uri.parse(
      '${session.baseUrl}/auth/register-requests',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);

    final data = _dataObject(json);
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) =>
              RegistrationRequestItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
    return RegistrationRequestListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<void> approveRegistrationRequest({
    required int requestId,
    required String account,
    required String roleCode,
    String? password,
    int? stageId,
  }) async {
    final uri = Uri.parse(
      '${session.baseUrl}/auth/register-requests/$requestId/approve',
    );
    final payload = <String, dynamic>{
      'account': account.trim(),
      'role_code': roleCode,
    };
    if (password != null && password.isNotEmpty) {
      payload['password'] = password;
    }
    if (stageId != null) {
      payload['stage_id'] = stageId;
    }
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode(payload),
    );
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
  }

  Future<void> rejectRegistrationRequest({
    required int requestId,
    String? reason,
  }) async {
    final uri = Uri.parse(
      '${session.baseUrl}/auth/register-requests/$requestId/reject',
    );
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'reason': reason}),
    );
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
  }

  Future<void> createUser({
    required String account,
    required String password,
    required String roleCode,
    String? remark,
    int? stageId,
    bool isActive = true,
  }) async {
    final uri = Uri.parse('${session.baseUrl}/users');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'username': account.trim(),
        'password': password,
        'full_name': account.trim(),
        'remark': remark?.trim(),
        'role_code': roleCode,
        'stage_id': stageId,
        'is_active': isActive,
      }),
    );

    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 201);
  }

  Future<void> updateUser({
    required int userId,
    String? account,
    String? roleCode,
    String? remark,
    int? stageId,
    bool? isActive,
    bool? mustChangePassword,
  }) async {
    final uri = Uri.parse('${session.baseUrl}/users/$userId');
    final payload = <String, dynamic>{};
    if (account != null && account.trim().isNotEmpty) {
      payload['username'] = account.trim();
      payload['full_name'] = account.trim();
    }
    if (roleCode != null && roleCode.trim().isNotEmpty) {
      payload['role_code'] = roleCode.trim();
    }
    if (remark != null) {
      payload['remark'] = remark.trim();
    }
    if (stageId != null) {
      payload['stage_id'] = stageId;
    }
    if (isActive != null) {
      payload['is_active'] = isActive;
    }
    if (mustChangePassword != null) {
      payload['must_change_password'] = mustChangePassword;
    }

    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode(payload),
    );
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
  }

  Future<UserLifecycleResult> enableUser({
    required int userId,
    String? remark,
  }) async {
    final uri = Uri.parse('${session.baseUrl}/users/$userId/enable');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'remark': remark?.trim()}),
    );
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
    return UserLifecycleResult.fromJson(_dataObject(json));
  }

  Future<UserLifecycleResult> disableUser({
    required int userId,
    required String remark,
  }) async {
    final uri = Uri.parse('${session.baseUrl}/users/$userId/disable');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'remark': remark.trim()}),
    );
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
    return UserLifecycleResult.fromJson(_dataObject(json));
  }

  Future<UserPasswordResetResult> resetUserPassword({
    required int userId,
    required String password,
    required String remark,
  }) async {
    final uri = Uri.parse('${session.baseUrl}/users/$userId/reset-password');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'password': password, 'remark': remark.trim()}),
    );
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
    return UserPasswordResetResult.fromJson(_dataObject(json));
  }

  Future<UserDeleteResult> deleteUser({
    required int userId,
    required String remark,
  }) async {
    final uri = Uri.parse('${session.baseUrl}/users/$userId');
    final response = await http.delete(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'remark': remark.trim()}),
    );
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
    return UserDeleteResult.fromJson(_dataObject(json));
  }

  Future<UserLifecycleResult> restoreUser({
    required int userId,
    required String remark,
  }) async {
    final uri = Uri.parse('${session.baseUrl}/users/$userId/restore');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'remark': remark.trim()}),
    );
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
    return UserLifecycleResult.fromJson(_dataObject(json));
  }

  Future<AuditLogListResult> listAuditLogs({
    required int page,
    required int pageSize,
    String? operatorUsername,
    String? actionCode,
    String? targetType,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (operatorUsername != null && operatorUsername.trim().isNotEmpty) {
      query['operator_username'] = operatorUsername.trim();
    }
    if (actionCode != null && actionCode.trim().isNotEmpty) {
      query['action_code'] = actionCode.trim();
    }
    if (targetType != null && targetType.trim().isNotEmpty) {
      query['target_type'] = targetType.trim();
    }
    if (startTime != null) {
      query['start_time'] = startTime.toIso8601String();
    }
    if (endTime != null) {
      query['end_time'] = endTime.toIso8601String();
    }

    final uri = Uri.parse(
      '${session.baseUrl}/audits',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);

    final data = _dataObject(json);
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map((entry) => AuditLogItem.fromJson(entry as Map<String, dynamic>))
        .toList();
    return AuditLogListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<ProfileResult> getMyProfile() async {
    final uri = Uri.parse('${session.baseUrl}/me/profile');
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
    return ProfileResult.fromJson(_dataObject(json));
  }

  Future<CurrentSessionResult> getMySession() async {
    final uri = Uri.parse('${session.baseUrl}/me/session');
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
    return CurrentSessionResult.fromJson(_dataObject(json));
  }

  Future<void> changeMyPassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final uri = Uri.parse('${session.baseUrl}/me/password');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'old_password': oldPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      }),
    );
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
  }

  Future<LoginLogListResult> listLoginLogs({
    required int page,
    required int pageSize,
    String? username,
    bool? success,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (username != null && username.trim().isNotEmpty) {
      query['username'] = username.trim();
    }
    if (success != null) {
      query['success'] = '$success';
    }
    if (startTime != null) {
      query['start_time'] = startTime.toUtc().toIso8601String();
    }
    if (endTime != null) {
      query['end_time'] = endTime.toUtc().toIso8601String();
    }

    final uri = Uri.parse(
      '${session.baseUrl}/sessions/login-logs',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);

    final data = _dataObject(json);
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map((entry) => LoginLogItem.fromJson(entry as Map<String, dynamic>))
        .toList();
    return LoginLogListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<OnlineSessionListResult> listOnlineSessions({
    required int page,
    required int pageSize,
    String? keyword,
    String? statusFilter,
  }) async {
    final query = <String, String>{'page': '$page', 'page_size': '$pageSize'};
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    if (statusFilter != null && statusFilter.trim().isNotEmpty) {
      query['status_filter'] = statusFilter.trim();
    }

    final uri = Uri.parse(
      '${session.baseUrl}/sessions/online',
    ).replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);

    final data = _dataObject(json);
    final items = (data['items'] as List<dynamic>? ?? const [])
        .map(
          (entry) => OnlineSessionItem.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
    return OnlineSessionListResult(
      total: (data['total'] as int?) ?? 0,
      items: items,
    );
  }

  Future<ForceOfflineResult> forceOffline({
    required String sessionTokenId,
  }) async {
    final uri = Uri.parse('${session.baseUrl}/sessions/force-offline');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'session_token_id': sessionTokenId}),
    );
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
    return ForceOfflineResult.fromJson(_dataObject(json));
  }

  Future<ForceOfflineResult> batchForceOffline({
    required List<String> sessionTokenIds,
  }) async {
    final uri = Uri.parse('${session.baseUrl}/sessions/force-offline/batch');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({'session_token_ids': sessionTokenIds}),
    );
    final json = _decodeBody(response);
    _throwIfNotSuccess(response, json, expectedCode: 200);
    return ForceOfflineResult.fromJson(_dataObject(json));
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    if (response.body.isEmpty) {
      return {};
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String? _resolveDownloadFilename(String contentDisposition) {
    final filenameUtf8Match = RegExp(
      r"filename\\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(contentDisposition);
    if (filenameUtf8Match != null) {
      return Uri.decodeComponent(filenameUtf8Match.group(1)!);
    }
    final filenameMatch = RegExp(
      r'filename=\"?([^\";]+)\"?',
      caseSensitive: false,
    ).firstMatch(contentDisposition);
    if (filenameMatch != null) {
      return filenameMatch.group(1);
    }
    return null;
  }

  String _resolveFormatFromMime(String mimeType) {
    final normalized = mimeType.toLowerCase();
    if (normalized.contains('spreadsheetml')) {
      return 'excel';
    }
    return 'csv';
  }

  Map<String, dynamic> _dataObject(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return <String, dynamic>{};
  }

  void _throwIfNotSuccess(
    http.Response response,
    Map<String, dynamic> body, {
    required int expectedCode,
  }) {
    if (response.statusCode == expectedCode) {
      return;
    }
    throw ApiException(
      _extractErrorMessage(body, response.statusCode),
      response.statusCode,
    );
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
    return '请求失败，状态码：$statusCode';
  }
}
