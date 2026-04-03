import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_session.dart';
import '../models/production_models.dart';
import '../services/api_exception.dart';
import '../services/production_service.dart';
import '../widgets/crud_list_table_section.dart';
import '../widgets/crud_page_header.dart';
import '../widgets/unified_list_table_header_style.dart';
import 'production_order_detail_page.dart';

class ProductionPipelineInstancesPage extends StatefulWidget {
  const ProductionPipelineInstancesPage({
    super.key,
    required this.session,
    required this.onLogout,
    this.orderId,
    this.orderCode,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;

  /// 从订单进入时传入，独立进入时为 null
  final int? orderId;
  final String? orderCode;
  final ProductionService? service;

  @override
  State<ProductionPipelineInstancesPage> createState() =>
      _ProductionPipelineInstancesPageState();
}

class _ProductionPipelineInstancesPageState
    extends State<ProductionPipelineInstancesPage> {
  late final ProductionService _service;

  bool _loading = false;
  String _message = '';
  int _total = 0;
  bool? _isActiveFilter;
  final _orderCodeController = TextEditingController();
  final _subOrderIdController = TextEditingController();
  final _processKeywordController = TextEditingController();
  final _pipelineSubOrderNoController = TextEditingController();
  List<PipelineInstanceItem> _items = const [];

  /// 独立进入模式（无固定订单）
  bool get _standaloneMode => widget.orderId == null;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProductionService(widget.session);
    if (!_standaloneMode) {
      _orderCodeController.text = widget.orderCode ?? '';
    }
    _load();
  }

  @override
  void dispose() {
    _orderCodeController.dispose();
    _subOrderIdController.dispose();
    _processKeywordController.dispose();
    _pipelineSubOrderNoController.dispose();
    super.dispose();
  }

  bool _isUnauthorized(Object error) =>
      error is ApiException && error.statusCode == 401;

  String _errorMessage(Object error) =>
      error is ApiException ? error.message : error.toString();

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }

  String _pipelineLinkLabel(PipelineInstanceItem item) {
    final linkId = item.pipelineLinkId?.trim() ?? '';
    if (linkId.isEmpty) {
      return '未生成';
    }
    return '链路 $linkId';
  }

  String _pipelineGroupKey(PipelineInstanceItem item) {
    final linkId = item.pipelineLinkId?.trim() ?? '';
    if (linkId.isNotEmpty) {
      return linkId;
    }
    return 'unlinked-${item.id}';
  }

  Future<void> _openOrderDetail(
    PipelineInstanceItem item, {
    int initialTabIndex = 0,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProductionOrderDetailPage(
          session: widget.session,
          onLogout: widget.onLogout,
          orderId: item.orderId,
          canEditOrder: false,
          canDeleteOrder: false,
          canCompleteOrder: false,
          canUpdatePipelineMode: false,
          readOnly: true,
          initialTabIndex: initialTabIndex,
          service: _service,
          onEditOrder: (_) async => false,
          onDeleteOrder: (_) async => false,
          onCompleteOrder: (_) async => false,
          onConfigurePipelineOrder: (_) async => false,
          onDisablePipelineOrder: (_) async => false,
        ),
      ),
    );
  }

  Future<void> _load() async {
    final rawSubOrderId = _subOrderIdController.text.trim();
    int? subOrderId;
    if (rawSubOrderId.isNotEmpty) {
      subOrderId = int.tryParse(rawSubOrderId);
      if (subOrderId == null || subOrderId <= 0) {
        setState(() {
          _loading = false;
          _message = '子订单ID必须为大于 0 的数字';
        });
        return;
      }
    }
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _service.listPipelineInstances(
        orderId: widget.orderId,
        orderCode: _standaloneMode ? _orderCodeController.text : null,
        subOrderId: subOrderId,
        processKeyword: _processKeywordController.text,
        pipelineSubOrderNo: _pipelineSubOrderNoController.text,
        isActive: _isActiveFilter,
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
      setState(() {
        _message = _errorMessage(error);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copyOrderCode(PipelineInstanceItem item) {
    Clipboard.setData(ClipboardData(text: item.orderCode));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已复制订单号：${item.orderCode}')));
  }

  Widget _buildTraceGroupCard(
    BuildContext context,
    ThemeData theme,
    String groupKey,
    List<PipelineInstanceItem> items,
  ) {
    final representative = items.first;
    final hasLinkId =
        (representative.pipelineLinkId?.trim().isNotEmpty ?? false);
    final activeCount = items.where((item) => item.isActive).length;
    final processSummary = items
        .map((item) => item.processDisplayText)
        .toSet()
        .join(' -> ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  avatar: const Icon(Icons.account_tree_outlined, size: 18),
                  label: Text(hasLinkId ? '链路 $groupKey' : '未生成链路标识'),
                ),
                Chip(label: Text('实例 ${items.length}')),
                Chip(label: Text('活跃 $activeCount/${items.length}')),
                Text(
                  '订单：${representative.orderCode}',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('跨工序路径：$processSummary', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            ...items.map((item) {
              final statusText = item.isActive ? '活跃' : '已失效';
              final invalidText = item.invalidReason?.trim().isNotEmpty == true
                  ? '，原因：${item.invalidReason}'
                  : '';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(child: Text('${item.pipelineSeq}')),
                  title: Text(item.processDisplayText),
                  subtitle: Text(
                    '子订单ID ${item.subOrderId} ｜ 实例 ${item.pipelineSubOrderNo}\n'
                    '状态：$statusText$invalidText',
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => _openOrderDetail(item),
                        child: const Text('查看订单'),
                      ),
                      TextButton(
                        onPressed: () =>
                            _openOrderDetail(item, initialTabIndex: 3),
                        child: const Text('查看事件日志'),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTraceView(ThemeData theme) {
    final groupedItems = <String, List<PipelineInstanceItem>>{};
    for (final item in _items) {
      final key = _pipelineGroupKey(item);
      groupedItems.putIfAbsent(key, () => <PipelineInstanceItem>[]).add(item);
    }
    final entries = groupedItems.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in entries) {
      entry.value.sort((a, b) {
        final seqCompare = a.pipelineSeq.compareTo(b.pipelineSeq);
        if (seqCompare != 0) {
          return seqCompare;
        }
        final processCompare = a.processDisplayText.compareTo(
          b.processDisplayText,
        );
        if (processCompare != 0) {
          return processCompare;
        }
        return a.id.compareTo(b.id);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('链路追踪视图', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          '按 pipeline_link_id 聚合同链路实例，可直接跳转到订单详情事件日志。',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        ...entries.map(
          (entry) =>
              _buildTraceGroupCard(context, theme, entry.key, entry.value),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        if (_standaloneMode) ...[
          SizedBox(
            width: 200,
            child: TextField(
              controller: _orderCodeController,
              decoration: const InputDecoration(
                labelText: '订单号',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
        ],
        SizedBox(
          width: 180,
          child: TextField(
            controller: _subOrderIdController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '子订单ID',
              hintText: '精确匹配',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _load(),
          ),
        ),
        SizedBox(
          width: 220,
          child: TextField(
            controller: _processKeywordController,
            decoration: const InputDecoration(
              labelText: '工序',
              hintText: '工序编码或名称',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _load(),
          ),
        ),
        SizedBox(
          width: 180,
          child: TextField(
            controller: _pipelineSubOrderNoController,
            decoration: const InputDecoration(
              labelText: '实例编号',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _load(),
          ),
        ),
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<bool?>(
            key: ValueKey<bool?>(_isActiveFilter),
            initialValue: _isActiveFilter,
            decoration: const InputDecoration(
              labelText: '状态',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem<bool?>(value: null, child: Text('全部')),
              DropdownMenuItem<bool?>(value: true, child: Text('活跃')),
              DropdownMenuItem<bool?>(value: false, child: Text('已失效')),
            ],
            onChanged: _loading
                ? null
                : (value) {
                    setState(() => _isActiveFilter = value);
                    _load();
                  },
          ),
        ),
        IconButton(
          tooltip: '查询',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.search),
        ),
        IconButton(
          tooltip: '刷新',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _standaloneMode ? '并行实例追踪' : '并行实例 - ${widget.orderCode}';

    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_standaloneMode) ...[
            CrudPageHeader(title: title, onRefresh: _loading ? null : _load),
            const SizedBox(height: 12),
          ],
          _buildFilterBar(),
          const SizedBox(height: 12),
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
                ? const Center(child: Text('暂无并行实例记录'))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final tableHeight = constraints.maxHeight.isFinite
                          ? constraints.maxHeight * 0.45
                          : 420.0;
                      return ListView(
                        children: [
                          _buildTraceView(theme),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: tableHeight < 320 ? 320 : tableHeight,
                            child: CrudListTableSection(
                              loading: false,
                              isEmpty: _items.isEmpty,
                              emptyText: '暂无并行实例记录',
                              enableUnifiedHeaderStyle: true,
                              child: DataTable(
                                columns: [
                                  UnifiedListTableHeaderStyle.column(
                                    context,
                                    'ID',
                                  ),
                                  UnifiedListTableHeaderStyle.column(
                                    context,
                                    '子订单ID',
                                  ),
                                  if (_standaloneMode)
                                    UnifiedListTableHeaderStyle.column(
                                      context,
                                      '订单号',
                                    ),
                                  UnifiedListTableHeaderStyle.column(
                                    context,
                                    '工序',
                                  ),
                                  UnifiedListTableHeaderStyle.column(
                                    context,
                                    '跨工序链路',
                                  ),
                                  UnifiedListTableHeaderStyle.column(
                                    context,
                                    '并行序号',
                                  ),
                                  UnifiedListTableHeaderStyle.column(
                                    context,
                                    '实例编号',
                                  ),
                                  UnifiedListTableHeaderStyle.column(
                                    context,
                                    '状态',
                                  ),
                                  UnifiedListTableHeaderStyle.column(
                                    context,
                                    '失效原因',
                                  ),
                                  UnifiedListTableHeaderStyle.column(
                                    context,
                                    '失效时间',
                                  ),
                                  UnifiedListTableHeaderStyle.column(
                                    context,
                                    '创建时间',
                                  ),
                                  UnifiedListTableHeaderStyle.column(
                                    context,
                                    '更新时间',
                                  ),
                                  if (_standaloneMode)
                                    UnifiedListTableHeaderStyle.column(
                                      context,
                                      '操作',
                                    ),
                                ],
                                rows: _items.map((item) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text('${item.id}')),
                                      DataCell(Text('${item.subOrderId}')),
                                      if (_standaloneMode)
                                        DataCell(Text(item.orderCode)),
                                      DataCell(Text(item.processDisplayText)),
                                      DataCell(
                                        Tooltip(
                                          message:
                                              item.pipelineLinkId ??
                                              '未生成跨工序链路标识',
                                          child: SelectableText(
                                            _pipelineLinkLabel(item),
                                          ),
                                        ),
                                      ),
                                      DataCell(Text('${item.pipelineSeq}')),
                                      DataCell(Text(item.pipelineSubOrderNo)),
                                      DataCell(
                                        Text(item.isActive ? '活跃' : '已失效'),
                                      ),
                                      DataCell(Text(item.invalidReason ?? '-')),
                                      DataCell(
                                        Text(
                                          item.invalidatedAt != null
                                              ? _formatDateTime(
                                                  item.invalidatedAt!,
                                                )
                                              : '-',
                                        ),
                                      ),
                                      DataCell(
                                        Text(_formatDateTime(item.createdAt)),
                                      ),
                                      DataCell(
                                        Text(_formatDateTime(item.updatedAt)),
                                      ),
                                      if (_standaloneMode)
                                        DataCell(
                                          Wrap(
                                            spacing: 8,
                                            children: [
                                              TextButton(
                                                onPressed: () =>
                                                    _openOrderDetail(item),
                                                child: const Text('查看订单'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    _openOrderDetail(
                                                      item,
                                                      initialTabIndex: 3,
                                                    ),
                                                child: const Text('查看事件日志'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    _copyOrderCode(item),
                                                child: const Text('复制订单号'),
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
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );

    // 从订单进入时用 Scaffold 包裹（保留返回按钮），独立进入时直接返回内容
    if (!_standaloneMode) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: body,
      );
    }
    return body;
  }
}
