import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_session.dart';
import '../models/user_models.dart';
import 'api_exception.dart';

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
  }) async {
    final query = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
    };
    if (keyword != null && keyword.trim().isNotEmpty) {
      query['keyword'] = keyword.trim();
    }
    final uri = Uri.parse('${session.baseUrl}/users').replace(queryParameters: query);
    final response = await http.get(uri, headers: _authHeaders);

    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(_extractErrorMessage(json, response.statusCode), response.statusCode);
    }

    final data = json['data'] as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>)
        .map((entry) => UserItem.fromJson(entry as Map<String, dynamic>))
        .toList();
    return UserListResult(total: data['total'] as int, items: items);
  }

  Future<RoleListResult> listRoles() async {
    final uri = Uri.parse('${session.baseUrl}/roles')
        .replace(queryParameters: const {'page': '1', 'page_size': '50'});
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(_extractErrorMessage(json, response.statusCode), response.statusCode);
    }

    final data = json['data'] as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>)
        .map((entry) => RoleItem.fromJson(entry as Map<String, dynamic>))
        .toList();
    return RoleListResult(total: data['total'] as int, items: items);
  }

  Future<ProcessListResult> listProcesses() async {
    final uri = Uri.parse('${session.baseUrl}/processes')
        .replace(queryParameters: const {'page': '1', 'page_size': '200'});
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(_extractErrorMessage(json, response.statusCode), response.statusCode);
    }

    final data = json['data'] as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>)
        .map((entry) => ProcessItem.fromJson(entry as Map<String, dynamic>))
        .toList();
    return ProcessListResult(total: data['total'] as int, items: items);
  }

  Future<void> createUser({
    required String account,
    required String password,
    required List<String> roleCodes,
    required List<String> processCodes,
  }) async {
    final uri = Uri.parse('${session.baseUrl}/users');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'username': account,
        'password': password,
        'full_name': account,
        'role_codes': roleCodes,
        'process_codes': processCodes,
      }),
    );

    final json = _decodeBody(response);
    if (response.statusCode != 201) {
      throw ApiException(_extractErrorMessage(json, response.statusCode), response.statusCode);
    }
  }

  Future<void> updateUser({
    required int userId,
    String? account,
    String? password,
    List<String>? roleCodes,
    List<String>? processCodes,
  }) async {
    final uri = Uri.parse('${session.baseUrl}/users/$userId');
    final payload = <String, dynamic>{};
    if (account != null && account.trim().isNotEmpty) {
      payload['username'] = account.trim();
      payload['full_name'] = account.trim();
    }
    if (password != null && password.isNotEmpty) {
      payload['password'] = password;
    }
    if (roleCodes != null) {
      payload['role_codes'] = roleCodes;
    }
    if (processCodes != null) {
      payload['process_codes'] = processCodes;
    }

    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode(payload),
    );
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(_extractErrorMessage(json, response.statusCode), response.statusCode);
    }
  }

  Future<void> deleteUser({required int userId}) async {
    final uri = Uri.parse('${session.baseUrl}/users/$userId');
    final response = await http.delete(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(_extractErrorMessage(json, response.statusCode), response.statusCode);
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
    return '请求失败，状态码 $statusCode';
  }
}
