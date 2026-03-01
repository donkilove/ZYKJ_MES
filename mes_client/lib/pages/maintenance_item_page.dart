import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/equipment_models.dart';
import '../services/api_exception.dart';
import '../services/equipment_service.dart';
import '../widgets/adaptive_table_container.dart';

class MaintenanceItemPage extends StatefulWidget {
  const MaintenanceItemPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canWrite,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canWrite;

  @override
  State<MaintenanceItemPage> createState() => _MaintenanceItemPageState();
}

class _MaintenanceItemPageState extends State<MaintenanceItemPage> {
  late final EquipmentService _equipmentService;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  String _message = '';
  int _total = 0;
  List<MaintenanceItemEntry> _items = const [];

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
      final result = await _equipmentService.listMaintenanceItems(
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
        _message = '加载保养项目失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showEditDialog({MaintenanceItemEntry? item}) async {
    if (!mounted) {
      return;
    }
    final pageContext = context;
    final isCreate = item == null;
    final nameController = TextEditingController(text: item?.name ?? '');
    final categoryController = TextEditingController(text: item?.category ?? '');
    final cycleController = TextEditingController(
      text: (item?.defaultCycleDays ?? 30).toString(),
    );
    final durationController = TextEditingController(
      text: (item?.defaultDurationMinutes ?? 60).toString(),
    );
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: pageContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isCreate ? '新增保养项目' : '编辑保养项目'),
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
                        labelText: '项目名称',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入项目名称';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: '项目分类',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: cycleController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '默认周期(天)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final parsed = int.tryParse((value ?? '').trim());
                              if (parsed == null || parsed <= 0) {
                                return '请输入正整数';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: durationController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '默认时长(分钟)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final parsed = int.tryParse((value ?? '').trim());
                              if (parsed == null || parsed <= 0) {
                                return '请输入正整数';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
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
                final cycle = int.parse(cycleController.text.trim());
                final duration = int.parse(durationController.text.trim());
                try {
                  if (isCreate) {
                    await _equipmentService.createMaintenanceItem(
                      name: nameController.text.trim(),
                      category: categoryController.text.trim(),
                      defaultCycleDays: cycle,
                      defaultDurationMinutes: duration,
                    );
                  } else {
                    await _equipmentService.updateMaintenanceItem(
                      itemId: item.id,
                      name: nameController.text.trim(),
                      category: categoryController.text.trim(),
                      defaultCycleDays: cycle,
                      defaultDurationMinutes: duration,
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
                      SnackBar(content: Text('保存保养项目失败：${_errorMessage(error)}')),
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
    categoryController.dispose();
    cycleController.dispose();
    durationController.dispose();

    if (saved == true) {
      await _loadItems();
    }
  }

  Future<void> _disableItem(MaintenanceItemEntry item) async {
    if (!mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('停用保养项目'),
        content: Text('确认停用项目“${item.name}”吗？'),
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
      await _equipmentService.disableMaintenanceItem(itemId: item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保养项目已停用')),
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
        SnackBar(content: Text('停用保养项目失败：${_errorMessage(error)}')),
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
                '保养项目',
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
                    labelText: '搜索项目名称/分类',
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
                label: const Text('新增项目'),
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
                ? const Center(child: Text('暂无保养项目'))
                : Card(
                    child: AdaptiveTableContainer(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('项目名称')),
                          DataColumn(label: Text('分类')),
                          DataColumn(label: Text('默认周期(天)')),
                          DataColumn(label: Text('默认时长(分钟)')),
                          DataColumn(label: Text('状态')),
                          DataColumn(label: Text('最后修改时间')),
                          DataColumn(label: Text('操作')),
                        ],
                        rows: _items.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(Text(item.name)),
                              DataCell(Text(item.category.isEmpty ? '-' : item.category)),
                              DataCell(Text('${item.defaultCycleDays}')),
                              DataCell(Text('${item.defaultDurationMinutes}')),
                              DataCell(Text(item.isEnabled ? '启用' : '停用')),
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
