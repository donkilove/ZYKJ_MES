import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/services/export_file_service.dart';
import 'package:mes_client/features/quality/services/quality_service.dart';
import 'package:mes_client/core/widgets/adaptive_table_container.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/widgets/crud_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';

class QualityDataPage extends StatefulWidget {
  const QualityDataPage({
    super.key,
    required this.session,
    required this.onLogout,
    this.canExport = false,
    this.service,
    this.initialStartDate,
    this.initialEndDate,
    this.routePayloadJson,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canExport;
  final QualityService? service;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final String? routePayloadJson;

  @override
  State<QualityDataPage> createState() => _QualityDataPageState();
}

class _QualityDataPageState extends State<QualityDataPage> {
  static const int _pageSize = 30;

  late final QualityService _service;
  final ExportFileService _exportFileService = const ExportFileService();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _processCodeController = TextEditingController();
  final TextEditingController _operatorUsernameController =
      TextEditingController();

  bool _loading = false;
  bool _exporting = false;
  String _message = '';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 29));
  DateTime _endDate = DateTime.now();
  String? _resultFilter;
  QualityStatsOverview _overview = QualityStatsOverview(
    firstArticleTotal: 0,
    passedTotal: 0,
    failedTotal: 0,
    passRatePercent: 0,
    defectTotal: 0,
    scrapTotal: 0,
    repairTotal: 0,
    coveredOrderCount: 0,
    coveredProcessCount: 0,
    coveredOperatorCount: 0,
    latestFirstArticleAt: null,
  );
  List<QualityProcessStatItem> _processItems = const [];
  List<QualityOperatorStatItem> _operatorItems = const [];
  List<QualityProductStatItem> _productItems = const [];
  List<QualityTrendItem> _trendItems = const [];
  int _trendPage = 1;
  int _processPage = 1;
  int _operatorPage = 1;
  int _productPage = 1;
  String? _lastHandledRoutePayloadJson;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? QualityService(widget.session);
    if (widget.initialStartDate != null) {
      _startDate = widget.initialStartDate!;
    }
    if (widget.initialEndDate != null) {
      _endDate = widget.initialEndDate!;
    }
    _consumeRoutePayload(widget.routePayloadJson, triggerLoad: false);
    _loadStats();
  }

  @override
  void didUpdateWidget(covariant QualityDataPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.routePayloadJson != oldWidget.routePayloadJson) {
      _consumeRoutePayload(widget.routePayloadJson);
    }
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _processCodeController.dispose();
    _operatorUsernameController.dispose();
    super.dispose();
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

  void _consumeRoutePayload(String? rawPayload, {bool triggerLoad = true}) {
    if (rawPayload == null ||
        rawPayload.trim().isEmpty ||
        rawPayload == _lastHandledRoutePayloadJson) {
      return;
    }
    try {
      final payload = jsonDecode(rawPayload) as Map<String, dynamic>;
      final dashboardFilter =
          (payload['dashboard_filter'] as String? ?? '').trim();
      if (dashboardFilter != 'warning') {
        return;
      }
      _lastHandledRoutePayloadJson = rawPayload;
      if (triggerLoad) {
        setState(() {
          _resultFilter = 'failed';
          _resetLocalPages();
        });
        _loadStats();
      } else {
        _resultFilter = 'failed';
        _resetLocalPages();
      }
    } catch (_) {}
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

  String _formatRate(double value) {
    return '${value.toStringAsFixed(2)}%';
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

  void _resetLocalPages() {
    _trendPage = 1;
    _processPage = 1;
    _operatorPage = 1;
    _productPage = 1;
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
    if (picked == null) {
      return;
    }
    onChanged(picked);
  }

  Future<void> _loadStats() async {
    if (_startDate.isAfter(_endDate)) {
      setState(() {
        _message = '开始日期不能晚于结束日期';
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final overview = await _service.getQualityOverview(
        startDate: _startDate,
        endDate: _endDate,
        productName: _productNameController.text.trim(),
        processCode: _processCodeController.text.trim(),
        operatorUsername: _operatorUsernameController.text.trim(),
        result: _resultFilter,
      );
      final processItems = await _service.getQualityProcessStats(
        startDate: _startDate,
        endDate: _endDate,
        productName: _productNameController.text.trim(),
        processCode: _processCodeController.text.trim(),
        operatorUsername: _operatorUsernameController.text.trim(),
        result: _resultFilter,
      );
      final operatorItems = await _service.getQualityOperatorStats(
        startDate: _startDate,
        endDate: _endDate,
        productName: _productNameController.text.trim(),
        processCode: _processCodeController.text.trim(),
        operatorUsername: _operatorUsernameController.text.trim(),
        result: _resultFilter,
      );
      final productItems = await _service.getQualityProductStats(
        startDate: _startDate,
        endDate: _endDate,
        productName: _productNameController.text.trim(),
        processCode: _processCodeController.text.trim(),
        operatorUsername: _operatorUsernameController.text.trim(),
        result: _resultFilter,
      );
      final trendItems = await _service.getQualityTrend(
        startDate: _startDate,
        endDate: _endDate,
        productName: _productNameController.text.trim(),
        processCode: _processCodeController.text.trim(),
        operatorUsername: _operatorUsernameController.text.trim(),
        result: _resultFilter,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _overview = overview;
        _processItems = processItems;
        _operatorItems = operatorItems;
        _productItems = productItems;
        _trendItems = trendItems;
        _resetLocalPages();
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
        _message = '加载品质统计失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _exportCsv() async {
    if (_startDate.isAfter(_endDate)) {
      setState(() {
        _message = '开始日期不能晚于结束日期';
      });
      return;
    }

    setState(() {
      _exporting = true;
      _message = '';
    });
    try {
      final exportFile = await _service.exportQualityStats(
        startDate: _startDate,
        endDate: _endDate,
        productName: _productNameController.text.trim(),
        processCode: _processCodeController.text.trim(),
        operatorUsername: _operatorUsernameController.text.trim(),
        result: _resultFilter,
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
      if (savedPath == null || !mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出成功：$savedPath')));
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() => _message = '导出失败：${_errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required ThemeData theme,
  }) {
    return SizedBox(
      width: 190,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(
                value,
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

  Widget _buildPaginatedTableSection({
    required Key cardKey,
    required List<DataColumn> columns,
    required List<DataRow> rows,
    required int page,
    required int total,
    required ValueChanged<int> onPageChanged,
    required String emptyText,
    double? height,
  }) {
    final totalPages = _totalPagesFor(total);
    final content = Column(
      children: [
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
          totalPages: totalPages,
          total: total,
          loading: _loading,
          onPrevious: () => onPageChanged(page - 1),
          onNext: () => onPageChanged(page + 1),
        ),
      ],
    );

    if (height == null) {
      return content;
    }
    return SizedBox(height: height, child: content);
  }

  Widget _buildTrendSection() {
    final rows = _slicePage(_trendItems, _trendPage).map((item) {
      return DataRow(
        cells: [
          DataCell(Text(item.date)),
          DataCell(Text('${item.firstArticleTotal}')),
          DataCell(Text('${item.passedTotal}')),
          DataCell(Text('${item.failedTotal}')),
          DataCell(Text(_formatRate(item.passRatePercent))),
          DataCell(Text('${item.defectTotal}')),
          DataCell(Text('${item.scrapTotal}')),
          DataCell(Text('${item.repairTotal}')),
        ],
      );
    }).toList();
    return _buildPaginatedTableSection(
      cardKey: const ValueKey('qualityDataTrendTableCard'),
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
      rows: rows,
      page: _trendPage,
      total: _trendItems.length,
      onPageChanged: (page) {
        setState(() {
          _trendPage = page;
        });
      },
      emptyText: '暂无趋势数据',
      height: 320,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 3,
      child: MesCrudPageScaffold(
        header: Row(
          children: [
            Expanded(
              child: CrudPageHeader(
                title: '品质数据',
                onRefresh: _loading ? null : _loadStats,
              ),
            ),
            if (widget.canExport)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: OutlinedButton.icon(
                  onPressed: (_loading || _exporting) ? null : _exportCsv,
                  icon: const Icon(Icons.download),
                  label: const Text('导出'),
                ),
              ),
          ],
        ),
        banner: _message.isEmpty
            ? null
            : Text(
                _message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
        content: ListView(
          children: [
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
                          onChanged: (value) {
                            setState(() {
                              _startDate = value;
                            });
                          },
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
                          onChanged: (value) {
                            setState(() {
                              _endDate = value;
                            });
                          },
                        ),
                  icon: const Icon(Icons.event_available),
                  label: Text('结束：${_formatDate(_endDate)}'),
                ),
                FilledButton.icon(
                  onPressed: _loading ? null : _loadStats,
                  icon: const Icon(Icons.search),
                  label: const Text('查询'),
                ),
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
                Text(
                  '时间范围默认最近30天（含当天）',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _productNameController,
                    decoration: const InputDecoration(
                      labelText: '产品名称',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _loadStats(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _processCodeController,
                    decoration: const InputDecoration(
                      labelText: '工序编码',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _loadStats(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _operatorUsernameController,
                    decoration: const InputDecoration(
                      labelText: '操作员',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _loadStats(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildOverviewCard(
                  title: '首件总数',
                  value: '${_overview.firstArticleTotal}',
                  theme: theme,
                ),
                _buildOverviewCard(
                  title: '通过数',
                  value: '${_overview.passedTotal}',
                  theme: theme,
                ),
                _buildOverviewCard(
                  title: '不通过数',
                  value: '${_overview.failedTotal}',
                  theme: theme,
                ),
                _buildOverviewCard(
                  title: '通过率',
                  value: _formatRate(_overview.passRatePercent),
                  theme: theme,
                ),
                _buildOverviewCard(
                  title: '不良总数',
                  value: '${_overview.defectTotal}',
                  theme: theme,
                ),
                _buildOverviewCard(
                  title: '报废总数',
                  value: '${_overview.scrapTotal}',
                  theme: theme,
                ),
                _buildOverviewCard(
                  title: '维修总数',
                  value: '${_overview.repairTotal}',
                  theme: theme,
                ),
                _buildOverviewCard(
                  title: '覆盖订单数',
                  value: '${_overview.coveredOrderCount}',
                  theme: theme,
                ),
                _buildOverviewCard(
                  title: '覆盖工序数',
                  value: '${_overview.coveredProcessCount}',
                  theme: theme,
                ),
                _buildOverviewCard(
                  title: '覆盖人员数',
                  value: '${_overview.coveredOperatorCount}',
                  theme: theme,
                ),
                _buildOverviewCard(
                  title: '最近首件时间',
                  value: _formatDateTime(_overview.latestFirstArticleAt),
                  theme: theme,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('趋势分析', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildTrendSection(),
            const SizedBox(height: 12),
            const TabBar(
              tabs: [
                Tab(text: '按工序'),
                Tab(text: '按人员'),
                Tab(text: '按产品'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 420,
              child: TabBarView(
                children: [
                  _buildPaginatedTableSection(
                    cardKey: const ValueKey(
                      'qualityDataProcessTableCard',
                    ),
                    columns: const [
                      DataColumn(label: Text('工序编码')),
                      DataColumn(label: Text('工序名称')),
                      DataColumn(label: Text('首件总数')),
                      DataColumn(label: Text('通过数')),
                      DataColumn(label: Text('不通过数')),
                      DataColumn(label: Text('通过率')),
                      DataColumn(label: Text('不良数')),
                      DataColumn(label: Text('报废数')),
                      DataColumn(label: Text('维修数')),
                      DataColumn(label: Text('最近首件时间')),
                    ],
                    rows: _slicePage(_processItems, _processPage)
                        .map(
                          (item) => DataRow(
                            cells: [
                              DataCell(Text(item.processCode)),
                              DataCell(Text(item.processName)),
                              DataCell(Text('${item.firstArticleTotal}')),
                              DataCell(Text('${item.passedTotal}')),
                              DataCell(Text('${item.failedTotal}')),
                              DataCell(
                                Text(_formatRate(item.passRatePercent)),
                              ),
                              DataCell(Text('${item.defectTotal}')),
                              DataCell(Text('${item.scrapTotal}')),
                              DataCell(Text('${item.repairTotal}')),
                              DataCell(
                                Text(
                                  _formatDateTime(
                                    item.latestFirstArticleAt,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                    page: _processPage,
                    total: _processItems.length,
                    onPageChanged: (page) {
                      setState(() {
                        _processPage = page;
                      });
                    },
                    emptyText: '暂无工序品质数据',
                  ),
                  _buildPaginatedTableSection(
                    cardKey: const ValueKey(
                      'qualityDataOperatorTableCard',
                    ),
                    columns: const [
                      DataColumn(label: Text('操作员')),
                      DataColumn(label: Text('首件总数')),
                      DataColumn(label: Text('通过数')),
                      DataColumn(label: Text('不通过数')),
                      DataColumn(label: Text('通过率')),
                      DataColumn(label: Text('不良数')),
                      DataColumn(label: Text('报废数')),
                      DataColumn(label: Text('维修数')),
                      DataColumn(label: Text('最近首件时间')),
                    ],
                    rows: _slicePage(_operatorItems, _operatorPage)
                        .map(
                          (item) => DataRow(
                            cells: [
                              DataCell(Text(item.operatorUsername)),
                              DataCell(Text('${item.firstArticleTotal}')),
                              DataCell(Text('${item.passedTotal}')),
                              DataCell(Text('${item.failedTotal}')),
                              DataCell(
                                Text(_formatRate(item.passRatePercent)),
                              ),
                              DataCell(Text('${item.defectTotal}')),
                              DataCell(Text('${item.scrapTotal}')),
                              DataCell(Text('${item.repairTotal}')),
                              DataCell(
                                Text(
                                  _formatDateTime(
                                    item.latestFirstArticleAt,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                    page: _operatorPage,
                    total: _operatorItems.length,
                    onPageChanged: (page) {
                      setState(() {
                        _operatorPage = page;
                      });
                    },
                    emptyText: '暂无人员品质数据',
                  ),
                  _buildPaginatedTableSection(
                    cardKey: const ValueKey(
                      'qualityDataProductTableCard',
                    ),
                    columns: const [
                      DataColumn(label: Text('产品编码')),
                      DataColumn(label: Text('产品名称')),
                      DataColumn(label: Text('首件总数')),
                      DataColumn(label: Text('通过数')),
                      DataColumn(label: Text('不通过数')),
                      DataColumn(label: Text('通过率')),
                      DataColumn(label: Text('不良数')),
                      DataColumn(label: Text('报废数')),
                      DataColumn(label: Text('维修数')),
                    ],
                    rows: _slicePage(_productItems, _productPage)
                        .map(
                          (item) => DataRow(
                            cells: [
                              DataCell(Text(item.productCode)),
                              DataCell(Text(item.productName)),
                              DataCell(Text('${item.firstArticleTotal}')),
                              DataCell(Text('${item.passedTotal}')),
                              DataCell(Text('${item.failedTotal}')),
                              DataCell(
                                Text(_formatRate(item.passRatePercent)),
                              ),
                              DataCell(Text('${item.defectTotal}')),
                              DataCell(Text('${item.scrapTotal}')),
                              DataCell(Text('${item.repairTotal}')),
                            ],
                          ),
                        )
                        .toList(),
                    page: _productPage,
                    total: _productItems.length,
                    onPageChanged: (page) {
                      setState(() {
                        _productPage = page;
                      });
                    },
                    emptyText: '暂无产品品质数据',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
