import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/quality_models.dart';
import '../services/api_exception.dart';
import '../services/quality_service.dart';
import '../widgets/adaptive_table_container.dart';
import 'first_article_disposition_page.dart';

class DailyFirstArticlePage extends StatefulWidget {
  const DailyFirstArticlePage({
    super.key,
    required this.session,
    required this.onLogout,
    this.canExport = false,
    this.canDispose = false,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canExport;
  final bool canDispose;

  @override
  State<DailyFirstArticlePage> createState() => _DailyFirstArticlePageState();
}

class _DailyFirstArticlePageState extends State<DailyFirstArticlePage> {
  static const int _pageSize = 20;

  late final QualityService _service;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  bool _exporting = false;
  String _message = '';
  DateTime _queryDate = DateTime.now();
  String? _resultFilter;
  int _page = 1;
  int _total = 0;
  String? _verificationCode;
  String _verificationCodeSource = 'none';
  List<FirstArticleListItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _service = QualityService(widget.session);
    _loadFirstArticles();
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

  int get _totalPages {
    if (_total <= 0) {
      return 1;
    }
    return ((_total - 1) ~/ _pageSize) + 1;
  }

  Future<void> _loadFirstArticles({int? page}) async {
    final targetPage = page ?? _page;
    setState(() {
      _loading = true;
      _message = '';
      _page = targetPage;
    });
    try {
      final result = await _service.listFirstArticles(
        date: _queryDate,
        keyword: _keywordController.text.trim(),
        result: _resultFilter,
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted) {
        return;
      }

      var resolvedPage = _page;
      final resolvedTotalPages = result.total <= 0
          ? 1
          : (((result.total - 1) ~/ _pageSize) + 1);
      if (resolvedPage > resolvedTotalPages) {
        resolvedPage = resolvedTotalPages;
      }

      setState(() {
        _queryDate = result.queryDate;
        _verificationCode = result.verificationCode;
        _verificationCodeSource = result.verificationCodeSource;
        _total = result.total;
        _items = result.items;
        _page = resolvedPage;
      });

      if (resolvedPage != targetPage) {
        await _loadFirstArticles(page: resolvedPage);
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
        _message = '加载每日首件失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickQueryDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      initialDate: _queryDate,
      helpText: '选择查询日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _queryDate = picked;
      _page = 1;
    });
    await _loadFirstArticles(page: 1);
  }

  Future<void> _exportCsv() async {
    setState(() {
      _exporting = true;
      _message = '';
    });
    try {
      final csvBase64 = await _service.exportFirstArticles(
        date: _queryDate,
        keyword: _keywordController.text.trim(),
        result: _resultFilter,
      );
      if (!mounted) return;
      if (csvBase64.isEmpty) {
        setState(() {
          _message = '导出失败：服务端返回空数据';
        });
        return;
      }
      _showExportDialog(csvBase64);
    } catch (error) {
      if (!mounted) return;
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

  void _showExportDialog(String csvBase64) {
    final csvText = utf8.decode(base64Decode(csvBase64));
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导出首件记录'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              csvText,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
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

  Future<void> _showDetailDialog(FirstArticleListItem item) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FirstArticleDetailDialog(
        session: widget.session,
        recordId: item.id,
        canDispose: widget.canDispose,
        onLogout: widget.onLogout,
        onDisposed: () {
          Navigator.of(ctx).pop();
          _loadFirstArticles();
        },
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
                '每日首件',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (widget.canExport)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OutlinedButton.icon(
                    onPressed: (_loading || _exporting) ? null : _exportCsv,
                    icon: const Icon(Icons.download),
                    label: const Text('导出'),
                  ),
                ),
              IconButton(
                tooltip: '刷新',
                onPressed: _loading ? null : _loadFirstArticles,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _loading ? null : _pickQueryDate,
                icon: const Icon(Icons.calendar_month),
                label: Text('查询日期：${_formatDate(_queryDate)}'),
              ),
              const SizedBox(width: 12),
              DropdownButton<String?>(
                value: _resultFilter,
                hint: const Text('全部结果'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('全部结果')),
                  DropdownMenuItem(value: 'pass', child: Text('合格')),
                  DropdownMenuItem(value: 'fail', child: Text('不合格')),
                  DropdownMenuItem(value: 'conditional', child: Text('条件放行')),
                ],
                onChanged: _loading
                    ? null
                    : (v) {
                        setState(() {
                          _resultFilter = v;
                          _page = 1;
                        });
                        _loadFirstArticles(page: 1);
                      },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _keywordController,
                  decoration: const InputDecoration(
                    labelText: '搜索订单号/产品/工序/操作员',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _loadFirstArticles(page: 1),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loading ? null : () => _loadFirstArticles(page: 1),
                icon: const Icon(Icons.search),
                label: const Text('查询'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text('查询日期：${_formatDate(_queryDate)}'),
                  Text('当日校验码：${_verificationCode ?? '-'}'),
                  Text(
                    '来源：${verificationCodeSourceLabel(_verificationCodeSource)}',
                  ),
                  Text('总数：$_total'),
                ],
              ),
            ),
          ),
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
                ? const Center(child: Text('暂无首件记录。'))
                : Column(
                    children: [
                      Expanded(
                        child: Card(
                          child: AdaptiveTableContainer(
                            child: DataTable(
                              columns: [
                                const DataColumn(label: Text('提交时间')),
                                const DataColumn(label: Text('订单号')),
                                const DataColumn(label: Text('产品')),
                                const DataColumn(label: Text('工序')),
                                const DataColumn(label: Text('操作员')),
                                const DataColumn(label: Text('结果')),
                                const DataColumn(label: Text('校验日期')),
                                const DataColumn(label: Text('备注')),
                                if (widget.canDispose)
                                  const DataColumn(label: Text('操作')),
                              ],
                              rows: _items.map((item) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(_formatDateTime(item.createdAt)),
                                    ),
                                    DataCell(Text(item.orderCode)),
                                    DataCell(Text(item.productName)),
                                    DataCell(
                                      Text(
                                        '${item.processName} (${item.processCode})',
                                      ),
                                    ),
                                    DataCell(Text(item.operatorUsername)),
                                    DataCell(
                                      Text(
                                        firstArticleResultLabel(item.result),
                                      ),
                                    ),
                                    DataCell(
                                      Text(_formatDate(item.verificationDate)),
                                    ),
                                    DataCell(Text(item.remark ?? '-')),
                                    if (widget.canDispose)
                                      DataCell(
                                        TextButton(
                                          onPressed: () =>
                                              _showDetailDialog(item),
                                          child: const Text('详情/处置'),
                                        ),
                                      ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('第 $_page / $_totalPages 页'),
                          const SizedBox(width: 12),
                          Text('总数：$_total'),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: _loading || _page <= 1
                                ? null
                                : () => _loadFirstArticles(page: _page - 1),
                            icon: const Icon(Icons.chevron_left),
                            label: const Text('上一页'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: _loading || _page >= _totalPages
                                ? null
                                : () => _loadFirstArticles(page: _page + 1),
                            icon: const Icon(Icons.chevron_right),
                            label: const Text('下一页'),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
