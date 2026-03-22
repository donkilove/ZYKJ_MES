import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/user_models.dart';
import '../services/api_exception.dart';
import '../services/user_service.dart';
import '../widgets/simple_pagination_bar.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({
    super.key,
    required this.session,
    required this.onLogout,
    this.userService,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final UserService? userService;

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  static const int _pageSize = 200;

  late final UserService _userService;
  final TextEditingController _operatorController = TextEditingController();
  final TextEditingController _actionController = TextEditingController();
  final TextEditingController _targetController = TextEditingController();

  DateTime? _startTime;
  DateTime? _endTime;

  bool _loading = false;
  String _message = '';
  int _total = 0;
  int _page = 1;
  List<AuditLogItem> _items = const [];

  int get _totalPages {
    if (_total <= 0) {
      return 1;
    }
    return ((_total - 1) ~/ _pageSize) + 1;
  }

  @override
  void initState() {
    super.initState();
    _userService = widget.userService ?? UserService(widget.session);
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

  Future<void> _loadAuditLogs({int? page}) async {
    final targetPage = page ?? _page;
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _userService.listAuditLogs(
        page: targetPage,
        pageSize: _pageSize,
        operatorUsername: _operatorController.text.trim(),
        actionCode: _actionController.text.trim(),
        targetType: _targetController.text.trim(),
        startTime: _startTime,
        endTime: _endTime,
      );
      if (!mounted) {
        return;
      }
      final resolvedTotalPages = result.total <= 0
          ? 1
          : (((result.total - 1) ~/ _pageSize) + 1);
      final resolvedPage = targetPage > resolvedTotalPages
          ? resolvedTotalPages
          : targetPage;
      setState(() {
        _items = result.items;
        _total = result.total;
        _page = resolvedPage;
      });
      if (resolvedPage != targetPage) {
        await _loadAuditLogs(page: resolvedPage);
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

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _startTime != null && _endTime != null
          ? DateTimeRange(start: _startTime!, end: _endTime!)
          : null,
    );
    if (range != null) {
      setState(() {
        _startTime = range.start;
        _endTime = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
        );
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      _startTime = null;
      _endTime = null;
    });
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '';
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
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

  String _formatMapData(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return '-';
    return data.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }

  static const _columns = [
    _ColDef('操作时间', 160),
    _ColDef('操作人', 100),
    _ColDef('操作对象', 140),
    _ColDef('操作类型', 140),
    _ColDef('结果', 60),
    _ColDef('变更前', 180),
    _ColDef('变更后', 180),
    _ColDef('IP地址', 120),
    _ColDef('终端信息', 160),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // 查询条件区
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
                  controller: _operatorController,
                  decoration: const InputDecoration(
                    labelText: '操作人账号',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadAuditLogs(page: 1),
                ),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _actionController,
                  decoration: const InputDecoration(
                    labelText: '操作编码',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadAuditLogs(page: 1),
                ),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _targetController,
                  decoration: const InputDecoration(
                    labelText: '目标类型',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadAuditLogs(page: 1),
                ),
              ),
              // 时间范围选择
              OutlinedButton.icon(
                onPressed: _pickDateRange,
                icon: const Icon(Icons.date_range, size: 16),
                label: Text(
                  _startTime != null && _endTime != null
                      ? '${_formatDate(_startTime)} ~ ${_formatDate(_endTime)}'
                      : '选择时间范围',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if (_startTime != null)
                IconButton(
                  onPressed: _clearDateRange,
                  icon: const Icon(Icons.clear, size: 16),
                  tooltip: '清除时间范围',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              FilledButton(
                onPressed: () => _loadAuditLogs(page: 1),
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
            child: Text('共 $_total 条'),
          ),
        ),
        // 表头
        Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Row(
            children: _columns
                .map(
                  (col) => SizedBox(
                    width: col.width,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: Text(
                        col.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const Divider(height: 1),
        // 列表区
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
              ? const Center(child: Text('暂无数据'))
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 8, endIndent: 8),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return _AuditLogRow(
                      item: item,
                      columns: _columns,
                      formatDateTime: _formatDateTime,
                      formatMapData: _formatMapData,
                      resultLabel: _resultLabel,
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: SimplePaginationBar(
            page: _page,
            totalPages: _totalPages,
            total: _total,
            loading: _loading,
            onPrevious: () => _loadAuditLogs(page: _page - 1),
            onNext: () => _loadAuditLogs(page: _page + 1),
          ),
        ),
      ],
    );
  }
}

class _ColDef {
  const _ColDef(this.label, this.width);
  final String label;
  final double width;
}

class _AuditLogRow extends StatelessWidget {
  const _AuditLogRow({
    required this.item,
    required this.columns,
    required this.formatDateTime,
    required this.formatMapData,
    required this.resultLabel,
  });

  final AuditLogItem item;
  final List<_ColDef> columns;
  final String Function(DateTime?) formatDateTime;
  final String Function(Map<String, dynamic>?) formatMapData;
  final String Function(String) resultLabel;

  @override
  Widget build(BuildContext context) {
    final cells = [
      formatDateTime(item.occurredAt),
      item.operatorUsername ?? '-',
      '${item.targetType}: ${item.targetName ?? item.targetId ?? '-'}',
      item.actionName.isNotEmpty ? item.actionName : item.actionCode,
      resultLabel(item.result),
      formatMapData(item.beforeData),
      formatMapData(item.afterData),
      item.ipAddress ?? '-',
      item.terminalInfo ?? '-',
    ];

    return Row(
      children: List.generate(columns.length, (i) {
        return SizedBox(
          width: columns[i].width,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Tooltip(
              message: cells[i],
              child: Text(
                cells[i],
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ),
        );
      }),
    );
  }
}
