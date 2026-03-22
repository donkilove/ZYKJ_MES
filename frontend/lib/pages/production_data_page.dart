import 'dart:convert';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/production_models.dart';
import '../services/api_exception.dart';
import '../services/production_service.dart';
import '../widgets/adaptive_table_container.dart';

class _StageFilterOption {
  const _StageFilterOption({
    required this.id,
    required this.code,
    required this.name,
  });

  final int id;
  final String code;
  final String name;
}

class ProductionDataPage extends StatefulWidget {
  const ProductionDataPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canExport,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canExport;
  final ProductionService? service;

  @override
  State<ProductionDataPage> createState() => _ProductionDataPageState();
}

class _ProductionDataPageState extends State<ProductionDataPage> {
  static const String _statModeMain = 'main_order';
  static const String _statModeSub = 'sub_order';

  late final ProductionService _service;

  bool _loadingOverview = false;
  bool _loadingToday = false;
  bool _loadingUnfinished = false;
  bool _loadingManual = false;
  bool _exportingManual = false;

  String _pageMessage = '';
  String _manualMessage = '';

  ProductionStatsOverview _overview = ProductionStatsOverview(
    totalOrders: 0,
    pendingOrders: 0,
    inProgressOrders: 0,
    completedOrders: 0,
    totalQuantity: 0,
    finishedQuantity: 0,
  );
  ProductionTodayRealtimeResult? _todayResult;
  DateTime? _todayLastRefreshedAt;
  ProductionUnfinishedProgressResult? _unfinishedResult;
  ProductionManualQueryResult? _manualResult;
  List<ProductionProcessStatItem> _processStats = const [];
  List<ProductionOperatorStatItem> _operatorStats = const [];

  String _todayStatMode = _statModeMain;

  String _manualStatMode = _statModeMain;
  DateTime _manualStartDate = DateTime.now().subtract(const Duration(days: 6));
  DateTime _manualEndDate = DateTime.now();
  String _manualOrderStatus = 'all';
  int? _manualProductId;
  int? _manualStageId;
  int? _manualProcessId;
  int? _manualOperatorUserId;

  List<ProductionProductOption> _productOptions = const [];
  List<ProductionProcessOption> _processOptions = const [];
  List<AssistUserOptionItem> _operatorOptions = const [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProductionService(widget.session);
    _loadInitialData();
  }

  bool get _anyLoading =>
      _loadingOverview ||
      _loadingToday ||
      _loadingUnfinished ||
      _loadingManual ||
      _exportingManual;

  bool _isUnauthorized(Object error) {
    return error is ApiException && error.statusCode == 401;
  }

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  String _statModeLabel(String statMode) {
    return statMode == _statModeSub ? '子订单' : '主订单';
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final sec = local.second.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min:$sec';
  }

  List<_StageFilterOption> get _stageOptions {
    final stageMap = <int, _StageFilterOption>{};
    for (final process in _processOptions) {
      final stageId = process.stageId;
      if (stageId == null || stageId <= 0) {
        continue;
      }
      if (stageMap.containsKey(stageId)) {
        continue;
      }
      stageMap[stageId] = _StageFilterOption(
        id: stageId,
        code: process.stageCode ?? '',
        name: process.stageName ?? '',
      );
    }
    final rows = stageMap.values.toList();
    rows.sort((left, right) {
      final byCode = left.code.compareTo(right.code);
      if (byCode != 0) {
        return byCode;
      }
      return left.id.compareTo(right.id);
    });
    return rows;
  }

  List<ProductionProcessOption> get _filteredProcessOptions {
    if (_manualStageId == null) {
      return _processOptions;
    }
    return _processOptions
        .where((item) => item.stageId == _manualStageId)
        .toList();
  }

  List<int>? _singleIdList(int? value) {
    if (value == null || value <= 0) {
      return null;
    }
    return <int>[value];
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _pageMessage = '';
      _manualMessage = '';
      _loadingOverview = true;
      _loadingToday = true;
      _loadingUnfinished = true;
      _loadingManual = true;
    });
    try {
      final results = await Future.wait<dynamic>([
        _service.getOverviewStats(),
        _service.getTodayRealtimeData(statMode: _todayStatMode),
        _service.getUnfinishedProgressData(),
        _service.getManualProductionData(
          statMode: _manualStatMode,
          startDate: _manualStartDate,
          endDate: _manualEndDate,
          orderStatus: _manualOrderStatus,
        ),
        _service.listProductOptions(),
        _service.listProcessOptions(),
        _service.listAssistUserOptions(
          page: 1,
          pageSize: 200,
          roleCode: 'operator',
        ),
        _service.getProcessStats(),
        _service.getOperatorStats(),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _overview = results[0] as ProductionStatsOverview;
        _todayResult = results[1] as ProductionTodayRealtimeResult;
        _todayLastRefreshedAt = DateTime.now();
        _unfinishedResult = results[2] as ProductionUnfinishedProgressResult;
        _manualResult = results[3] as ProductionManualQueryResult;
        _productOptions = results[4] as List<ProductionProductOption>;
        _processOptions = results[5] as List<ProductionProcessOption>;
        final operatorResult = results[6] as AssistUserOptionListResult;
        _operatorOptions = operatorResult.items;
        _processStats = results[7] as List<ProductionProcessStatItem>;
        _operatorStats = results[8] as List<ProductionOperatorStatItem>;
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
        _pageMessage = '加载生产数据失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingOverview = false;
          _loadingToday = false;
          _loadingUnfinished = false;
          _loadingManual = false;
        });
      }
    }
  }

  Future<void> _pickManualDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      initialDate: isStart ? _manualStartDate : _manualEndDate,
      helpText: isStart ? '选择开始日期' : '选择结束日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      if (isStart) {
        _manualStartDate = picked;
      } else {
        _manualEndDate = picked;
      }
    });
  }

  Future<void> _reloadOverview() async {
    setState(() {
      _loadingOverview = true;
      _pageMessage = '';
    });
    try {
      final result = await _service.getOverviewStats();
      if (!mounted) {
        return;
      }
      setState(() {
        _overview = result;
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
        _pageMessage = '刷新总览失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingOverview = false;
        });
      }
    }
  }

  Future<void> _reloadToday() async {
    setState(() {
      _loadingToday = true;
      _pageMessage = '';
    });
    try {
      final result = await _service.getTodayRealtimeData(
        statMode: _todayStatMode,
        productIds: _singleIdList(_manualProductId),
        stageIds: _singleIdList(_manualStageId),
        processIds: _singleIdList(_manualProcessId),
        operatorUserIds: _singleIdList(_manualOperatorUserId),
        orderStatus: _manualOrderStatus,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _todayResult = result;
        _todayLastRefreshedAt = DateTime.now();
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
        _pageMessage = '加载今日实时失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingToday = false;
        });
      }
    }
  }

  Future<void> _reloadUnfinished() async {
    setState(() {
      _loadingUnfinished = true;
      _pageMessage = '';
    });
    try {
      final result = await _service.getUnfinishedProgressData(
        productIds: _singleIdList(_manualProductId),
        stageIds: _singleIdList(_manualStageId),
        processIds: _singleIdList(_manualProcessId),
        operatorUserIds: _singleIdList(_manualOperatorUserId),
        orderStatus: _manualOrderStatus,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _unfinishedResult = result;
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
        _pageMessage = '加载未完工进度失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingUnfinished = false;
        });
      }
    }
  }

  Future<void> _reloadManual() async {
    if (_manualStartDate.isAfter(_manualEndDate)) {
      setState(() {
        _manualMessage = '开始日期不能晚于结束日期';
      });
      return;
    }

    setState(() {
      _loadingManual = true;
      _manualMessage = '';
    });
    try {
      final result = await _service.getManualProductionData(
        statMode: _manualStatMode,
        startDate: _manualStartDate,
        endDate: _manualEndDate,
        productIds: _singleIdList(_manualProductId),
        stageIds: _singleIdList(_manualStageId),
        processIds: _singleIdList(_manualProcessId),
        operatorUserIds: _singleIdList(_manualOperatorUserId),
        orderStatus: _manualOrderStatus,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _manualResult = result;
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
        _manualMessage = '加载手动筛选失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingManual = false;
        });
      }
    }
  }

  Future<void> _exportManual() async {
    if (!widget.canExport) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前账号无导出权限')));
      return;
    }
    if (_manualStartDate.isAfter(_manualEndDate)) {
      setState(() {
        _manualMessage = '开始日期不能晚于结束日期';
      });
      return;
    }
    setState(() {
      _exportingManual = true;
      _manualMessage = '';
    });
    try {
      final result = await _service.exportManualProductionData(
        statMode: _manualStatMode,
        startDate: _manualStartDate,
        endDate: _manualEndDate,
        productIds: _singleIdList(_manualProductId),
        stageIds: _singleIdList(_manualStageId),
        processIds: _singleIdList(_manualProcessId),
        operatorUserIds: _singleIdList(_manualOperatorUserId),
        orderStatus: _manualOrderStatus,
      );
      final bytes = base64Decode(result.contentBase64);
      final location = await getSaveLocation(
        suggestedName: result.fileName,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (location == null || !mounted) {
        return;
      }
      final file = XFile.fromData(
        bytes,
        mimeType: result.mimeType,
        name: result.fileName,
      );
      await file.saveTo(location.path);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出成功：${location.path}')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _manualMessage = '导出失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _exportingManual = false;
        });
      }
    }
  }

  Widget _buildOverviewCard({
    required String title,
    required int value,
    required ThemeData theme,
  }) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(
                '$value',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayChart() {
    final rows = _todayResult?.chartData ?? const [];
    if (rows.isEmpty) {
      return const Center(child: Text('暂无可统计数据'));
    }

    final maxValue = rows
        .map((item) => item.value.toDouble())
        .fold<double>(0, (left, right) => math.max(left, right));
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.2;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: math.max(520, rows.length * 88).toDouble(),
        child: BarChart(
          BarChartData(
            maxY: maxY,
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: true),
            barGroups: rows.asMap().entries.map((entry) {
              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: entry.value.value.toDouble(),
                    width: 28,
                    borderRadius: BorderRadius.circular(6),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              );
            }).toList(),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 56,
                  getTitlesWidget: (value, _) {
                    final index = value.toInt();
                    if (index < 0 || index >= rows.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Transform.rotate(
                        angle: -0.6,
                        child: Text(
                          rows[index].label,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, _) {
                    return Text(
                      value.toInt().toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManualModelChart() {
    final rows = _manualResult?.chartData.modelOutput ?? const [];
    if (rows.isEmpty) {
      return const Center(child: Text('暂无图表数据'));
    }
    final maxValue = rows
        .map((item) => item.quantity.toDouble())
        .fold<double>(0, (left, right) => math.max(left, right));
    final maxY = maxValue <= 0 ? 1.0 : maxValue * 1.2;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: math.max(520, rows.length * 88).toDouble(),
        child: BarChart(
          BarChartData(
            maxY: maxY,
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: true),
            barGroups: rows.asMap().entries.map((entry) {
              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: entry.value.quantity.toDouble(),
                    width: 28,
                    color: Theme.of(context).colorScheme.tertiary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              );
            }).toList(),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 56,
                  getTitlesWidget: (value, _) {
                    final index = value.toInt();
                    if (index < 0 || index >= rows.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Transform.rotate(
                        angle: -0.6,
                        child: Text(
                          rows[index].productName,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, _) {
                    return Text(
                      value.toInt().toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManualTrendChart() {
    final rows = _manualResult?.chartData.trendOutput ?? const [];
    if (rows.isEmpty) {
      return const Center(child: Text('暂无图表数据'));
    }
    final spots = rows.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.quantity.toDouble());
    }).toList();
    final maxY = rows
        .map((item) => item.quantity.toDouble())
        .fold<double>(0, (left, right) => math.max(left, right));
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY * 1.2,
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: rows.length > 7 ? 2 : 1,
              getTitlesWidget: (value, _) {
                final index = value.toInt();
                if (index < 0 || index >= rows.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    rows[index].bucket,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, _) {
                return Text(
                  value.toInt().toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManualPieChart() {
    final rows = _manualResult?.chartData.pieOutput ?? const [];
    if (rows.isEmpty) {
      return const Center(child: Text('暂无图表数据'));
    }
    final total = rows.fold<int>(0, (sum, row) => sum + row.quantity);
    final palette = <Color>[
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.tertiary,
      Theme.of(context).colorScheme.error,
    ];
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 36,
        sections: rows.asMap().entries.map((entry) {
          final row = entry.value;
          final rate = total <= 0 ? 0.0 : (row.quantity / total * 100.0);
          return PieChartSectionData(
            value: row.quantity.toDouble(),
            title: '${row.name}\n${rate.toStringAsFixed(1)}%',
            radius: 78,
            titleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            color: palette[entry.key % palette.length],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTodayTab(ThemeData theme) {
    final rows = _todayResult?.tableRows ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<String>(
              value: _todayStatMode,
              items: const [
                DropdownMenuItem(value: _statModeMain, child: Text('主订单')),
                DropdownMenuItem(value: _statModeSub, child: Text('子订单')),
              ],
              onChanged: _loadingToday
                  ? null
                  : (value) {
                      if (value == null || value == _todayStatMode) {
                        return;
                      }
                      setState(() {
                        _todayStatMode = value;
                      });
                      _reloadToday();
                    },
            ),
            FilledButton.icon(
              onPressed: _loadingToday ? null : _reloadToday,
              icon: const Icon(Icons.search),
              label: const Text('刷新今日实时'),
            ),
            Text(
              '统计模式：${_statModeLabel(_todayStatMode)}',
              style: theme.textTheme.bodyMedium,
            ),
            if (_todayLastRefreshedAt != null)
              Text(
                '最后刷新：${_formatDateTime(_todayLastRefreshedAt)}',
                style: theme.textTheme.bodyMedium,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loadingToday
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: _buildTodayChart(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      flex: 4,
                      child: Card(
                        child: rows.isEmpty
                            ? const Center(child: Text('暂无可统计数据'))
                            : AdaptiveTableContainer(
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('产品名称')),
                                    DataColumn(label: Text('今日产量')),
                                    DataColumn(label: Text('最后生产时间')),
                                  ],
                                  rows: rows.map((row) {
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(row.productName)),
                                        DataCell(Text('${row.quantity}')),
                                        DataCell(
                                          Text(
                                            row.latestTimeText.isEmpty
                                                ? _formatDateTime(
                                                    row.latestTime,
                                                  )
                                                : row.latestTimeText,
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildUnfinishedTab() {
    final rows = _unfinishedResult?.tableRows ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _loadingUnfinished ? null : _reloadUnfinished,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新进度'),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _loadingUnfinished
              ? const Center(child: CircularProgressIndicator())
              : Card(
                  child: rows.isEmpty
                      ? const Center(child: Text('暂无未完工订单'))
                      : AdaptiveTableContainer(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('订单编号')),
                              DataColumn(label: Text('产品名称')),
                              DataColumn(label: Text('当前工序')),
                              DataColumn(label: Text('订单状态')),
                              DataColumn(label: Text('已产总量')),
                              DataColumn(label: Text('剩余数量')),
                              DataColumn(label: Text('进度')),
                            ],
                            rows: rows.map((row) {
                              final progress = row.progressPercent / 100.0;
                              return DataRow(
                                cells: [
                                  DataCell(Text(row.orderCode)),
                                  DataCell(Text(row.productName)),
                                  DataCell(
                                    Text(
                                      row.currentProcessName.trim().isEmpty
                                          ? '-'
                                          : row.currentProcessName,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      productionOrderStatusLabel(
                                        row.orderStatus,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text('${row.producedTotal}')),
                                  DataCell(Text('${row.remainingQuantity}')),
                                  DataCell(
                                    SizedBox(
                                      width: 200,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${row.progressPercent.toStringAsFixed(2)}%',
                                          ),
                                          const SizedBox(height: 4),
                                          LinearProgressIndicator(
                                            value: progress.clamp(0, 1),
                                            minHeight: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _buildManualFilterControls(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<String>(
              value: _manualStatMode,
              items: const [
                DropdownMenuItem(value: _statModeMain, child: Text('主订单')),
                DropdownMenuItem(value: _statModeSub, child: Text('子订单')),
              ],
              onChanged: _loadingManual
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _manualStatMode = value;
                      });
                    },
            ),
            OutlinedButton.icon(
              onPressed: _loadingManual
                  ? null
                  : () => _pickManualDate(isStart: true),
              icon: const Icon(Icons.event),
              label: Text('开始：${_formatDate(_manualStartDate)}'),
            ),
            OutlinedButton.icon(
              onPressed: _loadingManual
                  ? null
                  : () => _pickManualDate(isStart: false),
              icon: const Icon(Icons.event_available),
              label: Text('结束：${_formatDate(_manualEndDate)}'),
            ),
            DropdownButton<String>(
              value: _manualOrderStatus,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('全部状态')),
                DropdownMenuItem(value: 'pending', child: Text('待生产')),
                DropdownMenuItem(value: 'in_progress', child: Text('生产中')),
                DropdownMenuItem(value: 'completed', child: Text('生产完成')),
              ],
              onChanged: _loadingManual
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _manualOrderStatus = value;
                      });
                    },
            ),
            FilledButton.icon(
              onPressed: _loadingManual ? null : _reloadManual,
              icon: const Icon(Icons.search),
              label: const Text('筛选'),
            ),
            FilledButton.icon(
              onPressed:
                  (!widget.canExport || _loadingManual || _exportingManual)
                  ? null
                  : _exportManual,
              icon: _exportingManual
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: const Text('导出CSV'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<int?>(
              value: _manualProductId,
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('全部产品')),
                ..._productOptions.map(
                  (item) => DropdownMenuItem<int?>(
                    value: item.id,
                    child: Text(item.name),
                  ),
                ),
              ],
              onChanged: _loadingManual
                  ? null
                  : (value) {
                      setState(() {
                        _manualProductId = value;
                      });
                    },
            ),
            DropdownButton<int?>(
              value: _manualStageId,
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('全部工段')),
                ..._stageOptions.map(
                  (item) => DropdownMenuItem<int?>(
                    value: item.id,
                    child: Text('${item.code} ${item.name}'),
                  ),
                ),
              ],
              onChanged: _loadingManual
                  ? null
                  : (value) {
                      setState(() {
                        _manualStageId = value;
                        final processIds = _filteredProcessOptions
                            .map((row) => row.id)
                            .toSet();
                        if (_manualProcessId != null &&
                            !processIds.contains(_manualProcessId)) {
                          _manualProcessId = null;
                        }
                      });
                    },
            ),
            DropdownButton<int?>(
              value: _manualProcessId,
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('全部工序')),
                ..._filteredProcessOptions.map(
                  (item) => DropdownMenuItem<int?>(
                    value: item.id,
                    child: Text('${item.code} ${item.name}'),
                  ),
                ),
              ],
              onChanged: _loadingManual
                  ? null
                  : (value) {
                      setState(() {
                        _manualProcessId = value;
                      });
                    },
            ),
            DropdownButton<int?>(
              value: _manualOperatorUserId,
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('全部操作员')),
                ..._operatorOptions.map(
                  (item) => DropdownMenuItem<int?>(
                    value: item.id,
                    child: Text(item.displayName),
                  ),
                ),
              ],
              onChanged: _loadingManual
                  ? null
                  : (value) {
                      setState(() {
                        _manualOperatorUserId = value;
                      });
                    },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '当前统计模式：${_statModeLabel(_manualStatMode)}',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildManualTab(ThemeData theme) {
    final rows = _manualResult?.tableRows ?? const [];
    final summary = _manualResult?.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildManualFilterControls(theme),
        if (_manualMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _manualMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (summary != null)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Chip(label: Text('记录数：${summary.rows}')),
              Chip(label: Text('筛选产量：${summary.filteredTotal}')),
              Chip(label: Text('区间总量：${summary.timeRangeTotal}')),
              Chip(
                label: Text('占比：${summary.ratioPercent.toStringAsFixed(2)}%'),
              ),
            ],
          ),
        const SizedBox(height: 12),
        Expanded(
          child: _loadingManual
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Row(
                        children: [
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: _buildManualModelChart(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: _buildManualTrendChart(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: _buildManualPieChart(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      flex: 6,
                      child: Card(
                        child: rows.isEmpty
                            ? const Center(child: Text('暂无可统计数据'))
                            : AdaptiveTableContainer(
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('订单编号')),
                                    DataColumn(label: Text('产品名称')),
                                    DataColumn(label: Text('工段')),
                                    DataColumn(label: Text('工序')),
                                    DataColumn(label: Text('操作员')),
                                    DataColumn(label: Text('产量')),
                                    DataColumn(label: Text('生产时间')),
                                    DataColumn(label: Text('订单状态')),
                                  ],
                                  rows: rows.map((row) {
                                    final stageLabel = [
                                      row.stageCode ?? '',
                                      row.stageName ?? '',
                                    ].join(' ').trim();
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(row.orderCode)),
                                        DataCell(Text(row.productName)),
                                        DataCell(
                                          Text(
                                            stageLabel.isEmpty
                                                ? '-'
                                                : stageLabel,
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            '${row.processCode} ${row.processName}',
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            row.operatorUsername.trim().isEmpty
                                                ? '-'
                                                : row.operatorUsername,
                                          ),
                                        ),
                                        DataCell(Text('${row.quantity}')),
                                        DataCell(
                                          Text(
                                            row.productionTimeText.isEmpty
                                                ? _formatDateTime(
                                                    row.productionTime,
                                                  )
                                                : row.productionTimeText,
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            productionOrderStatusLabel(
                                              row.orderStatus,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildProcessStatsTab() {
    if (_processStats.isEmpty) {
      return const Center(child: Text('暂无工序统计数据。'));
    }
    return Card(
      child: AdaptiveTableContainer(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('工序编码')),
            DataColumn(label: Text('工序名称')),
            DataColumn(label: Text('总订单数')),
            DataColumn(label: Text('待生产')),
            DataColumn(label: Text('生产中')),
            DataColumn(label: Text('部分完成')),
            DataColumn(label: Text('生产完成')),
            DataColumn(label: Text('可见总量')),
            DataColumn(label: Text('完成总量')),
          ],
          rows: _processStats.map((item) {
            return DataRow(
              cells: [
                DataCell(Text(item.processCode)),
                DataCell(Text(item.processName)),
                DataCell(Text('${item.totalOrders}')),
                DataCell(Text('${item.pendingOrders}')),
                DataCell(Text('${item.inProgressOrders}')),
                DataCell(Text('${item.partialOrders}')),
                DataCell(Text('${item.completedOrders}')),
                DataCell(Text('${item.totalVisibleQuantity}')),
                DataCell(Text('${item.totalCompletedQuantity}')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOperatorStatsTab() {
    if (_operatorStats.isEmpty) {
      return const Center(child: Text('暂无人员统计数据。'));
    }
    return Card(
      child: AdaptiveTableContainer(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('操作员')),
            DataColumn(label: Text('工序编码')),
            DataColumn(label: Text('工序名称')),
            DataColumn(label: Text('报工次数')),
            DataColumn(label: Text('报工数量')),
            DataColumn(label: Text('最近报工时间')),
          ],
          rows: _operatorStats.map((item) {
            return DataRow(
              cells: [
                DataCell(Text(item.operatorUsername)),
                DataCell(Text(item.processCode)),
                DataCell(Text(item.processName)),
                DataCell(Text('${item.productionRecords}')),
                DataCell(Text('${item.productionQuantity}')),
                DataCell(Text(_formatDateTime(item.lastProductionAt))),
              ],
            );
          }).toList(),
        ),
      ),
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
          Row(
            children: [
              Text(
                '生产数据查询',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '刷新全部',
                onPressed: _anyLoading
                    ? null
                    : () async {
                        await _reloadOverview();
                        await _reloadToday();
                        await _reloadUnfinished();
                        await _reloadManual();
                      },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildOverviewCard(
                title: '订单总数',
                value: _overview.totalOrders,
                theme: theme,
              ),
              _buildOverviewCard(
                title: '待生产',
                value: _overview.pendingOrders,
                theme: theme,
              ),
              _buildOverviewCard(
                title: '生产中',
                value: _overview.inProgressOrders,
                theme: theme,
              ),
              _buildOverviewCard(
                title: '生产完成',
                value: _overview.completedOrders,
                theme: theme,
              ),
              _buildOverviewCard(
                title: '计划总量',
                value: _overview.totalQuantity,
                theme: theme,
              ),
              _buildOverviewCard(
                title: '完成总量',
                value: _overview.finishedQuantity,
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_pageMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _pageMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          Expanded(
            child: DefaultTabController(
              length: 5,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: '今日实时产量'),
                      Tab(text: '未完工进度'),
                      Tab(text: '手动筛选'),
                      Tab(text: '工序统计'),
                      Tab(text: '人员统计'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildTodayTab(theme),
                        _buildUnfinishedTab(),
                        _buildManualTab(theme),
                        _buildProcessStatsTab(),
                        _buildOperatorStatsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
