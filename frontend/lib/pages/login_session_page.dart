import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/user_models.dart';
import '../services/api_exception.dart';
import '../services/user_service.dart';
import '../widgets/simple_pagination_bar.dart';

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
  static const int _logPageSize = 200;
  static const int _sessionPageSize = 200;

  late final UserService _userService;

  final TextEditingController _logUsernameController = TextEditingController();
  final TextEditingController _sessionKeywordController =
      TextEditingController();
  bool? _logSuccessFilter;
  DateTime? _logStartTime;
  DateTime? _logEndTime;

  bool _loadingLogs = false;
  bool _loadingSessions = false;
  String _message = '';

  int _logTotal = 0;
  int _sessionTotal = 0;
  int _logPage = 1;
  int _sessionPage = 1;
  List<LoginLogItem> _loginLogs = const [];
  List<OnlineSessionItem> _onlineSessions = const [];
  final Set<String> _selectedSessionIds = <String>{};

  int get _logTotalPages {
    if (_logTotal <= 0) {
      return 1;
    }
    return ((_logTotal - 1) ~/ _logPageSize) + 1;
  }

  int get _sessionTotalPages {
    if (_sessionTotal <= 0) {
      return 1;
    }
    return ((_sessionTotal - 1) ~/ _sessionPageSize) + 1;
  }

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
    await Future.wait([_loadLoginLogs(), _loadOnlineSessions()]);
  }

  Future<void> _loadLoginLogs({int? page}) async {
    final targetPage = page ?? _logPage;
    setState(() {
      _loadingLogs = true;
      _message = '';
    });
    try {
      final result = await _userService.listLoginLogs(
        page: targetPage,
        pageSize: _logPageSize,
        username: _logUsernameController.text.trim(),
        success: _logSuccessFilter,
        startTime: _logStartTime,
        endTime: _logEndTime,
      );
      if (!mounted) {
        return;
      }
      final resolvedTotalPages = result.total <= 0
          ? 1
          : (((result.total - 1) ~/ _logPageSize) + 1);
      final resolvedPage = targetPage > resolvedTotalPages
          ? resolvedTotalPages
          : targetPage;
      setState(() {
        _loginLogs = result.items;
        _logTotal = result.total;
        _logPage = resolvedPage;
      });
      if (resolvedPage != targetPage) {
        await _loadLoginLogs(page: resolvedPage);
      }
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

  Future<void> _loadOnlineSessions({int? page}) async {
    final targetPage = page ?? _sessionPage;
    setState(() {
      _loadingSessions = true;
      _message = '';
    });
    try {
      final result = await _userService.listOnlineSessions(
        page: targetPage,
        pageSize: _sessionPageSize,
        keyword: _sessionKeywordController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      final validIds = result.items.map((item) => item.sessionTokenId).toSet();
      final resolvedTotalPages = result.total <= 0
          ? 1
          : (((result.total - 1) ~/ _sessionPageSize) + 1);
      final resolvedPage = targetPage > resolvedTotalPages
          ? resolvedTotalPages
          : targetPage;
      setState(() {
        _onlineSessions = result.items;
        _sessionTotal = result.total;
        _sessionPage = resolvedPage;
        _selectedSessionIds.removeWhere((id) => !validIds.contains(id));
      });
      if (resolvedPage != targetPage) {
        await _loadOnlineSessions(page: resolvedPage);
      }
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

  String _sessionStatusLabel(String status) {
    switch (status) {
      case 'active':
        return '在线';
      case 'forced_offline':
        return '已强制下线';
      case 'expired':
        return '已过期';
      default:
        return status;
    }
  }

  Color _sessionStatusColor(BuildContext context, String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'forced_offline':
        return Colors.deepOrange;
      case 'expired':
        return Theme.of(context).colorScheme.error;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
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
    final startLabel = _logStartTime != null
        ? '${_logStartTime!.year}-${_logStartTime!.month.toString().padLeft(2, '0')}-${_logStartTime!.day.toString().padLeft(2, '0')}'
        : '开始日期';
    final endLabel = _logEndTime != null
        ? '${_logEndTime!.year}-${_logEndTime!.month.toString().padLeft(2, '0')}-${_logEndTime!.day.toString().padLeft(2, '0')}'
        : '结束日期';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _logUsernameController,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadLoginLogs(page: 1),
                ),
              ),
              DropdownButton<bool?>(
                value: _logSuccessFilter,
                items: const [
                  DropdownMenuItem<bool?>(value: null, child: Text('全部')),
                  DropdownMenuItem<bool?>(value: true, child: Text('成功')),
                  DropdownMenuItem<bool?>(value: false, child: Text('失败')),
                ],
                onChanged: (value) {
                  setState(() => _logSuccessFilter = value);
                  _loadLoginLogs(page: 1);
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(startLabel),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _logStartTime ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) {
                    setState(() => _logStartTime = picked);
                  }
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(endLabel),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _logEndTime ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) {
                    setState(
                      () => _logEndTime = DateTime(
                        picked.year,
                        picked.month,
                        picked.day,
                        23,
                        59,
                        59,
                      ),
                    );
                  }
                },
              ),
              if (_logStartTime != null || _logEndTime != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _logStartTime = null;
                      _logEndTime = null;
                    });
                    _loadLoginLogs(page: 1);
                  },
                  child: const Text('清除时间'),
                ),
              OutlinedButton(
                onPressed: () => _loadLoginLogs(page: 1),
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
              : _loginLogs.isEmpty
              ? const Center(child: Text('暂无登录日志'))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 980),
                          child: SingleChildScrollView(
                            child: DataTable(
                              columnSpacing: 20,
                              headingRowHeight: 44,
                              dataRowMinHeight: 56,
                              dataRowMaxHeight: 72,
                              columns: const [
                                DataColumn(label: Text('用户名')),
                                DataColumn(label: Text('结果')),
                                DataColumn(label: Text('登录时间')),
                                DataColumn(label: Text('IP 地址')),
                                DataColumn(label: Text('终端信息')),
                                DataColumn(label: Text('失败原因')),
                              ],
                              rows: _loginLogs.map((item) {
                                final successColor = item.success
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.error;
                                return DataRow(
                                  cells: [
                                    DataCell(Text(item.username)),
                                    DataCell(
                                      Text(
                                        item.success ? '成功' : '失败',
                                        style: TextStyle(
                                          color: successColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(_formatDateTime(item.loginTime))),
                                    DataCell(Text(item.ipAddress ?? '-')),
                                    DataCell(Text(item.terminalInfo ?? '-')),
                                    DataCell(Text(item.failureReason ?? '-')),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: SimplePaginationBar(
            page: _logPage,
            totalPages: _logTotalPages,
            total: _logTotal,
            loading: _loadingLogs,
            onPrevious: () => _loadLoginLogs(page: _logPage - 1),
            onNext: () => _loadLoginLogs(page: _logPage + 1),
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
                  onSubmitted: (_) => _loadOnlineSessions(page: 1),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _loadOnlineSessions(page: 1),
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
              : _onlineSessions.isEmpty
              ? const Center(child: Text('暂无在线会话'))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 1220),
                          child: SingleChildScrollView(
                            child: DataTable(
                              columnSpacing: 16,
                              headingRowHeight: 44,
                              dataRowMinHeight: 60,
                              dataRowMaxHeight: 76,
                              columns: const [
                                DataColumn(label: Text('选择')),
                                DataColumn(label: Text('用户名')),
                                DataColumn(label: Text('角色')),
                                DataColumn(label: Text('工段')),
                                DataColumn(label: Text('状态')),
                                DataColumn(label: Text('登录时间')),
                                DataColumn(label: Text('最后活跃')),
                                DataColumn(label: Text('IP 地址')),
                                DataColumn(label: Text('终端信息')),
                                DataColumn(label: Text('操作')),
                              ],
                              rows: _onlineSessions.map((item) {
                                final checked = _selectedSessionIds.contains(
                                  item.sessionTokenId,
                                );
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Checkbox(
                                        value: checked,
                                        onChanged: widget.canManage
                                            ? (value) {
                                                setState(() {
                                                  if (value ?? false) {
                                                    _selectedSessionIds.add(
                                                      item.sessionTokenId,
                                                    );
                                                  } else {
                                                    _selectedSessionIds.remove(
                                                      item.sessionTokenId,
                                                    );
                                                  }
                                                });
                                              }
                                            : null,
                                      ),
                                    ),
                                    DataCell(Text(item.username)),
                                    DataCell(
                                      Text(
                                        item.roleName?.trim().isNotEmpty == true
                                            ? item.roleName!
                                            : '-',
                                      ),
                                    ),
                                    DataCell(Text(item.stageName ?? '-')),
                                    DataCell(
                                      Text(
                                        _sessionStatusLabel(item.status),
                                        style: TextStyle(
                                          color: _sessionStatusColor(
                                            context,
                                            item.status,
                                          ),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(_formatDateTime(item.loginTime))),
                                    DataCell(
                                      Text(_formatDateTime(item.lastActiveAt)),
                                    ),
                                    DataCell(Text(item.ipAddress ?? '-')),
                                    DataCell(Text(item.terminalInfo ?? '-')),
                                    DataCell(
                                      OutlinedButton(
                                        onPressed: widget.canManage
                                            ? () => _forceOfflineSingle(
                                                item.sessionTokenId,
                                              )
                                            : null,
                                        child: const Text('强制下线'),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: SimplePaginationBar(
            page: _sessionPage,
            totalPages: _sessionTotalPages,
            total: _sessionTotal,
            loading: _loadingSessions,
            onPrevious: () => _loadOnlineSessions(page: _sessionPage - 1),
            onNext: () => _loadOnlineSessions(page: _sessionPage + 1),
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
              children: [_buildLoginLogsTab(), _buildOnlineSessionsTab()],
            ),
          ),
        ],
      ),
    );
  }
}
