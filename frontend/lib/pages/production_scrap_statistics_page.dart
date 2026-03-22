import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/production_models.dart';
import 'production_scrap_statistics_detail_page.dart';
import '../services/api_exception.dart';
import '../services/production_service.dart';
import '../widgets/adaptive_table_container.dart';
import '../widgets/unified_list_table_header_style.dart';

class ProductionScrapStatisticsPage extends StatefulWidget {
  const ProductionScrapStatisticsPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canExport,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canExport;
  final ProductionService? service;

  @override
  State<ProductionScrapStatisticsPage> createState() =>
      _ProductionScrapStatisticsPageState();
}

class _ProductionScrapStatisticsPageState
    extends State<ProductionScrapStatisticsPage> {
  late final ProductionService _service;
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _processCodeController = TextEditingController();

  bool _loading = false;
  bool _exporting = false;
  String _message = '';
  String _progress = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  int _total = 0;
  List<ScrapStatisticsItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProductionService(widget.session);
    _loadItems();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _productNameController.dispose();
    _processCodeController.dispose();
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

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
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

  Future<void> _pickDate({required bool isStart}) async {
    final initial =
        (isStart ? _startDate : _endDate) ?? DateTime.now().toLocal();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      initialDate: initial,
      helpText: isStart ? '选择开始日期' : '选择结束日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _loadItems() async {
    if (_startDate != null &&
        _endDate != null &&
        _startDate!.isAfter(_endDate!)) {
      setState(() {
        _message = '开始日期不能晚于结束日期';
      });
      return;
    }
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _service.getScrapStatistics(
        page: 1,
        pageSize: 200,
        keyword: _keywordController.text.trim(),
        productName: _productNameController.text.trim(),
        processCode: _processCodeController.text.trim(),
        progress: _progress,
        startDate: _startDate,
        endDate: _endDate,
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
        _message = '加载报废统计失败：${_errorMessage(error)}';
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
      ).showSnackBar(const SnackBar(content: Text('当前账号无导出权限')));
      return;
    }
    if (_startDate != null &&
        _endDate != null &&
        _startDate!.isAfter(_endDate!)) {
      setState(() {
        _message = '开始日期不能晚于结束日期';
      });
      return;
    }
    setState(() {
      _exporting = true;
      _message = '';
    });
    try {
      final result = await _service.exportScrapStatistics(
        keyword: _keywordController.text.trim().isEmpty
            ? null
            : _keywordController.text.trim(),
        productName: _productNameController.text.trim().isEmpty
            ? null
            : _productNameController.text.trim(),
        processCode: _processCodeController.text.trim().isEmpty
            ? null
            : _processCodeController.text.trim(),
        progress: _progress,
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
      await _loadItems();
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

  Future<void> _showDetail(ScrapStatisticsItem item) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductionScrapStatisticsDetailPage(
          session: widget.session,
          onLogout: widget.onLogout,
          scrapId: item.id,
          orderCode: item.orderCode,
          service: _service,
        ),
      ),
    );
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
                '报废统计',
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
            runSpacing: 8,
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _keywordController,
                  decoration: const InputDecoration(
                    labelText: '关键词（订单/原因）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadItems(),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _productNameController,
                  decoration: const InputDecoration(
                    labelText: '产品名称（精确）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadItems(),
                ),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _processCodeController,
                  decoration: const InputDecoration(
                    labelText: '工序编码（精确）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadItems(),
                ),
              ),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<String>(
                  initialValue: _progress,
                  decoration: const InputDecoration(
                    labelText: '进度',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('全部')),
                    DropdownMenuItem(
                      value: 'pending_apply',
                      child: Text('待处理'),
                    ),
                    DropdownMenuItem(value: 'applied', child: Text('已处理')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _progress = value;
                    });
                  },
                ),
              ),
              OutlinedButton(
                onPressed: _loading ? null : () => _pickDate(isStart: true),
                child: Text(
                  _startDate == null ? '开始日期' : _formatDate(_startDate!),
                ),
              ),
              OutlinedButton(
                onPressed: _loading ? null : () => _pickDate(isStart: false),
                child: Text(_endDate == null ? '结束日期' : _formatDate(_endDate!)),
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
                ? const Center(child: Text('暂无报废统计数据'))
                : Card(
                    child: UnifiedListTableHeaderStyle.wrap(
                      theme: theme,
                      child: AdaptiveTableContainer(
                        child: DataTable(
                          columns: [
                            UnifiedListTableHeaderStyle.column(context, '订单号'),
                            UnifiedListTableHeaderStyle.column(context, '产品'),
                            UnifiedListTableHeaderStyle.column(context, '工序'),
                            UnifiedListTableHeaderStyle.column(context, '报废原因'),
                            UnifiedListTableHeaderStyle.column(context, '数量'),
                            UnifiedListTableHeaderStyle.column(context, '进度'),
                            UnifiedListTableHeaderStyle.column(
                              context,
                              '最近报废时间',
                            ),
                            UnifiedListTableHeaderStyle.column(context, '处理时间'),
                            UnifiedListTableHeaderStyle.column(context, '操作'),
                          ],
                          rows: _items
                              .map(
                                (item) => DataRow(
                                  cells: [
                                    DataCell(Text(item.orderCode ?? '-')),
                                    DataCell(Text(item.productName ?? '-')),
                                    DataCell(Text(item.processName ?? '-')),
                                    DataCell(Text(item.scrapReason)),
                                    DataCell(Text('${item.scrapQuantity}')),
                                    DataCell(
                                      Text(scrapProgressLabel(item.progress)),
                                    ),
                                    DataCell(
                                      Text(_formatDateTime(item.lastScrapTime)),
                                    ),
                                    DataCell(
                                      Text(_formatDateTime(item.appliedAt)),
                                    ),
                                    DataCell(
                                      TextButton(
                                        onPressed: () => _showDetail(item),
                                        child: const Text('详情'),
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
