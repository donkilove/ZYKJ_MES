import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/models/page_catalog_models.dart';
import 'package:mes_client/core/network/api_exception.dart';

class PageCatalogService {
  PageCatalogService(this.session);

  final AppSession session;

  Map<String, String> get _authHeaders {
    return {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  Future<List<PageCatalogItem>> listPageCatalog() async {
    final uri = Uri.parse('${session.baseUrl}/ui/page-catalog');
    final response = await http.get(uri, headers: _authHeaders).timeout(const Duration(seconds: 30));
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }

    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    final items =
        (data['items'] as List<dynamic>? ?? const [])
            .map((entry) => PageCatalogItem.fromJson(entry as Map<String, dynamic>))
            .toList();
    return items;
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
