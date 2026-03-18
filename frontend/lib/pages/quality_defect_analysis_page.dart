import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/quality_models.dart';
import '../services/api_exception.dart';
import '../services/quality_service.dart';
import '../widgets/adaptive_table_container.dart';

class QualityDefectAnalysisPage extends StatefulWidget {
  const QualityDefectAnalysisPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canExport,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canExport;

  @override
  State<QualityDefectAnalysisPage> createState() =>
      _QualityDefectAnalysisPageState();
}

class _QualityDefectAnalysisPageState
    extends State<QualityDefectAnalysisPage> {
  late final QualityService _service;

  bool _loading = false;
  String _message = '';
  DefectAnalysisResult? _result;

  DateTime? _startDate;
  DateTime? _endDate;
  final _processCodeController = TextEditingController();
  final _productNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _service = QualityService(widget.session);
    _load();
  }

  @override
  void dispose() {
    _processCodeController.dispose();
    _productNameController.dispose();
    super.dispose();
  }

  bool _isUnauthorized(Object e) => e is ApiException && e.statusCode == 401;
  String _errMsg(Object e) => e is ApiException ? e.message : e.toString();

  String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  Future<void> _load() async {
    setState(() { _loading = true; _message = ''; });
    try {
      final result = await _service.getDefectAnalysis(
        startDate: _startDate,
        endDate: _endDate,
        productName: _productNameController.text.trim().isEmpty
            ? null
            : _productNameController.text.trim(),
        processCode: _processCodeController.text.trim().isEmpty
            ? null
            : _processCodeController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      if (_isUnauthorized(e)) { widget.onLogout(); return; }
      setState(() => _message = _errMsg(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now().subtract(const Duration(days: 30)))
        : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(theme),
          const SizedBox(height: 12),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_message, style: TextStyle(color: theme.colorScheme.error)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _result == null
                ? const Center(child: Text('暂无数据'))
                : _buildContent(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () => _pickDate(isStart: true),
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(_startDate != null ? _formatDate(_startDate!) : '开始日期'),
        ),
        OutlinedButton.icon(
          onPressed: () => _pickDate(isStart: false),
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(_endDate != null ? _formatDate(_endDate!) : '结束日期'),
        ),
        if (_startDate != null || _endDate != null)
          TextButton(
            onPressed: () => setState(() { _startDate = null; _endDate = null; }),
            child: const Text('清除日期'),
          ),
        SizedBox(
          width: 160,
          child: TextField(
            controller: _processCodeController,
            decoration: const InputDecoration(
              labelText: '工序编码',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _load(),
          ),
        ),
        SizedBox(
          width: 160,
          child: TextField(
            controller: _productNameController,
            decoration: const InputDecoration(
              labelText: '产品名称',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _load(),
          ),
        ),
        IconButton(tooltip: '查询', onPressed: _loading ? null : _load, icon: const Icon(Icons.search)),
        IconButton(tooltip: '刷新', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
      ],
    );
  }

  Widget _buildTopDefectsChart(DefectAnalysisResult result, ThemeData theme) {
    final items = result.topDefects.take(8).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final maxQty = items.fold<int>(0, (m, e) => math.max(m, e.quantity));
    final maxY = (maxQty + 1).toDouble();
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= items.length) return const SizedBox.shrink();
                  final label = items[idx].phenomenon;
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: SizedBox(
                      width: 56,
                      child: Text(label.length > 6 ? '${label.substring(0, 6)}…' : label, style: const TextStyle(fontSize: 9), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: items.asMap().entries.map((entry) {
            return BarChartGroupData(x: entry.key, barRods: [
              BarChartRodData(toY: entry.value.quantity.toDouble(), width: 24, borderRadius: BorderRadius.circular(4), color: theme.colorScheme.error),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final result = _result!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('不良总数', style: theme.textTheme.bodySmall),
                      Text(
                        '${result.totalDefectQuantity}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Top 缺陷现象', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (result.topDefects.isNotEmpty) ...[
            _buildTopDefectsChart(result, theme),
            const SizedBox(height: 12),
          ],
          if (result.topDefects.isEmpty)
            const Text('暂无数据')
          else
            Card(
              child: AdaptiveTableContainer(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('缺陷现象')),
                    DataColumn(label: Text('数量')),
                    DataColumn(label: Text('占比 %')),
                  ],
                  rows: result.topDefects.map((item) {
                    return DataRow(cells: [
                      DataCell(Text(item.phenomenon)),
                      DataCell(Text('${item.quantity}')),
                      DataCell(Text('${item.ratio}')),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('按工序分布', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (result.byProcess.isEmpty)
            const Text('暂无数据')
          else
            Card(
              child: AdaptiveTableContainer(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('工序编码')),
                    DataColumn(label: Text('工序名称')),
                    DataColumn(label: Text('不良数量')),
                  ],
                  rows: result.byProcess.map((item) {
                    return DataRow(cells: [
                      DataCell(Text(item.processCode)),
                      DataCell(Text(item.processName ?? '-')),
                      DataCell(Text('${item.quantity}')),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('按产品分布', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (result.byProduct.isEmpty)
            const Text('暂无数据')
          else
            Card(
              child: AdaptiveTableContainer(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('产品')),
                    DataColumn(label: Text('不良数量')),
                  ],
                  rows: result.byProduct.map((item) {
                    return DataRow(cells: [
                      DataCell(Text(item.productName ?? '未知产品')),
                      DataCell(Text('${item.quantity}')),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
