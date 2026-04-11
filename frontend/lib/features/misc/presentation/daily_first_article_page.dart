import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/services/export_file_service.dart';
import 'package:mes_client/features/quality/services/quality_service.dart';
import 'package:mes_client/core/widgets/adaptive_table_container.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/widgets/crud_page_header.dart';
import 'package:mes_client/core/widgets/simple_pagination_bar.dart';
import 'package:mes_client/features/misc/presentation/first_article_disposition_page.dart';

class DailyFirstArticlePage extends StatefulWidget {
  const DailyFirstArticlePage({
    super.key,
    required this.session,
    required this.onLogout,
    this.canViewDetail = false,
    this.canExport = false,
    this.canDispose = false,
    this.routePayloadJson,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canViewDetail;
  final bool canExport;
  final bool canDispose;
  final String? routePayloadJson;
  final QualityService? service;

  @override
  State<DailyFirstArticlePage> createState() => _DailyFirstArticlePageState();
}

class _DailyFirstArticlePageState extends State<DailyFirstArticlePage> {
  static const int _pageSize = 30;

  late final QualityService _service;
  final ExportFileService _exportFileService = const ExportFileService();
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _processCodeController = TextEditingController();
  final TextEditingController _operatorUsernameController =
      TextEditingController();

  bool _loading = false;
  bool _exporting = false;
  String _message = '';
  DateTime _queryDate = DateTime.now();
  String? _resultFilter;
  int _page = 1;
  int _total = 0;
  List<FirstArticleListItem> _items = const [];
  String? _lastHandledRoutePayloadJson;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? QualityService(widget.session);
    _loadFirstArticles();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeRoutePayload(widget.routePayloadJson);
    });
  }

  @override
  void didUpdateWidget(covariant DailyFirstArticlePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.routePayloadJson != oldWidget.routePayloadJson) {
      _consumeRoutePayload(widget.routePayloadJson);
    }
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _productNameController.dispose();
    _processCodeController.dispose();
    _operatorUsernameController.dispose();
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
        productName: _productNameController.text.trim(),
        processCode: _processCodeController.text.trim(),
        operatorUsername: _operatorUsernameController.text.trim(),
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
      final exportFile = await _service.exportFirstArticles(
        date: _queryDate,
        keyword: _keywordController.text.trim(),
        result: _resultFilter,
        productName: _productNameController.text.trim(),
        processCode: _processCodeController.text.trim(),
        operatorUsername: _operatorUsernameController.text.trim(),
      );
      if (!mounted) return;
      if (exportFile.contentBase64.isEmpty) {
        setState(() {
          _message = '导出失败：服务端返回空数据';
        });
        return;
      }
      final savedPath = await _exportFileService.saveCsvBase64(
        filename: exportFile.filename,
        contentBase64: exportFile.contentBase64,
      );
      if (savedPath == null || !mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出成功：$savedPath')));
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

  Future<void> _openDetailPage(
    FirstArticleListItem item, {
    required bool isDispositionMode,
  }) async {
    await _openDetailPageById(
      recordId: item.id,
      isDispositionMode: isDispositionMode,
    );
  }

  Future<void> _openDetailPageById({
    required int recordId,
    required bool isDispositionMode,
  }) async {
    final needsRefresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => FirstArticleDispositionPage(
          session: widget.session,
          recordId: recordId,
          canDispose: widget.canDispose,
          isDispositionMode: isDispositionMode,
          onLogout: widget.onLogout,
          service: _service,
        ),
      ),
    );
    if (needsRefresh == true && mounted) {
      await _loadFirstArticles();
    }
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
      final rawRecordId = payload['record_id'];
      final recordId = rawRecordId is int
          ? rawRecordId
          : int.tryParse('${rawRecordId ?? ''}');
      if (action != 'detail' || recordId == null || recordId <= 0) {
        return;
      }
      _lastHandledRoutePayloadJson = rawPayload;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _openDetailPageById(recordId: recordId, isDispositionMode: false);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CrudPageHeader(
            title: '每日首件',
            onRefresh: _loading ? null : _loadFirstArticles,
          ),
          if (widget.canExport) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: (_loading || _exporting) ? null : _exportCsv,
                icon: const Icon(Icons.download),
                label: const Text('导出'),
              ),
            ),
            const SizedBox(height: 12),
          ],
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
                  DropdownMenuItem(value: 'passed', child: Text('合格')),
                  DropdownMenuItem(value: 'failed', child: Text('不合格')),
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _productNameController,
                  decoration: const InputDecoration(
                    labelText: '产品名称',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadFirstArticles(page: 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _processCodeController,
                  decoration: const InputDecoration(
                    labelText: '工序编码',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadFirstArticles(page: 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _operatorUsernameController,
                  decoration: const InputDecoration(
                    labelText: '操作员',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _loadFirstArticles(page: 1),
                ),
              ),
            ],
          ),
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
            child: Column(
              children: [
                Expanded(
                  child: CrudListTableSection(
                    cardKey: const ValueKey('dailyFirstArticleListCard'),
                    loading: _loading,
                    isEmpty: _items.isEmpty,
                    emptyText: '暂无首件记录。',
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
                          if (widget.canViewDetail || widget.canDispose)
                            const DataColumn(label: Text('操作')),
                        ],
                        rows: _items.map((item) {
                          final canDisposeItem =
                              widget.canDispose && item.result != 'passed';
                          return DataRow(
                            cells: [
                              DataCell(Text(_formatDateTime(item.createdAt))),
                              DataCell(Text(item.orderCode)),
                              DataCell(Text(item.productName)),
                              DataCell(
                                Text(
                                  '${item.processName} (${item.processCode})',
                                ),
                              ),
                              DataCell(Text(item.operatorUsername)),
                              DataCell(
                                Text(firstArticleResultLabel(item.result)),
                              ),
                              DataCell(
                                Text(_formatDate(item.verificationDate)),
                              ),
                              DataCell(Text(item.remark ?? '-')),
                              if (widget.canViewDetail || canDisposeItem)
                                DataCell(
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      if (widget.canViewDetail)
                                        TextButton(
                                          onPressed: () => _openDetailPage(
                                            item,
                                            isDispositionMode: false,
                                          ),
                                          child: const Text('详情'),
                                        ),
                                      if (canDisposeItem)
                                        TextButton(
                                          onPressed: () => _openDetailPage(
                                            item,
                                            isDispositionMode: true,
                                          ),
                                          child: const Text('处置'),
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
                const SizedBox(height: 12),
                SimplePaginationBar(
                  page: _page,
                  totalPages: _totalPages,
                  total: _total,
                  loading: _loading,
                  onPrevious: () => _loadFirstArticles(page: _page - 1),
                  onNext: () => _loadFirstArticles(page: _page + 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
