import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';
import 'package:mes_client/features/equipment/presentation/equipment_detail_page.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/equipment/services/equipment_service.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/widgets/crud_page_header.dart';
import 'package:mes_client/core/widgets/locked_form_dialog.dart';
import 'package:mes_client/core/widgets/simple_pagination_bar.dart';

class EquipmentLedgerPage extends StatefulWidget {
  const EquipmentLedgerPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canWrite,
    this.equipmentService,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canWrite;
  final EquipmentService? equipmentService;

  @override
  State<EquipmentLedgerPage> createState() => _EquipmentLedgerPageState();
}

class _EquipmentLedgerPageState extends State<EquipmentLedgerPage> {
  static const int _pageSize = 30;
  static const String _allOwnersLabel = '全部负责人';

  late final EquipmentService _equipmentService;
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _locationFilterController =
      TextEditingController();

  bool _loading = false;
  String _message = '';
  int _total = 0;
  int _page = 1;
  List<EquipmentLedgerItem> _items = const [];
  List<EquipmentOwnerOption> _ownerOptions = const [];
  bool? _enabledFilter;
  String? _ownerFilterName;

  @override
  void initState() {
    super.initState();
    _equipmentService =
        widget.equipmentService ?? EquipmentService(widget.session);
    _loadItems(reloadOwners: true);
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _locationFilterController.dispose();
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
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final sec = local.second.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min:$sec';
  }

  Widget _buildOwnerDropdownText(String text) {
    return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  int get _totalPages {
    final pages = (_total + _pageSize - 1) ~/ _pageSize;
    return pages > 0 ? pages : 1;
  }

  Future<void> _loadItems({int? page, bool reloadOwners = false}) async {
    final targetPage = page ?? _page;
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      if (reloadOwners || _ownerOptions.isEmpty) {
        try {
          _ownerOptions = await _equipmentService.listAllOwners();
        } catch (_) {}
      }
      final result = await _equipmentService.listEquipment(
        page: targetPage,
        pageSize: _pageSize,
        keyword: _keywordController.text.trim(),
        enabled: _enabledFilter,
        locationKeyword: _locationFilterController.text.trim(),
        ownerName: _ownerFilterName,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _page = targetPage;
        _items = result.items;
        _total = result.total;
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
        _message = '加载设备台账失败: ${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showEditDialog({EquipmentLedgerItem? item}) async {
    if (!mounted) {
      return;
    }
    final pageContext = context;
    final isCreate = item == null;
    final codeController = TextEditingController(text: item?.code ?? '');
    final nameController = TextEditingController(text: item?.name ?? '');
    final modelController = TextEditingController(text: item?.model ?? '');
    final locationController = TextEditingController(
      text: item?.location ?? '',
    );
    final remarkController = TextEditingController(text: item?.remark ?? '');
    final formKey = GlobalKey<FormState>();
    var selectedOwner = (item?.ownerName ?? '').trim();
    final ownerNames = _ownerOptions.map((owner) => owner.username).toSet();
    if (selectedOwner.isNotEmpty && !ownerNames.contains(selectedOwner)) {
      selectedOwner = '';
    }

    final saved = await showLockedFormDialog<bool>(
      context: pageContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setInnerState) {
            return AlertDialog(
              title: Text(isCreate ? '新增设备' : '编辑设备'),
              content: SizedBox(
                width: 560,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: codeController,
                          decoration: const InputDecoration(
                            labelText: '设备编号',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请输入设备编号';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: '设备名称',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请输入设备名称';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: modelController,
                          decoration: const InputDecoration(
                            labelText: '型号',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: locationController,
                          decoration: const InputDecoration(
                            labelText: '位置',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请输入位置';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedOwner.isEmpty
                              ? null
                              : selectedOwner,
                          isExpanded: true,
                          items: _ownerOptions
                              .map(
                                (entry) => DropdownMenuItem<String>(
                                  value: entry.username,
                                  child: _buildOwnerDropdownText(
                                    entry.displayName,
                                  ),
                                ),
                              )
                              .toList(),
                          selectedItemBuilder: (context) {
                            return _ownerOptions
                                .map(
                                  (entry) => Align(
                                    alignment: Alignment.centerLeft,
                                    child: _buildOwnerDropdownText(
                                      entry.displayName,
                                    ),
                                  ),
                                )
                                .toList();
                          },
                          onChanged: (value) {
                            setInnerState(() {
                              selectedOwner = value ?? '';
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: '负责人',
                            border: OutlineInputBorder(),
                          ),
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
                    try {
                      if (isCreate) {
                        await _equipmentService.createEquipment(
                          code: codeController.text.trim(),
                          name: nameController.text.trim(),
                          model: modelController.text.trim(),
                          location: locationController.text.trim(),
                          ownerName: selectedOwner,
                          remark: remarkController.text.trim(),
                        );
                      } else {
                        await _equipmentService.updateEquipment(
                          equipmentId: item.id,
                          code: codeController.text.trim(),
                          name: nameController.text.trim(),
                          model: modelController.text.trim(),
                          location: locationController.text.trim(),
                          ownerName: selectedOwner,
                          remark: remarkController.text.trim(),
                        );
                      }
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    } catch (error) {
                      if (_isUnauthorized(error)) {
                        widget.onLogout();
                        return;
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('保存设备失败: ${_errorMessage(error)}'),
                          ),
                        );
                      }
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

    codeController.dispose();
    nameController.dispose();
    modelController.dispose();
    locationController.dispose();
    remarkController.dispose();

    if (saved == true) {
      await _loadItems();
    }
  }

  Future<void> _showDetailDialog(EquipmentLedgerItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EquipmentDetailPage(
          session: widget.session,
          onLogout: widget.onLogout,
          equipmentId: item.id,
        ),
      ),
    );
  }

  Future<void> _toggleItem(EquipmentLedgerItem item) async {
    final nextEnabled = !item.isEnabled;
    final action = nextEnabled ? '启用' : '停用';
    if (!mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$action设备'),
        content: Text('确认$action设备“${item.name}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await _equipmentService.toggleEquipment(
        equipmentId: item.id,
        enabled: nextEnabled,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('设备已$action')));
      }
      await _loadItems();
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$action设备失败: ${_errorMessage(error)}')),
      );
    }
  }

  Future<void> _deleteItem(EquipmentLedgerItem item) async {
    if (!mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除设备'),
        content: Text('确认删除设备“${item.name}”吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await _equipmentService.deleteEquipment(equipmentId: item.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('设备已删除')));
      }
      await _loadItems();
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除设备失败: ${_errorMessage(error)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const toolbarSpacing = 12.0;
    const locationFilterWidth = 160.0;
    const ownerFilterWidth = 180.0;
    const statusFilterWidth = 140.0;
    const desktopSearchMinWidth = 320.0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: CrudPageHeader(
                  title: '设备台账',
                  onRefresh: _loading
                      ? null
                      : () => _loadItems(
                          page: _page,
                          reloadOwners: widget.canWrite,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final keywordField = TextField(
                controller: _keywordController,
                decoration: const InputDecoration(
                  labelText: '搜索设备编号/名称/型号/位置/负责人',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _loadItems(page: 1),
              );
              final locationFilter = SizedBox(
                width: constraints.maxWidth < locationFilterWidth
                    ? constraints.maxWidth
                    : locationFilterWidth,
                child: TextField(
                  controller: _locationFilterController,
                  decoration: const InputDecoration(
                    labelText: '位置筛选',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _loadItems(page: 1),
                ),
              );
              final ownerFilter = SizedBox(
                width: constraints.maxWidth < ownerFilterWidth
                    ? constraints.maxWidth
                    : ownerFilterWidth,
                child: DropdownButtonFormField<String?>(
                  initialValue: _ownerFilterName,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: _buildOwnerDropdownText(_allOwnersLabel),
                    ),
                    ..._ownerOptions.map(
                      (entry) => DropdownMenuItem<String?>(
                        value: entry.username,
                        child: _buildOwnerDropdownText(entry.displayName),
                      ),
                    ),
                  ],
                  selectedItemBuilder: (context) {
                    return [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _buildOwnerDropdownText(_allOwnersLabel),
                      ),
                      ..._ownerOptions.map(
                        (entry) => Align(
                          alignment: Alignment.centerLeft,
                          child: _buildOwnerDropdownText(entry.displayName),
                        ),
                      ),
                    ];
                  },
                  onChanged: (value) {
                    setState(() => _ownerFilterName = value);
                  },
                  decoration: const InputDecoration(
                    labelText: '负责人',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              );
              final statusFilter = SizedBox(
                width: constraints.maxWidth < statusFilterWidth
                    ? constraints.maxWidth
                    : statusFilterWidth,
                child: DropdownButtonFormField<bool?>(
                  initialValue: _enabledFilter,
                  items: const [
                    DropdownMenuItem<bool?>(value: null, child: Text('全部状态')),
                    DropdownMenuItem<bool?>(value: true, child: Text('启用')),
                    DropdownMenuItem<bool?>(value: false, child: Text('停用')),
                  ],
                  onChanged: (value) {
                    setState(() => _enabledFilter = value);
                  },
                  decoration: const InputDecoration(
                    labelText: '状态',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              );
              final toolbarButtons = <Widget>[
                FilledButton.icon(
                  onPressed: _loading ? null : () => _loadItems(page: 1),
                  icon: const Icon(Icons.search),
                  label: const Text('搜索'),
                ),
                FilledButton.icon(
                  onPressed: (_loading || !widget.canWrite)
                      ? null
                      : () => _showEditDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('新增设备'),
                ),
              ];
              final desktopToolbarMinWidth =
                  desktopSearchMinWidth +
                  locationFilterWidth +
                  ownerFilterWidth +
                  statusFilterWidth +
                  240 +
                  (5 * toolbarSpacing);

              if (constraints.maxWidth >= desktopToolbarMinWidth) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: keywordField),
                    const SizedBox(width: toolbarSpacing),
                    locationFilter,
                    const SizedBox(width: toolbarSpacing),
                    ownerFilter,
                    const SizedBox(width: toolbarSpacing),
                    statusFilter,
                    const SizedBox(width: toolbarSpacing),
                    Wrap(
                      spacing: toolbarSpacing,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: toolbarButtons,
                    ),
                  ],
                );
              }

              return Wrap(
                spacing: toolbarSpacing,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(width: constraints.maxWidth, child: keywordField),
                  locationFilter,
                  ownerFilter,
                  statusFilter,
                  ...toolbarButtons,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text('总数: $_total', style: theme.textTheme.titleMedium),
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
            child: CrudListTableSection(
              loading: _loading,
              isEmpty: _items.isEmpty,
              emptyText: '暂无设备',
              enableUnifiedHeaderStyle: true,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('设备编号')),
                  DataColumn(label: Text('设备名称')),
                  DataColumn(label: Text('型号')),
                  DataColumn(label: Text('位置')),
                  DataColumn(label: Text('负责人')),
                  DataColumn(label: Text('状态')),
                  DataColumn(label: Text('创建时间')),
                  DataColumn(label: Text('更新时间')),
                  DataColumn(label: Text('操作')),
                ],
                rows: _items.map((item) {
                  return DataRow(
                    cells: [
                      DataCell(Text(item.code)),
                      DataCell(Text(item.name)),
                      DataCell(Text(item.model.isEmpty ? '-' : item.model)),
                      DataCell(
                        Text(item.location.isEmpty ? '-' : item.location),
                      ),
                      DataCell(
                        Text(item.ownerName.isEmpty ? '-' : item.ownerName),
                      ),
                      DataCell(Text(item.isEnabled ? '启用' : '停用')),
                      DataCell(Text(_formatDateTime(item.createdAt))),
                      DataCell(Text(_formatDateTime(item.updatedAt))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: widget.canWrite
                                  ? () => _showEditDialog(item: item)
                                  : null,
                              child: const Text('编辑'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: widget.canWrite
                                  ? () => _toggleItem(item)
                                  : null,
                              child: Text(item.isEnabled ? '停用' : '启用'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: widget.canWrite
                                  ? () => _deleteItem(item)
                                  : null,
                              child: const Text('删除'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => _showDetailDialog(item),
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
          ),
          const SizedBox(height: 12),
          SimplePaginationBar(
            page: _page,
            totalPages: _totalPages,
            total: _total,
            loading: _loading,
            onPrevious: () => _loadItems(page: _page - 1),
            onNext: () => _loadItems(page: _page + 1),
          ),
        ],
      ),
    );
  }
}
