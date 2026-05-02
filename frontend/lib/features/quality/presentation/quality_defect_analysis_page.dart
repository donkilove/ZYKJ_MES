import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/services/export_file_service.dart';
import 'package:mes_client/core/ui/patterns/mes_metric_card.dart';
import 'package:mes_client/core/ui/patterns/mes_section_card.dart';
import 'package:mes_client/features/quality/presentation/widgets/quality_defect_analysis_page_header.dart';
import 'package:mes_client/features/quality/services/quality_service.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';
import 'package:mes_client/features/quality/presentation/widgets/quality_workbench_filter_panel.dart';
import 'package:mes_client/features/quality/presentation/widgets/quality_workbench_summary_grid.dart';

class QualityDefectAnalysisPage extends StatefulWidget {
  const QualityDefectAnalysisPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canExport,
    this.service,
    this.initialStartDate,
    this.initialEndDate,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canExport;
  final QualityService? service;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  @override
  State<QualityDefectAnalysisPage> createState() =>
      _QualityDefectAnalysisPageState();
}

class _QualityDefectAnalysisPageState extends State<QualityDefectAnalysisPage> {
  static const int _pageSize = 30;

  late final QualityService _service;
  final ExportFileService _exportFileService = const ExportFileService();

  bool _loading = false;
  String _message = '';
  DefectAnalysisResult? _result;

  DateTime? _startDate;
  DateTime? _endDate;
  final _processCodeController = TextEditingController();
  final _productNameController = TextEditingController();
  final _operatorController = TextEditingController();
  final _phenomenonController = TextEditingController();
  bool _exporting = false;
  int _topReasonsPage = 1;
  int _topDefectsPage = 1;
  int _byProcessPage = 1;
  int _byProductPage = 1;
  int _productComparisonPage = 1;
  int _byOperatorPage = 1;
  int _byDatePage = 1;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? QualityService(widget.session);
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _syncDateRangeMessage();
    _load();
  }

  @override
  void dispose() {
    _processCodeController.dispose();
    _productNameController.dispose();
    _operatorController.dispose();
    _phenomenonController.dispose();
    super.dispose();
  }

  bool _isUnauthorized(Object e) => e is ApiException && e.statusCode == 401;
  String _errMsg(Object e) => e is ApiException ? e.message : e.toString();

  String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  void _syncDateRangeMessage() {
    final hasInvalidRange =
        _startDate != null &&
        _endDate != null &&
        _startDate!.isAfter(_endDate!);
    _message = hasInvalidRange ? '开始日期不能晚于结束日期' : '';
  }

  Future<void> _load() async {
    if (_startDate != null &&
        _endDate != null &&
        _startDate!.isAfter(_endDate!)) {
      setState(() {
        _syncDateRangeMessage();
      });
      return;
    }
    setState(() {
      _loading = true;
      _syncDateRangeMessage();
    });
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
        operatorUsername: _operatorController.text.trim().isEmpty
            ? null
            : _operatorController.text.trim(),
        phenomenon: _phenomenonController.text.trim().isEmpty
            ? null
            : _phenomenonController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _topReasonsPage = 1;
        _topDefectsPage = 1;
        _byProcessPage = 1;
        _byProductPage = 1;
        _productComparisonPage = 1;
        _byOperatorPage = 1;
        _byDatePage = 1;
      });
    } catch (e) {
      if (!mounted) return;
      if (_isUnauthorized(e)) {
        widget.onLogout();
        return;
      }
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
      _syncDateRangeMessage();
    });
  }

  Future<void> _export() async {
    if (_startDate != null &&
        _endDate != null &&
        _startDate!.isAfter(_endDate!)) {
      setState(() {
        _syncDateRangeMessage();
      });
      return;
    }
    setState(() {
      _exporting = true;
      _syncDateRangeMessage();
    });
    try {
      final exportFile = await _service.exportDefectAnalysis(
        startDate: _startDate,
        endDate: _endDate,
        productName: _productNameController.text.trim().isEmpty
            ? null
            : _productNameController.text.trim(),
        processCode: _processCodeController.text.trim().isEmpty
            ? null
            : _processCodeController.text.trim(),
        operatorUsername: _operatorController.text.trim().isEmpty
            ? null
            : _operatorController.text.trim(),
        phenomenon: _phenomenonController.text.trim().isEmpty
            ? null
            : _phenomenonController.text.trim(),
      );
      if (!mounted) return;
      if (exportFile.contentBase64.isEmpty) {
        setState(() => _message = '导出失败：服务端返回空数据');
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
    } catch (e) {
      if (!mounted) return;
      if (_isUnauthorized(e)) {
        widget.onLogout();
        return;
      }
      setState(() => _message = '导出失败：${_errMsg(e)}');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  int get _topDefectCount =>
      _result?.topDefects.fold<int>(0, (sum, item) => sum + item.quantity) ?? 0;

  int get _topReasonCount =>
      _result?.topReasons.fold<int>(0, (sum, item) => sum + item.quantity) ?? 0;

  Widget _buildSummarySection() {
    final totalDefectQuantity = _result?.totalDefectQuantity ?? 0;
    final processCount = _result?.byProcess.length ?? 0;
    final operatorCount = _result?.byOperator.length ?? 0;
    return MesSectionCard(
      title: '质量总览',
      child: QualityWorkbenchSummaryGrid(
        children: [
          SizedBox(
            width: 190,
            child: MesMetricCard(label: '不良总数', value: '$totalDefectQuantity'),
          ),
          SizedBox(
            width: 190,
            child: MesMetricCard(label: 'Top缺陷量', value: '$_topDefectCount'),
          ),
          SizedBox(
            width: 190,
            child: MesMetricCard(label: 'Top原因量', value: '$_topReasonCount'),
          ),
          SizedBox(
            width: 190,
            child: MesMetricCard(label: '覆盖工序', value: '$processCount'),
          ),
          SizedBox(
            width: 190,
            child: MesMetricCard(label: '涉及人员', value: '$operatorCount'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MesCrudPageScaffold(
      header: QualityDefectAnalysisPageHeader(
        loading: _loading,
        canExport: widget.canExport,
        exporting: _exporting,
        onRefresh: _load,
        onExport: _export,
      ),
      filters: _buildFilterBar(theme),
      banner: _message.isEmpty
          ? _buildSummarySection()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_message, style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 12),
                _buildSummarySection(),
              ],
            ),
      content: _loading
          ? const MesLoadingState(label: '缺陷分析加载中...')
          : _result == null
          ? const Center(child: Text('暂无数据'))
          : _buildContent(theme),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return QualityWorkbenchFilterPanel(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
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
              onPressed: () => setState(() {
                _startDate = null;
                _endDate = null;
                _syncDateRangeMessage();
              }),
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
          SizedBox(
            width: 150,
            child: TextField(
              controller: _operatorController,
              decoration: const InputDecoration(
                labelText: '操作员',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          SizedBox(
            width: 150,
            child: TextField(
              controller: _phenomenonController,
              decoration: const InputDecoration(
                labelText: '不良类型',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          FilledButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.search),
            label: const Text('查询'),
          ),
        ],
      ),
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
                  if (idx < 0 || idx >= items.length) {
                    return const SizedBox.shrink();
                  }
                  final label = items[idx].phenomenon;
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: SizedBox(
                      width: 56,
                      child: Text(
                        label.length > 6 ? '${label.substring(0, 6)}…' : label,
                        style: const TextStyle(fontSize: 9),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
          barGroups: items.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.quantity.toDouble(),
                  width: 24,
                  borderRadius: BorderRadius.circular(4),
                  color: theme.colorScheme.error,
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
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

  Widget _buildPaginatedTableSection({
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
        children: [
          Expanded(
            child: CrudListTableSection(
              cardKey: cardKey,
              loading: _loading,
              isEmpty: rows.isEmpty,
              emptyText: emptyText,
              enableUnifiedHeaderStyle: true,
              child: DataTable(columns: columns, rows: rows),
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

  Widget _buildContent(ThemeData theme) {
    final result = _result!;
    return ListView(
      children: [
        MesSectionCard(
          title: '关键分布',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Top 缺陷原因', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (result.topReasons.isEmpty)
                const Text('暂无数据')
              else
                _buildPaginatedTableSection(
                  cardKey: const ValueKey('qualityDefectTopReasonsCard'),
                  columns: const [
                    DataColumn(label: Text('缺陷原因')),
                    DataColumn(label: Text('数量')),
                    DataColumn(label: Text('占比 %')),
                  ],
                  rows: _slicePage(result.topReasons, _topReasonsPage)
                      .map(
                        (item) => DataRow(
                          cells: [
                            DataCell(Text(item.reason)),
                            DataCell(Text('${item.quantity}')),
                            DataCell(Text('${item.ratio}')),
                          ],
                        ),
                      )
                      .toList(),
                  page: _topReasonsPage,
                  total: result.topReasons.length,
                  onPageChanged: (page) {
                    setState(() {
                      _topReasonsPage = page;
                    });
                  },
                  emptyText: '暂无缺陷原因数据',
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
                _buildPaginatedTableSection(
                  cardKey: const ValueKey('qualityDefectTopDefectsCard'),
                  columns: const [
                    DataColumn(label: Text('缺陷现象')),
                    DataColumn(label: Text('数量')),
                    DataColumn(label: Text('占比 %')),
                  ],
                  rows: _slicePage(result.topDefects, _topDefectsPage)
                      .map(
                        (item) => DataRow(
                          cells: [
                            DataCell(Text(item.phenomenon)),
                            DataCell(Text('${item.quantity}')),
                            DataCell(Text('${item.ratio}')),
                          ],
                        ),
                      )
                      .toList(),
                  page: _topDefectsPage,
                  total: result.topDefects.length,
                  onPageChanged: (page) {
                    setState(() {
                      _topDefectsPage = page;
                    });
                  },
                  emptyText: '暂无缺陷现象数据',
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        MesSectionCard(
          title: '维度观察',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('按工序分布', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (result.byProcess.isEmpty)
                const Text('暂无数据')
              else
                _buildPaginatedTableSection(
                  cardKey: const ValueKey('qualityDefectByProcessCard'),
                  columns: const [
                    DataColumn(label: Text('工序编码')),
                    DataColumn(label: Text('工序名称')),
                    DataColumn(label: Text('不良数量')),
                  ],
                  rows: _slicePage(result.byProcess, _byProcessPage)
                      .map(
                        (item) => DataRow(
                          cells: [
                            DataCell(Text(item.processCode)),
                            DataCell(Text(item.processName ?? '-')),
                            DataCell(Text('${item.quantity}')),
                          ],
                        ),
                      )
                      .toList(),
                  page: _byProcessPage,
                  total: result.byProcess.length,
                  onPageChanged: (page) {
                    setState(() {
                      _byProcessPage = page;
                    });
                  },
                  emptyText: '暂无工序分布数据',
                ),
              const SizedBox(height: 16),
              Text('按产品分布', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (result.byProduct.isEmpty)
                const Text('暂无数据')
              else
                _buildPaginatedTableSection(
                  cardKey: const ValueKey('qualityDefectByProductCard'),
                  columns: const [
                    DataColumn(label: Text('产品')),
                    DataColumn(label: Text('不良数量')),
                  ],
                  rows: _slicePage(result.byProduct, _byProductPage)
                      .map(
                        (item) => DataRow(
                          cells: [
                            DataCell(Text(item.productName ?? '未知产品')),
                            DataCell(Text('${item.quantity}')),
                          ],
                        ),
                      )
                      .toList(),
                  page: _byProductPage,
                  total: result.byProduct.length,
                  onPageChanged: (page) {
                    setState(() {
                      _byProductPage = page;
                    });
                  },
                  emptyText: '暂无产品分布数据',
                ),
              const SizedBox(height: 16),
              Text('产品质量对比', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (result.productQualityComparison.isEmpty)
                const Text('暂无数据')
              else
                _buildPaginatedTableSection(
                  cardKey: const ValueKey('qualityDefectProductComparisonCard'),
                  columns: const [
                    DataColumn(label: Text('产品名称')),
                    DataColumn(label: Text('首件总数')),
                    DataColumn(label: Text('通过数')),
                    DataColumn(label: Text('不通过数')),
                    DataColumn(label: Text('通过率')),
                    DataColumn(label: Text('报废数')),
                    DataColumn(label: Text('维修数')),
                  ],
                  rows: _slicePage(
                    result.productQualityComparison,
                    _productComparisonPage,
                  ).map(
                    (item) => DataRow(
                      cells: [
                        DataCell(Text(item.productName)),
                        DataCell(Text('${item.firstArticleTotal}')),
                        DataCell(Text('${item.passedTotal}')),
                        DataCell(Text('${item.failedTotal}')),
                        DataCell(Text('${item.passRatePercent}%')),
                        DataCell(Text('${item.scrapTotal}')),
                        DataCell(Text('${item.repairTotal}')),
                      ],
                    ),
                  ).toList(),
                  page: _productComparisonPage,
                  total: result.productQualityComparison.length,
                  onPageChanged: (page) {
                    setState(() {
                      _productComparisonPage = page;
                    });
                  },
                  emptyText: '暂无产品质量对比数据',
                ),
              const SizedBox(height: 16),
              Text('按人员分布', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (result.byOperator.isEmpty)
                const Text('暂无数据')
              else
                _buildPaginatedTableSection(
                  cardKey: const ValueKey('qualityDefectByOperatorCard'),
                  columns: const [
                    DataColumn(label: Text('操作员')),
                    DataColumn(label: Text('不良数量')),
                  ],
                  rows: _slicePage(result.byOperator, _byOperatorPage)
                      .map(
                        (item) => DataRow(
                          cells: [
                            DataCell(Text(item.operatorUsername ?? '未知人员')),
                            DataCell(Text('${item.quantity}')),
                          ],
                        ),
                      )
                      .toList(),
                  page: _byOperatorPage,
                  total: result.byOperator.length,
                  onPageChanged: (page) {
                    setState(() {
                      _byOperatorPage = page;
                    });
                  },
                  emptyText: '暂无人员分布数据',
                ),
              const SizedBox(height: 16),
              Text('按日期趋势', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (result.byDate.isEmpty)
                const Text('暂无数据')
              else
                _buildPaginatedTableSection(
                  cardKey: const ValueKey('qualityDefectByDateCard'),
                  columns: const [
                    DataColumn(label: Text('日期')),
                    DataColumn(label: Text('不良数量')),
                  ],
                  rows: _slicePage(result.byDate, _byDatePage)
                      .map(
                        (item) => DataRow(
                          cells: [
                            DataCell(Text(item.date)),
                            DataCell(Text('${item.quantity}')),
                          ],
                        ),
                      )
                      .toList(),
                  page: _byDatePage,
                  total: result.byDate.length,
                  onPageChanged: (page) {
                    setState(() {
                      _byDatePage = page;
                    });
                  },
                  emptyText: '暂无日期趋势数据',
                ),
            ],
          ),
        ),
      ],
    );
  }
}
