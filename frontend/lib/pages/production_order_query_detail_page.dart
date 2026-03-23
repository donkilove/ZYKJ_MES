import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/production_models.dart';
import '../services/api_exception.dart';
import '../services/production_service.dart';
import '../widgets/adaptive_table_container.dart';

class ProductionOrderQueryDetailPage extends StatefulWidget {
  const ProductionOrderQueryDetailPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.orderId,
    required this.canFirstArticle,
    required this.canEndProduction,
    required this.canCreateManualRepairOrder,
    required this.canCreateAssistAuthorization,
    required this.initialOrderContext,
    required this.onSubmitFirstArticle,
    required this.onEndProduction,
    required this.onCreateManualRepair,
    required this.onApplyAssist,
    required this.onRefreshOrderContext,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final int orderId;
  final bool canFirstArticle;
  final bool canEndProduction;
  final bool canCreateManualRepairOrder;
  final bool canCreateAssistAuthorization;
  final MyOrderItem initialOrderContext;
  final Future<bool> Function(MyOrderItem item) onSubmitFirstArticle;
  final Future<bool> Function(MyOrderItem item) onEndProduction;
  final Future<bool> Function(MyOrderItem item) onCreateManualRepair;
  final Future<bool> Function(MyOrderItem item) onApplyAssist;
  final Future<MyOrderContextResult> Function(int orderId)
  onRefreshOrderContext;
  final ProductionService? service;

  @override
  State<ProductionOrderQueryDetailPage> createState() =>
      _ProductionOrderQueryDetailPageState();
}

class _ProductionOrderQueryDetailPageState
    extends State<ProductionOrderQueryDetailPage> {
  late final ProductionService _service;
  static const double _summaryMetricWidth = 180;

  bool _loading = false;
  bool _acting = false;
  bool _needsRefreshOnPop = false;
  String _message = '';
  ProductionOrderDetail? _detail;
  MyOrderItem? _orderContext;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProductionService(widget.session);
    _orderContext = widget.initialOrderContext;
    _loadDetail();
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

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final sec = local.second.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min:$sec';
  }

  String _viewModeLabel(String? value) {
    switch (value) {
      case 'assist':
        return '我的代班工单';
      case 'proxy':
        return '代理操作员视角';
      case 'own':
      default:
        return '我的工单';
    }
  }

  String _templateLabel(ProductionOrderItem order) {
    final templateName = order.processTemplateName;
    if (templateName == null || templateName.trim().isEmpty) {
      return '-';
    }
    final version = order.processTemplateVersion;
    return version == null ? templateName : '$templateName v$version';
  }

  String _displayValue(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  Widget _buildSummaryMetric(String label, String value) {
    return SizedBox(
      width: _summaryMetricWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 6),
          SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  TableRow _buildInfoRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 12),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SelectableText(value),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, String subtitle, List<TableRow> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Table(
              columnWidths: const {
                0: IntrinsicColumnWidth(),
                1: FlexColumnWidth(),
              },
              children: rows,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryWorkbench(ProductionOrderDetail detail) {
    final order = detail.order;
    final contextItem = _orderContext;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 280,
                    maxWidth: 520,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderCode,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              '订单状态 ${productionOrderStatusLabel(order.status)}',
                            ),
                          ),
                          Chip(
                            label: Text(
                              '视角 ${_viewModeLabel(contextItem?.workView)}',
                            ),
                          ),
                          Chip(
                            label: Text(
                              '并行模式 ${order.pipelineEnabled ? '开启' : '关闭'}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildSummaryMetric('数量', '${order.quantity}'),
                _buildSummaryMetric(
                  '当前工序',
                  _displayValue(order.currentProcessName),
                ),
                _buildSummaryMetric(
                  '并行实例',
                  _displayValue(contextItem?.pipelineInstanceNo),
                ),
                _buildSummaryMetric('开始日期', _formatDate(order.startDate)),
                _buildSummaryMetric('交期', _formatDate(order.dueDate)),
              ],
            ),
            const SizedBox(height: 20),
            _buildActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailWorkbench(ProductionOrderDetail detail) {
    final order = detail.order;
    final contextItem = _orderContext;
    final cards = [
      _buildInfoCard('工单基础信息', '使用桌面详情卡片承载订单与模板信息。', [
        _buildInfoRow('订单号', order.orderCode),
        _buildInfoRow('产品', order.productName),
        _buildInfoRow('产品版本', _displayValue(order.productVersion?.toString())),
        _buildInfoRow('订单状态', productionOrderStatusLabel(order.status)),
        _buildInfoRow('当前工序', _displayValue(order.currentProcessName)),
        _buildInfoRow('模板名称/版本', _templateLabel(order)),
        _buildInfoRow('创建人', _displayValue(order.createdByUsername)),
      ]),
      _buildInfoCard('当前视角信息', '汇总当前可操作视角与追踪字段，保持业务语义不变。', [
        _buildInfoRow('视角', _viewModeLabel(contextItem?.workView)),
        _buildInfoRow('并行模式', order.pipelineEnabled ? '开启' : '关闭'),
        _buildInfoRow('并行实例', _displayValue(contextItem?.pipelineInstanceNo)),
        _buildInfoRow('创建时间', _formatDateTime(order.createdAt)),
        _buildInfoRow(
          '更新时间',
          contextItem == null
              ? _formatDateTime(order.updatedAt)
              : _formatDateTime(contextItem.updatedAt),
        ),
        _buildInfoRow('开始日期', _formatDate(order.startDate)),
        _buildInfoRow('交期', _formatDate(order.dueDate)),
      ]),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        if (!wide) {
          return Column(
            children: cards
                .map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: card,
                  ),
                )
                .toList(),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        );
      },
    );
  }

  Future<void> _loadDetail({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _message = '';
      });
    }
    try {
      final detail = await _service.getOrderDetail(orderId: widget.orderId);
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
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
        _message = '加载订单详情失败：${_errorMessage(error)}';
      });
    } finally {
      if (!silent && mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _refreshOrderContext() async {
    final result = await widget.onRefreshOrderContext(widget.orderId);
    if (!mounted) {
      return;
    }
    setState(() {
      _orderContext = result.found ? result.item : null;
    });
  }

  Future<void> _executeAction(
    Future<bool> Function(MyOrderItem item) action,
  ) async {
    if (_acting) {
      return;
    }
    final orderContext = _orderContext;
    if (orderContext == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前视角下该工单已不可操作，仅支持查看详情')));
      return;
    }
    setState(() {
      _acting = true;
    });
    try {
      final changed = await action(orderContext);
      if (!mounted || !changed) {
        return;
      }
      _needsRefreshOnPop = true;
      await _loadDetail(silent: true);
      await _refreshOrderContext();
    } finally {
      if (mounted) {
        setState(() {
          _acting = false;
        });
      }
    }
  }

  Widget _buildActionBar() {
    final contextItem = _orderContext;
    final canFirstArticle =
        widget.canFirstArticle &&
        !_acting &&
        (contextItem?.canFirstArticle ?? false);
    final canEndProduction =
        widget.canEndProduction &&
        !_acting &&
        (contextItem?.canEndProduction ?? false);
    final canCreateManualRepair =
        widget.canCreateManualRepairOrder && !_acting && contextItem != null;
    final canCreateAssist =
        widget.canCreateAssistAuthorization && !_acting && contextItem != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: canFirstArticle
                  ? () => _executeAction(widget.onSubmitFirstArticle)
                  : null,
              icon: const Icon(Icons.verified_outlined),
              label: const Text('首件'),
            ),
            FilledButton.icon(
              onPressed: canEndProduction
                  ? () => _executeAction(widget.onEndProduction)
                  : null,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('报工'),
            ),
            FilledButton.icon(
              onPressed: canCreateManualRepair
                  ? () => _executeAction(widget.onCreateManualRepair)
                  : null,
              icon: const Icon(Icons.build_outlined),
              label: const Text('手工送修建单'),
            ),
            FilledButton.icon(
              onPressed: canCreateAssist
                  ? () => _executeAction(widget.onApplyAssist)
                  : null,
              icon: const Icon(Icons.how_to_reg_outlined),
              label: const Text('发起代班'),
            ),
          ],
        ),
        if (contextItem == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '当前视角下该工单已不可操作，仅保留详情查看。',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _buildBodyContent(ProductionOrderDetail detail) {
    final sortedProcesses = detail.processes.toList()
      ..sort((a, b) => a.processOrder.compareTo(b.processOrder));
    final sortedSubOrders = detail.subOrders.toList()
      ..sort((a, b) {
        final byOrder = a.orderProcessId.compareTo(b.orderProcessId);
        if (byOrder != 0) {
          return byOrder;
        }
        final byUser = a.operatorUsername.compareTo(b.operatorUsername);
        if (byUser != 0) {
          return byUser;
        }
        return a.id.compareTo(b.id);
      });
    final sortedRecords = detail.records.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final sortedEvents = detail.events.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '工序'),
              Tab(text: '子订单'),
              Tab(text: '记录'),
              Tab(text: '事件'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              children: [
                Card(
                  child: AdaptiveTableContainer(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('顺序')),
                        DataColumn(label: Text('工序编码')),
                        DataColumn(label: Text('工序名称')),
                        DataColumn(label: Text('状态')),
                        DataColumn(label: Text('可见数量')),
                        DataColumn(label: Text('完成数量')),
                      ],
                      rows: sortedProcesses.map((item) {
                        return DataRow(
                          cells: [
                            DataCell(Text('${item.processOrder}')),
                            DataCell(Text(item.processCode)),
                            DataCell(Text(item.processName)),
                            DataCell(
                              Text(productionProcessStatusLabel(item.status)),
                            ),
                            DataCell(Text('${item.visibleQuantity}')),
                            DataCell(Text('${item.completedQuantity}')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Card(
                  child: AdaptiveTableContainer(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('工序编码')),
                        DataColumn(label: Text('工序名称')),
                        DataColumn(label: Text('操作员')),
                        DataColumn(label: Text('分配数量')),
                        DataColumn(label: Text('完成数量')),
                        DataColumn(label: Text('状态')),
                        DataColumn(label: Text('可见')),
                      ],
                      rows: sortedSubOrders.map((item) {
                        return DataRow(
                          cells: [
                            DataCell(Text(item.processCode)),
                            DataCell(Text(item.processName)),
                            DataCell(Text(item.operatorUsername)),
                            DataCell(Text('${item.assignedQuantity}')),
                            DataCell(Text('${item.completedQuantity}')),
                            DataCell(
                              Text(productionSubOrderStatusLabel(item.status)),
                            ),
                            DataCell(Text(item.isVisible ? '是' : '否')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Card(
                  child: AdaptiveTableContainer(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('时间')),
                        DataColumn(label: Text('工序')),
                        DataColumn(label: Text('操作员')),
                        DataColumn(label: Text('类型')),
                        DataColumn(label: Text('数量')),
                      ],
                      rows: sortedRecords.map((item) {
                        return DataRow(
                          cells: [
                            DataCell(Text(_formatDateTime(item.createdAt))),
                            DataCell(Text(item.processName)),
                            DataCell(Text(item.operatorUsername)),
                            DataCell(Text(item.recordType)),
                            DataCell(Text('${item.productionQuantity}')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Card(
                  child: ListView.separated(
                    itemCount: sortedEvents.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = sortedEvents[index];
                      final snapshotParts = <String>[];
                      if ((item.orderCode ?? '').trim().isNotEmpty) {
                        snapshotParts.add(item.orderCode!.trim());
                      }
                      if ((item.productName ?? '').trim().isNotEmpty) {
                        snapshotParts.add(item.productName!.trim());
                      }
                      if ((item.processCode ?? '').trim().isNotEmpty) {
                        snapshotParts.add(item.processCode!.trim());
                      }
                      if ((item.orderStatus ?? '').trim().isNotEmpty) {
                        snapshotParts.add(item.orderStatus!.trim());
                      }
                      final payload = (item.payloadJson ?? '').trim();
                      return ListTile(
                        title: Text(item.eventTitle),
                        subtitle: Text(
                          '${_formatDateTime(item.createdAt)}  ${item.eventDetail ?? ''}'
                          '${snapshotParts.isEmpty ? '' : '\n快照：${snapshotParts.join(' ｜ ')}'}'
                          '${payload.isEmpty ? '' : '\n载荷：$payload'}',
                        ),
                        isThreeLine:
                            snapshotParts.isNotEmpty || payload.isNotEmpty,
                        trailing: Text(item.operatorUsername ?? '-'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(_needsRefreshOnPop);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            detail == null ? '工单详情' : '工单详情 - ${detail.order.orderCode}',
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_needsRefreshOnPop),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : detail == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _message.isEmpty ? '暂无工单详情数据' : _message,
                        style: TextStyle(
                          color: _message.isEmpty
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _loadDetail,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryWorkbench(detail),
                    const SizedBox(height: 12),
                    _buildDetailWorkbench(detail),
                    if (_message.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _message,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Expanded(child: _buildBodyContent(detail)),
                  ],
                ),
        ),
      ),
    );
  }
}
