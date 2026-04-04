import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/production_models.dart';
import '../services/api_exception.dart';
import '../services/production_service.dart';
import '../widgets/crud_list_table_section.dart';
import '../widgets/crud_page_header.dart';
import '../widgets/simple_pagination_bar.dart';
import '../widgets/unified_list_table_header_style.dart';

class ProductionAssistApprovalPage extends StatefulWidget {
  const ProductionAssistApprovalPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canReview,
    this.routePayloadJson,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canReview;
  final String? routePayloadJson;
  final ProductionService? service;

  @override
  State<ProductionAssistApprovalPage> createState() =>
      _ProductionAssistApprovalPageState();
}

class _ProductionAssistApprovalPageState
    extends State<ProductionAssistApprovalPage> {
  late final ProductionService _service;

  bool _loading = false;
  String _message = '';
  String? _statusFilter = 'pending';
  int _page = 1;
  int _total = 0;
  List<AssistAuthorizationItem> _items = const [];
  String? _lastHandledRoutePayloadJson;
  int? _pendingDetailAuthorizationId;

  static const int _pageSize = 200;

  final TextEditingController _orderCodeController = TextEditingController();
  final TextEditingController _processNameController = TextEditingController();
  final TextEditingController _requesterController = TextEditingController();
  final TextEditingController _helperController = TextEditingController();
  DateTime? _createdAtFrom;
  DateTime? _createdAtTo;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProductionService(widget.session);
    _loadRows();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeRoutePayload(widget.routePayloadJson);
    });
  }

  @override
  void didUpdateWidget(covariant ProductionAssistApprovalPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.routePayloadJson != oldWidget.routePayloadJson) {
      _consumeRoutePayload(widget.routePayloadJson);
    }
  }

  @override
  void dispose() {
    _orderCodeController.dispose();
    _processNameController.dispose();
    _requesterController.dispose();
    _helperController.dispose();
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

  Future<DateTime?> _pickDate(BuildContext ctx, DateTime? initial) =>
      showDatePicker(
        context: ctx,
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );

  String _formatDate(DateTime value) {
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

  int get _totalPages =>
      _total <= 0 ? 1 : ((_total + _pageSize - 1) ~/ _pageSize);

  void _showDetail(BuildContext context, AssistAuthorizationItem item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('代班申请详情'),
        content: SizedBox(
          width: 400,
          child: Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: FlexColumnWidth(),
            },
            children: [
              _detailRow('订单号', item.orderCode),
              _detailRow('工序', item.processName),
              _detailRow('目标操作员', item.targetOperatorUsername),
              _detailRow('发起人', item.requesterUsername),
              _detailRow('代班人', item.helperUsername),
              _detailRow('状态', assistAuthorizationStatusLabel(item.status)),
              _detailRow('申请原因', item.reason ?? '-'),
              _detailRow('审批人', item.reviewerUsername ?? '-'),
              _detailRow(
                '审批时间',
                item.reviewedAt != null
                    ? _formatDateTime(item.reviewedAt!)
                    : '-',
              ),
              _detailRow('审批备注', item.reviewRemark ?? '-'),
              _detailRow('创建时间', _formatDateTime(item.createdAt)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  TableRow _detailRow(String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Text(label, style: const TextStyle(color: Colors.grey)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Text(value),
        ),
      ],
    );
  }

  void _consumeRoutePayload(String? rawPayload) {
    if (!mounted ||
        rawPayload == null ||
        rawPayload.trim().isEmpty ||
        rawPayload == _lastHandledRoutePayloadJson) {
      return;
    }
    try {
      final payload = jsonDecode(rawPayload) as Map<String, dynamic>;
      final action = (payload['action'] as String? ?? '').trim();
      final rawAuthorizationId = payload['authorization_id'];
      final authorizationId = rawAuthorizationId is int
          ? rawAuthorizationId
          : int.tryParse('${rawAuthorizationId ?? ''}');
      if (action != 'detail' ||
          authorizationId == null ||
          authorizationId <= 0) {
        return;
      }
      _lastHandledRoutePayloadJson = rawPayload;
      _pendingDetailAuthorizationId = authorizationId;
      if (_statusFilter != null) {
        setState(() {
          _statusFilter = null;
        });
      }
      _loadRows(page: 1);
    } catch (_) {}
  }

  void _tryAutoOpenDetail() {
    final authorizationId = _pendingDetailAuthorizationId;
    if (authorizationId == null || !mounted) {
      return;
    }
    final matchedItem = _items
        .where((item) => item.id == authorizationId)
        .firstOrNull;
    if (matchedItem == null) {
      return;
    }
    _pendingDetailAuthorizationId = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _showDetail(context, matchedItem);
    });
  }

  Future<void> _reviewRow(AssistAuthorizationItem item, bool approve) async {
    var draftRemark = '';
    final reviewRemark = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? '审批通过' : '审批拒绝'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '代班申请：${item.orderCode} / ${item.processName}\n'
                '代班人：${item.helperUsername}',
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: '审批备注（可选）',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                onChanged: (value) {
                  draftRemark = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(draftRemark.trim()),
            child: Text(approve ? '通过' : '拒绝'),
          ),
        ],
      ),
    );
    if (reviewRemark == null || !mounted) return;
    try {
      await _service.reviewAssistAuthorization(
        authorizationId: item.id,
        approve: approve,
        reviewRemark: reviewRemark.isEmpty ? null : reviewRemark,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(approve ? '已审批通过。' : '已拒绝。')));
      await _loadRows();
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  Future<void> _loadRows({int? page}) async {
    final targetPage = page ?? _page;
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _service.listAssistAuthorizations(
        page: targetPage,
        pageSize: _pageSize,
        status: _statusFilter,
        orderCode: _orderCodeController.text.trim().isEmpty
            ? null
            : _orderCodeController.text.trim(),
        processName: _processNameController.text.trim().isEmpty
            ? null
            : _processNameController.text.trim(),
        requesterUsername: _requesterController.text.trim().isEmpty
            ? null
            : _requesterController.text.trim(),
        helperUsername: _helperController.text.trim().isEmpty
            ? null
            : _helperController.text.trim(),
        createdAtFrom: _createdAtFrom,
        createdAtTo: _createdAtTo,
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
        await _loadRows(page: totalPages);
        return;
      }
      setState(() {
        _page = targetPage;
        _items = result.items;
        _total = result.total;
      });
      _tryAutoOpenDetail();
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = _errorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
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
              Expanded(
                child: CrudPageHeader(
                  title: '代班记录',
                  onRefresh: _loading ? null : _loadRows,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  key: ValueKey<String?>(_statusFilter),
                  initialValue: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: '状态筛选',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('全部')),
                    DropdownMenuItem<String?>(
                      value: 'pending',
                      child: Text('待审批'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'approved',
                      child: Text('已审批'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'rejected',
                      child: Text('已拒绝'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'consumed',
                      child: Text('已消耗'),
                    ),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) {
                          if (value == _statusFilter) {
                            return;
                          }
                          setState(() {
                            _statusFilter = value;
                          });
                          _loadRows(page: 1);
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _orderCodeController,
                  decoration: const InputDecoration(
                    labelText: '订单号',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadRows(page: 1),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _processNameController,
                  decoration: const InputDecoration(
                    labelText: '工序名称',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadRows(page: 1),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _requesterController,
                  decoration: const InputDecoration(
                    labelText: '发起人',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadRows(page: 1),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _helperController,
                  decoration: const InputDecoration(
                    labelText: '代班人',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadRows(page: 1),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range, size: 16),
                label: Text(
                  '创建时间：${_createdAtFrom == null ? '不限' : _formatDate(_createdAtFrom!)} ~ ${_createdAtTo == null ? '不限' : _formatDate(_createdAtTo!)}',
                ),
                onPressed: () async {
                  final ctx = context;
                  final from = await _pickDate(ctx, _createdAtFrom);
                  if (from == null || !mounted) return;
                  // ignore: use_build_context_synchronously
                  final to = await _pickDate(ctx, _createdAtTo ?? from);
                  if (!mounted) return;
                  setState(() {
                    _createdAtFrom = from;
                    _createdAtTo = to;
                  });
                  _loadRows(page: 1);
                },
              ),
              if (_createdAtFrom != null || _createdAtTo != null) ...[
                const SizedBox(width: 4),
                TextButton.icon(
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('清除'),
                  onPressed: () {
                    setState(() {
                      _createdAtFrom = null;
                      _createdAtTo = null;
                    });
                    _loadRows(page: 1);
                  },
                ),
              ],
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _loading ? null : () => _loadRows(page: 1),
                icon: const Icon(Icons.search, size: 16),
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
          if (!widget.canReview)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '当前账号无查看权限。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          Expanded(
            child: CrudListTableSection(
              cardKey: const ValueKey('productionAssistApprovalListCard'),
              loading: _loading,
              isEmpty: _items.isEmpty,
              emptyText: '暂无代班记录',
              enableUnifiedHeaderStyle: true,
              child: DataTable(
                columns: [
                  UnifiedListTableHeaderStyle.column(context, '订单号'),
                  UnifiedListTableHeaderStyle.column(context, '工序'),
                  UnifiedListTableHeaderStyle.column(context, '目标操作员'),
                  UnifiedListTableHeaderStyle.column(context, '发起人'),
                  UnifiedListTableHeaderStyle.column(context, '代班人'),
                  UnifiedListTableHeaderStyle.column(context, '状态'),
                  UnifiedListTableHeaderStyle.column(context, '审批人'),
                  UnifiedListTableHeaderStyle.column(context, '审批时间'),
                  UnifiedListTableHeaderStyle.column(context, '创建时间'),
                  UnifiedListTableHeaderStyle.column(context, '操作'),
                ],
                rows: _items.map((item) {
                  final isPending = item.status == 'pending';
                  return DataRow(
                    cells: [
                      DataCell(Text(item.orderCode)),
                      DataCell(Text(item.processName)),
                      DataCell(Text(item.targetOperatorUsername)),
                      DataCell(Text(item.requesterUsername)),
                      DataCell(Text(item.helperUsername)),
                      DataCell(
                        Text(assistAuthorizationStatusLabel(item.status)),
                      ),
                      DataCell(Text(item.reviewerUsername ?? '-')),
                      DataCell(
                        Text(
                          item.reviewedAt != null
                              ? _formatDateTime(item.reviewedAt!)
                              : '-',
                        ),
                      ),
                      DataCell(Text(_formatDateTime(item.createdAt))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => _showDetail(context, item),
                              child: const Text('详情'),
                            ),
                            if (isPending && widget.canReview) ...[
                              const SizedBox(width: 4),
                              TextButton(
                                onPressed: () => _reviewRow(item, true),
                                child: const Text('通过'),
                              ),
                              const SizedBox(width: 4),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                ),
                                onPressed: () => _reviewRow(item, false),
                                child: const Text('拒绝'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SimplePaginationBar(
            page: _page,
            totalPages: _totalPages,
            total: _total,
            loading: _loading,
            onPrevious: () => _loadRows(page: _page - 1),
            onNext: () => _loadRows(page: _page + 1),
          ),
        ],
      ),
    );
  }
}
