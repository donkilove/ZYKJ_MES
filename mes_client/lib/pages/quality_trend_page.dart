import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/quality_models.dart';
import '../services/api_exception.dart';
import '../services/quality_service.dart';
import '../widgets/adaptive_table_container.dart';

class QualityTrendPage extends StatefulWidget {
  const QualityTrendPage({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final AppSession session;
  final VoidCallback onLogout;

  @override
  State<QualityTrendPage> createState() => _QualityTrendPageState();
}

class _QualityTrendPageState extends State<QualityTrendPage> {
  late final QualityService _service;

  bool _loading = false;
  String _message = '';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 29));
  DateTime _endDate = DateTime.now();
  List<QualityTrendItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _service = QualityService(widget.session);
    _loadTrend();
  }

  bool _isUnauthorized(Object error) =>
      error is ApiException && error.statusCode == 401;

  String _errorMessage(Object error) =>
      error is ApiException ? error.message : error.toString();

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  Future<void> _pickDate({
    required DateTime current,
    required ValueChanged<DateTime> onChanged,
    required String helpText,
  }) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      initialDate: current,
      helpText: helpText,
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null) return;
    onChanged(picked);
  }

  Future<void> _loadTrend() async {
    if (_startDate.isAfter(_endDate)) {
      setState(() => _message = '开始日期不能晚于结束日期');
      return;
    }
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final items = await _service.getQualityTrend(
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) return;
      setState(() => _items = items);
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() => _message = '加载质量趋势失败：${_errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '质量趋势',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '刷新',
                onPressed: _loading ? null : _loadTrend,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () => _pickDate(
                          current: _startDate,
                          helpText: '选择开始日期',
                          onChanged: (v) => setState(() => _startDate = v),
                        ),
                icon: const Icon(Icons.event),
                label: Text('开始：${_formatDate(_startDate)}'),
              ),
              OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () => _pickDate(
                          current: _endDate,
                          helpText: '选择结束日期',
                          onChanged: (v) => setState(() => _endDate = v),
                        ),
                icon: const Icon(Icons.event_available),
                label: Text('结束：${_formatDate(_endDate)}'),
              ),
              FilledButton.icon(
                onPressed: _loading ? null : _loadTrend,
                icon: const Icon(Icons.search),
                label: const Text('查询'),
              ),
              Text('默认最近30天', style: theme.textTheme.bodySmall),
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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('暂无趋势数据'))
                    : Card(
                        child: AdaptiveTableContainer(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('日期')),
                              DataColumn(label: Text('首件总数')),
                              DataColumn(label: Text('通过数')),
                              DataColumn(label: Text('不通过数')),
                              DataColumn(label: Text('报废数')),
                              DataColumn(label: Text('维修数')),
                            ],
                            rows: _items.map((item) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(item.date)),
                                  DataCell(Text('${item.firstArticleTotal}')),
                                  DataCell(Text('${item.passedTotal}')),
                                  DataCell(Text('${item.failedTotal}')),
                                  DataCell(Text('${item.scrapTotal}')),
                                  DataCell(Text('${item.repairTotal}')),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
