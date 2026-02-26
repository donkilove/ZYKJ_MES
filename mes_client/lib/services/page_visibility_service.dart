import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_session.dart';
import '../models/page_visibility_models.dart';
import 'api_exception.dart';

class PageVisibilityService {
  PageVisibilityService(this.session);

  final AppSession session;

  Map<String, String> get _authHeaders {
    return {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  Future<List<PageCatalogItem>> listPageCatalog() async {
    final uri = Uri.parse('${session.baseUrl}/ui/page-catalog');
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }

    final data = json['data'] as Map<String, dynamic>;
    final items =
        (data['items'] as List<dynamic>? ?? const [])
            .map((entry) => PageCatalogItem.fromJson(entry as Map<String, dynamic>))
            .toList();
    return items;
  }

  Future<PageVisibilityMeResult> getMyVisibility() async {
    final uri = Uri.parse('${session.baseUrl}/ui/page-visibility/me');
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }

    final data = json['data'] as Map<String, dynamic>;
    return PageVisibilityMeResult.fromJson(data);
  }

  Future<List<PageVisibilityConfigItem>> getVisibilityConfig() async {
    final uri = Uri.parse('${session.baseUrl}/ui/page-visibility/config');
    final response = await http.get(uri, headers: _authHeaders);
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }

    final data = json['data'] as Map<String, dynamic>;
    final items =
        (data['items'] as List<dynamic>? ?? const [])
            .map(
              (entry) =>
                  PageVisibilityConfigItem.fromJson(entry as Map<String, dynamic>),
            )
            .toList();
    return items;
  }

  Future<int> updateVisibilityConfig({
    required List<PageVisibilityConfigUpdateItem> items,
  }) async {
    final uri = Uri.parse('${session.baseUrl}/ui/page-visibility/config');
    final response = await http.put(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'items': items.map((entry) => entry.toJson()).toList(),
      }),
    );
    final json = _decodeBody(response);
    if (response.statusCode != 200) {
      throw ApiException(
        _extractErrorMessage(json, response.statusCode),
        response.statusCode,
      );
    }
    final data = json['data'] as Map<String, dynamic>;
    return (data['updated_count'] as int?) ?? 0;
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
