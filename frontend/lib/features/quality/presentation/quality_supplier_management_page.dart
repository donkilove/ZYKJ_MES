import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/quality/presentation/widgets/quality_supplier_management_page_header.dart';
import 'package:mes_client/features/quality/presentation/widgets/quality_supplier_action_dialogs.dart';
import 'package:mes_client/features/quality/presentation/widgets/quality_supplier_form_dialog.dart';
import 'package:mes_client/features/quality/services/quality_supplier_service.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_pagination_bar.dart';

class QualitySupplierManagementPage extends StatefulWidget {
  const QualitySupplierManagementPage({
    super.key,
    required this.session,
    required this.onLogout,
    this.service,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final QualitySupplierService? service;

  @override
  State<QualitySupplierManagementPage> createState() =>
      _QualitySupplierManagementPageState();
}

class _QualitySupplierManagementPageState
    extends State<QualitySupplierManagementPage> {
  static const int _pageSize = 30;

  late final QualitySupplierService _service;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  int _page = 1;
  int _total = 0;
  String _message = '';
  List<QualitySupplierItem> _items = const [];
  bool? _enabledFilter;

  int get _totalPages => _total <= 0 ? 1 : ((_total - 1) ~/ _pageSize) + 1;

  List<QualitySupplierItem> get _pagedItems {
    if (_items.isEmpty) {
      return const [];
    }
    final start = (_page - 1) * _pageSize;
    if (start >= _items.length) {
      return const [];
    }
    final end = (start + _pageSize).clamp(0, _items.length);
    return _items.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? QualitySupplierService(widget.session);
    _loadSuppliers();
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

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  Future<void> _loadSuppliers() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _service.listSuppliers(
        keyword: _keywordController.text.trim(),
        enabled: _enabledFilter,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items = result.items;
        _total = result.total;
        final resolvedTotalPages = result.total <= 0
            ? 1
            : ((result.total - 1) ~/ _pageSize) + 1;
        _page = _page > resolvedTotalPages ? resolvedTotalPages : _page;
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
        _message = '加载供应商失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showEditDialog({QualitySupplierItem? item}) async {
    final isCreate = item == null;
    final saved = await showQualitySupplierFormDialog(
      context: context,
      supplierService: _service,
      item: item,
    );
    if (saved != true || !mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(isCreate ? '供应商已新增' : '供应商已更新')));
    await _loadSuppliers();
  }

  Future<void> _deleteSupplier(QualitySupplierItem item) async {
    final confirmed = await showQualitySupplierDeleteDialog(
      context: context,
      item: item,
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await _service.deleteSupplier(item.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('供应商已删除')));
      await _loadSuppliers();
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
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MesCrudPageScaffold(
      header: Row(
        children: [
          Expanded(
            child: QualitySupplierManagementPageHeader(
              total: _total,
              loading: _loading,
              onRefresh: _loadSuppliers,
              onCreate: () => _showEditDialog(),
            ),
          ),
        ],
      ),
      filters: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: _keywordController,
              decoration: const InputDecoration(
                labelText: '搜索供应商名称',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _loadSuppliers(),
            ),
          ),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<bool?>(
              initialValue: _enabledFilter,
              decoration: const InputDecoration(
                labelText: '状态筛选',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem<bool?>(value: null, child: Text('全部')),
                DropdownMenuItem<bool?>(value: true, child: Text('启用')),
                DropdownMenuItem<bool?>(value: false, child: Text('停用')),
              ],
              onChanged: _loading
                  ? null
                  : (value) {
                      setState(() {
                        _enabledFilter = value;
                        _page = 1;
                      });
                      _loadSuppliers();
                    },
            ),
          ),
          FilledButton.icon(
            onPressed: _loading
                ? null
                : () {
                    setState(() => _page = 1);
                    _loadSuppliers();
                  },
            icon: const Icon(Icons.search),
            label: const Text('查询'),
          ),
        ],
      ),
      banner: _message.isEmpty
          ? null
          : Text(
              _message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
      content: CrudListTableSection(
        cardKey: const ValueKey('qualitySupplierListCard'),
        loading: _loading,
        isEmpty: _pagedItems.isEmpty,
        emptyText: '暂无供应商数据',
        enableUnifiedHeaderStyle: true,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('名称')),
            DataColumn(label: Text('备注')),
            DataColumn(label: Text('启用状态')),
            DataColumn(label: Text('更新时间')),
            DataColumn(label: Text('操作')),
          ],
          rows: _pagedItems
              .map(
                (item) => DataRow(
                  cells: [
                    DataCell(Text(item.name)),
                    DataCell(
                      Text(
                        item.remark?.trim().isNotEmpty == true
                            ? item.remark!
                            : '-',
                      ),
                    ),
                    DataCell(Text(item.isEnabled ? '启用' : '停用')),
                    DataCell(Text(_formatDateTime(item.updatedAt))),
                    DataCell(
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => _showEditDialog(item: item),
                            child: const Text('编辑'),
                          ),
                          OutlinedButton(
                            onPressed: () => _deleteSupplier(item),
                            child: const Text('删除'),
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
        onPrevious: () {
          setState(() {
            _page -= 1;
          });
        },
        onNext: () {
          setState(() {
            _page += 1;
          });
        },
      ),
    );
  }
}
