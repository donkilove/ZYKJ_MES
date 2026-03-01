import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/equipment_models.dart';
import '../services/api_exception.dart';
import '../services/equipment_service.dart';
import '../widgets/adaptive_table_container.dart';

class EquipmentLedgerPage extends StatefulWidget {
  const EquipmentLedgerPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canWrite,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canWrite;

  @override
  State<EquipmentLedgerPage> createState() => _EquipmentLedgerPageState();
}

class _EquipmentLedgerPageState extends State<EquipmentLedgerPage> {
  late final EquipmentService _equipmentService;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  String _message = '';
  int _total = 0;
  List<EquipmentLedgerItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _equipmentService = EquipmentService(widget.session);
    _loadItems();
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
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final sec = local.second.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min:$sec';
  }

  Future<void> _loadItems() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _equipmentService.listEquipment(
        page: 1,
        pageSize: 100,
        keyword: _keywordController.text.trim(),
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
        _message = '加载设备台账失败：${_errorMessage(error)}';
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
    final nameController = TextEditingController(text: item?.name ?? '');
    final modelController = TextEditingController(text: item?.model ?? '');
    final locationController = TextEditingController(text: item?.location ?? '');
    final ownerController = TextEditingController(text: item?.ownerName ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: pageContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isCreate ? '新增设备' : '编辑设备'),
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
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: ownerController,
                      decoration: const InputDecoration(
                        labelText: '负责人',
                        border: OutlineInputBorder(),
                      ),
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
                      name: nameController.text.trim(),
                      model: modelController.text.trim(),
                      location: locationController.text.trim(),
                      ownerName: ownerController.text.trim(),
                    );
                  } else {
                    await _equipmentService.updateEquipment(
                      equipmentId: item.id,
                      name: nameController.text.trim(),
                      model: modelController.text.trim(),
                      location: locationController.text.trim(),
                      ownerName: ownerController.text.trim(),
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
                      SnackBar(content: Text('保存设备失败：${_errorMessage(error)}')),
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

    nameController.dispose();
    modelController.dispose();
    locationController.dispose();
    ownerController.dispose();

    if (saved == true) {
      await _loadItems();
    }
  }

  Future<void> _disableItem(EquipmentLedgerItem item) async {
    if (!mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('停用设备'),
        content: Text('确认停用设备“${item.name}”吗？'),
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
      await _equipmentService.disableEquipment(equipmentId: item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备已停用')),
        );
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
        SnackBar(content: Text('停用设备失败：${_errorMessage(error)}')),
      );
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
              IconButton(
                tooltip: '刷新',
                onPressed: _loading ? null : _loadItems,
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
                    labelText: '搜索设备名称/型号/位置/负责人',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _loadItems(),
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
          Text('总数：$_total', style: theme.textTheme.titleMedium),
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
                          DataColumn(label: Text('设备名称')),
                          DataColumn(label: Text('型号')),
                          DataColumn(label: Text('位置')),
                          DataColumn(label: Text('负责人')),
                          DataColumn(label: Text('状态')),
                          DataColumn(label: Text('创建时间')),
                          DataColumn(label: Text('最后修改时间')),
                          DataColumn(label: Text('操作')),
                        ],
                        rows: _items.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(Text(item.name)),
                              DataCell(Text(item.model.isEmpty ? '-' : item.model)),
                              DataCell(Text(item.location.isEmpty ? '-' : item.location)),
                              DataCell(Text(item.ownerName.isEmpty ? '-' : item.ownerName)),
                              DataCell(Text(item.isEnabled ? '启用' : '停用')),
                              DataCell(Text(_formatDateTime(item.createdAt))),
                              DataCell(Text(_formatDateTime(item.updatedAt))),
                              DataCell(
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed: widget.canWrite
                                          ? () => _showEditDialog(item: item)
                                          : null,
                                      child: const Text('编辑'),
                                    ),
                                    TextButton(
                                      onPressed: (widget.canWrite && item.isEnabled)
                                          ? () => _disableItem(item)
                                          : null,
                                      child: const Text('停用'),
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
