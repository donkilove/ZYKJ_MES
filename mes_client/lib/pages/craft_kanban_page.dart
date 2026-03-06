import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/craft_models.dart';
import '../models/production_models.dart';
import '../services/api_exception.dart';
import '../services/craft_service.dart';
import '../services/production_service.dart';

class CraftKanbanPage extends StatefulWidget {
  const CraftKanbanPage({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final AppSession session;
  final VoidCallback onLogout;

  @override
  State<CraftKanbanPage> createState() => _CraftKanbanPageState();
}

class _CraftKanbanPageState extends State<CraftKanbanPage> {
  late final CraftService _craftService;
  late final ProductionService _productionService;

  bool _loadingProducts = false;
  bool _loadingMetrics = false;
  String _message = '';

  List<ProductionProductOption> _products = const [];
  int? _selectedProductId;
  CraftKanbanProcessMetricsResult? _metrics;

  @override
  void initState() {
    super.initState();
    _craftService = CraftService(widget.session);
    _productionService = ProductionService(widget.session);
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

  Widget _buildMetricHeader() {
    return Row(
      children: [
        SizedBox(
          width: 320,
          child: DropdownButtonFormField<int>(
            initialValue: _selectedProductId,
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
            onChanged: (_loadingProducts || _loadingMetrics)
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
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _loadingProducts || _loadingMetrics ? null : _loadMetrics,
          icon: const Icon(Icons.refresh),
          label: const Text('刷新'),
        ),
      ],
    );
  }

  Widget _buildWorkMinutesChart(List<CraftKanbanSampleItem> samples) {
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
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: sample.workMinutes.toDouble(),
                width: 16,
                borderRadius: BorderRadius.circular(3),
                color: Colors.blueAccent,
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
            const SizedBox(height: 8),
            SizedBox(height: 220, child: _buildWorkMinutesChart(samples)),
            const SizedBox(height: 10),
            SizedBox(height: 220, child: _buildCapacityChart(samples)),
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
          Expanded(
            child: (_loadingProducts || _loadingMetrics)
                ? const Center(child: CircularProgressIndicator())
                : (_metrics == null || _metrics!.items.isEmpty)
                ? const Center(child: Text('暂无可统计数据'))
                : ListView.builder(
                    itemCount: _metrics!.items.length,
                    itemBuilder: (context, index) {
                      return _buildProcessCard(_metrics!.items[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
