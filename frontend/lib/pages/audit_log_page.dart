import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/user_models.dart';
import '../services/api_exception.dart';
import '../services/user_service.dart';
import '../widgets/crud_list_table_section.dart';
import '../widgets/crud_page_header.dart';
import '../widgets/simple_pagination_bar.dart';
import '../widgets/unified_list_table_header_style.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({
    super.key,
    required this.session,
    required this.onLogout,
    this.userService,
    this.dateRangePicker,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final UserService? userService;
  final Future<DateTimeRange?> Function(
    BuildContext context,
    DateTime? start,
    DateTime? end,
  )?
  dateRangePicker;

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  static const int _pageSize = 50;

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
    final picker = widget.dateRangePicker;
    final range =
        await (picker?.call(context, _startTime, _endTime) ??
            showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              initialDateRange: _startTime != null && _endTime != null
                  ? DateTimeRange(start: _startTime!, end: _endTime!)
                  : null,
            ));
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
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CrudPageHeader(
            title: '审计日志',
            onRefresh: _loading ? null : () => _loadAuditLogs(page: _page),
          ),
          const SizedBox(height: 12),
          Wrap(
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
            child: CrudListTableSection(
              loading: _loading,
              isEmpty: _items.isEmpty,
              emptyText: '暂无数据',
              enableUnifiedHeaderStyle: true,
              child: DataTable(
                columnSpacing: 16,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 72,
                columns: [
                  for (final column in _columns)
                    UnifiedListTableHeaderStyle.column(context, column.label),
                ],
                rows: _items.map((item) {
                  return DataRow(cells: _buildCells(item));
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SimplePaginationBar(
            page: _page,
            totalPages: _totalPages,
            total: _total,
            loading: _loading,
            onPrevious: () => _loadAuditLogs(page: _page - 1),
            onNext: () => _loadAuditLogs(page: _page + 1),
          ),
        ],
      ),
    );
  }

  List<DataCell> _buildCells(AuditLogItem item) {
    final cellValues = [
      _formatDateTime(item.occurredAt),
      item.operatorUsername ?? '-',
      '${item.targetType}: ${item.targetName ?? item.targetId ?? '-'}',
      item.actionName.isNotEmpty ? item.actionName : item.actionCode,
      _resultLabel(item.result),
      _formatMapData(item.beforeData),
      _formatMapData(item.afterData),
    ];

    return List<DataCell>.generate(_columns.length, (index) {
      return DataCell(
        SizedBox(
          width: _columns[index].width,
          child: Tooltip(
            message: cellValues[index],
            child: Text(
              cellValues[index],
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ),
      );
    });
  }
}

class _ColDef {
  const _ColDef(this.label, this.width);
  final String label;
  final double width;
}
