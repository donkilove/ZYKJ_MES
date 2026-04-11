import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/production/services/production_service.dart';

class CraftKanbanPage extends StatefulWidget {
  const CraftKanbanPage({
    super.key,
    required this.session,
    required this.onLogout,
    this.craftService,
    this.productionService,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final CraftService? craftService;
  final ProductionService? productionService;

  @override
  State<CraftKanbanPage> createState() => _CraftKanbanPageState();
}

class _CraftKanbanPageState extends State<CraftKanbanPage> {
  static const int _kanbanExportLimit = 100;

  late final CraftService _craftService;
  late final ProductionService _productionService;

  bool _loadingProducts = false;
  bool _loadingMetrics = false;
  bool _exporting = false;
  String _message = '';

  List<ProductionProductOption> _products = const [];
  List<CraftStageItem> _stages = const [];
  List<CraftProcessItem> _processes = const [];
  int? _selectedProductId;
  int? _selectedStageId;
  int? _selectedProcessId;
  DateTime? _startDate;
  DateTime? _endDate;
  CraftKanbanProcessMetricsResult? _metrics;

  @override
  void initState() {
    super.initState();
    _craftService = widget.craftService ?? CraftService(widget.session);
    _productionService =
        widget.productionService ?? ProductionService(widget.session);
    _loadProducts();
  }

  bool _isUnauthorized(Object error) {
    return error is ApiException && error.statusCode == 401;
  }

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _message = '';
    });
    try {
      final products = await _productionService.listProductOptions();
      final stageResult = await _craftService.listStages(
        pageSize: 500,
        enabled: true,
      );
      final processResult = await _craftService.listProcesses(
        pageSize: 500,
        enabled: true,
      );
      if (!mounted) {
        return;
      }
      final sorted = [...products]..sort((a, b) => a.name.compareTo(b.name));
      int? selected = _selectedProductId;
      if (sorted.isEmpty) {
        selected = null;
      } else if (selected == null ||
          !sorted.any((item) => item.id == selected)) {
        selected = sorted.first.id;
      }
      setState(() {
        _products = sorted;
        _stages = [...stageResult.items]
          ..sort((a, b) {
            final c = a.sortOrder.compareTo(b.sortOrder);
            return c != 0 ? c : a.id.compareTo(b.id);
          });
        _processes = [...processResult.items]
          ..sort((a, b) => a.id.compareTo(b.id));
        _selectedProductId = selected;
      });
      if (selected != null) {
        await _loadMetrics();
      } else {
        setState(() {
          _metrics = null;
        });
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
        _message = '加载产品失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingProducts = false;
        });
      }
    }
  }

  Future<void> _loadMetrics() async {
    final productId = _selectedProductId;
    if (productId == null) {
      setState(() {
        _metrics = null;
      });
      return;
    }

    setState(() {
      _loadingMetrics = true;
      _message = '';
    });
    try {
      final metrics = await _craftService.getCraftKanbanProcessMetrics(
        productId: productId,
        limit: 5,
        stageId: _selectedStageId,
        processId: _selectedProcessId,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _metrics = metrics;
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
        _message = '加载看板失败：${_errorMessage(error)}';
        _metrics = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingMetrics = false;
        });
      }
    }
  }

  Future<void> _exportMetricsCsv() async {
    final productId = _selectedProductId;
    if (productId == null) {
      return;
    }
    setState(() {
      _exporting = true;
    });
    try {
      final contentBase64 = await _craftService.exportCraftKanbanProcessMetrics(
        productId: productId,
        limit: _kanbanExportLimit,
        stageId: _selectedStageId,
        processId: _selectedProcessId,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) return;
      final text = contentBase64.isEmpty
          ? ''
          : utf8.decode(base64Decode(contentBase64));
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('看板导出预览'),
          content: SizedBox(
            width: 920,
            height: 560,
            child: text.isEmpty
                ? const Center(child: Text('暂无可导出数据'))
                : SingleChildScrollView(child: SelectableText(text)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
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
      setState(() {
        _message = '导出失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  String _sampleLabel(CraftKanbanSampleItem sample) {
    final time = sample.endAt.toLocal();
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final order = sample.orderCode.trim();
    if (order.isEmpty) {
      return '$month-$day';
    }
    return '$order\n$month-$day';
  }

  List<CraftProcessItem> get _filteredProcesses {
    if (_selectedStageId == null) {
      return _processes;
    }
    return _processes.where((p) => p.stageId == _selectedStageId).toList();
  }

  Widget _buildFilterGroup({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricHeader() {
    final bool busy = _loadingProducts || _loadingMetrics || _exporting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterGroup(
          context: context,
          title: '主筛选',
          children: [
            SizedBox(
              width: 320,
              child: DropdownButtonFormField<int>(
                initialValue: _selectedProductId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '选择产品',
                  border: OutlineInputBorder(),
                ),
                items: _products
                    .map(
                      (item) => DropdownMenuItem<int>(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    )
                    .toList(),
                onChanged: busy
                    ? null
                    : (value) async {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedProductId = value;
                        });
                        await _loadMetrics();
                      },
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<int?>(
                initialValue: _selectedStageId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '工段筛选',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('全部工段'),
                  ),
                  ..._stages.map(
                    (s) => DropdownMenuItem<int?>(
                      value: s.id,
                      child: Text(s.name),
                    ),
                  ),
                ],
                onChanged: busy
                    ? null
                    : (value) async {
                        setState(() {
                          _selectedStageId = value;
                          _selectedProcessId = null;
                        });
                        await _loadMetrics();
                      },
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<int?>(
                initialValue: _selectedProcessId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '工序筛选',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('全部工序'),
                  ),
                  ..._filteredProcesses.map(
                    (p) => DropdownMenuItem<int?>(
                      value: p.id,
                      child: Text(p.name),
                    ),
                  ),
                ],
                onChanged: busy
                    ? null
                    : (value) async {
                        setState(() {
                          _selectedProcessId = value;
                        });
                        await _loadMetrics();
                      },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : _loadMetrics,
                    icon: const Icon(Icons.refresh),
                    label: const Text('刷新'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : _exportMetricsCsv,
                    icon: const Icon(Icons.download),
                    label: const Text('导出数据'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildFilterGroup(
          context: context,
          title: '日期范围',
          children: [
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          _startDate = picked;
                        });
                        await _loadMetrics();
                      }
                    },
              icon: const Icon(Icons.date_range),
              label: Text(
                _startDate == null
                    ? '开始日期'
                    : '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}',
              ),
            ),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          _endDate = picked;
                        });
                        await _loadMetrics();
                      }
                    },
              icon: const Icon(Icons.date_range),
              label: Text(
                _endDate == null
                    ? '结束日期'
                    : '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}',
              ),
            ),
            if (_startDate != null || _endDate != null)
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        setState(() {
                          _startDate = null;
                          _endDate = null;
                        });
                        await _loadMetrics();
                      },
                child: const Text('清除日期'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildWorkMinutesChart(List<CraftKanbanSampleItem> samples) {
    final averageMinutes = samples.isEmpty
        ? 0.0
        : samples
                  .map((item) => item.workMinutes)
                  .fold<int>(0, (sum, value) => sum + value) /
              samples.length;
    final anomalyThreshold = averageMinutes <= 0 ? 0 : averageMinutes * 1.3;
    final maxY = samples.fold<double>(
      1,
      (maxValue, item) =>
          item.workMinutes > maxValue ? item.workMinutes.toDouble() : maxValue,
    );
    return BarChart(
      BarChartData(
        maxY: maxY * 1.2,
        minY: 0,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (value, _) {
                final index = value.toInt();
                if (index < 0 || index >= samples.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _sampleLabel(samples[index]),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(samples.length, (index) {
          final sample = samples[index];
          final isAnomaly =
              anomalyThreshold > 0 &&
              sample.workMinutes.toDouble() > anomalyThreshold;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: sample.workMinutes.toDouble(),
                width: 16,
                borderRadius: BorderRadius.circular(3),
                color: isAnomaly ? Colors.redAccent : Colors.blueAccent,
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCapacityChart(List<CraftKanbanSampleItem> samples) {
    final maxY = samples.fold<double>(
      1,
      (maxValue, item) =>
          item.capacityPerHour > maxValue ? item.capacityPerHour : maxValue,
    );
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.2,
        lineTouchData: LineTouchData(enabled: true),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, _) => Text(
                value.toStringAsFixed(0),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (value, _) {
                final index = value.toInt();
                if (index < 0 || index >= samples.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _sampleLabel(samples[index]),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: Colors.orangeAccent,
            barWidth: 3,
            spots: List.generate(
              samples.length,
              (index) =>
                  FlSpot(index.toDouble(), samples[index].capacityPerHour),
            ),
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessCard(CraftKanbanProcessItem processItem) {
    final samples = processItem.samples;
    if (samples.isEmpty) {
      return Card(
        child: ListTile(
          title: Text('${processItem.processCode} ${processItem.processName}'),
          subtitle: const Text('暂无可统计数据'),
        ),
      );
    }

    final stageText = [
      if ((processItem.stageCode ?? '').trim().isNotEmpty)
        processItem.stageCode!.trim(),
      if ((processItem.stageName ?? '').trim().isNotEmpty)
        processItem.stageName!.trim(),
    ].join(' ');
    final first = samples.first;
    final last = samples.last;
    final rangeLabel =
        '${first.startAt.toLocal()} ~ ${last.endAt.toLocal()}（样本 ${samples.length}）';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stageText.isEmpty
                  ? '${processItem.processCode} ${processItem.processName}'
                  : '$stageText  /  ${processItem.processCode} ${processItem.processName}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(rangeLabel, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            SizedBox(height: 220, child: _buildWorkMinutesChart(samples)),
            const SizedBox(height: 10),
            SizedBox(height: 220, child: _buildCapacityChart(samples)),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendComparison(List<CraftKanbanProcessItem> items) {
    final rows = items.where((item) => item.samples.isNotEmpty).map((item) {
      final totalMinutes = item.samples.fold<int>(
        0,
        (sum, sample) => sum + sample.workMinutes,
      );
      final totalCapacity = item.samples.fold<double>(
        0,
        (sum, sample) => sum + sample.capacityPerHour,
      );
      final avgMinutes = totalMinutes / item.samples.length;
      final avgCapacity = totalCapacity / item.samples.length;
      return (process: item, avgMinutes: avgMinutes, avgCapacity: avgCapacity);
    }).toList()..sort((a, b) => b.avgMinutes.compareTo(a.avgMinutes));

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '工序趋势对比（平均工时/产能）',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('工序')),
                  DataColumn(label: Text('样本数')),
                  DataColumn(label: Text('平均工时(分钟)')),
                  DataColumn(label: Text('平均产能(件/小时)')),
                ],
                rows: rows
                    .map(
                      (row) => DataRow(
                        cells: [
                          DataCell(
                            Text(
                              '${row.process.processCode} ${row.process.processName}',
                            ),
                          ),
                          DataCell(Text('${row.process.samples.length}')),
                          DataCell(Text(row.avgMinutes.toStringAsFixed(1))),
                          DataCell(Text(row.avgCapacity.toStringAsFixed(1))),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '工艺看板',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (_products.isEmpty && !_loadingProducts)
            const Text('暂无产品数据')
          else
            _buildMetricHeader(),
          const SizedBox(height: 12),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '统计口径：仅统计已完成工序记录；工时=首件/生产记录最早时间到最后一次生产记录时间（分钟）；产能=产出数量/工时。红色柱体表示工时超过该工序样本均值的 130%。',
            ),
          ),
          Expanded(
            child: (_loadingProducts || _loadingMetrics)
                ? const Center(child: CircularProgressIndicator())
                : (_metrics == null || _metrics!.items.isEmpty)
                ? const Center(child: Text('暂无可统计数据'))
                : ListView(
                    children: [
                      _buildTrendComparison(_metrics!.items),
                      ..._metrics!.items.map(_buildProcessCard),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
