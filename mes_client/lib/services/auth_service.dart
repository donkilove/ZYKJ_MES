import 'dart:convert';

import 'package:http/http.dart' as http;

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
      body: {
        'username': username,
        'password': password,
      },
    );

    final decoded = _decodeBody(response.body);
    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(decoded, response.statusCode));
    }

    final data = decoded['data'] as Map<String, dynamic>?;
    final token = data?['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('登录失败：缺少访问令牌');
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
      body: jsonEncode({
        'account': account,
        'password': password,
      }),
    );

    final decoded = _decodeBody(response.body);
    if (response.statusCode != 201) {
      throw Exception(_extractErrorMessage(decoded, response.statusCode));
    }
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

