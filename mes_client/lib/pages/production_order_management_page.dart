import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/craft_models.dart';
import '../models/production_models.dart';
import '../services/api_exception.dart';
import '../services/craft_service.dart';
import '../services/production_service.dart';
import '../widgets/adaptive_table_container.dart';
import '../widgets/locked_form_dialog.dart';
import 'production_order_detail_page.dart';
import 'production_order_form_page.dart';
import 'production_pipeline_instances_page.dart';

class ProductionOrderManagementPage extends StatefulWidget {
  const ProductionOrderManagementPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canCreateOrder,
    required this.canEditOrder,
    required this.canDeleteOrder,
    required this.canCompleteOrder,
    required this.canUpdatePipelineMode,
    this.service,
    this.craftService,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canCreateOrder;
  final bool canEditOrder;
  final bool canDeleteOrder;
  final bool canCompleteOrder;
  final bool canUpdatePipelineMode;
  final ProductionService? service;
  final CraftService? craftService;

  @override
  State<ProductionOrderManagementPage> createState() =>
      _ProductionOrderManagementPageState();
}

class _ProductionOrderManagementPageState
    extends State<ProductionOrderManagementPage> {
  late final ProductionService _service;
  late final CraftService _craftService;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  String _message = '';
  int _total = 0;
  String? _statusFilter;
  bool? _pipelineEnabledFilter;
  DateTime? _startDateFrom;
  DateTime? _startDateTo;
  DateTime? _dueDateFrom;
  DateTime? _dueDateTo;
  final TextEditingController _productNameController = TextEditingController();
  List<ProductionOrderItem> _items = const [];
  List<ProductionProductOption> _products = const [];
  List<ProductionProcessOption> _processes = const [];
  List<CraftTemplateItem> _templates = const [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProductionService(widget.session);
    _craftService = widget.craftService ?? CraftService(widget.session);
    _loadReferenceData();
    _loadOrders();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _productNameController.dispose();
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

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  Future<DateTime?> _pickDate(BuildContext context, DateTime? initial) async {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
  }

  Future<void> _loadReferenceData() async {
    try {
      final products = await _service.listProductOptions();
      final processes = await _service.listProcessOptions();
      final templates = await _craftService.listTemplates(
        page: 1,
        pageSize: 500,
        enabled: null,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _products = products;
        _processes = processes;
        _templates = templates.items;
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
        _message = '加载产品/工序选项失败：${_errorMessage(error)}';
      });
    }
  }

  Future<void> _exportOrders() async {
    try {
      final result = await _service.exportOrders(
        keyword: _keywordController.text.trim().isEmpty
            ? null
            : _keywordController.text.trim(),
        status: _statusFilter,
        productName: _productNameController.text.trim().isEmpty
            ? null
            : _productNameController.text.trim(),
        pipelineEnabled: _pipelineEnabledFilter,
        startDateFrom: _startDateFrom,
        startDateTo: _startDateTo,
        dueDateFrom: _dueDateFrom,
        dueDateTo: _dueDateTo,
      );
      if (!mounted) return;
      final filename =
          (result['file_name'] as String?) ??
          (result['filename'] as String?) ??
          'orders.csv';
      final base64Data =
          (result['content_base64'] as String?) ??
          (result['data'] as String?) ??
          '';
      final bytes = base64Decode(base64Data);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出成功：$filename（${bytes.length} 字节）')),
      );
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出失败：${_errorMessage(error)}')));
    }
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _service.listOrders(
        page: 1,
        pageSize: 200,
        keyword: _keywordController.text.trim(),
        status: _statusFilter,
        productName: _productNameController.text.trim().isEmpty
            ? null
            : _productNameController.text.trim(),
        pipelineEnabled: _pipelineEnabledFilter,
        startDateFrom: _startDateFrom,
        startDateTo: _startDateTo,
        dueDateFrom: _dueDateFrom,
        dueDateTo: _dueDateTo,
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
      setState(() {
        _message = '加载订单失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<bool> _showOrderDialog({
    ProductionOrderItem? existing,
    bool reloadAfterSave = true,
  }) async {
    final canWriteCurrent = existing == null
        ? widget.canCreateOrder
        : widget.canEditOrder;
    if (!canWriteCurrent) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无权限管理订单。')));
      }
      return false;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ProductionOrderFormPage(
          session: widget.session,
          onLogout: widget.onLogout,
          existing: existing,
          initialProducts: _products,
          initialProcesses: _processes,
          initialTemplates: _templates,
        ),
      ),
    );

    if (saved == true) {
      if (reloadAfterSave) {
        await _loadReferenceData();
        await _loadOrders();
      }
      return true;
    }
    return false;
  }

  Future<bool> _deleteOrder(
    ProductionOrderItem order, {
    bool reloadAfterAction = true,
  }) async {
    if (!widget.canDeleteOrder) {
      return false;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除订单'),
        content: Text('确认删除订单 ${order.orderCode} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return false;
    }

    try {
      await _service.deleteOrder(orderId: order.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('订单已删除。')));
      }
      if (reloadAfterAction) {
        await _loadOrders();
      }
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      return false;
    }
  }

  Future<bool> _completeOrder(
    ProductionOrderItem order, {
    bool reloadAfterAction = true,
  }) async {
    if (!widget.canCompleteOrder) {
      return false;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('结束订单'),
        content: Text('确认将订单 ${order.orderCode} 标记为已完成吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('结束'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return false;
    }

    try {
      await _service.completeOrder(orderId: order.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('订单已结束。')));
      }
      if (reloadAfterAction) {
        await _loadOrders();
      }
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      return false;
    }
  }

  Future<void> _openOrderDetailPage(ProductionOrderItem order) async {
    final needsRefresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ProductionOrderDetailPage(
          session: widget.session,
          onLogout: widget.onLogout,
          orderId: order.id,
          canEditOrder: widget.canEditOrder,
          canDeleteOrder: widget.canDeleteOrder,
          canCompleteOrder: widget.canCompleteOrder,
          canUpdatePipelineMode: widget.canUpdatePipelineMode,
          onEditOrder: (targetOrder) =>
              _showOrderDialog(existing: targetOrder, reloadAfterSave: false),
          onDeleteOrder: (targetOrder) =>
              _deleteOrder(targetOrder, reloadAfterAction: false),
          onCompleteOrder: (targetOrder) =>
              _completeOrder(targetOrder, reloadAfterAction: false),
          onConfigurePipelineOrder: (targetOrder) =>
              _showPipelineModeDialog(targetOrder, reloadAfterAction: false),
          onDisablePipelineOrder: (targetOrder) =>
              _disablePipelineMode(targetOrder, reloadAfterAction: false),
        ),
      ),
    );
    if (needsRefresh == true && mounted) {
      await _loadOrders();
    }
  }

  Future<bool> _showPipelineModeDialog(
    ProductionOrderItem order, {
    bool reloadAfterAction = true,
  }) async {
    if (!widget.canUpdatePipelineMode) {
      return false;
    }
    try {
      final detail = await _service.getOrderDetail(orderId: order.id);
      final mode = await _service.getOrderPipelineMode(orderId: order.id);
      final sortedProcesses = detail.processes.toList()
        ..sort((a, b) => a.processOrder.compareTo(b.processOrder));
      if (sortedProcesses.length < 2) {
        if (!mounted) {
          return false;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('工序不足两道，无法开启并行模式。')));
        return false;
      }
      final availableCodes = mode.availableProcessCodes.toSet();
      final initialSelected = mode.processCodes.toSet();
      if (!mounted) {
        return false;
      }
      final selectedCodes = await showLockedFormDialog<List<String>>(
        context: context,
        builder: (dialogContext) {
          final selected = <String>{...initialSelected};
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: Text('并行模式设置 - ${order.orderCode}'),
                content: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('请选择参与并行的工序（至少 2 道）。'),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 260,
                        child: ListView(
                          children: sortedProcesses.map((row) {
                            final code = row.processCode;
                            final enabled = availableCodes.contains(code);
                            return CheckboxListTile(
                              dense: true,
                              value: selected.contains(code),
                              onChanged: enabled
                                  ? (checked) {
                                      setDialogState(() {
                                        if (checked == true) {
                                          selected.add(code);
                                        } else {
                                          selected.remove(code);
                                        }
                                      });
                                    }
                                  : null,
                              title: Text('${row.processName} ($code)'),
                              subtitle: Text('顺序 ${row.processOrder}'),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '当前已选 ${selected.length} 道。',
                        style: Theme.of(dialogContext).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(null),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(selected.toList());
                    },
                    child: const Text('保存'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (selectedCodes == null) {
        return false;
      }
      await _service.updateOrderPipelineMode(
        orderId: order.id,
        enabled: true,
        processCodes: selectedCodes,
      );
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('并行模式已更新。')));
      if (reloadAfterAction) {
        await _loadOrders();
      }
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      return false;
    }
  }

  Future<bool> _disablePipelineMode(
    ProductionOrderItem order, {
    bool reloadAfterAction = true,
  }) async {
    if (!widget.canUpdatePipelineMode) {
      return false;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('关闭并行模式'),
          content: Text('确认关闭订单 ${order.orderCode} 的并行模式吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认关闭'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return false;
    }
    try {
      await _service.updateOrderPipelineMode(
        orderId: order.id,
        enabled: false,
        processCodes: const [],
      );
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('并行模式已关闭。')));
      if (reloadAfterAction) {
        await _loadOrders();
      }
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      return false;
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
                '生产订单管理',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
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
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _productNameController,
                  decoration: const InputDecoration(
                    labelText: '产品名称',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _loadOrders(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String?>(
                  initialValue: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: '状态',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('全部')),
                    DropdownMenuItem<String?>(
                      value: 'pending',
                      child: Text('待生产'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'in_progress',
                      child: Text('生产中'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'completed',
                      child: Text('已完成'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _statusFilter = value;
                    });
                    _loadOrders();
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<bool?>(
                  initialValue: _pipelineEnabledFilter,
                  decoration: const InputDecoration(
                    labelText: '并行模式',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem<bool?>(value: null, child: Text('全部')),
                    DropdownMenuItem<bool?>(value: true, child: Text('已开启')),
                    DropdownMenuItem<bool?>(value: false, child: Text('未开启')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _pipelineEnabledFilter = value;
                    });
                    _loadOrders();
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _loadOrders,
                icon: const Icon(Icons.search),
                label: const Text('查询'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : _exportOrders,
                icon: const Icon(Icons.download),
                label: const Text('导出'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _loading || !widget.canCreateOrder
                    ? null
                    : () => _showOrderDialog(),
                icon: const Icon(Icons.add),
                label: const Text('创建'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range, size: 16),
                label: Text(
                  '开始日期：${_startDateFrom == null ? '不限' : _formatDate(_startDateFrom)} ~ ${_startDateTo == null ? '不限' : _formatDate(_startDateTo)}',
                ),
                onPressed: () async {
                  final ctx = context;
                  final from = await _pickDate(ctx, _startDateFrom);
                  if (from == null || !mounted) return;
                  final to = await _pickDate(ctx, _startDateTo ?? from);
                  if (!mounted) return;
                  setState(() {
                    _startDateFrom = from;
                    _startDateTo = to;
                  });
                  _loadOrders();
                },
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.event, size: 16),
                label: Text(
                  '交期：${_dueDateFrom == null ? '不限' : _formatDate(_dueDateFrom)} ~ ${_dueDateTo == null ? '不限' : _formatDate(_dueDateTo)}',
                ),
                onPressed: () async {
                  final ctx = context;
                  final from = await _pickDate(ctx, _dueDateFrom);
                  if (from == null || !mounted) return;
                  final to = await _pickDate(ctx, _dueDateTo ?? from);
                  if (!mounted) return;
                  setState(() {
                    _dueDateFrom = from;
                    _dueDateTo = to;
                  });
                  _loadOrders();
                },
              ),
              if (_startDateFrom != null || _startDateTo != null || _dueDateFrom != null || _dueDateTo != null) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('清除日期'),
                  onPressed: () {
                    setState(() {
                      _startDateFrom = null;
                      _startDateTo = null;
                      _dueDateFrom = null;
                      _dueDateTo = null;
                    });
                    _loadOrders();
                  },
                ),
              ],
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
                ? const Center(child: Text('暂无生产订单。'))
                : Card(
                    child: AdaptiveTableContainer(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('订单号')),
                          DataColumn(label: Text('产品')),
                          DataColumn(label: Text('产品版本')),
                          DataColumn(label: Text('数量')),
                          DataColumn(label: Text('状态')),
                          DataColumn(label: Text('当前工序')),
                          DataColumn(label: Text('模板名称/版本')),
                          DataColumn(label: Text('并行模式')),
                          DataColumn(label: Text('创建人')),
                          DataColumn(label: Text('开始日期')),
                          DataColumn(label: Text('交期')),
                          DataColumn(label: Text('更新时间')),
                          DataColumn(label: Text('操作')),
                        ],
                        rows: _items.map((item) {
                          final templateLabel = item.processTemplateName != null
                              ? '${item.processTemplateName} v${item.processTemplateVersion ?? '-'}'
                              : '-';
                          return DataRow(
                            cells: [
                              DataCell(Text(item.orderCode)),
                              DataCell(Text(item.productName)),
                              DataCell(Text(item.productVersion != null ? 'v${item.productVersion}' : '-')),
                              DataCell(Text('${item.quantity}')),
                              DataCell(
                                Text(productionOrderStatusLabel(item.status)),
                              ),
                              DataCell(Text(item.currentProcessName ?? '-')),
                              DataCell(Text(templateLabel)),
                              DataCell(Text(item.pipelineEnabled ? '已开启' : '未开启')),
                              DataCell(Text(item.createdByUsername ?? '-')),
                              DataCell(Text(_formatDate(item.startDate))),
                              DataCell(Text(_formatDate(item.dueDate))),
                              DataCell(Text(_formatDateTime(item.updatedAt))),
                              DataCell(
                                PopupMenuButton<String>(
                                  tooltip: '操作',
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (action) async {
                                    switch (action) {
                                      case 'detail':
                                        await _openOrderDetailPage(item);
                                        break;
                                      case 'edit':
                                        await _showOrderDialog(existing: item);
                                        break;
                                      case 'delete':
                                        await _deleteOrder(item);
                                        break;
                                      case 'complete':
                                        await _completeOrder(item);
                                        break;
                                      case 'pipeline':
                                        await _showPipelineModeDialog(item);
                                        break;
                                      case 'pipeline_instances':
                                        await Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                ProductionPipelineInstancesPage(
                                              session: widget.session,
                                              onLogout: widget.onLogout,
                                              orderId: item.id,
                                              orderCode: item.orderCode,
                                              service: _service,
                                            ),
                                          ),
                                        );
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'detail',
                                      child: Text('查看详情'),
                                    ),
                                    if (item.pipelineEnabled)
                                      const PopupMenuItem(
                                        value: 'pipeline_instances',
                                        child: Text('查看并行实例'),
                                      ),
                                    if (widget.canEditOrder &&
                                        item.status == 'pending')
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('编辑订单'),
                                      ),
                                    if (widget.canCompleteOrder &&
                                        item.status == 'in_progress')
                                      const PopupMenuItem(
                                        value: 'complete',
                                        child: Text('手工完工'),
                                      ),
                                    if (widget.canUpdatePipelineMode &&
                                        item.status != 'completed')
                                      const PopupMenuItem(
                                        value: 'pipeline',
                                        child: Text('并行模式设置'),
                                      ),
                                    if (widget.canDeleteOrder &&
                                        item.status == 'pending')
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Text('删除订单'),
                                      ),
                                  ],
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
    );
  }
}
