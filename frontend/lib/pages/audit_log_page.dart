import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/user_models.dart';
import '../services/api_exception.dart';
import '../services/user_service.dart';
import '../widgets/adaptive_table_container.dart';
import '../widgets/simple_pagination_bar.dart';
import '../widgets/unified_list_table_header_style.dart';

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

  double get _tableWidth => _columns.fold(0, (sum, col) => sum + col.width);

  int get _successCount =>
      _items.where((item) => item.result.toLowerCase() == 'success').length;

  int get _failureCount => _items.length - _successCount;

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

  Widget _buildFilterPanel(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '筛选条件',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 180,
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
                  width: 180,
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
                  width: 180,
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
                  ),
                ),
                if (_startTime != null)
                  TextButton.icon(
                    onPressed: _clearDateRange,
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('清除时间'),
                  ),
                FilledButton.icon(
                  onPressed: () => _loadAuditLogs(page: 1),
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('查询'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCard(ThemeData theme) {
    final table = UnifiedListTableHeaderStyle.wrap(
      theme: theme,
      child: DataTable(
        dataRowMinHeight: 58,
        dataRowMaxHeight: 76,
        columns: _columns
            .map(
              (col) => UnifiedListTableHeaderStyle.column(context, col.label),
            )
            .toList(),
        rows: _items.map((item) {
          final cells = [
            formatDataCell(_formatDateTime(item.occurredAt)),
            formatDataCell(item.operatorUsername ?? '-'),
            formatDataCell(
              '${item.targetType}: ${item.targetName ?? item.targetId ?? '-'}',
            ),
            formatDataCell(
              item.actionName.isNotEmpty ? item.actionName : item.actionCode,
            ),
            DataCell(
              Text(
                _resultLabel(item.result),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: item.result.toLowerCase() == 'success'
                      ? Colors.green
                      : theme.colorScheme.error,
                ),
              ),
            ),
            formatDataCell(_formatMapData(item.beforeData)),
            formatDataCell(_formatMapData(item.afterData)),
            formatDataCell(item.ipAddress ?? '-'),
            formatDataCell(item.terminalInfo ?? '-'),
          ];
          return DataRow(cells: cells);
        }).toList(),
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '审计日志列表',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _buildMetricChip(theme, '总记录', '$_total'),
                _buildMetricChip(
                  theme,
                  '本页成功',
                  '$_successCount',
                  color: Colors.green,
                ),
                _buildMetricChip(
                  theme,
                  '本页失败',
                  '$_failureCount',
                  color: theme.colorScheme.error,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(child: Text('暂无数据'))
                : AdaptiveTableContainer(
                    minTableWidth: _tableWidth,
                    padding: const EdgeInsets.all(12),
                    child: table,
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: SimplePaginationBar(
              page: _page,
              totalPages: _totalPages,
              total: _total,
              loading: _loading,
              onPrevious: () => _loadAuditLogs(page: _page - 1),
              onNext: () => _loadAuditLogs(page: _page + 1),
              onPageChanged: (page) => _loadAuditLogs(page: page),
            ),
          ),
        ],
      ),
    );
  }

  DataCell formatDataCell(String value) {
    return DataCell(
      Tooltip(
        message: value,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilterPanel(theme),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(
                _message,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(child: _buildTableCard(theme)),
        ],
      ),
    );
  }
}

class _ColDef {
  const _ColDef(this.label, this.width);
  final String label;
  final double width;
}
