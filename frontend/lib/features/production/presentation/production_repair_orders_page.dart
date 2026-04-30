import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/production/presentation/production_repair_order_detail_page.dart';
import 'package:mes_client/features/production/presentation/widgets/production_repair_complete_dialog.dart';
import 'package:mes_client/features/production/presentation/widgets/production_repair_phenomena_summary_dialog.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/production/services/production_service.dart';
import 'package:mes_client/features/quality/services/repair_scrap_service.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';

enum _RepairOrderAction { detail, summary, complete }

class ProductionRepairOrdersPage extends StatefulWidget {
  const ProductionRepairOrdersPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canComplete,
    required this.canExport,
    this.jumpPayloadJson,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canComplete;
  final bool canExport;
  final String? jumpPayloadJson;
  final RepairScrapService? service;

  @override
  State<ProductionRepairOrdersPage> createState() =>
      _ProductionRepairOrdersPageState();
}

class _ProductionRepairOrdersPageState
    extends State<ProductionRepairOrdersPage> {
  late final RepairScrapService _service;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  bool _exporting = false;
  bool _acting = false;
  String _message = '';
  String _status = 'all';
  int _page = 1;
  DateTime? _startDate;
  DateTime? _endDate;
  int _total = 0;
  List<RepairOrderItem> _items = const [];
  String? _lastHandledJumpPayloadJson;

  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProductionService(widget.session);
    _loadItems();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeJumpPayload(widget.jumpPayloadJson);
    });
  }

  @override
  void didUpdateWidget(covariant ProductionRepairOrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.jumpPayloadJson != oldWidget.jumpPayloadJson) {
      _consumeJumpPayload(widget.jumpPayloadJson);
    }
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

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now())
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
      _page = 1;
    });
  }

  Future<void> _showRepairDetail(RepairOrderItem item) async {
    await _showRepairDetailById(
      repairOrderId: item.id,
      repairOrderCode: item.repairOrderCode,
    );
  }

  Future<void> _showRepairDetailById({
    required int repairOrderId,
    String? repairOrderCode,
  }) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductionRepairOrderDetailPage(
          session: widget.session,
          onLogout: widget.onLogout,
          repairOrderId: repairOrderId,
          repairOrderCode: repairOrderCode,
          service: _service,
        ),
      ),
    );
  }

  void _consumeJumpPayload(String? rawPayload) {
    if (!mounted ||
        rawPayload == null ||
        rawPayload.trim().isEmpty ||
        rawPayload == _lastHandledJumpPayloadJson) {
      return;
    }
    try {
      final payload = jsonDecode(rawPayload) as Map<String, dynamic>;
      final action = (payload['action'] as String? ?? '').trim();
      final rawRepairOrderId = payload['repair_order_id'];
      final repairOrderId = rawRepairOrderId is int
          ? rawRepairOrderId
          : int.tryParse('${rawRepairOrderId ?? ''}');
      if (action != 'detail' || repairOrderId == null || repairOrderId <= 0) {
        return;
      }
      _lastHandledJumpPayloadJson = rawPayload;
      final repairOrderCode = payload['repair_order_code'] as String?;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _showRepairDetailById(
          repairOrderId: repairOrderId,
          repairOrderCode: repairOrderCode,
        );
      });
    } catch (error) {
      _lastHandledJumpPayloadJson = rawPayload;
      if (mounted) {
        setState(() {
          _message = '跳转参数解析失败：${_errorMessage(error)}';
        });
      }
    }
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

  int get _totalPages =>
      _total <= 0 ? 1 : ((_total + _pageSize - 1) ~/ _pageSize);

  Future<void> _loadItems({int? page}) async {
    final targetPage = page ?? _page;
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _service.getRepairOrders(
        page: targetPage,
        pageSize: _pageSize,
        keyword: _keywordController.text.trim(),
        status: _status,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) {
        return;
      }
      final totalPages = result.total <= 0
          ? 1
          : ((result.total + _pageSize - 1) ~/ _pageSize);
      if (result.total > 0 && targetPage > totalPages) {
        setState(() {
          _page = totalPages;
          _total = result.total;
          _items = const [];
        });
        await _loadItems(page: totalPages);
        return;
      }
      setState(() {
        _page = targetPage;
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
        startDate: _startDate,
        endDate: _endDate,
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
        builder: (context) => ProductionRepairPhenomenaSummaryDialog(
          repairOrderCode: item.repairOrderCode,
          items: result.items,
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

  Future<List<ProductionRepairReturnProcessOption>> _loadReturnProcessOptions(
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
          (row) => ProductionRepairReturnProcessOption(
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
      final result = await showProductionRepairCompleteDialog(
        context: context,
        repairOrder: item,
        phenomena: phenomena,
        processOptions: processOptions,
      );
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
    final filtersToolbar = Wrap(
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
            onSubmitted: (_) => _loadItems(page: 1),
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
              if (value == null) return;
              setState(() {
                _status = value;
                _page = 1;
              });
            },
          ),
        ),
        OutlinedButton(
          onPressed: _loading ? null : () => _pickDate(isStart: true),
          child: Text(_startDate == null ? '开始日期' : _formatDate(_startDate!)),
        ),
        OutlinedButton(
          onPressed: _loading ? null : () => _pickDate(isStart: false),
          child: Text(_endDate == null ? '结束日期' : _formatDate(_endDate!)),
        ),
        FilledButton.icon(
          onPressed: _loading ? null : () => _loadItems(page: 1),
          icon: const Icon(Icons.search),
          label: const Text('查询'),
        ),
        FilledButton.tonalIcon(
          onPressed: (!widget.canExport || _exporting) ? null : _export,
          icon: const Icon(Icons.download),
          label: const Text('导出CSV'),
        ),
      ],
    );

    return MesCrudPageScaffold(
      header: MesRefreshPageHeader(
        title: '维修订单',
        onRefresh: _loading ? null : _loadItems,
      ),
      filters: filtersToolbar,
      banner: _message.isEmpty
          ? null
          : Text(_message, style: TextStyle(color: theme.colorScheme.error)),
      content: CrudListTableSection(
        cardKey: const ValueKey('productionRepairOrdersListCard'),
        loading: _loading,
        isEmpty: _items.isEmpty,
        emptyText: '暂无维修订单',
        enableUnifiedHeaderStyle: true,
        child: DataTable(
          columns: [
            UnifiedListTableHeaderStyle.column(context, '维修单号'),
            UnifiedListTableHeaderStyle.column(context, '订单号'),
            UnifiedListTableHeaderStyle.column(context, '产品'),
            UnifiedListTableHeaderStyle.column(context, '工序'),
            UnifiedListTableHeaderStyle.column(context, '送修量'),
            UnifiedListTableHeaderStyle.column(context, '已修复量'),
            UnifiedListTableHeaderStyle.column(context, '补投产'),
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
                    DataCell(Text('${item.repairedQuantity}')),
                    DataCell(Text(item.scrapReplenished ? '是' : '否')),
                    DataCell(Text('${item.scrapQuantity}')),
                    DataCell(Text(repairOrderStatusLabel(item.status))),
                    DataCell(Text(_formatDateTime(item.repairTime))),
                    DataCell(
                      UnifiedListTableHeaderStyle.actionMenuButton<
                        _RepairOrderAction
                      >(
                        theme: theme,
                        onSelected: (action) {
                          switch (action) {
                            case _RepairOrderAction.detail:
                              _showRepairDetail(item);
                              break;
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
                            value: _RepairOrderAction.detail,
                            child: Text('查看详情'),
                          ),
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
      pagination: MesPaginationBar(
        page: _page,
        totalPages: _totalPages,
        total: _total,
        loading: _loading,
        onPrevious: () => _loadItems(page: _page - 1),
        onNext: () => _loadItems(page: _page + 1),
      ),
    );
  }
}
