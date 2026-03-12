import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/user_models.dart';
import '../services/api_exception.dart';
import '../services/user_service.dart';

class LoginSessionPage extends StatefulWidget {
  const LoginSessionPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canManage,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canManage;

  @override
  State<LoginSessionPage> createState() => _LoginSessionPageState();
}

class _LoginSessionPageState extends State<LoginSessionPage> {
  late final UserService _userService;

  final TextEditingController _logUsernameController = TextEditingController();
  final TextEditingController _sessionKeywordController =
      TextEditingController();
  bool? _logSuccessFilter;

  bool _loadingLogs = false;
  bool _loadingSessions = false;
  String _message = '';

  int _logTotal = 0;
  int _sessionTotal = 0;
  List<LoginLogItem> _loginLogs = const [];
  List<OnlineSessionItem> _onlineSessions = const [];
  final Set<String> _selectedSessionIds = <String>{};

  @override
  void initState() {
    super.initState();
    _userService = UserService(widget.session);
    _loadAll();
  }

  @override
  void dispose() {
    _logUsernameController.dispose();
    _sessionKeywordController.dispose();
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

  Future<void> _loadAll() async {
    await Future.wait([
      _loadLoginLogs(),
      _loadOnlineSessions(),
    ]);
  }

  Future<void> _loadLoginLogs() async {
    setState(() {
      _loadingLogs = true;
      _message = '';
    });
    try {
      final result = await _userService.listLoginLogs(
        page: 1,
        pageSize: 200,
        username: _logUsernameController.text.trim(),
        success: _logSuccessFilter,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _loginLogs = result.items;
        _logTotal = result.total;
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
        _message = '加载登录日志失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingLogs = false;
        });
      }
    }
  }

  Future<void> _loadOnlineSessions() async {
    setState(() {
      _loadingSessions = true;
      _message = '';
    });
    try {
      final result = await _userService.listOnlineSessions(
        page: 1,
        pageSize: 200,
        keyword: _sessionKeywordController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      final validIds = result.items.map((item) => item.sessionTokenId).toSet();
      setState(() {
        _onlineSessions = result.items;
        _sessionTotal = result.total;
        _selectedSessionIds.removeWhere((id) => !validIds.contains(id));
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
        _message = '加载在线会话失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingSessions = false;
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

  Future<void> _forceOfflineSingle(String sessionTokenId) async {
    if (!widget.canManage) {
      return;
    }
    try {
      await _userService.forceOffline(sessionTokenId: sessionTokenId);
      if (!mounted) {
        return;
      }
      await _loadOnlineSessions();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  Future<void> _forceOfflineBatch() async {
    if (!widget.canManage || _selectedSessionIds.isEmpty) {
      return;
    }
    try {
      await _userService.batchForceOffline(
        sessionTokenIds: _selectedSessionIds.toList(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedSessionIds.clear();
      });
      await _loadOnlineSessions();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  Widget _buildLoginLogsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _logUsernameController,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadLoginLogs(),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<bool?>(
                value: _logSuccessFilter,
                items: const [
                  DropdownMenuItem<bool?>(value: null, child: Text('全部')),
                  DropdownMenuItem<bool?>(value: true, child: Text('成功')),
                  DropdownMenuItem<bool?>(value: false, child: Text('失败')),
                ],
                onChanged: (value) {
                  setState(() {
                    _logSuccessFilter = value;
                  });
                  _loadLoginLogs();
                },
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _loadLoginLogs,
                child: const Text('查询'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('总数：$_logTotal'),
          ),
        ),
        Expanded(
          child: _loadingLogs
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _loginLogs.length,
                  itemBuilder: (context, index) {
                    final item = _loginLogs[index];
                    return ListTile(
                      title: Text(
                        '${item.username} | ${item.success ? '成功' : '失败'}',
                      ),
                      subtitle: Text(
                        '登录时间=${_formatDateTime(item.loginTime)}\n'
                        'IP=${item.ipAddress ?? '-'}\n'
                        '失败原因=${item.failureReason ?? '-'}',
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOnlineSessionsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sessionKeywordController,
                  decoration: const InputDecoration(
                    labelText: '关键词',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadOnlineSessions(),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _loadOnlineSessions,
                child: const Text('查询'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: widget.canManage && _selectedSessionIds.isNotEmpty
                    ? _forceOfflineBatch
                    : null,
                child: Text('批量强制下线（${_selectedSessionIds.length}）'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('总数：$_sessionTotal'),
          ),
        ),
        Expanded(
          child: _loadingSessions
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _onlineSessions.length,
                  itemBuilder: (context, index) {
                    final item = _onlineSessions[index];
                    return CheckboxListTile(
                      value: _selectedSessionIds.contains(item.sessionTokenId),
                      onChanged: widget.canManage
                          ? (checked) {
                              setState(() {
                                if (checked ?? false) {
                                  _selectedSessionIds.add(item.sessionTokenId);
                                } else {
                                  _selectedSessionIds.remove(item.sessionTokenId);
                                }
                              });
                            }
                          : null,
                      title: Text('${item.username}（${item.roleNames.join('、')}）'),
                      subtitle: Text(
                        '登录时间=${_formatDateTime(item.loginTime)}\n'
                        '最后活跃=${_formatDateTime(item.lastActiveAt)}\n'
                        '过期时间=${_formatDateTime(item.expiresAt)}\n'
                        'IP=${item.ipAddress ?? '-'}',
                      ),
                      isThreeLine: true,
                      secondary: IconButton(
                        onPressed: widget.canManage
                            ? () => _forceOfflineSingle(item.sessionTokenId)
                            : null,
                        icon: const Icon(Icons.power_settings_new_outlined),
                        tooltip: '强制下线',
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _message,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          const TabBar(
            tabs: [
              Tab(text: '登录日志'),
              Tab(text: '在线会话'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildLoginLogsTab(),
                _buildOnlineSessionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
