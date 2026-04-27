import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/production/services/production_service.dart';
import 'package:mes_client/features/quality/services/quality_supplier_service.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';
import 'package:mes_client/features/production/presentation/widgets/production_order_status_chip.dart';
import 'package:mes_client/features/production/presentation/production_order_detail_page.dart';
import 'package:mes_client/features/production/presentation/production_order_form_page.dart';
import 'package:mes_client/features/production/presentation/production_pipeline_instances_page.dart';

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
    this.supplierService,
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
  final QualitySupplierService? supplierService;

  @override
  State<ProductionOrderManagementPage> createState() =>
      _ProductionOrderManagementPageState();
}

class _ProductionOrderManagementPageState
    extends State<ProductionOrderManagementPage> {
  static const int _pageSize = 200;

  late final ProductionService _service;
  late final CraftService _craftService;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  String _message = '';
  int _page = 1;
  int _total = 0;
  String? _statusFilter;
  bool? _pipelineEnabledFilter;
  List<ProductionOrderItem> _items = const [];
  List<ProductionProductOption> _products = const [];
  List<ProductionProcessOption> _processes = const [];
  List<CraftTemplateItem> _templates = const [];

  int get _totalPages {
    if (_total <= 0) {
      return 1;
    }
    return ((_total - 1) ~/ _pageSize) + 1;
  }

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

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
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

  Future<void> _loadOrders({int? page}) async {
    final targetPage = page ?? _page;
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _service.listOrders(
        page: targetPage,
        pageSize: _pageSize,
        keyword: _keywordController.text.trim(),
        status: _statusFilter,
        pipelineEnabled: _pipelineEnabledFilter,
      );
      if (!mounted) {
        return;
      }
      final resolvedTotalPages = result.total <= 0
          ? 1
          : (((result.total - 1) ~/ _pageSize) + 1);
      final resolvedPage = targetPage > resolvedTotalPages
          ? resolvedTotalPages
          : targetPage;
      setState(() {
        _items = result.items;
        _total = result.total;
        _page = resolvedPage;
      });
      if (resolvedPage != targetPage) {
        await _loadOrders(page: resolvedPage);
      }
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

  Future<void> _searchFromFirstPage() async {
    await _loadOrders(page: 1);
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
          service: _service,
          craftService: _craftService,
          supplierService: widget.supplierService,
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
      builder: (context) => MesDialog(
        title: const Text('删除订单'),
        width: 420,
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
    final passwordController = TextEditingController();
    final confirmed = await showMesLockedFormDialog<bool>(
      context: context,
      builder: (context) => MesDialog(
        title: const Text('结束订单'),
        width: 420,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确认结束订单 ${order.orderCode} 吗？'),
            const SizedBox(height: 8),
            const Text('请输入当前生产管理员登录密码后，才能结束订单。'),
            const SizedBox(height: 4),
            const Text('该操作会强制释放相关生产状态。'),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '当前登录密码',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (passwordController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入当前登录密码后再结束订单')),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text('结束'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        passwordController.dispose();
      });
      return false;
    }

    try {
      await _service.completeOrder(
        orderId: order.id,
        password: passwordController.text,
      );
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
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        passwordController.dispose();
      });
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
      final selectedCodes = await showMesLockedFormDialog<List<String>>(
        context: context,
        builder: (dialogContext) {
          final selected = <String>{...initialSelected};
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return MesDialog(
                title: Text('并行模式设置 - ${order.orderCode}'),
                width: 520,
                content: Column(
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
        return MesDialog(
          title: const Text('关闭并行模式'),
          width: 420,
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

    final filtersToolbar = Row(
      children: [
        Expanded(
          child: TextField(
            controller: _keywordController,
            decoration: const InputDecoration(
              labelText: '搜索订单号/产品',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _searchFromFirstPage(),
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
                child: Text('生产完成'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _statusFilter = value;
              });
              _searchFromFirstPage();
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
              DropdownMenuItem<bool?>(value: true, child: Text('开启')),
              DropdownMenuItem<bool?>(value: false, child: Text('关闭')),
            ],
            onChanged: (value) {
              setState(() {
                _pipelineEnabledFilter = value;
              });
              _searchFromFirstPage();
            },
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _loading ? null : _searchFromFirstPage,
          icon: const Icon(Icons.search),
          label: const Text('查询'),
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
    );

    return MesCrudPageScaffold(
      header: MesRefreshPageHeader(
        title: '生产订单管理',
        onRefresh: _loading ? null : () => _loadOrders(page: _page),
      ),
      filters: filtersToolbar,
      banner: _message.isEmpty
          ? null
          : Text(
              _message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
      content: CrudListTableSection(
        cardKey: const ValueKey('productionOrderManagementListCard'),
        loading: _loading,
        isEmpty: _items.isEmpty,
        emptyText: '暂无生产订单。',
        enableUnifiedHeaderStyle: true,
        child: DataTable(
          columns: [
            UnifiedListTableHeaderStyle.column(context, '订单编号'),
            UnifiedListTableHeaderStyle.column(context, '产品名称'),
            UnifiedListTableHeaderStyle.column(context, '供应商'),
            UnifiedListTableHeaderStyle.column(context, '数量'),
            UnifiedListTableHeaderStyle.column(context, '交货日期'),
            UnifiedListTableHeaderStyle.column(context, '状态'),
            UnifiedListTableHeaderStyle.column(context, '当前工序'),
            UnifiedListTableHeaderStyle.column(context, '备注'),
            UnifiedListTableHeaderStyle.column(context, '操作'),
          ],
          rows: _items.map((item) {
            final supplierName = item.supplierName?.trim();
            final remark = item.remark?.trim();
            return DataRow(
              cells: [
                DataCell(Text(item.orderCode)),
                DataCell(Text(item.productName)),
                DataCell(
                  Text(
                    supplierName == null || supplierName.isEmpty
                        ? '-'
                        : supplierName,
                  ),
                ),
                DataCell(Text('${item.quantity}')),
                DataCell(Text(_formatDate(item.dueDate))),
                DataCell(ProductionOrderStatusChip(status: item.status)),
                DataCell(Text(item.currentProcessName ?? '-')),
                DataCell(
                  Text(remark == null || remark.isEmpty ? '-' : remark),
                ),
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
                      if (widget.canEditOrder && item.status == 'pending')
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
      pagination: MesPaginationBar(
        page: _page,
        totalPages: _totalPages,
        total: _total,
        loading: _loading,
        onPrevious: () => _loadOrders(page: _page - 1),
        onNext: () => _loadOrders(page: _page + 1),
      ),
    );
  }
}
