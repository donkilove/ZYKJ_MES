import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/production_models.dart';
import '../services/api_exception.dart';
import '../services/production_service.dart';
import '../widgets/adaptive_table_container.dart';

class ProductionDataPage extends StatefulWidget {
  const ProductionDataPage({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final AppSession session;
  final VoidCallback onLogout;

  @override
  State<ProductionDataPage> createState() => _ProductionDataPageState();
}

class _ProductionDataPageState extends State<ProductionDataPage> {
  late final ProductionService _service;

  bool _loading = false;
  String _message = '';
  ProductionStatsOverview _overview = ProductionStatsOverview(
    totalOrders: 0,
    pendingOrders: 0,
    inProgressOrders: 0,
    completedOrders: 0,
    totalQuantity: 0,
    finishedQuantity: 0,
  );
  List<ProductionProcessStatItem> _processItems = const [];
  List<ProductionOperatorStatItem> _operatorItems = const [];

  @override
  void initState() {
    super.initState();
    _service = ProductionService(widget.session);
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

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final overview = await _service.getOverviewStats();
      final processItems = await _service.getProcessStats();
      final operatorItems = await _service.getOperatorStats();
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
        _message = '加载生产统计失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _buildOverviewCard({required String title, required int value}) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(
                '$value',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                '生产数据查询',
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
            runSpacing: 12,
            children: [
              _buildOverviewCard(title: '订单总数', value: _overview.totalOrders),
              _buildOverviewCard(title: '待生产', value: _overview.pendingOrders),
              _buildOverviewCard(
                title: '生产中',
                value: _overview.inProgressOrders,
              ),
              _buildOverviewCard(
                title: '已完成',
                value: _overview.completedOrders,
              ),
              _buildOverviewCard(title: '计划总量', value: _overview.totalQuantity),
              _buildOverviewCard(
                title: '完成总量',
                value: _overview.finishedQuantity,
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
                                    ? const Center(child: Text('暂无工序统计'))
                                    : AdaptiveTableContainer(
                                        child: DataTable(
                                          columns: const [
                                            DataColumn(label: Text('工序')),
                                            DataColumn(label: Text('订单数')),
                                            DataColumn(label: Text('待生产')),
                                            DataColumn(label: Text('生产中')),
                                            DataColumn(label: Text('部分完成')),
                                            DataColumn(label: Text('已完成')),
                                            DataColumn(label: Text('可见数量')),
                                            DataColumn(label: Text('完成数量')),
                                          ],
                                          rows: _processItems.map((item) {
                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  Text(
                                                    '${item.processName} (${item.processCode})',
                                                  ),
                                                ),
                                                DataCell(
                                                  Text('${item.totalOrders}'),
                                                ),
                                                DataCell(
                                                  Text('${item.pendingOrders}'),
                                                ),
                                                DataCell(
                                                  Text(
                                                    '${item.inProgressOrders}',
                                                  ),
                                                ),
                                                DataCell(
                                                  Text('${item.partialOrders}'),
                                                ),
                                                DataCell(
                                                  Text(
                                                    '${item.completedOrders}',
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    '${item.totalVisibleQuantity}',
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    '${item.totalCompletedQuantity}',
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
                                    ? const Center(child: Text('暂无人员统计'))
                                    : AdaptiveTableContainer(
                                        child: DataTable(
                                          columns: const [
                                            DataColumn(label: Text('操作员')),
                                            DataColumn(label: Text('工序')),
                                            DataColumn(label: Text('记录数')),
                                            DataColumn(label: Text('数量')),
                                            DataColumn(label: Text('最近报工')),
                                          ],
                                          rows: _operatorItems.map((item) {
                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  Text(item.operatorUsername),
                                                ),
                                                DataCell(
                                                  Text(
                                                    '${item.processName} (${item.processCode})',
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    '${item.productionRecords}',
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    '${item.productionQuantity}',
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    _formatDateTime(
                                                      item.lastProductionAt,
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
