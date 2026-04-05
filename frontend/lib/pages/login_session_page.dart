import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/user_models.dart';
import '../services/api_exception.dart';
import '../services/user_service.dart';
import '../widgets/crud_list_table_section.dart';
import '../widgets/crud_page_header.dart';
import '../widgets/simple_pagination_bar.dart';
import '../widgets/unified_list_table_header_style.dart';

class LoginSessionPage extends StatefulWidget {
  const LoginSessionPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canViewOnlineSessions,
    required this.canForceOffline,
    this.userService,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canViewOnlineSessions;
  final bool canForceOffline;
  final UserService? userService;

  @override
  State<LoginSessionPage> createState() => _LoginSessionPageState();
}

class _LoginSessionPageState extends State<LoginSessionPage> {
  static const int _sessionPageSize = 200;

  late final UserService _userService;

  final TextEditingController _sessionKeywordController =
      TextEditingController();
  bool _loadingSessions = false;
  String _message = '';

  int _sessionTotal = 0;
  int _sessionPage = 1;
  List<OnlineSessionItem> _onlineSessions = const [];
  final Set<String> _selectedSessionIds = <String>{};

  int get _sessionTotalPages {
    if (_sessionTotal <= 0) {
      return 1;
    }
    return ((_sessionTotal - 1) ~/ _sessionPageSize) + 1;
  }

  List<OnlineSessionItem> get _selectableSessions => widget.canForceOffline
      ? _onlineSessions.where((item) => item.status == 'active').toList()
      : const [];

  bool get _hasSelectableSessions => _selectableSessions.isNotEmpty;

  bool get _allCurrentPageSelected {
    final selectableIds = _selectableSessions
        .map((item) => item.sessionTokenId)
        .toSet();
    return selectableIds.isNotEmpty &&
        selectableIds.every(_selectedSessionIds.contains);
  }

  bool get _someCurrentPageSelected {
    if (_allCurrentPageSelected) {
      return false;
    }
    return _selectableSessions.any(
      (item) => _selectedSessionIds.contains(item.sessionTokenId),
    );
  }

  @override
  void initState() {
    super.initState();
    _userService = widget.userService ?? UserService(widget.session);
    _loadAll();
  }

  @override
  void dispose() {
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
    if (!widget.canViewOnlineSessions) {
      setState(() {
        _message = '当前账号没有在线会话查看权限。';
      });
      return;
    }
    await _loadOnlineSessions();
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
        statusFilter: 'active',
      );
      if (!mounted) {
        return;
      }
      final activeItems = result.items
          .where((item) => item.status == 'active')
          .toList();
      final validIds = activeItems.map((item) => item.sessionTokenId).toSet();
      final resolvedTotalPages = result.total <= 0
          ? 1
          : (((result.total - 1) ~/ _sessionPageSize) + 1);
      final resolvedPage = targetPage > resolvedTotalPages
          ? resolvedTotalPages
          : targetPage;
      setState(() {
        _onlineSessions = activeItems;
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

  bool _canForceOfflineSession(OnlineSessionItem item) {
    return widget.canForceOffline && item.status == 'active';
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

  void _toggleSelectCurrentPage(bool? value) {
    if (!_hasSelectableSessions) {
      return;
    }
    final nextSelected = value ?? false;
    setState(() {
      for (final item in _selectableSessions) {
        if (nextSelected) {
          _selectedSessionIds.add(item.sessionTokenId);
        } else {
          _selectedSessionIds.remove(item.sessionTokenId);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!widget.canViewOnlineSessions) {
      return Center(
        child: Text(_message.isEmpty ? '当前账号没有在线会话查看权限。' : _message),
      );
    }

    return Semantics(
      container: true,
      label: '登录会话主区域',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CrudPageHeader(
              title: '在线会话',
              onRefresh: _loadingSessions ? null : () => _loadOnlineSessions(),
            ),
            const SizedBox(height: 12),
            Semantics(
              container: true,
              label: '登录会话筛选与操作区',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 320,
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
                  OutlinedButton(
                    onPressed: () => _loadOnlineSessions(page: 1),
                    child: const Text('查询'),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _allCurrentPageSelected
                            ? true
                            : (_someCurrentPageSelected ? null : false),
                        tristate: true,
                        onChanged: _hasSelectableSessions
                            ? _toggleSelectCurrentPage
                            : null,
                      ),
                      const Text('全选当前页'),
                    ],
                  ),
                  FilledButton(
                    onPressed:
                        widget.canForceOffline && _selectedSessionIds.isNotEmpty
                        ? _forceOfflineBatch
                        : null,
                    child: Text('批量强制下线（${_selectedSessionIds.length}）'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            Expanded(
              child: Semantics(
                container: true,
                label: '在线会话列表区域',
                child: CrudListTableSection(
                  loading: _loadingSessions,
                  isEmpty: _onlineSessions.isEmpty,
                  emptyText: '暂无在线会话',
                  enableUnifiedHeaderStyle: true,
                  child: DataTable(
                    columnSpacing: 16,
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
                      final checked = _selectedSessionIds.contains(
                        item.sessionTokenId,
                      );
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
                          const DataCell(
                            Text(
                              '在线',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DataCell(Text(_formatDateTime(item.loginTime))),
                          DataCell(Text(_formatDateTime(item.lastActiveAt))),
                          DataCell(Text(item.ipAddress ?? '-')),
                          DataCell(Text(item.terminalInfo ?? '-')),
                          DataCell(
                            OutlinedButton(
                              onPressed: canForceOffline
                                  ? () =>
                                        _forceOfflineSingle(item.sessionTokenId)
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
            const SizedBox(height: 12),
            SimplePaginationBar(
              page: _sessionPage,
              totalPages: _sessionTotalPages,
              total: _sessionTotal,
              loading: _loadingSessions,
              onPrevious: () => _loadOnlineSessions(page: _sessionPage - 1),
              onNext: () => _loadOnlineSessions(page: _sessionPage + 1),
            ),
          ],
        ),
      ),
    );
  }
}
