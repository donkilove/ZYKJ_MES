import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/production/services/production_service.dart';

enum ProductionDataSection { processStats, todayRealtime, operatorStats }

class ProductionDataPage extends StatefulWidget {
  const ProductionDataPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.section,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final ProductionDataSection section;
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
  bool _loadingProcessStats = false;
  bool _loadingOperatorStats = false;

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
  List<ProductionProcessStatItem> _processStats = const [];
  List<ProductionOperatorStatItem> _operatorStats = const [];

  String _todayStatMode = _statModeMain;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProductionService(widget.session);
    _loadInitialData();
  }

  bool get _anyLoading =>
      _loadingOverview ||
      _loadingToday ||
      _loadingProcessStats ||
      _loadingOperatorStats;

  String get _pageTitle {
    switch (widget.section) {
      case ProductionDataSection.processStats:
        return '工序统计';
      case ProductionDataSection.todayRealtime:
        return '今日实时产量';
      case ProductionDataSection.operatorStats:
        return '人员统计';
    }
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

  String _statModeLabel(String statMode) {
    return statMode == _statModeSub ? '子订单' : '主订单';
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

  Future<void> _loadInitialData() async {
    await _reloadOverview();
    await _reloadCurrentSection(clearMessage: false);
  }

  Future<void> _reloadAll() async {
    await _reloadOverview();
    await _reloadCurrentSection(clearMessage: false);
  }

  Future<void> _reloadCurrentSection({bool clearMessage = true}) async {
    switch (widget.section) {
      case ProductionDataSection.processStats:
        await _reloadProcessStats(clearMessage: clearMessage);
        return;
      case ProductionDataSection.todayRealtime:
        await _reloadToday(clearMessage: clearMessage);
        return;
      case ProductionDataSection.operatorStats:
        await _reloadOperatorStats(clearMessage: clearMessage);
        return;
    }
  }

  Future<void> _reloadOverview() async {
    setState(() {
      _loadingOverview = true;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刷新总览失败：${_errorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingOverview = false;
        });
      }
    }
  }

  Future<void> _reloadToday({bool clearMessage = true}) async {
    setState(() {
      _loadingToday = true;
    });
    try {
      final result = await _service.getTodayRealtimeData(
        statMode: _todayStatMode,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载今日实时失败：${_errorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingToday = false;
        });
      }
    }
  }

  Future<void> _reloadProcessStats({bool clearMessage = true}) async {
    setState(() {
      _loadingProcessStats = true;
    });
    try {
      final result = await _service.getProcessStats();
      if (!mounted) {
        return;
      }
      setState(() {
        _processStats = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载工序统计失败：${_errorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingProcessStats = false;
        });
      }
    }
  }

  Future<void> _reloadOperatorStats({bool clearMessage = true}) async {
    setState(() {
      _loadingOperatorStats = true;
    });
    try {
      final result = await _service.getOperatorStats();
      if (!mounted) {
        return;
      }
      setState(() {
        _operatorStats = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载人员统计失败：${_errorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingOperatorStats = false;
        });
      }
    }
  }

  Widget _buildOverviewCards() {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 180,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('待生产', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text(
                    '${_overview.pendingOrders}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: 180,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('生产中', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text(
                    '${_overview.inProgressOrders}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: 180,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('生产完成', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text(
                    '${_overview.completedOrders}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: 180,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('完成总量', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text(
                    '${_overview.finishedQuantity}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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

  Widget _buildTodaySection() {
    final theme = Theme.of(context);
    final result = _todayResult;
    final rows = result?.tableRows ?? const [];
    return Column(
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
            if (result != null)
              Text(
                '产品数：${result.summary.totalProducts}  今日总量：${result.summary.totalQuantity}',
                style: theme.textTheme.bodyMedium,
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
              ? const MesLoadingState(label: '今日实时产量加载中...')
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
                      child: CrudListTableSection(
                        loading: false,
                        isEmpty: rows.isEmpty,
                        emptyText: '暂无可统计数据',
                        enableUnifiedHeaderStyle: true,
                        child: DataTable(
                          columns: [
                            UnifiedListTableHeaderStyle.column(context, '产品名称'),
                            UnifiedListTableHeaderStyle.column(context, '今日产量'),
                            UnifiedListTableHeaderStyle.column(
                              context,
                              '最后生产时间',
                            ),
                          ],
                          rows: rows.map((row) {
                            return DataRow(
                              cells: [
                                DataCell(Text(row.productName)),
                                DataCell(Text('${row.quantity}')),
                                DataCell(
                                  Text(
                                    row.latestTimeText.isEmpty
                                        ? _formatDateTime(row.latestTime)
                                        : row.latestTimeText,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildProcessStatsSection() {
    if (_loadingProcessStats) {
      return const MesLoadingState(label: '工序统计加载中...');
    }
    return CrudListTableSection(
      loading: false,
      isEmpty: _processStats.isEmpty,
      emptyText: '暂无工序统计数据。',
      enableUnifiedHeaderStyle: true,
      child: DataTable(
        columns: [
          UnifiedListTableHeaderStyle.column(context, '工序编码'),
          UnifiedListTableHeaderStyle.column(context, '工序名称'),
          UnifiedListTableHeaderStyle.column(context, '总订单数'),
          UnifiedListTableHeaderStyle.column(context, '待生产'),
          UnifiedListTableHeaderStyle.column(context, '生产中'),
          UnifiedListTableHeaderStyle.column(context, '部分完成'),
          UnifiedListTableHeaderStyle.column(context, '生产完成'),
          UnifiedListTableHeaderStyle.column(context, '可见总量'),
          UnifiedListTableHeaderStyle.column(context, '完成总量'),
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
    );
  }

  Widget _buildOperatorStatsSection() {
    if (_loadingOperatorStats) {
      return const MesLoadingState(label: '人员统计加载中...');
    }
    return CrudListTableSection(
      loading: false,
      isEmpty: _operatorStats.isEmpty,
      emptyText: '暂无人员统计数据。',
      enableUnifiedHeaderStyle: true,
      child: DataTable(
        columns: [
          UnifiedListTableHeaderStyle.column(context, '操作员'),
          UnifiedListTableHeaderStyle.column(context, '工序编码'),
          UnifiedListTableHeaderStyle.column(context, '工序名称'),
          UnifiedListTableHeaderStyle.column(context, '报工次数'),
          UnifiedListTableHeaderStyle.column(context, '报工数量'),
          UnifiedListTableHeaderStyle.column(context, '最近报工时间'),
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
    );
  }

  Widget _buildSectionBody() {
    switch (widget.section) {
      case ProductionDataSection.processStats:
        return _buildProcessStatsSection();
      case ProductionDataSection.todayRealtime:
        return _buildTodaySection();
      case ProductionDataSection.operatorStats:
        return _buildOperatorStatsSection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MesCrudPageScaffold(
      header: MesRefreshPageHeader(
        title: _pageTitle,
        onRefresh: _anyLoading ? null : _reloadAll,
      ),
      banner: _buildOverviewCards(),
      content: _buildSectionBody(),
    );
  }
}
