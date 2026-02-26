import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/current_user.dart';
import 'api_exception.dart';

class AuthService {
  Future<String> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': username, 'password': password},
    );

    final decoded = _decodeBody(response.body);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(decoded, response.statusCode),
        response.statusCode,
      );
    }

    final data = decoded['data'] as Map<String, dynamic>?;
    final token = data?['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw ApiException('登录失败：缺少访问令牌', response.statusCode);
    }
    return token;
  }

  Future<void> register({
    required String baseUrl,
    required String account,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/register');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'account': account, 'password': password}),
    );

    final decoded = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(decoded, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<List<String>> listAccounts({required String baseUrl}) async {
    final uri = Uri.parse('$baseUrl/auth/accounts');
    final response = await http.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    );

    final decoded = _decodeBody(response.body);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(decoded, response.statusCode),
        response.statusCode,
      );
    }

    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) {
      return const [];
    }
    final accounts = (data['accounts'] as List<dynamic>? ?? const [])
        .cast<String>();
    return accounts;
  }

  Future<CurrentUser> getCurrentUser({
    required String baseUrl,
    required String accessToken,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/me');
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    final decoded = _decodeBody(response.body);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(decoded, response.statusCode),
        response.statusCode,
      );
    }

    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw ApiException('获取当前用户失败：响应数据为空', response.statusCode);
    }
    return CurrentUser.fromJson(data);
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.isEmpty) {
      return {};
    }
    return jsonDecode(body) as Map<String, dynamic>;
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
