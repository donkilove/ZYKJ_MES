import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/user_models.dart';
import '../services/api_exception.dart';
import '../services/user_service.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final AppSession session;
  final VoidCallback onLogout;

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  late final UserService _userService;
  final TextEditingController _operatorController = TextEditingController();
  final TextEditingController _actionController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();

  bool _loading = false;
  String _message = '';
  int _total = 0;
  List<AuditLogItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _userService = UserService(widget.session);
    _loadAuditLogs();
  }

  @override
  void dispose() {
    _operatorController.dispose();
    _actionController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  bool _isUnauthorized(Object error) =>
      error is ApiException && error.statusCode == 401;

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  Future<void> _loadAuditLogs() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _userService.listAuditLogs(
        page: 1,
        pageSize: 200,
        operatorUsername: _operatorController.text.trim(),
        actionCode: _actionController.text.trim(),
        targetType: _targetController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items = result.items;
        _total = result.total;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '加载审计日志失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}:${twoDigits(local.second)}';
  }

  String _resultLabel(String result) {
    switch (result.toLowerCase()) {
      case 'success':
        return '成功';
      case 'failed':
      case 'failure':
      case 'error':
        return '失败';
      default:
        return result;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _operatorController,
                  decoration: const InputDecoration(
                    labelText: '操作人账号',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadAuditLogs(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _actionController,
                  decoration: const InputDecoration(
                    labelText: '操作编码',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadAuditLogs(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _targetController,
                  decoration: const InputDecoration(
                    labelText: '目标类型',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadAuditLogs(),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _loadAuditLogs,
                child: const Text('查询'),
              ),
            ],
          ),
        ),
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(_message, style: const TextStyle(color: Colors.red)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('总数：$_total'),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return ListTile(
                      title: Text(
                        '${item.actionName.isEmpty ? item.actionCode : item.actionName} '
                        '[${_resultLabel(item.result)}]',
                      ),
                      subtitle: Text(
                        '时间=${_formatDateTime(item.occurredAt)}\n'
                        '操作人=${item.operatorUsername ?? '-'} '
                        '目标=${item.targetType}:${item.targetName ?? item.targetId ?? '-'}\n'
                        'IP=${item.ipAddress ?? '-'}',
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
