import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/production_models.dart';
import '../services/api_exception.dart';
import '../services/production_service.dart';
import '../widgets/adaptive_table_container.dart';
import '../widgets/locked_form_dialog.dart';

enum _QueryOrderAction { detail, firstArticle, endProduction, applyAssist }

class ProductionOrderQueryPage extends StatefulWidget {
  const ProductionOrderQueryPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canOperate,
    required this.isProductionAdmin,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canOperate;
  final bool isProductionAdmin;

  @override
  State<ProductionOrderQueryPage> createState() => _ProductionOrderQueryPageState();
}

class _ProductionOrderQueryPageState extends State<ProductionOrderQueryPage> {
  static const Duration _pollInterval = Duration(seconds: 12);

  late final ProductionService _service;
  final TextEditingController _keywordController = TextEditingController();
  Timer? _pollTimer;

  bool _loading = false;
  bool _acting = false;
  String _message = '';
  String _viewMode = 'own';
  int? _proxyOperatorUserId;
  int _total = 0;
  List<MyOrderItem> _items = const [];
  List<AssistUserOptionItem> _proxyOperators = const [];
  List<AssistUserOptionItem> _assistUsers = const [];

  @override
  void initState() {
    super.initState();
    _service = ProductionService(widget.session);
    if (widget.isProductionAdmin) {
      _loadProxyOperators();
    }
    _loadOrders();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _keywordController.dispose();
    super.dispose();
  }

  bool _isUnauthorized(Object error) => error is ApiException && error.statusCode == 401;

  String _errorMessage(Object error) => error is ApiException ? error.message : error.toString();

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final sec = local.second.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min:$sec';
  }

  Future<void> _loadProxyOperators() async {
    try {
      final result = await _service.listAssistUserOptions(page: 1, pageSize: 200, roleCode: 'operator');
      if (!mounted) return;
      setState(() {
        _proxyOperators = result.items;
        if (_proxyOperatorUserId != null && !_proxyOperators.any((item) => item.id == _proxyOperatorUserId)) {
          _proxyOperatorUserId = null;
        }
      });
    } catch (_) {}
  }

  Future<void> _ensureAssistUsersLoaded() async {
    if (_assistUsers.isNotEmpty) return;
    final result = await _service.listAssistUserOptions(page: 1, pageSize: 200);
    _assistUsers = result.items;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _loadOrders(silent: true));
  }

  Future<void> _loadOrders({bool silent = false}) async {
    if (_viewMode == 'proxy' && _proxyOperatorUserId == null) {
      if (!silent && mounted) {
        setState(() {
          _items = const [];
          _total = 0;
          _loading = false;
          _message = '';
        });
      }
      return;
    }
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
        viewMode: _viewMode,
        proxyOperatorUserId: _proxyOperatorUserId,
      );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _total = result.total;
      });
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (!silent) {
        setState(() {
          _message = '加载工单失败：${_errorMessage(error)}';
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
    try {
      final detail = await _service.getOrderDetail(orderId: item.orderId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('订单详情：${detail.order.orderCode}'),
          content: SizedBox(
            width: 620,
            child: Text('产品：${detail.order.productName}\n工序数：${detail.processes.length}\n事件数：${detail.events.length}'),
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('关闭')),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  Future<void> _showFirstArticleDialog(MyOrderItem item) async {
    final codeController = TextEditingController();
    try {
      final ok = await showLockedFormDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提交首件'),
          content: TextField(
            controller: codeController,
            decoration: const InputDecoration(labelText: '当日校验码', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('提交')),
          ],
        ),
      );
      if (ok != true || codeController.text.trim().isEmpty) return;
      await _service.submitFirstArticle(
        orderId: item.orderId,
        orderProcessId: item.currentProcessId,
        verificationCode: codeController.text.trim(),
        effectiveOperatorUserId: item.operatorUserId,
        assistAuthorizationId: item.assistAuthorizationId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('首件提交成功')));
      await _loadOrders();
    } finally {
      codeController.dispose();
    }
  }

  Future<void> _showEndProductionDialog(MyOrderItem item) async {
    final qtyController = TextEditingController(text: '${item.maxProducibleQuantity.clamp(1, 999999)}');
    try {
      final ok = await showLockedFormDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('报工'),
          content: TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '数量', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('提交')),
          ],
        ),
      );
      if (ok != true) return;
      final qty = int.tryParse(qtyController.text.trim());
      if (qty == null || qty <= 0) return;
      await _service.endProduction(
        orderId: item.orderId,
        orderProcessId: item.currentProcessId,
        quantity: qty,
        effectiveOperatorUserId: item.operatorUserId,
        assistAuthorizationId: item.assistAuthorizationId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('报工成功')));
      await _loadOrders();
    } finally {
      qtyController.dispose();
    }
  }

  Future<void> _showApplyAssistDialog(MyOrderItem item) async {
    await _ensureAssistUsersLoaded();
    if (widget.isProductionAdmin && _proxyOperators.isEmpty) {
      await _loadProxyOperators();
    }
    int? targetId = item.operatorUserId;
    int? helperId;
    final reasonController = TextEditingController();
    try {
      final ok = await showLockedFormDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('申请代班'),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: targetId,
                    decoration: const InputDecoration(labelText: '目标操作员', border: OutlineInputBorder()),
                    items: _proxyOperators.map((it) => DropdownMenuItem<int>(value: it.id, child: Text(it.displayName))).toList(),
                    onChanged: (value) => setDialogState(() => targetId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: helperId,
                    decoration: const InputDecoration(labelText: '代班人', border: OutlineInputBorder()),
                    items: _assistUsers.map((it) => DropdownMenuItem<int>(value: it.id, child: Text(it.displayName))).toList(),
                    onChanged: (value) => setDialogState(() => helperId = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: '申请原因（可选）', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('提交申请')),
            ],
          ),
        ),
      );
      if (ok != true || targetId == null || helperId == null) return;
      await _service.createAssistAuthorization(
        orderId: item.orderId,
        orderProcessId: item.currentProcessId,
        targetOperatorUserId: targetId!,
        helperUserId: helperId!,
        reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('代班申请已提交')));
      await _loadOrders();
    } finally {
      reasonController.dispose();
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
              Text('生产订单查询', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('每 ${_pollInterval.inSeconds} 秒自动刷新', style: theme.textTheme.bodySmall),
              IconButton(onPressed: _loading ? null : _loadOrders, icon: const Icon(Icons.refresh)),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keywordController,
                  decoration: const InputDecoration(labelText: '搜索订单号/产品', border: OutlineInputBorder()),
                  onSubmitted: (_) => _loadOrders(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(onPressed: _loading ? null : _loadOrders, icon: const Icon(Icons.search), label: const Text('查询')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: _viewMode,
                  decoration: const InputDecoration(labelText: '工单视角', border: OutlineInputBorder(), isDense: true),
                  items: [
                    const DropdownMenuItem(value: 'own', child: Text('我的工单')),
                    const DropdownMenuItem(value: 'assist', child: Text('我的代班工单')),
                    if (widget.isProductionAdmin) const DropdownMenuItem(value: 'proxy', child: Text('代理操作员视角')),
                  ],
                  onChanged: (value) {
                    if (value == null || value == _viewMode) return;
                    setState(() {
                      _viewMode = value;
                      if (_viewMode != 'proxy') _proxyOperatorUserId = null;
                    });
                    _loadOrders();
                  },
                ),
              ),
              if (widget.isProductionAdmin && _viewMode == 'proxy') ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<int>(
                    value: _proxyOperatorUserId,
                    decoration: const InputDecoration(labelText: '选择操作员', border: OutlineInputBorder(), isDense: true),
                    items: _proxyOperators.map((entry) => DropdownMenuItem<int>(value: entry.id, child: Text(entry.displayName))).toList(),
                    onChanged: (value) {
                      setState(() => _proxyOperatorUserId = value);
                      _loadOrders();
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text('总数：$_total', style: theme.textTheme.titleMedium),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_message, style: TextStyle(color: theme.colorScheme.error)),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(child: Text('暂无可执行生产工单'))
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
                          return DataRow(cells: [
                            DataCell(Text(item.orderCode)),
                            DataCell(Text(item.productName)),
                            DataCell(Text(productionOrderStatusLabel(item.orderStatus))),
                            DataCell(Text(item.currentProcessName)),
                            DataCell(Text(productionProcessStatusLabel(item.processStatus))),
                            DataCell(Text('${item.visibleQuantity}')),
                            DataCell(Text('${item.processCompletedQuantity}')),
                            DataCell(Text(_formatDateTime(item.updatedAt))),
                            DataCell(
                              PopupMenuButton<_QueryOrderAction>(
                                onSelected: (action) {
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
                                    case _QueryOrderAction.applyAssist:
                                      _showApplyAssistDialog(item);
                                      break;
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: _QueryOrderAction.detail, child: Text('详情')),
                                  PopupMenuItem(value: _QueryOrderAction.firstArticle, enabled: widget.canOperate && item.canFirstArticle && !_acting, child: const Text('首件')),
                                  PopupMenuItem(value: _QueryOrderAction.endProduction, enabled: widget.canOperate && item.canEndProduction && !_acting, child: const Text('报工')),
                                  PopupMenuItem(value: _QueryOrderAction.applyAssist, enabled: widget.canOperate && !_acting, child: const Text('申请代班')),
                                ],
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [Text('操作'), Icon(Icons.arrow_drop_down)],
                                  ),
                                ),
                              ),
                            ),
                          ]);
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
