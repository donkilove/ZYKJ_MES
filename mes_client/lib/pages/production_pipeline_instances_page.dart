import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_session.dart';
import '../models/production_models.dart';
import '../services/api_exception.dart';
import '../services/production_service.dart';
import '../widgets/adaptive_table_container.dart';

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _service.listPipelineInstances(
        orderId: widget.orderId,
        orderCode: _standaloneMode ? _orderCodeController.text : null,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制订单号：${item.orderCode}')),
    );
  }

  Widget _buildFilterBar() {
    return Row(
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
          const SizedBox(width: 12),
        ],
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
        const SizedBox(width: 12),
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
    final title = _standaloneMode
        ? '并行实例追踪'
        : '并行实例 - ${widget.orderCode}';

    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                : Card(
                    child: AdaptiveTableContainer(
                      child: DataTable(
                        columns: [
                          const DataColumn(label: Text('ID')),
                          if (_standaloneMode)
                            const DataColumn(label: Text('订单号')),
                          const DataColumn(label: Text('工序编码')),
                          const DataColumn(label: Text('并行序号')),
                          const DataColumn(label: Text('子订单编号')),
                          const DataColumn(label: Text('状态')),
                          const DataColumn(label: Text('失效原因')),
                          const DataColumn(label: Text('失效时间')),
                          const DataColumn(label: Text('创建时间')),
                          if (_standaloneMode)
                            const DataColumn(label: Text('操作')),
                        ],
                        rows: _items.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(Text('${item.id}')),
                              if (_standaloneMode)
                                DataCell(Text(item.orderCode)),
                              DataCell(Text(item.processCode)),
                              DataCell(Text('${item.pipelineSeq}')),
                              DataCell(Text(item.pipelineSubOrderNo)),
                              DataCell(
                                Text(item.isActive ? '活跃' : '已失效'),
                              ),
                              DataCell(Text(item.invalidReason ?? '-')),
                              DataCell(
                                Text(
                                  item.invalidatedAt != null
                                      ? _formatDateTime(item.invalidatedAt!)
                                      : '-',
                                ),
                              ),
                              DataCell(Text(_formatDateTime(item.createdAt))),
                              if (_standaloneMode)
                                DataCell(
                                  TextButton(
                                    onPressed: () => _copyOrderCode(item),
                                    child: const Text('复制订单号'),
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
