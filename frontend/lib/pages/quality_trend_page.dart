import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
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
    this.canExport = false,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canExport;

  @override
  State<QualityTrendPage> createState() => _QualityTrendPageState();
}

class _QualityTrendPageState extends State<QualityTrendPage> {
  late final QualityService _service;
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _processController = TextEditingController();
  final TextEditingController _operatorController = TextEditingController();

  bool _loading = false;
  bool _exporting = false;
  String _message = '';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 29));
  DateTime _endDate = DateTime.now();
  String? _resultFilter;
  List<QualityTrendItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _service = QualityService(widget.session);
    _loadTrend();
  }

  @override
  void dispose() {
    _productController.dispose();
    _processController.dispose();
    _operatorController.dispose();
    super.dispose();
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
    setState(() { _loading = true; _message = ''; });
    try {
      final items = await _service.getQualityTrend(
        startDate: _startDate,
        endDate: _endDate,
        productName: _productController.text.trim(),
        processCode: _processController.text.trim(),
        operatorUsername: _operatorController.text.trim(),
        result: _resultFilter,
      );
      if (!mounted) return;
      setState(() => _items = items);
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) { widget.onLogout(); return; }
      setState(() => _message = '加载质量趋势失败：${_errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportTrend() async {
    setState(() {
      _exporting = true;
      _message = '';
    });
    try {
      final csvBase64 = await _service.exportQualityTrend(
        startDate: _startDate,
        endDate: _endDate,
        productName: _productController.text.trim(),
        processCode: _processController.text.trim(),
        operatorUsername: _operatorController.text.trim(),
        result: _resultFilter,
      );
      if (!mounted) return;
      final csvText = utf8.decode(base64Decode(csvBase64));
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导出质量趋势'),
          content: SizedBox(
            width: 600,
            height: 400,
            child: SelectableText(csvText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() => _message = '导出质量趋势失败：${_errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
  Widget _buildChart() {
    if (_items.length < 2) return const SizedBox.shrink();
    final maxFirst = _items.fold<int>(0, (m, e) => math.max(m, e.firstArticleTotal));
    final maxY = (maxFirst + 2).toDouble();
    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          gridData: const FlGridData(show: true),
          borderData: FlBorderData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: math.max(1, (_items.length / 6).ceilToDouble()),
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= _items.length) return const SizedBox.shrink();
                  final d = _items[idx].date;
                  return Text(d.length >= 5 ? d.substring(5) : d, style: const TextStyle(fontSize: 10));
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            _line(_items.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.passedTotal.toDouble())).toList(), Colors.green, '通过'),
            _line(_items.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.failedTotal.toDouble())).toList(), Colors.red, '不通过'),
            _line(_items.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.scrapTotal.toDouble())).toList(), Colors.orange, '报废'),
          ],
        ),
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color, String label) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2,
      dotData: const FlDotData(show: false),
    );
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('质量趋势', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            if (widget.canExport)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: OutlinedButton.icon(
                  onPressed: (_loading || _exporting) ? null : _exportTrend,
                  icon: const Icon(Icons.download),
                  label: const Text('导出'),
                ),
              ),
            IconButton(tooltip: '刷新', onPressed: _loading ? null : _loadTrend, icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            OutlinedButton.icon(
              onPressed: _loading ? null : () => _pickDate(current: _startDate, helpText: '选择开始日期', onChanged: (v) => setState(() => _startDate = v)),
              icon: const Icon(Icons.event), label: Text('开始：${_formatDate(_startDate)}'),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : () => _pickDate(current: _endDate, helpText: '选择结束日期', onChanged: (v) => setState(() => _endDate = v)),
              icon: const Icon(Icons.event_available), label: Text('结束：${_formatDate(_endDate)}'),
            ),
            SizedBox(width: 130, child: TextField(controller: _productController, decoration: const InputDecoration(labelText: '产品名称', border: OutlineInputBorder(), isDense: true), onSubmitted: (_) => _loadTrend())),
            SizedBox(width: 120, child: TextField(controller: _processController, decoration: const InputDecoration(labelText: '工序编码', border: OutlineInputBorder(), isDense: true), onSubmitted: (_) => _loadTrend())),
            SizedBox(width: 120, child: TextField(controller: _operatorController, decoration: const InputDecoration(labelText: '操作员', border: OutlineInputBorder(), isDense: true), onSubmitted: (_) => _loadTrend())),
            DropdownButton<String?>(
              value: _resultFilter,
              hint: const Text('全部结果'),
              items: const [
                DropdownMenuItem(value: null, child: Text('全部结果')),
                DropdownMenuItem(value: 'passed', child: Text('合格')),
                DropdownMenuItem(value: 'failed', child: Text('不合格')),
              ],
              onChanged: _loading
                  ? null
                  : (v) => setState(() => _resultFilter = v),
            ),
            FilledButton.icon(onPressed: _loading ? null : _loadTrend, icon: const Icon(Icons.search), label: const Text('查询')),
          ]),
          const SizedBox(height: 12),
          if (_message.isNotEmpty)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error))),
          if (!_loading && _items.length >= 2) ...[
            _buildChart(),
            const SizedBox(height: 8),
            Wrap(spacing: 16, children: [
              _legendDot(Colors.green, '通过'),
              _legendDot(Colors.red, '不通过'),
              _legendDot(Colors.orange, '报废'),
            ]),
            const SizedBox(height: 12),
          ],
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
                              DataColumn(label: Text('通过率')),
                              DataColumn(label: Text('报废数')),
                              DataColumn(label: Text('维修数')),
                            ],
                            rows: _items.map((item) => DataRow(cells: [
                              DataCell(Text(item.date)),
                              DataCell(Text('${item.firstArticleTotal}')),
                              DataCell(Text('${item.passedTotal}')),
                              DataCell(Text('${item.failedTotal}')),
                              DataCell(Text('${item.passRatePercent.toStringAsFixed(1)}%')),
                              DataCell(Text('${item.scrapTotal}')),
                              DataCell(Text('${item.repairTotal}')),
                            ])).toList(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]);
  }
}
