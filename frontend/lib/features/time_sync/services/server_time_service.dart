import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/time_sync/models/time_sync_models.dart';

class ServerTimeService {
  ServerTimeService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<ServerTimeSnapshot> fetchSnapshot({required String baseUrl}) async {
    final uri = Uri.parse('$baseUrl/system/time');
    final response = await _client
        .get(uri, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 15));

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(decoded, response.statusCode),
        response.statusCode,
      );
    }

    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw ApiException('获取服务器时间失败：响应数据为空', response.statusCode);
    }
    return ServerTimeSnapshot.fromJson(data);
  }

  String _extractErrorMessage(Map<String, dynamic> body, int statusCode) {
    final message = body['message'];
    if (message is String && message.isNotEmpty) {
      return message;
    }
    return '获取服务器时间失败，状态码 $statusCode';
  }
}
