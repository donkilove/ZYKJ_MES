import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:mes_client/core/models/current_user.dart';
import 'package:mes_client/core/network/api_exception.dart';

class AuthService {
  Future<({String token, bool mustChangePassword, int expiresIn})>
  mobileScanReviewLogin({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/mobile-scan-review-login');
    return _performLogin(uri, username: username, password: password);
  }

  Future<({String token, bool mustChangePassword, int expiresIn})> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/login');
    final result = await _performLogin(
      uri,
      username: username,
      password: password,
    );
    return (
      token: result.token,
      mustChangePassword: result.mustChangePassword,
      expiresIn: result.expiresIn,
    );
  }

  Future<({String token, bool mustChangePassword, int expiresIn})>
  _performLogin(
    Uri uri, {
    required String username,
    required String password,
  }) async {
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'username': username, 'password': password},
        )
        .timeout(const Duration(seconds: 30));

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
    final mustChangePassword =
        (data?['must_change_password'] as bool?) ?? false;
    final expiresIn = (data?['expires_in'] as int?) ?? 0;
    return (
      token: token,
      mustChangePassword: mustChangePassword,
      expiresIn: expiresIn,
    );
  }

  Future<void> register({
    required String baseUrl,
    required String account,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/register');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'account': account, 'password': password}),
        )
        .timeout(const Duration(seconds: 30));

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
    final response = await http
        .get(uri, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 30));

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
    final response = await http
        .get(
          uri,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 30));

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

  Future<void> logout({
    required String baseUrl,
    required String accessToken,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/logout');
    final response = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 30));

    final decoded = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(decoded, response.statusCode),
        response.statusCode,
      );
    }
  }

  Future<({String token, int expiresIn})> renewToken({
    required String baseUrl,
    required String accessToken,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/renew-token');
    final response = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'password': password}),
        )
        .timeout(const Duration(seconds: 30));

    final decoded = _decodeBody(response.body);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(decoded, response.statusCode),
        response.statusCode,
      );
    }

    final data = decoded['data'] as Map<String, dynamic>?;
    final newToken = data?['access_token'] as String? ?? '';
    final expiresIn = (data?['expires_in'] as int?) ?? 0;
    if (newToken.isEmpty) {
      throw ApiException('续期失败：缺少新的访问令牌', response.statusCode);
    }
    return (token: newToken, expiresIn: expiresIn);
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
