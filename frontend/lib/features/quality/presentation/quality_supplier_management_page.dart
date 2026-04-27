import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/quality/presentation/widgets/quality_supplier_management_page_header.dart';
import 'package:mes_client/features/quality/services/quality_supplier_service.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
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

  bool _loading = false;
  int _page = 1;
  int _total = 0;
  String _message = '';
  List<QualitySupplierItem> _items = const [];

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
      final result = await _service.listSuppliers();
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
    final nameController = TextEditingController(text: item?.name ?? '');
    final remarkController = TextEditingController(text: item?.remark ?? '');
    final formKey = GlobalKey<FormState>();
    var isEnabled = item?.isEnabled ?? true;

    final saved = await showMesLockedFormDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setInnerState) {
            return AlertDialog(
              title: Text(isCreate ? '新增供应商' : '编辑供应商'),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: '名称',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请输入供应商名称';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: remarkController,
                          decoration: const InputDecoration(
                            labelText: '备注',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          value: isEnabled,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('启用状态'),
                          subtitle: Text(isEnabled ? '当前为启用' : '当前为停用'),
                          onChanged: (value) {
                            setInnerState(() {
                              isEnabled = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    final payload = QualitySupplierUpsertPayload(
                      name: nameController.text.trim(),
                      remark: remarkController.text.trim().isEmpty
                          ? null
                          : remarkController.text.trim(),
                      isEnabled: isEnabled,
                    );
                    try {
                      if (isCreate) {
                        await _service.createSupplier(payload);
                      } else {
                        await _service.updateSupplier(item.id, payload);
                      }
                      if (!dialogContext.mounted) {
                        return;
                      }
                      Navigator.of(dialogContext).pop(true);
                    } catch (error) {
                      if (!dialogContext.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text(_errorMessage(error))),
                      );
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确认删除供应商 ${item.name} 吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
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

  Widget _buildToolbar() {
    return Row(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToolbar(),
          if (_message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: CrudListTableSection(
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
          ),
          const SizedBox(height: 12),
          MesPaginationBar(
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
        ],
      ),
    );
  }
}
