import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/equipment_models.dart';
import 'equipment_detail_page.dart';
import '../services/api_exception.dart';
import '../services/equipment_service.dart';
import '../widgets/adaptive_table_container.dart';
import '../widgets/locked_form_dialog.dart';

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
  late final EquipmentService _equipmentService;
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _locationFilterController =
      TextEditingController();

  bool _loading = false;
  bool _exporting = false;
  String _message = '';
  int _total = 0;
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

  Future<void> _loadItems({bool reloadOwners = false}) async {
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
        page: 1,
        pageSize: 100,
        keyword: _keywordController.text.trim(),
        enabled: _enabledFilter,
        locationKeyword: _locationFilterController.text.trim(),
        ownerName: _ownerFilterName,
      );
      if (!mounted) {
        return;
      }
      setState(() {
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
                          items: _ownerOptions
                              .map(
                                (entry) => DropdownMenuItem<String>(
                                  value: entry.username,
                                  child: Text(entry.displayName),
                                ),
                              )
                              .toList(),
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

  Future<void> _exportCsv() async {
    setState(() {
      _exporting = true;
      _message = '';
    });
    try {
      final csvBase64 = await _equipmentService.exportEquipmentLedger(
        keyword: _keywordController.text.trim(),
        enabled: _enabledFilter,
        locationKeyword: _locationFilterController.text.trim().isEmpty
            ? null
            : _locationFilterController.text.trim(),
        ownerName: _ownerFilterName,
      );
      if (!mounted) return;
      if (csvBase64.isEmpty) {
        setState(() => _message = '导出失败：服务端返回空数据');
        return;
      }
      final bytes = base64Decode(csvBase64);
      final location = await getSaveLocation(
        suggestedName: 'equipment_ledger.csv',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (location == null || !mounted) {
        return;
      }
      await XFile.fromData(
        bytes,
        mimeType: 'text/csv',
        name: 'equipment_ledger.csv',
      ).saveTo(location.path);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出成功：${location.path}')));
    } catch (error) {
      if (!mounted) return;
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() => _message = '导出失败：${_errorMessage(error)}');
    } finally {
      if (mounted) setState(() => _exporting = false);
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
              Text(
                '设备台账',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
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
                onPressed: _loading
                    ? null
                    : () => _loadItems(reloadOwners: widget.canWrite),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keywordController,
                  decoration: const InputDecoration(
                    labelText: '搜索设备编号/名称/型号/位置/负责人',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _loadItems(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _locationFilterController,
                  decoration: const InputDecoration(
                    labelText: '位置筛选',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _loadItems(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String?>(
                  initialValue: _ownerFilterName,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('全部负责人'),
                    ),
                    ..._ownerOptions.map(
                      (entry) => DropdownMenuItem<String?>(
                        value: entry.username,
                        child: Text(entry.displayName),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _ownerFilterName = value);
                  },
                  decoration: const InputDecoration(
                    labelText: '负责人',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 140,
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
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _loadItems,
                icon: const Icon(Icons.search),
                label: const Text('搜索'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: (_loading || !widget.canWrite)
                    ? null
                    : () => _showEditDialog(),
                icon: const Icon(Icons.add),
                label: const Text('新增设备'),
              ),
            ],
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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(child: Text('暂无设备'))
                : Card(
                    child: AdaptiveTableContainer(
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
                              DataCell(
                                Text(item.model.isEmpty ? '-' : item.model),
                              ),
                              DataCell(
                                Text(
                                  item.location.isEmpty ? '-' : item.location,
                                ),
                              ),
                              DataCell(
                                Text(
                                  item.ownerName.isEmpty ? '-' : item.ownerName,
                                ),
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
          ),
        ],
      ),
    );
  }
}
