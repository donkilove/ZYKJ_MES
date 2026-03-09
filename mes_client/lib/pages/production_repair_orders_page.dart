import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/production_models.dart';
import '../services/api_exception.dart';
import '../services/production_service.dart';
import '../widgets/adaptive_table_container.dart';
import '../widgets/locked_form_dialog.dart';
import '../widgets/unified_list_table_header_style.dart';

enum _RepairOrderAction { summary, complete }

class _RepairCauseDraft {
  _RepairCauseDraft({required this.phenomenon, required this.quantity})
    : reasonController = TextEditingController();

  final String phenomenon;
  final int quantity;
  final TextEditingController reasonController;
  bool isScrap = false;

  void dispose() {
    reasonController.dispose();
  }
}

class _RepairCompleteDialogResult {
  const _RepairCompleteDialogResult({
    required this.causeItems,
    required this.scrapReplenished,
    required this.returnAllocations,
  });

  final List<RepairCauseItemInput> causeItems;
  final bool scrapReplenished;
  final List<RepairReturnAllocationInput> returnAllocations;
}

class _ReturnProcessOption {
  const _ReturnProcessOption({
    required this.id,
    required this.code,
    required this.name,
  });

  final int id;
  final String code;
  final String name;
}

class ProductionRepairOrdersPage extends StatefulWidget {
  const ProductionRepairOrdersPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canComplete,
    required this.canExport,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canComplete;
  final bool canExport;
  final ProductionService? service;

  @override
  State<ProductionRepairOrdersPage> createState() =>
      _ProductionRepairOrdersPageState();
}

class _ProductionRepairOrdersPageState
    extends State<ProductionRepairOrdersPage> {
  late final ProductionService _service;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  bool _exporting = false;
  bool _acting = false;
  String _message = '';
  String _status = 'all';
  int _total = 0;
  List<RepairOrderItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProductionService(widget.session);
    _loadItems();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  bool _isUnauthorized(Object error) =>
      error is ApiException && error.statusCode == 401;

  String _errorMessage(Object error) =>
      error is ApiException ? error.message : error.toString();

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

  Future<void> _loadItems() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _service.getRepairOrders(
        page: 1,
        pageSize: 200,
        keyword: _keywordController.text.trim(),
        status: _status,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _total = result.total;
        _items = result.items;
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
        _message = '加载维修订单失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _export() async {
    if (!widget.canExport) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前角色无导出权限')));
      return;
    }
    setState(() {
      _exporting = true;
      _message = '';
    });
    try {
      final result = await _service.exportRepairOrders(
        keyword: _keywordController.text.trim().isEmpty
            ? null
            : _keywordController.text.trim(),
        status: _status,
      );
      final bytes = base64Decode(result.contentBase64);
      final location = await getSaveLocation(
        suggestedName: result.fileName,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (location == null || !mounted) {
        return;
      }
      final file = XFile.fromData(
        bytes,
        mimeType: result.mimeType,
        name: result.fileName,
      );
      await file.saveTo(location.path);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出成功（${result.exportedCount} 条）：${location.path}'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '导出失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  Future<void> _showPhenomenaSummary(RepairOrderItem item) async {
    try {
      final result = await _service.getRepairOrderPhenomenaSummary(
        repairOrderId: item.id,
      );
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('现象汇总 - ${item.repairOrderCode}'),
          content: SizedBox(
            width: 420,
            child: result.items.isEmpty
                ? const Text('暂无现象明细')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: result.items
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text(entry.phenomenon)),
                                Text('数量：${entry.quantity}'),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载现象汇总失败：${_errorMessage(error)}')),
      );
    }
  }

  Future<List<_ReturnProcessOption>> _loadReturnProcessOptions(
    RepairOrderItem item,
  ) async {
    if (item.sourceOrderId == null || item.sourceOrderProcessId == null) {
      return const [];
    }
    final detail = await _service.getOrderDetail(orderId: item.sourceOrderId!);
    final processRows = [...detail.processes]
      ..sort((left, right) => left.processOrder.compareTo(right.processOrder));
    final sourceRows = processRows
        .where((row) => row.id == item.sourceOrderProcessId)
        .toList();
    if (sourceRows.isEmpty) {
      return const [];
    }
    final sourceOrder = sourceRows.first.processOrder;
    return processRows
        .where((row) => row.processOrder <= sourceOrder)
        .map(
          (row) => _ReturnProcessOption(
            id: row.id,
            code: row.processCode,
            name: row.processName,
          ),
        )
        .toList();
  }

  Future<void> _showCompleteDialog(RepairOrderItem item) async {
    if (!widget.canComplete) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前角色无维修完成权限')));
      return;
    }
    if (item.status != 'in_repair') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('仅维修中的工单可执行完成')));
      return;
    }
    setState(() => _acting = true);
    try {
      final summary = await _service.getRepairOrderPhenomenaSummary(
        repairOrderId: item.id,
      );
      final processOptions = await _loadReturnProcessOptions(item);
      if (!mounted) {
        return;
      }
      final phenomena = summary.items.isEmpty
          ? <RepairOrderPhenomenonSummaryItem>[
              RepairOrderPhenomenonSummaryItem(
                phenomenon: '未归类',
                quantity: item.repairQuantity,
              ),
            ]
          : summary.items;
      final causeDrafts = phenomena
          .map(
            (entry) => _RepairCauseDraft(
              phenomenon: entry.phenomenon,
              quantity: entry.quantity,
            ),
          )
          .toList();
      var selectedTargetProcessId = processOptions.isNotEmpty
          ? processOptions.first.id
          : null;
      var scrapReplenished = false;
      var dialogError = '';
      final result = await showLockedFormDialog<_RepairCompleteDialogResult?>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('完成维修 - ${item.repairOrderCode}'),
            content: SizedBox(
              width: 680,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('送修数量：${item.repairQuantity}'),
                    const SizedBox(height: 12),
                    ...causeDrafts.map((draft) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(flex: 3, child: Text(draft.phenomenon)),
                            Expanded(
                              flex: 2,
                              child: Text('数量：${draft.quantity}'),
                            ),
                            Expanded(
                              flex: 4,
                              child: TextField(
                                controller: draft.reasonController,
                                decoration: const InputDecoration(
                                  labelText: '原因',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              children: [
                                Checkbox(
                                  value: draft.isScrap,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      draft.isScrap = value ?? false;
                                    });
                                  },
                                ),
                                const Text('报废'),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: scrapReplenished,
                          onChanged: (value) {
                            setDialogState(() {
                              scrapReplenished = value ?? false;
                            });
                          },
                        ),
                        const Text('报废已补充'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: selectedTargetProcessId,
                      decoration: const InputDecoration(
                        labelText: '回流目标工序（仅对非报废数量生效）',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: processOptions
                          .map(
                            (entry) => DropdownMenuItem<int>(
                              value: entry.id,
                              child: Text('${entry.code} ${entry.name}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedTargetProcessId = value;
                        });
                      },
                    ),
                    if (dialogError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          dialogError,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final causeItems = <RepairCauseItemInput>[];
                  var total = 0;
                  var scrapTotal = 0;
                  for (final draft in causeDrafts) {
                    final reason = draft.reasonController.text.trim();
                    if (reason.isEmpty) {
                      setDialogState(() {
                        dialogError = '请填写每条现象的维修原因';
                      });
                      return;
                    }
                    causeItems.add(
                      RepairCauseItemInput(
                        phenomenon: draft.phenomenon,
                        reason: reason,
                        quantity: draft.quantity,
                        isScrap: draft.isScrap,
                      ),
                    );
                    total += draft.quantity;
                    if (draft.isScrap) {
                      scrapTotal += draft.quantity;
                    }
                  }
                  if (total != item.repairQuantity) {
                    setDialogState(() {
                      dialogError = '原因数量合计必须等于送修数量 ${item.repairQuantity}';
                    });
                    return;
                  }
                  final repairedQuantity = item.repairQuantity - scrapTotal;
                  final allocations = <RepairReturnAllocationInput>[];
                  if (repairedQuantity > 0) {
                    if (selectedTargetProcessId == null) {
                      setDialogState(() {
                        dialogError = '存在可回流数量时必须选择回流目标工序';
                      });
                      return;
                    }
                    allocations.add(
                      RepairReturnAllocationInput(
                        targetOrderProcessId: selectedTargetProcessId!,
                        quantity: repairedQuantity,
                      ),
                    );
                  }
                  Navigator.of(context).pop(
                    _RepairCompleteDialogResult(
                      causeItems: causeItems,
                      scrapReplenished: scrapReplenished,
                      returnAllocations: allocations,
                    ),
                  );
                },
                child: const Text('提交完成'),
              ),
            ],
          ),
        ),
      );
      for (final draft in causeDrafts) {
        draft.dispose();
      }
      if (result == null) {
        return;
      }
      await _service.completeRepairOrder(
        repairOrderId: item.id,
        causeItems: result.causeItems,
        scrapReplenished: result.scrapReplenished,
        returnAllocations: result.returnAllocations,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('维修完成提交成功')));
      await _loadItems();
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
      ).showSnackBar(SnackBar(content: Text('维修完成失败：${_errorMessage(error)}')));
    } finally {
      if (mounted) {
        setState(() => _acting = false);
      }
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
                '维修订单',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loading ? null : _loadItems,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _keywordController,
                  decoration: const InputDecoration(
                    labelText: '关键词（维修单/订单/产品）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadItems(),
                ),
              ),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: '状态',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('全部')),
                    DropdownMenuItem(value: 'in_repair', child: Text('维修中')),
                    DropdownMenuItem(value: 'completed', child: Text('已完成')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _status = value;
                    });
                  },
                ),
              ),
              FilledButton.icon(
                onPressed: _loading ? null : _loadItems,
                icon: const Icon(Icons.search),
                label: const Text('查询'),
              ),
              FilledButton.tonalIcon(
                onPressed: (!widget.canExport || _exporting) ? null : _export,
                icon: const Icon(Icons.download),
                label: const Text('导出CSV'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('总数：$_total', style: theme.textTheme.titleMedium),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _message,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(child: Text('暂无维修订单'))
                : Card(
                    child: UnifiedListTableHeaderStyle.wrap(
                      theme: theme,
                      child: AdaptiveTableContainer(
                        child: DataTable(
                          columns: [
                            UnifiedListTableHeaderStyle.column(context, '维修单号'),
                            UnifiedListTableHeaderStyle.column(context, '订单号'),
                            UnifiedListTableHeaderStyle.column(context, '产品'),
                            UnifiedListTableHeaderStyle.column(context, '工序'),
                            UnifiedListTableHeaderStyle.column(context, '送修量'),
                            UnifiedListTableHeaderStyle.column(context, '报废量'),
                            UnifiedListTableHeaderStyle.column(context, '状态'),
                            UnifiedListTableHeaderStyle.column(context, '送修时间'),
                            UnifiedListTableHeaderStyle.column(context, '操作'),
                          ],
                          rows: _items
                              .map(
                                (item) => DataRow(
                                  cells: [
                                    DataCell(Text(item.repairOrderCode)),
                                    DataCell(Text(item.sourceOrderCode ?? '-')),
                                    DataCell(Text(item.productName ?? '-')),
                                    DataCell(Text(item.sourceProcessName)),
                                    DataCell(Text('${item.repairQuantity}')),
                                    DataCell(Text('${item.scrapQuantity}')),
                                    DataCell(
                                      Text(repairOrderStatusLabel(item.status)),
                                    ),
                                    DataCell(
                                      Text(_formatDateTime(item.repairTime)),
                                    ),
                                    DataCell(
                                      UnifiedListTableHeaderStyle.actionMenuButton<
                                        _RepairOrderAction
                                      >(
                                        theme: theme,
                                        onSelected: (action) {
                                          switch (action) {
                                            case _RepairOrderAction.summary:
                                              _showPhenomenaSummary(item);
                                              break;
                                            case _RepairOrderAction.complete:
                                              _showCompleteDialog(item);
                                              break;
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(
                                            value: _RepairOrderAction.summary,
                                            child: Text('现象汇总'),
                                          ),
                                          PopupMenuItem(
                                            value: _RepairOrderAction.complete,
                                            enabled:
                                                widget.canComplete &&
                                                item.status == 'in_repair' &&
                                                !_acting,
                                            child: const Text('完成维修'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
