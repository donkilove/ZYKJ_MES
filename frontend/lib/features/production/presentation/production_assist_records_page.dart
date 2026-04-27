import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/production/services/production_service.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';

class ProductionAssistRecordsPage extends StatefulWidget {
  const ProductionAssistRecordsPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canViewRecords,
    this.routePayloadJson,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canViewRecords;
  final String? routePayloadJson;
  final ProductionService? service;

  @override
  State<ProductionAssistRecordsPage> createState() =>
      _ProductionAssistRecordsPageState();
}

class _ProductionAssistRecordsPageState
    extends State<ProductionAssistRecordsPage> {
  late final ProductionService _service;

  bool _loading = false;
  String _message = '';
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
  void didUpdateWidget(covariant ProductionAssistRecordsPage oldWidget) {
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
      builder: (ctx) => MesDialog(
        title: const Text('代班记录详情'),
        width: 400,
        content: Table(
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
            _detailRow('处理人', item.reviewerUsername ?? '-'),
            _detailRow(
              '处理时间',
              item.reviewedAt != null
                  ? _formatDateTime(item.reviewedAt!)
                  : '-',
            ),
            _detailRow('处理备注', item.reviewRemark ?? '-'),
            _detailRow('创建时间', _formatDateTime(item.createdAt)),
          ],
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
    final filtersToolbar = Row(
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
    );

    final bannerWidgets = <Widget>[
      if (_message.isNotEmpty)
        Text(
          _message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      if (!widget.canViewRecords)
        Text(
          '当前账号无查看权限。',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
    ];

    return MesCrudPageScaffold(
      header: MesRefreshPageHeader(title: '代班记录', onRefresh: _loading ? null : _loadRows),
      filters: filtersToolbar,
      banner: bannerWidgets.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: bannerWidgets,
            ),
      content: CrudListTableSection(
        cardKey: const ValueKey('productionAssistRecordsListCard'),
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
            UnifiedListTableHeaderStyle.column(context, '处理人'),
            UnifiedListTableHeaderStyle.column(context, '处理时间'),
            UnifiedListTableHeaderStyle.column(context, '创建时间'),
            UnifiedListTableHeaderStyle.column(context, '操作'),
          ],
          rows: _items.map((item) {
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
        onPrevious: () => _loadRows(page: _page - 1),
        onNext: () => _loadRows(page: _page + 1),
      ),
    );
  }
}
