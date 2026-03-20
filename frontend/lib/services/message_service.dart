import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_session.dart';
import '../models/message_models.dart';
import 'api_exception.dart';

class MessageService {
  MessageService(this._session);

  final AppSession _session;

  String get _base => '${_session.baseUrl}/messages';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${_session.accessToken}',
        'Content-Type': 'application/json',
      };

  Future<int> getUnreadCount() async {
    final uri = Uri.parse('$_base/unread-count');
    final resp = await http.get(uri, headers: _headers);
    _checkStatus(resp);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return (data['unread_count'] as int?) ?? 0;
  }

  Future<MessageSummaryResult> getSummary() async {
    final uri = Uri.parse('$_base/summary');
    final resp = await http.get(uri, headers: _headers);
    _checkStatus(resp);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return MessageSummaryResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<MessageListResult> listMessages({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? status,
    String? messageType,
    String? priority,
    String? sourceModule,
    DateTime? startTime,
    DateTime? endTime,
    bool todoOnly = false,
    bool activeOnly = true,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      if (status != null && status.isNotEmpty) 'status': status,
      if (messageType != null && messageType.isNotEmpty) 'message_type': messageType,
      if (priority != null && priority.isNotEmpty) 'priority': priority,
      if (sourceModule != null && sourceModule.isNotEmpty) 'source_module': sourceModule,
      if (startTime != null) 'start_time': startTime.toUtc().toIso8601String(),
      if (endTime != null) 'end_time': endTime.toUtc().toIso8601String(),
      if (todoOnly) 'todo_only': 'true',
      if (!activeOnly) 'active_only': 'false',
    };
    final uri = Uri.parse(_base).replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers);
    _checkStatus(resp);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return MessageListResult.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> markRead(int messageId) async {
    final uri = Uri.parse('$_base/$messageId/read');
    final resp = await http.post(uri, headers: _headers);
    _checkStatus(resp);
  }

  Future<void> markAllRead() async {
    final uri = Uri.parse('$_base/read-all');
    final resp = await http.post(uri, headers: _headers);
    _checkStatus(resp);
  }

  Future<int> markBatchRead(List<int> messageIds) async {
    final uri = Uri.parse('$_base/read-batch');
    final resp = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({'message_ids': messageIds}),
    );
    _checkStatus(resp);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return (data['updated'] as int?) ?? 0;
  }

  void _checkStatus(http.Response resp) {
    if (resp.statusCode == 401) {
      throw ApiException('登录已过期，请重新登录', 401);
    }
    if (resp.statusCode == 403) {
      throw ApiException('无权限访问消息接口', 403);
    }
    if (resp.statusCode >= 400) {
      String msg = '请求失败（${resp.statusCode}）';
      try {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        msg = body['detail']?.toString() ?? msg;
      } catch (_) {}
      throw ApiException(msg, resp.statusCode);
    }
  }
}
