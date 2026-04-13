import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/shell/models/home_dashboard_models.dart';

class HomeDashboardService {
  HomeDashboardService(this.session);

  final AppSession session;

  Map<String, String> get _authHeaders {
    return {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  Future<HomeDashboardData> load() async {
    final uri = Uri.parse('${session.baseUrl}/ui/home-dashboard');
    final response = await http.get(uri, headers: _authHeaders);
    final body = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(body),
        response.statusCode,
      );
    }

    final data = body['data'];
    return HomeDashboardData.fromJson(
      data is Map<String, dynamic> ? data : const {},
    );
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    if (response.body.isEmpty) {
      return {};
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _extractErrorMessage(Map<String, dynamic> body) {
    final detail = body['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
    final message = body['message'];
    if (message is String && message.isNotEmpty) {
      return message;
    }
    return '加载首页工作台失败';
  }
}
