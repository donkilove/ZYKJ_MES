import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/services/export_file_service.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';
import 'package:mes_client/core/widgets/adaptive_table_container.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';
import 'package:mes_client/features/quality/presentation/widgets/quality_trend_page_header.dart';
import 'package:mes_client/features/quality/services/quality_service.dart';

class QualityTrendPage extends StatefulWidget {
  const QualityTrendPage({
    super.key,
    required this.session,
    required this.onLogout,
    this.canExport = false,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canExport;
  final QualityService? service;

  @override
  State<QualityTrendPage> createState() => _QualityTrendPageState();
}

class _QualityTrendPageState extends State<QualityTrendPage> {
  static const int _pageSize = 30;

  late final QualityService _service;
  final ExportFileService _exportFileService = const ExportFileService();
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _processController = TextEditingController();
  final TextEditingController _operatorController = TextEditingController();

  bool _loading = false;
  bool _exporting = false;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 29));
  DateTime _endDate = DateTime.now();
  String? _resultFilter;
  QualityStatsOverview? _overview;
  List<QualityTrendItem> _items = const [];
  List<QualityProductStatItem> _productStats = const [];
  List<QualityProcessStatItem> _processStats = const [];
  List<QualityOperatorStatItem> _operatorStats = const [];
  int _trendPage = 1;
  int _productPage = 1;
  int _processPage = 1;
  int _operatorPage = 1;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? QualityService(widget.session);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('开始日期不能晚于结束日期')),
      );
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      final productName = _productController.text.trim();
      final processCode = _processController.text.trim();
      final operatorUsername = _operatorController.text.trim();
      final requests = await Future.wait<Object>([
        _service.getQualityTrend(
          startDate: _startDate,
          endDate: _endDate,
          productName: productName,
          processCode: processCode,
          operatorUsername: operatorUsername,
          result: _resultFilter,
        ),
        _service.getQualityOverview(
          startDate: _startDate,
          endDate: _endDate,
          productName: productName,
          processCode: processCode,
          operatorUsername: operatorUsername,
          result: _resultFilter,
        ),
        _service.getQualityProductStats(
          startDate: _startDate,
          endDate: _endDate,
          productName: productName,
          processCode: processCode,
          operatorUsername: operatorUsername,
          result: _resultFilter,
        ),
        _service.getQualityProcessStats(
          startDate: _startDate,
          endDate: _endDate,
          productName: productName,
          processCode: processCode,
          operatorUsername: operatorUsername,
          result: _resultFilter,
        ),
        _service.getQualityOperatorStats(
          startDate: _startDate,
          endDate: _endDate,
          productName: productName,
          processCode: processCode,
          operatorUsername: operatorUsername,
          result: _resultFilter,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _items = requests[0] as List<QualityTrendItem>;
        _overview = requests[1] as QualityStatsOverview;
        _productStats = requests[2] as List<QualityProductStatItem>;
        _processStats = requests[3] as List<QualityProcessStatItem>;
        _operatorStats = requests[4] as List<QualityOperatorStatItem>;
        _trendPage = 1;
        _productPage = 1;
        _processPage = 1;
        _operatorPage = 1;
      });
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载质量趋势失败：${_errorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportTrend() async {
    setState(() {
      _exporting = true;
    });
    try {
      final exportFile = await _service.exportQualityTrend(
        startDate: _startDate,
        endDate: _endDate,
        productName: _productController.text.trim(),
        processCode: _processController.text.trim(),
        operatorUsername: _operatorController.text.trim(),
        result: _resultFilter,
      );
      if (!mounted) return;
      if (exportFile.contentBase64.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出质量趋势失败：服务端返回空数据')),
        );
        return;
      }
      final savedPath = await _exportFileService.saveCsvBase64(
        filename: exportFile.filename,
        contentBase64: exportFile.contentBase64,
      );
      if (savedPath == null || !mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出成功：$savedPath')));
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出质量趋势失败：${_errorMessage(error)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _buildFilterBar() {
    return Wrap(
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
        SizedBox(
          width: 130,
          child: TextField(
            controller: _productController,
            decoration: const InputDecoration(
              labelText: '产品名称',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _loadTrend(),
          ),
        ),
        SizedBox(
          width: 120,
          child: TextField(
            controller: _processController,
            decoration: const InputDecoration(
              labelText: '工序编码',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _loadTrend(),
          ),
        ),
        SizedBox(
          width: 120,
          child: TextField(
            controller: _operatorController,
            decoration: const InputDecoration(
              labelText: '操作员',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _loadTrend(),
          ),
        ),
        DropdownButton<String?>(
          value: _resultFilter,
          hint: const Text('全部结果'),
          items: const [
            DropdownMenuItem(value: null, child: Text('全部结果')),
            DropdownMenuItem(value: 'passed', child: Text('合格')),
            DropdownMenuItem(value: 'failed', child: Text('不合格')),
          ],
          onChanged: _loading ? null : (v) => setState(() => _resultFilter = v),
        ),
        FilledButton.icon(
          onPressed: _loading ? null : _loadTrend,
          icon: const Icon(Icons.search),
          label: const Text('查询'),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    final theme = Theme.of(context);
    final overallPassRate =
        _overview?.passRatePercent ??
        _ratioPercent(_totalPassedCount, _totalFirstArticleCount);
    final scrapRate = _ratioPercent(_totalScrapCount, _totalFirstArticleCount);
    final repairShare = _ratioPercent(_totalRepairCount, _totalFirstArticleCount);
    final cards = [
      ('整体通过率', _formatMetricPercent(overallPassRate), '首件通过表现'),
      ('不良总数', '$_totalDefectCount', '趋势期累计不良'),
      ('报废率', _formatMetricPercent(scrapRate), '报废占首件总数'),
      ('维修占比', _formatMetricPercent(repairShare), '维修占首件总数'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards
          .map(
            (card) => SizedBox(
              width: 220,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.$1,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        card.$2,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(card.$3, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildChart() {
    if (_items.length < 2) return const SizedBox.shrink();
    final maxCount = _items.fold<int>(0, (maxValue, item) {
      final itemMax = [
        item.firstArticleTotal,
        item.passedTotal,
        item.failedTotal,
        item.defectTotal,
        item.scrapTotal,
        item.repairTotal,
      ].fold<int>(0, math.max);
      return math.max(maxValue, itemMax);
    });
    final maxY = (maxCount + 2).toDouble();
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
                  if (idx < 0 || idx >= _items.length) {
                    return const SizedBox.shrink();
                  }
                  final d = _items[idx].date;
                  return Text(
                    d.length >= 5 ? d.substring(5) : d,
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 36),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          lineBarsData: [
            _line(
              _items
                  .asMap()
                  .entries
                  .map(
                    (e) => FlSpot(
                      e.key.toDouble(),
                      e.value.passedTotal.toDouble(),
                    ),
                  )
                  .toList(),
              Colors.green,
              '通过',
            ),
            _line(
              _items
                  .asMap()
                  .entries
                  .map(
                    (e) => FlSpot(
                      e.key.toDouble(),
                      e.value.failedTotal.toDouble(),
                    ),
                  )
                  .toList(),
              Colors.red,
              '不通过',
            ),
            _line(
              _items
                  .asMap()
                  .entries
                  .map(
                    (e) => FlSpot(
                      e.key.toDouble(),
                      e.value.defectTotal.toDouble(),
                    ),
                  )
                  .toList(),
              Colors.deepOrange,
              '不良',
            ),
            _line(
              _items
                  .asMap()
                  .entries
                  .map(
                    (e) =>
                        FlSpot(e.key.toDouble(), e.value.scrapTotal.toDouble()),
                  )
                  .toList(),
              Colors.orange,
              '报废',
            ),
            _line(
              _items
                  .asMap()
                  .entries
                  .map(
                    (e) => FlSpot(
                      e.key.toDouble(),
                      e.value.repairTotal.toDouble(),
                    ),
                  )
                  .toList(),
              Colors.purple,
              '维修',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassRateChart() {
    if (_items.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
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
                  if (idx < 0 || idx >= _items.length) {
                    return const SizedBox.shrink();
                  }
                  final d = _items[idx].date;
                  return Text(
                    d.length >= 5 ? d.substring(5) : d,
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 36),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          lineBarsData: [
            _line(
              _items.asMap().entries.map((entry) {
                return FlSpot(
                  entry.key.toDouble(),
                  entry.value.passRatePercent,
                );
              }).toList(),
              Colors.blue,
              '通过率',
            ),
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

  int get _totalFirstArticleCount {
    final overviewTotal = _overview?.firstArticleTotal ?? 0;
    if (overviewTotal > 0) {
      return overviewTotal;
    }
    return _items.fold<int>(0, (sum, item) => sum + item.firstArticleTotal);
  }

  int get _totalPassedCount {
    final overviewPassed = _overview?.passedTotal ?? 0;
    if (overviewPassed > 0) {
      return overviewPassed;
    }
    return _items.fold<int>(0, (sum, item) => sum + item.passedTotal);
  }

  int get _totalDefectCount {
    return _items.fold<int>(0, (sum, item) => sum + item.defectTotal);
  }

  int get _totalScrapCount {
    return _items.fold<int>(0, (sum, item) => sum + item.scrapTotal);
  }

  int get _totalRepairCount {
    return _items.fold<int>(0, (sum, item) => sum + item.repairTotal);
  }

  double? _ratioPercent(int numerator, int denominator) {
    if (denominator <= 0) {
      return null;
    }
    return numerator * 100 / denominator;
  }

  String _formatMetricPercent(double? value) {
    if (value == null) {
      return '-';
    }
    return '${value.toStringAsFixed(1)}%';
  }

  String _fallbackLabel(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  int _totalPagesFor(int total) {
    if (total <= 0) {
      return 1;
    }
    return ((total - 1) ~/ _pageSize) + 1;
  }

  List<T> _slicePage<T>(List<T> items, int page) {
    if (items.isEmpty) {
      return const [];
    }
    final safePage = page.clamp(1, _totalPagesFor(items.length));
    final start = (safePage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, items.length);
    return items.sublist(start, end);
  }

  List<QualityProductStatItem> get _topProducts {
    final items = List<QualityProductStatItem>.from(_productStats);
    items.sort((a, b) => b.firstArticleTotal.compareTo(a.firstArticleTotal));
    return items;
  }

  List<QualityProcessStatItem> get _topProcesses {
    final items = List<QualityProcessStatItem>.from(_processStats);
    items.sort((a, b) => b.firstArticleTotal.compareTo(a.firstArticleTotal));
    return items;
  }

  List<QualityOperatorStatItem> get _topOperators {
    final items = List<QualityOperatorStatItem>.from(_operatorStats);
    items.sort((a, b) => b.firstArticleTotal.compareTo(a.firstArticleTotal));
    return items;
  }

  Widget _buildDimensionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '维度观察',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _buildProductStatsCard(),
        const SizedBox(height: 12),
        _buildProcessStatsCard(),
        const SizedBox(height: 12),
        _buildOperatorStatsCard(),
      ],
    );
  }

  Widget _buildStatsCard({
    required String title,
    required Key cardKey,
    required List<DataColumn> columns,
    required List<DataRow> rows,
    required int page,
    required int total,
    required ValueChanged<int> onPageChanged,
    required String emptyText,
  }) {
    return SizedBox(
      height: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: CrudListTableSection(
              cardKey: cardKey,
              loading: _loading,
              isEmpty: rows.isEmpty,
              emptyText: emptyText,
              child: AdaptiveTableContainer(
                child: DataTable(columns: columns, rows: rows),
              ),
            ),
          ),
          const SizedBox(height: 12),
          MesPaginationBar(
            page: page,
            totalPages: _totalPagesFor(total),
            total: total,
            loading: _loading,
            onPrevious: () => onPageChanged(page - 1),
            onNext: () => onPageChanged(page + 1),
          ),
        ],
      ),
    );
  }

  Widget _buildProductStatsCard() {
    return _buildStatsCard(
      title: '按产品对比',
      cardKey: const ValueKey('qualityTrendProductStatsCard'),
      emptyText: '暂无产品维度数据',
      columns: const [
        DataColumn(label: Text('产品')),
        DataColumn(label: Text('首件数')),
        DataColumn(label: Text('通过率')),
        DataColumn(label: Text('报废数')),
        DataColumn(label: Text('维修数')),
      ],
      rows: _slicePage(_topProducts, _productPage)
          .map(
            (item) => DataRow(
              cells: [
                DataCell(
                  Text(_fallbackLabel(item.productName, item.productCode)),
                ),
                DataCell(Text('${item.firstArticleTotal}')),
                DataCell(Text('${item.passRatePercent.toStringAsFixed(1)}%')),
                DataCell(Text('${item.scrapTotal}')),
                DataCell(Text('${item.repairTotal}')),
              ],
            ),
          )
          .toList(),
      page: _productPage,
      total: _topProducts.length,
      onPageChanged: (page) {
        setState(() {
          _productPage = page;
        });
      },
    );
  }

  Widget _buildProcessStatsCard() {
    return _buildStatsCard(
      title: '按工序对比',
      cardKey: const ValueKey('qualityTrendProcessStatsCard'),
      emptyText: '暂无工序维度数据',
      columns: const [
        DataColumn(label: Text('工序')),
        DataColumn(label: Text('首件数')),
        DataColumn(label: Text('不通过数')),
        DataColumn(label: Text('通过率')),
      ],
      rows: _slicePage(_topProcesses, _processPage)
          .map(
            (item) => DataRow(
              cells: [
                DataCell(
                  Text(
                    _fallbackLabel(
                      item.processName,
                      _fallbackLabel(item.processCode, '-'),
                    ),
                  ),
                ),
                DataCell(Text('${item.firstArticleTotal}')),
                DataCell(Text('${item.failedTotal}')),
                DataCell(Text('${item.passRatePercent.toStringAsFixed(1)}%')),
              ],
            ),
          )
          .toList(),
      page: _processPage,
      total: _topProcesses.length,
      onPageChanged: (page) {
        setState(() {
          _processPage = page;
        });
      },
    );
  }

  Widget _buildOperatorStatsCard() {
    return _buildStatsCard(
      title: '按人员对比',
      cardKey: const ValueKey('qualityTrendOperatorStatsCard'),
      emptyText: '暂无人员维度数据',
      columns: const [
        DataColumn(label: Text('人员')),
        DataColumn(label: Text('首件数')),
        DataColumn(label: Text('不通过数')),
        DataColumn(label: Text('通过率')),
      ],
      rows: _slicePage(_topOperators, _operatorPage)
          .map(
            (item) => DataRow(
              cells: [
                DataCell(Text(_fallbackLabel(item.operatorUsername, '-'))),
                DataCell(Text('${item.firstArticleTotal}')),
                DataCell(Text('${item.failedTotal}')),
                DataCell(Text('${item.passRatePercent.toStringAsFixed(1)}%')),
              ],
            ),
          )
          .toList(),
      page: _operatorPage,
      total: _topOperators.length,
      onPageChanged: (page) {
        setState(() {
          _operatorPage = page;
        });
      },
    );
  }

  Widget _buildTrendTable() {
    return SizedBox(
      height: 360,
      child: Column(
        children: [
          Expanded(
            child: CrudListTableSection(
              cardKey: const ValueKey('qualityTrendTrendTableCard'),
              loading: _loading,
              isEmpty: _items.isEmpty,
              emptyText: '暂无趋势数据',
              child: AdaptiveTableContainer(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('日期')),
                    DataColumn(label: Text('首件总数')),
                    DataColumn(label: Text('通过数')),
                    DataColumn(label: Text('不通过数')),
                    DataColumn(label: Text('通过率')),
                    DataColumn(label: Text('不良数')),
                    DataColumn(label: Text('报废数')),
                    DataColumn(label: Text('维修数')),
                  ],
                  rows: _slicePage(_items, _trendPage)
                      .map(
                        (item) => DataRow(
                          cells: [
                            DataCell(Text(item.date)),
                            DataCell(Text('${item.firstArticleTotal}')),
                            DataCell(Text('${item.passedTotal}')),
                            DataCell(Text('${item.failedTotal}')),
                            DataCell(
                              Text(
                                '${item.passRatePercent.toStringAsFixed(1)}%',
                              ),
                            ),
                            DataCell(Text('${item.defectTotal}')),
                            DataCell(Text('${item.scrapTotal}')),
                            DataCell(Text('${item.repairTotal}')),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          MesPaginationBar(
            page: _trendPage,
            totalPages: _totalPagesFor(_items.length),
            total: _items.length,
            loading: _loading,
            onPrevious: () {
              setState(() {
                _trendPage -= 1;
              });
            },
            onNext: () {
              setState(() {
                _trendPage += 1;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return ListView(
      children: [
        if (_items.length >= 2) ...[
          _buildChart(),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _legendDot(Colors.green, '通过'),
              _legendDot(Colors.red, '不通过'),
              _legendDot(Colors.deepOrange, '不良'),
              _legendDot(Colors.orange, '报废'),
              _legendDot(Colors.purple, '维修'),
            ],
          ),
          const SizedBox(height: 12),
          _buildPassRateChart(),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            children: [_legendDot(Colors.blue, '通过率趋势')],
          ),
          const SizedBox(height: 12),
        ],
        _buildDimensionSection(),
        const SizedBox(height: 12),
        _buildTrendTable(),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MesCrudPageScaffold(
      header: QualityTrendPageHeader(
        loading: _loading,
        canExport: widget.canExport,
        exporting: _exporting,
        onRefresh: _loadTrend,
        onExport: _exportTrend,
      ),
      filters: _buildFilterBar(),
      banner: _buildSummaryCards(context),
      content: _loading
          ? const MesLoadingState(label: '质量趋势加载中...')
          : _buildMainContent(),
    );
  }
}
