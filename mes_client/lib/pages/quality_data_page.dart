import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/quality_models.dart';
import '../services/api_exception.dart';
import '../services/quality_service.dart';
import '../widgets/adaptive_table_container.dart';

class QualityDataPage extends StatefulWidget {
  const QualityDataPage({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final AppSession session;
  final VoidCallback onLogout;

  @override
  State<QualityDataPage> createState() => _QualityDataPageState();
}

class _QualityDataPageState extends State<QualityDataPage> {
  late final QualityService _service;

  bool _loading = false;
  String _message = '';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 29));
  DateTime _endDate = DateTime.now();
  QualityStatsOverview _overview = QualityStatsOverview(
    firstArticleTotal: 0,
    passedTotal: 0,
    failedTotal: 0,
    passRatePercent: 0,
    coveredOrderCount: 0,
    coveredProcessCount: 0,
    coveredOperatorCount: 0,
    latestFirstArticleAt: null,
  );
  List<QualityProcessStatItem> _processItems = const [];
  List<QualityOperatorStatItem> _operatorItems = const [];

  @override
  void initState() {
    super.initState();
    _service = QualityService(widget.session);
    _loadStats();
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
      );
      final processItems = await _service.getQualityProcessStats(
        startDate: _startDate,
        endDate: _endDate,
      );
      final operatorItems = await _service.getQualityOperatorStats(
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _overview = overview;
        _processItems = processItems;
        _operatorItems = operatorItems;
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
                '品质数据',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '刷新',
                onPressed: _loading ? null : _loadStats,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
              Text('时间范围默认最近30天（含当天）', style: theme.textTheme.bodySmall),
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
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        const TabBar(
                          tabs: [
                            Tab(text: '按工序'),
                            Tab(text: '按人员'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              Card(
                                child: _processItems.isEmpty
                                    ? const Center(child: Text('暂无工序品质数据'))
                                    : AdaptiveTableContainer(
                                        child: DataTable(
                                          columns: const [
                                            DataColumn(label: Text('工序编码')),
                                            DataColumn(label: Text('工序名称')),
                                            DataColumn(label: Text('首件总数')),
                                            DataColumn(label: Text('通过数')),
                                            DataColumn(label: Text('不通过数')),
                                            DataColumn(label: Text('通过率')),
                                            DataColumn(label: Text('最近首件时间')),
                                          ],
                                          rows: _processItems.map((item) {
                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  Text(item.processCode),
                                                ),
                                                DataCell(
                                                  Text(item.processName),
                                                ),
                                                DataCell(
                                                  Text(
                                                    '${item.firstArticleTotal}',
                                                  ),
                                                ),
                                                DataCell(
                                                  Text('${item.passedTotal}'),
                                                ),
                                                DataCell(
                                                  Text('${item.failedTotal}'),
                                                ),
                                                DataCell(
                                                  Text(
                                                    _formatRate(
                                                      item.passRatePercent,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    _formatDateTime(
                                                      item.latestFirstArticleAt,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                              ),
                              Card(
                                child: _operatorItems.isEmpty
                                    ? const Center(child: Text('暂无人员品质数据'))
                                    : AdaptiveTableContainer(
                                        child: DataTable(
                                          columns: const [
                                            DataColumn(label: Text('操作员')),
                                            DataColumn(label: Text('首件总数')),
                                            DataColumn(label: Text('通过数')),
                                            DataColumn(label: Text('不通过数')),
                                            DataColumn(label: Text('通过率')),
                                            DataColumn(label: Text('最近首件时间')),
                                          ],
                                          rows: _operatorItems.map((item) {
                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  Text(item.operatorUsername),
                                                ),
                                                DataCell(
                                                  Text(
                                                    '${item.firstArticleTotal}',
                                                  ),
                                                ),
                                                DataCell(
                                                  Text('${item.passedTotal}'),
                                                ),
                                                DataCell(
                                                  Text('${item.failedTotal}'),
                                                ),
                                                DataCell(
                                                  Text(
                                                    _formatRate(
                                                      item.passRatePercent,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    _formatDateTime(
                                                      item.latestFirstArticleAt,
                                                    ),
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
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
