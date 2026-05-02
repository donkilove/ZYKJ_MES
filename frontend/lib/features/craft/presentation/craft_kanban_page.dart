import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_empty_state.dart';
import 'package:mes_client/core/ui/patterns/mes_error_state.dart';
import 'package:mes_client/core/ui/patterns/mes_filter_bar.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';
import 'package:mes_client/core/ui/patterns/mes_metric_card.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/craft/presentation/widgets/craft_kanban_action_dialogs.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/production/services/production_service.dart';

class _CraftKanbanSummary {
  const _CraftKanbanSummary({
    required this.processCount,
    required this.sampleCount,
    required this.averageMinutes,
    required this.averageCapacity,
    required this.anomalyCount,
  });

  final int processCount;
  final int sampleCount;
  final double averageMinutes;
  final double averageCapacity;
  final int anomalyCount;
}

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
            final compare = a.sortOrder.compareTo(b.sortOrder);
            return compare != 0 ? compare : a.id.compareTo(b.id);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载产品失败：${_errorMessage(error)}')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载看板失败：${_errorMessage(error)}')),
      );
      setState(() {
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
      if (!mounted) {
        return;
      }
      final text = contentBase64.isEmpty
          ? ''
          : utf8.decode(base64Decode(contentBase64));
      await showCraftKanbanExportPreviewDialog(context: context, text: text);
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
      ).showSnackBar(SnackBar(content: Text('导出失败：${_errorMessage(error)}')));
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

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  List<CraftProcessItem> get _filteredProcesses {
    if (_selectedStageId == null) {
      return _processes;
    }
    return _processes.where((p) => p.stageId == _selectedStageId).toList();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: isStart ? '选择开始日期' : '选择结束日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
    await _loadMetrics();
  }

  Future<void> _clearDateRange() async {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    await _loadMetrics();
  }

  _CraftKanbanSummary _buildSummary(List<CraftKanbanProcessItem> items) {
    final samples = items.expand((item) => item.samples).toList();
    if (samples.isEmpty) {
      return const _CraftKanbanSummary(
        processCount: 0,
        sampleCount: 0,
        averageMinutes: 0,
        averageCapacity: 0,
        anomalyCount: 0,
      );
    }
    final totalMinutes = samples.fold<int>(
      0,
      (sum, item) => sum + item.workMinutes,
    );
    final totalCapacity = samples.fold<double>(
      0,
      (sum, item) => sum + item.capacityPerHour,
    );
    final averageMinutes = totalMinutes / samples.length;
    final anomalyThreshold = averageMinutes * 1.3;
    final anomalyCount = samples
        .where((item) => item.workMinutes.toDouble() > anomalyThreshold)
        .length;
    return _CraftKanbanSummary(
      processCount: items.where((item) => item.samples.isNotEmpty).length,
      sampleCount: samples.length,
      averageMinutes: averageMinutes,
      averageCapacity: totalCapacity / samples.length,
      anomalyCount: anomalyCount,
    );
  }

  Widget _buildHeader() {
    final busy = _loadingProducts || _loadingMetrics || _exporting;
    return MesRefreshPageHeader(
      title: '工艺看板',
      subtitle: '快速识别异常工时与工序产能波动。',
      onRefresh: busy ? null : _loadProducts,
      actionsBeforeRefresh: [
        if (busy)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  Widget _buildProductDropdown(bool busy) {
    return DropdownButtonFormField<int>(
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
    );
  }

  Widget _buildStageDropdown(bool busy) {
    return DropdownButtonFormField<int?>(
      initialValue: _selectedStageId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '工段筛选',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('全部工段')),
        ..._stages.map(
          (stage) => DropdownMenuItem<int?>(value: stage.id, child: Text(stage.name)),
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
    );
  }

  Widget _buildProcessDropdown(bool busy) {
    return DropdownButtonFormField<int?>(
      initialValue: _selectedProcessId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '工序筛选',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('全部工序')),
        ..._filteredProcesses.map(
          (process) => DropdownMenuItem<int?>(
            value: process.id,
            child: Text(process.name),
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
    );
  }

  Widget _buildDateButton({required bool isStart, required bool busy}) {
    final date = isStart ? _startDate : _endDate;
    return OutlinedButton.icon(
      onPressed: busy ? null : () => _pickDate(isStart: isStart),
      icon: const Icon(Icons.date_range),
      label: Text(date == null ? (isStart ? '开始日期' : '结束日期') : _formatDate(date)),
    );
  }

  Widget _buildFilterBar() {
    final busy = _loadingProducts || _loadingMetrics || _exporting;
    if (_products.isEmpty && !_loadingProducts) {
      return const SizedBox.shrink();
    }
    return MesFilterBar(
      title: '筛选控制台',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(width: 320, child: _buildProductDropdown(busy)),
              SizedBox(width: 220, child: _buildStageDropdown(busy)),
              SizedBox(width: 220, child: _buildProcessDropdown(busy)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildDateButton(isStart: true, busy: busy),
              _buildDateButton(isStart: false, busy: busy),
              if (_startDate != null || _endDate != null)
                TextButton(
                  onPressed: busy ? null : _clearDateRange,
                  child: const Text('清除日期'),
                ),
              FilledButton.icon(
                onPressed: busy ? null : _exportMetricsCsv,
                icon: const Icon(Icons.download),
                label: Text(_exporting ? '导出中...' : '导出数据'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return const MesSectionCard(
      title: '统计规则',
      child: Text(
        '仅统计已完成工序记录；工时=首件/生产记录最早时间到最后一次生产记录时间（分钟）；产能=产出数量/工时。红色柱体表示工时超过该工序样本均值的 130%。',
      ),
    );
  }

  Widget _buildSummaryCards() {
    final summary = _buildSummary(_metrics?.items ?? const []);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        MesMetricCard(
          label: '工序数',
          value: '${summary.processCount}',
          hint: '当前筛选下有样本的工序',
        ),
        MesMetricCard(
          label: '样本数',
          value: '${summary.sampleCount}',
          hint: '已完成工序样本总数',
        ),
        MesMetricCard(
          label: '平均工时',
          value: '${summary.averageMinutes.toStringAsFixed(1)} 分钟',
        ),
        MesMetricCard(
          label: '平均产能',
          value: '${summary.averageCapacity.toStringAsFixed(1)} 件/小时',
        ),
        MesMetricCard(
          label: '异常样本',
          value: '${summary.anomalyCount}',
          hint: summary.anomalyCount == 0 ? '当前无超阈值样本' : '高于均值 130%',
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

  Widget _buildChartPanel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return MesSectionCard(
      title: title,
      subtitle: subtitle,
      child: SizedBox(height: 220, child: child),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 980;
        final workPanel = KeyedSubtree(
          key: ValueKey('craft-kanban-work-chart-${processItem.processId}'),
          child: _buildChartPanel(
            title: '工时分布',
            subtitle: '红柱表示高于样本均值 130%',
            child: _buildWorkMinutesChart(samples),
          ),
        );
        final capacityPanel = KeyedSubtree(
          key: ValueKey('craft-kanban-capacity-chart-${processItem.processId}'),
          child: _buildChartPanel(
            title: '产能走势',
            subtitle: '按样本记录展示件/小时变化',
            child: _buildCapacityChart(samples),
          ),
        );

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
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(rangeLabel, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                if (stacked)
                  Column(
                    children: [
                      workPanel,
                      const SizedBox(height: 12),
                      capacityPanel,
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: workPanel),
                      const SizedBox(width: 12),
                      Expanded(child: capacityPanel),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
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

    return MesSectionCard(
      title: '工序趋势对比（平均工时/产能）',
      child: SizedBox(
        height: 220,
        child: CrudListTableSection(
          loading: false,
          isEmpty: rows.isEmpty,
          emptyText: '暂无趋势对比数据',
          enableUnifiedHeaderStyle: true,
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
      ),
    );
  }

  Widget _buildContent() {
    if (_loadingProducts || _loadingMetrics) {
      return const MesLoadingState(label: '工艺看板加载中...');
    }
    if (_products.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 240,
            child: const MesEmptyState(
              title: '暂无产品数据',
              description: '当前无法生成工艺看板，请先补齐产品基础资料。',
            ),
          ),
        ],
      );
    }
    if (_metrics == null) {
      return ListView(
        children: [
          SizedBox(
            height: 240,
            child: MesErrorState(
              message: '当前看板数据加载失败，请重试。',
              onRetry: _loadMetrics,
            ),
          ),
        ],
      );
    }
    if (_metrics!.items.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 240,
            child: const MesEmptyState(
              title: '当前筛选下暂无已完工样本',
              description: '可尝试调整产品、工段、工序或日期范围后重试',
            ),
          ),
        ],
      );
    }
    return ListView(
      children: [
        _buildSummaryCards(),
        const SizedBox(height: 12),
        _buildTrendComparison(_metrics!.items),
        ..._metrics!.items.map(_buildProcessCard),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MesCrudPageScaffold(
      header: _buildHeader(),
      filters: _buildFilterBar(),
      banner: _buildBanner(),
      content: _buildContent(),
    );
  }
}
