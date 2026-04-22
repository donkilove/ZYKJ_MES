import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/message/models/message_models.dart';
import 'package:mes_client/core/network/api_exception.dart';

class MessageService {
  MessageService(AppSession session)
    : _baseUrl = session.baseUrl,
      _accessToken = session.accessToken;

  MessageService.public(String baseUrl)
    : _baseUrl = baseUrl,
      _accessToken = null;

  final String _baseUrl;
  final String? _accessToken;

  String get _base => '$_baseUrl/messages';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_accessToken != null && _accessToken.isNotEmpty)
      'Authorization': 'Bearer $_accessToken',
  };

  Future<int> getUnreadCount() async {
    final uri = Uri.parse('$_base/unread-count');
    final resp = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));
    _checkStatus(resp);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = (body['data'] as Map<String, dynamic>?) ?? const {};
    return (data['unread_count'] as int?) ?? 0;
  }

  Future<MessageSummaryResult> getSummary() async {
    final uri = Uri.parse('$_base/summary');
    final resp = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));
    _checkStatus(resp);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return MessageSummaryResult.fromJson(
      (body['data'] as Map<String, dynamic>?) ?? const {},
    );
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
      if (messageType != null && messageType.isNotEmpty)
        'message_type': messageType,
      if (priority != null && priority.isNotEmpty) 'priority': priority,
      if (sourceModule != null && sourceModule.isNotEmpty)
        'source_module': sourceModule,
      if (startTime != null) 'start_time': startTime.toUtc().toIso8601String(),
      if (endTime != null) 'end_time': endTime.toUtc().toIso8601String(),
      if (todoOnly) 'todo_only': 'true',
      if (!activeOnly) 'active_only': 'false',
    };
    final uri = Uri.parse(_base).replace(queryParameters: params);
    final resp = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));
    _checkStatus(resp);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return MessageListResult.fromJson(
      (body['data'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Future<List<MessageItem>> getAnnouncements({
    int pageSize = 20,
    String? priority,
  }) async {
    final result = await listMessages(
      messageType: 'announcement',
      status: 'active',
      pageSize: pageSize,
      priority: priority,
    );
    return result.items;
  }

  Future<List<MessageItem>> getPublicAnnouncements({
    int page = 1,
    int pageSize = 10,
    String? priority,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      if (priority != null && priority.isNotEmpty) 'priority': priority,
    };
    final uri = Uri.parse(
      '$_base/public-announcements',
    ).replace(queryParameters: params);
    final resp = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));
    _checkStatus(resp);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final result = MessageListResult.fromJson(
      (body['data'] as Map<String, dynamic>?) ?? const {},
    );
    return result.items;
  }

  Future<void> markRead(int messageId) async {
    final uri = Uri.parse('$_base/$messageId/read');
    final resp = await http
        .post(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));
    _checkStatus(resp);
  }

  Future<void> markAllRead() async {
    final uri = Uri.parse('$_base/read-all');
    final resp = await http
        .post(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));
    _checkStatus(resp);
  }

  Future<int> markBatchRead(List<int> messageIds) async {
    final uri = Uri.parse('$_base/read-batch');
    final resp = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({'message_ids': messageIds}),
        )
        .timeout(const Duration(seconds: 30));
    _checkStatus(resp);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return (data['updated'] as int?) ?? 0;
  }

  Future<AnnouncementPublishResult> publishAnnouncement(
    AnnouncementPublishRequest request,
  ) async {
    final uri = Uri.parse('$_base/announcements');
    final resp = await http
        .post(uri, headers: _headers, body: jsonEncode(request.toJson()))
        .timeout(const Duration(seconds: 30));
    _checkStatus(resp);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return AnnouncementPublishResult.fromJson(
      (body['data'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Future<MessageMaintenanceResult> runMaintenance() async {
    final uri = Uri.parse('$_base/maintenance/run');
    final resp = await http
        .post(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));
    _checkStatus(resp);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return MessageMaintenanceResult.fromJson(
      (body['data'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Future<MessageDetailResult> getMessageDetail(int messageId) async {
    final uri = Uri.parse('$_base/$messageId');
    final resp = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));
    _checkStatus(resp);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return MessageDetailResult.fromJson(
      (body['data'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Future<MessageJumpResult> getMessageJumpTarget(int messageId) async {
    final uri = Uri.parse('$_base/$messageId/jump-target');
    final resp = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));
    _checkStatus(resp);
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return MessageJumpResult.fromJson(
      (body['data'] as Map<String, dynamic>?) ?? const {},
    );
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
