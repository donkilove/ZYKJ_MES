import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/production_models.dart';
import '../services/api_exception.dart';
import '../services/production_service.dart';
import '../widgets/adaptive_table_container.dart';
import '../widgets/locked_form_dialog.dart';

enum _QueryOrderAction { detail, firstArticle, endProduction }

class ProductionOrderQueryPage extends StatefulWidget {
  const ProductionOrderQueryPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canOperate,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canOperate;

  @override
  State<ProductionOrderQueryPage> createState() =>
      _ProductionOrderQueryPageState();
}

class _ProductionOrderQueryPageState extends State<ProductionOrderQueryPage> {
  static const Duration _pollInterval = Duration(seconds: 12);

  late final ProductionService _service;
  final TextEditingController _keywordController = TextEditingController();

  Timer? _pollTimer;
  bool _loading = false;
  bool _acting = false;
  String _message = '';
  int _total = 0;
  List<MyOrderItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _service = ProductionService(widget.session);
    _loadOrders();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _keywordController.dispose();
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

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final sec = local.second.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min:$sec';
  }

  bool _canSubmitFirstArticle(MyOrderItem item) {
    return widget.canOperate && item.canFirstArticle && !_acting;
  }

  bool _canSubmitEndProduction(MyOrderItem item) {
    return widget.canOperate && item.canEndProduction && !_acting;
  }

  List<PopupMenuEntry<_QueryOrderAction>> _buildOrderActionMenuItems(
    MyOrderItem item,
  ) {
    return [
      const PopupMenuItem<_QueryOrderAction>(
        value: _QueryOrderAction.detail,
        child: Text('详情'),
      ),
      PopupMenuItem<_QueryOrderAction>(
        value: _QueryOrderAction.firstArticle,
        enabled: _canSubmitFirstArticle(item),
        child: const Text('首件'),
      ),
      PopupMenuItem<_QueryOrderAction>(
        value: _QueryOrderAction.endProduction,
        enabled: _canSubmitEndProduction(item),
        child: const Text('报工'),
      ),
    ];
  }

  void _onOrderActionSelected(_QueryOrderAction action, MyOrderItem item) {
    switch (action) {
      case _QueryOrderAction.detail:
        _showOrderDetail(item);
        break;
      case _QueryOrderAction.firstArticle:
        _showFirstArticleDialog(item);
        break;
      case _QueryOrderAction.endProduction:
        _showEndProductionDialog(item);
        break;
    }
  }

  Widget _buildOrderActionMenu(MyOrderItem item) {
    return PopupMenuButton<_QueryOrderAction>(
      tooltip: '操作',
      onSelected: (action) => _onOrderActionSelected(action, item),
      itemBuilder: (_) => _buildOrderActionMenuItems(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('操作'),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      _loadOrders(silent: true);
    });
  }

  Future<void> _loadOrders({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _message = '';
      });
    }
    try {
      final result = await _service.listMyOrders(
        page: 1,
        pageSize: 200,
        keyword: _keywordController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items = result.items;
        _total = result.total;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (!silent) {
        setState(() {
          _message = '加载订单失败：${_errorMessage(error)}';
        });
      }
    } finally {
      if (!silent && mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showOrderDetail(MyOrderItem item) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          child: SizedBox(
            width: 1100,
            height: 720,
            child: FutureBuilder<ProductionOrderDetail>(
              future: _service.getOrderDetail(orderId: item.orderId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('加载订单详情失败'),
                        const SizedBox(height: 8),
                        Text(snapshot.error.toString()),
                        const Spacer(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('关闭'),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final detail = snapshot.data!;
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '订单详情：${detail.order.orderCode}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('关闭'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          Text('产品：${detail.order.productName}'),
                          Text('数量：${detail.order.quantity}'),
                          Text(
                            '状态：${productionOrderStatusLabel(detail.order.status)}',
                          ),
                          Text(
                            '当前工序：${detail.order.currentProcessName ?? '-'}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: DefaultTabController(
                          length: 2,
                          child: Column(
                            children: [
                              const TabBar(
                                tabs: [
                                  Tab(text: '工序'),
                                  Tab(text: '事件'),
                                ],
                              ),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    Card(
                                      child: AdaptiveTableContainer(
                                        child: DataTable(
                                          columns: const [
                                            DataColumn(label: Text('顺序')),
                                            DataColumn(label: Text('工序')),
                                            DataColumn(label: Text('状态')),
                                            DataColumn(label: Text('可见数量')),
                                            DataColumn(label: Text('完成数量')),
                                          ],
                                          rows: detail.processes.map((entry) {
                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  Text('${entry.processOrder}'),
                                                ),
                                                DataCell(
                                                  Text(entry.processName),
                                                ),
                                                DataCell(
                                                  Text(
                                                    productionProcessStatusLabel(
                                                      entry.status,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    '${entry.visibleQuantity}',
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    '${entry.completedQuantity}',
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                    Card(
                                      child: ListView.separated(
                                        itemCount: detail.events.length,
                                        separatorBuilder: (_, _) =>
                                            const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final event = detail.events[index];
                                          return ListTile(
                                            title: Text(event.eventTitle),
                                            subtitle: Text(
                                              '${_formatDateTime(event.createdAt)}  ${event.eventDetail ?? ''}',
                                            ),
                                            trailing: Text(
                                              event.operatorUsername ?? '-',
                                            ),
                                          );
                                        },
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
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFirstArticleDialog(MyOrderItem item) async {
    final codeController = TextEditingController();
    final remarkController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    try {
      final confirmed = await showLockedFormDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('提交首件'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: codeController,
                      decoration: const InputDecoration(
                        labelText: '当日校验码',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入当日校验码';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: remarkController,
                      decoration: const InputDecoration(
                        labelText: '备注',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }
                  Navigator.of(context).pop(true);
                },
                child: const Text('提交'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        return;
      }

      setState(() {
        _acting = true;
      });
      try {
        await _service.submitFirstArticle(
          orderId: item.orderId,
          orderProcessId: item.currentProcessId,
          verificationCode: codeController.text.trim(),
          remark: remarkController.text.trim().isEmpty
              ? null
              : remarkController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('首件提交成功。')));
        }
        await _loadOrders();
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
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      } finally {
        if (mounted) {
          setState(() {
            _acting = false;
          });
        }
      }
    } finally {
      codeController.dispose();
      remarkController.dispose();
    }
  }

  Future<void> _showEndProductionDialog(MyOrderItem item) async {
    final quantityController = TextEditingController(
      text: item.maxProducibleQuantity > 0
          ? '${item.maxProducibleQuantity}'
          : '1',
    );
    final remarkController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    try {
      final confirmed = await showLockedFormDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('报工'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('最大可报工数量：${item.maxProducibleQuantity}'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '数量',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final quantity = int.tryParse(value?.trim() ?? '');
                        if (quantity == null || quantity <= 0) {
                          return 'Quantity must be greater than 0';
                        }
                        if (quantity > item.maxProducibleQuantity) {
                          return 'Quantity exceeds max producible amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: remarkController,
                      decoration: const InputDecoration(
                        labelText: '备注',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }
                  Navigator.of(context).pop(true);
                },
                child: const Text('提交'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) {
        return;
      }

      setState(() {
        _acting = true;
      });
      try {
        await _service.endProduction(
          orderId: item.orderId,
          orderProcessId: item.currentProcessId,
          quantity: int.parse(quantityController.text.trim()),
          remark: remarkController.text.trim().isEmpty
              ? null
              : remarkController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('报工成功。')));
        }
        await _loadOrders();
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
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      } finally {
        if (mounted) {
          setState(() {
            _acting = false;
          });
        }
      }
    } finally {
      quantityController.dispose();
      remarkController.dispose();
    }
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
                '生产订单查询',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '每 ${_pollInterval.inSeconds} 秒自动刷新',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '刷新',
                onPressed: _loading ? null : _loadOrders,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keywordController,
                  decoration: const InputDecoration(
                    labelText: '搜索订单号/产品',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _loadOrders(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _loadOrders,
                icon: const Icon(Icons.search),
                label: const Text('查询'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('总数：$_total', style: theme.textTheme.titleMedium),
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
                : _items.isEmpty
                ? const Center(child: Text('暂无可执行生产订单。'))
                : Card(
                    child: AdaptiveTableContainer(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('订单号')),
                          DataColumn(label: Text('产品')),
                          DataColumn(label: Text('订单状态')),
                          DataColumn(label: Text('工序')),
                          DataColumn(label: Text('工序状态')),
                          DataColumn(label: Text('可见数量')),
                          DataColumn(label: Text('完成数量')),
                          DataColumn(label: Text('更新时间')),
                          DataColumn(label: Text('操作')),
                        ],
                        rows: _items.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(Text(item.orderCode)),
                              DataCell(Text(item.productName)),
                              DataCell(
                                Text(
                                  productionOrderStatusLabel(item.orderStatus),
                                ),
                              ),
                              DataCell(Text(item.currentProcessName)),
                              DataCell(
                                Text(
                                  productionProcessStatusLabel(
                                    item.processStatus,
                                  ),
                                ),
                              ),
                              DataCell(Text('${item.visibleQuantity}')),
                              DataCell(
                                Text('${item.processCompletedQuantity}'),
                              ),
                              DataCell(Text(_formatDateTime(item.updatedAt))),
                              DataCell(_buildOrderActionMenu(item)),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
