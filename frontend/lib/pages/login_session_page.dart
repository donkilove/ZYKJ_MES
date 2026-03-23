import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/user_models.dart';
import '../services/api_exception.dart';
import '../services/user_service.dart';
import '../widgets/adaptive_table_container.dart';
import '../widgets/simple_pagination_bar.dart';
import '../widgets/unified_list_table_header_style.dart';

class LoginSessionPage extends StatefulWidget {
  const LoginSessionPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canViewLoginLogs,
    required this.canViewOnlineSessions,
    required this.canForceOffline,
    this.userService,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canViewLoginLogs;
  final bool canViewOnlineSessions;
  final bool canForceOffline;
  final UserService? userService;

  @override
  State<LoginSessionPage> createState() => _LoginSessionPageState();
}

class _LoginSessionPageState extends State<LoginSessionPage> {
  static const int _logPageSize = 200;
  static const int _sessionPageSize = 200;
  static const double _logTableMinWidth = 1040;
  static const double _sessionTableMinWidth = 1280;
  static const Key _loginLogsTabKey = Key('login-session-tab-login-logs');
  static const Key _onlineSessionsTabKey = Key(
    'login-session-tab-online-sessions',
  );
  static const Key _loginLogsSectionTitleKey = Key(
    'login-session-section-title-login-logs',
  );
  static const Key _onlineSessionsSectionTitleKey = Key(
    'login-session-section-title-online-sessions',
  );

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
  String? _sessionStatusFilter;

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
    _userService = widget.userService ?? UserService(widget.session);
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
    final tasks = <Future<void>>[];
    if (widget.canViewLoginLogs) {
      tasks.add(_loadLoginLogs());
    }
    if (widget.canViewOnlineSessions) {
      tasks.add(_loadOnlineSessions());
    }
    if (tasks.isEmpty) {
      setState(() {
        _message = '当前账号没有登录日志或在线会话查看权限。';
      });
      return;
    }
    await Future.wait(tasks);
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
        statusFilter: _sessionStatusFilter,
      );
      if (!mounted) {
        return;
      }
      final validIds = result.items.map((item) => item.sessionTokenId).toSet();
      final activeIds = result.items
          .where((item) => item.status == 'active')
          .map((item) => item.sessionTokenId)
          .toSet();
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
        _selectedSessionIds.removeWhere(
          (id) => !validIds.contains(id) || !activeIds.contains(id),
        );
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
    return status == 'active' ? '在线' : '离线';
  }

  bool _canForceOfflineSession(OnlineSessionItem item) {
    return widget.canForceOffline && item.status == 'active';
  }

  Color _sessionStatusColor(BuildContext context, String status) {
    return status == 'active' ? Colors.green : Colors.grey;
  }

  Future<void> _forceOfflineSingle(String sessionTokenId) async {
    if (!widget.canForceOffline) {
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
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  Future<void> _forceOfflineBatch() async {
    if (!widget.canForceOffline || _selectedSessionIds.isEmpty) {
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
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  Widget _buildMetricChip(
    ThemeData theme,
    String label,
    String value, {
    Color? color,
  }) {
    final resolvedColor = color ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: resolvedColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: resolvedColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }

  DataCell _dataCell(String value, {double maxWidth = 220}) {
    return DataCell(
      Tooltip(
        message: value,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  Widget _buildSectionShell({
    required ThemeData theme,
    required String title,
    required List<Widget> metrics,
    required Widget filters,
    required bool loading,
    required bool isEmpty,
    required String emptyText,
    required Widget table,
    required Widget pagination,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    key: title == '登录日志'
                        ? _loginLogsSectionTitleKey
                        : title == '在线会话'
                        ? _onlineSessionsSectionTitleKey
                        : null,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 12, runSpacing: 12, children: metrics),
                  const SizedBox(height: 12),
                  filters,
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : isEmpty
                        ? Center(child: Text(emptyText))
                        : table,
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: pagination,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginLogsTab() {
    final startLabel = _logStartTime != null
        ? '${_logStartTime!.year}-${_logStartTime!.month.toString().padLeft(2, '0')}-${_logStartTime!.day.toString().padLeft(2, '0')}'
        : '开始日期';
    final endLabel = _logEndTime != null
        ? '${_logEndTime!.year}-${_logEndTime!.month.toString().padLeft(2, '0')}-${_logEndTime!.day.toString().padLeft(2, '0')}'
        : '结束日期';
    final theme = Theme.of(context);
    final successCount = _loginLogs.where((item) => item.success).length;
    final table = AdaptiveTableContainer(
      minTableWidth: _logTableMinWidth,
      padding: const EdgeInsets.all(12),
      child: UnifiedListTableHeaderStyle.wrap(
        theme: theme,
        child: DataTable(
          dataRowMinHeight: 58,
          dataRowMaxHeight: 76,
          columns: [
            UnifiedListTableHeaderStyle.column(context, '用户名'),
            UnifiedListTableHeaderStyle.column(context, '结果'),
            UnifiedListTableHeaderStyle.column(context, '登录时间'),
            UnifiedListTableHeaderStyle.column(context, 'IP 地址'),
            UnifiedListTableHeaderStyle.column(context, '终端信息'),
            UnifiedListTableHeaderStyle.column(context, '失败原因'),
          ],
          rows: _loginLogs.map((item) {
            final successColor = item.success
                ? Colors.green
                : theme.colorScheme.error;
            return DataRow(
              cells: [
                _dataCell(item.username),
                DataCell(
                  Text(
                    item.success ? '成功' : '失败',
                    style: TextStyle(
                      color: successColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _dataCell(_formatDateTime(item.loginTime)),
                _dataCell(item.ipAddress ?? '-'),
                _dataCell(item.terminalInfo ?? '-'),
                _dataCell(item.failureReason ?? '-', maxWidth: 260),
              ],
            );
          }).toList(),
        ),
      ),
    );

    return _buildSectionShell(
      theme: theme,
      title: '登录日志',
      metrics: [
        _buildMetricChip(theme, '总记录', '$_logTotal'),
        _buildMetricChip(theme, '本页成功', '$successCount', color: Colors.green),
        _buildMetricChip(
          theme,
          '本页失败',
          '${_loginLogs.length - successCount}',
          color: theme.colorScheme.error,
        ),
      ],
      filters: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 180,
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
              DropdownMenuItem<bool?>(value: null, child: Text('全部结果')),
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
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _logStartTime = null;
                  _logEndTime = null;
                });
                _loadLoginLogs(page: 1);
              },
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('清除时间'),
            ),
          FilledButton.icon(
            onPressed: () => _loadLoginLogs(page: 1),
            icon: const Icon(Icons.search, size: 16),
            label: const Text('查询'),
          ),
        ],
      ),
      loading: _loadingLogs,
      isEmpty: _loginLogs.isEmpty,
      emptyText: '暂无登录日志',
      table: table,
      pagination: SimplePaginationBar(
        page: _logPage,
        totalPages: _logTotalPages,
        total: _logTotal,
        loading: _loadingLogs,
        onPrevious: () => _loadLoginLogs(page: _logPage - 1),
        onNext: () => _loadLoginLogs(page: _logPage + 1),
        onPageChanged: (page) => _loadLoginLogs(page: page),
      ),
    );
  }

  Widget _buildOnlineSessionsTab() {
    final theme = Theme.of(context);
    final activeCount = _onlineSessions
        .where((item) => item.status == 'active')
        .length;
    final table = AdaptiveTableContainer(
      minTableWidth: _sessionTableMinWidth,
      padding: const EdgeInsets.all(12),
      child: UnifiedListTableHeaderStyle.wrap(
        theme: theme,
        child: DataTable(
          dataRowMinHeight: 60,
          dataRowMaxHeight: 76,
          columns: [
            UnifiedListTableHeaderStyle.column(context, '选择'),
            UnifiedListTableHeaderStyle.column(context, '用户名'),
            UnifiedListTableHeaderStyle.column(context, '角色'),
            UnifiedListTableHeaderStyle.column(context, '工段'),
            UnifiedListTableHeaderStyle.column(context, '状态'),
            UnifiedListTableHeaderStyle.column(context, '登录时间'),
            UnifiedListTableHeaderStyle.column(context, '最后活跃'),
            UnifiedListTableHeaderStyle.column(context, 'IP 地址'),
            UnifiedListTableHeaderStyle.column(context, '终端信息'),
            UnifiedListTableHeaderStyle.column(context, '操作'),
          ],
          rows: _onlineSessions.map((item) {
            final checked = _selectedSessionIds.contains(item.sessionTokenId);
            final canForceOffline = _canForceOfflineSession(item);
            return DataRow(
              cells: [
                DataCell(
                  Checkbox(
                    value: checked,
                    onChanged: canForceOffline
                        ? (value) {
                            setState(() {
                              if (value ?? false) {
                                _selectedSessionIds.add(item.sessionTokenId);
                              } else {
                                _selectedSessionIds.remove(item.sessionTokenId);
                              }
                            });
                          }
                        : null,
                  ),
                ),
                _dataCell(item.username),
                _dataCell(
                  item.roleName?.trim().isNotEmpty == true
                      ? item.roleName!
                      : '-',
                ),
                _dataCell(item.stageName ?? '-'),
                DataCell(
                  Text(
                    _sessionStatusLabel(item.status),
                    style: TextStyle(
                      color: _sessionStatusColor(context, item.status),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _dataCell(_formatDateTime(item.loginTime)),
                _dataCell(_formatDateTime(item.lastActiveAt)),
                _dataCell(item.ipAddress ?? '-'),
                _dataCell(item.terminalInfo ?? '-'),
                DataCell(
                  OutlinedButton(
                    onPressed: canForceOffline
                        ? () => _forceOfflineSingle(item.sessionTokenId)
                        : null,
                    child: const Text('强制下线'),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );

    return _buildSectionShell(
      theme: theme,
      title: '在线会话',
      metrics: [
        _buildMetricChip(theme, '总会话', '$_sessionTotal'),
        _buildMetricChip(theme, '本页在线', '$activeCount', color: Colors.green),
        _buildMetricChip(
          theme,
          '已勾选',
          '${_selectedSessionIds.length}',
          color: theme.colorScheme.secondary,
        ),
      ],
      filters: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
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
          DropdownButton<String?>(
            value: _sessionStatusFilter,
            items: const [
              DropdownMenuItem<String?>(value: null, child: Text('全部状态')),
              DropdownMenuItem<String?>(value: 'active', child: Text('在线')),
              DropdownMenuItem<String?>(value: 'offline', child: Text('离线')),
            ],
            onChanged: (value) {
              setState(() => _sessionStatusFilter = value);
              _loadOnlineSessions(page: 1);
            },
          ),
          FilledButton.icon(
            onPressed: () => _loadOnlineSessions(page: 1),
            icon: const Icon(Icons.search, size: 16),
            label: const Text('查询'),
          ),
          FilledButton.tonalIcon(
            onPressed: widget.canForceOffline && _selectedSessionIds.isNotEmpty
                ? _forceOfflineBatch
                : null,
            icon: const Icon(Icons.power_settings_new, size: 16),
            label: Text('批量强制下线（${_selectedSessionIds.length}）'),
          ),
        ],
      ),
      loading: _loadingSessions,
      isEmpty: _onlineSessions.isEmpty,
      emptyText: '暂无在线会话',
      table: table,
      pagination: SimplePaginationBar(
        page: _sessionPage,
        totalPages: _sessionTotalPages,
        total: _sessionTotal,
        loading: _loadingSessions,
        onPrevious: () => _loadOnlineSessions(page: _sessionPage - 1),
        onNext: () => _loadOnlineSessions(page: _sessionPage + 1),
        onPageChanged: (page) => _loadOnlineSessions(page: page),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[];
    final pages = <Widget>[];
    if (widget.canViewLoginLogs) {
      tabs.add(const Tab(key: _loginLogsTabKey, text: '登录日志'));
      pages.add(_buildLoginLogsTab());
    }
    if (widget.canViewOnlineSessions) {
      tabs.add(const Tab(key: _onlineSessionsTabKey, text: '在线会话'));
      pages.add(_buildOnlineSessionsTab());
    }

    if (tabs.isEmpty) {
      return Center(
        child: Text(_message.isEmpty ? '当前账号没有登录日志或在线会话查看权限。' : _message),
      );
    }

    return DefaultTabController(
      length: tabs.length,
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
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(tabs: tabs),
          ),
          Expanded(child: TabBarView(children: pages)),
        ],
      ),
    );
  }
}
