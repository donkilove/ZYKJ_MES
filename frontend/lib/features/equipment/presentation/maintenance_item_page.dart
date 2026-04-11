import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/equipment/services/equipment_service.dart';
import 'package:mes_client/core/widgets/crud_list_table_section.dart';
import 'package:mes_client/core/widgets/crud_page_header.dart';
import 'package:mes_client/core/widgets/locked_form_dialog.dart';
import 'package:mes_client/core/widgets/simple_pagination_bar.dart';

class MaintenanceItemPage extends StatefulWidget {
  const MaintenanceItemPage({
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
  State<MaintenanceItemPage> createState() => _MaintenanceItemPageState();
}

class _MaintenanceItemPageState extends State<MaintenanceItemPage> {
  static const int _pageSize = 30;

  late final EquipmentService _equipmentService;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  String _message = '';
  int _total = 0;
  int _page = 1;
  List<MaintenanceItemEntry> _items = const [];
  bool? _enabledFilter;
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _equipmentService =
        widget.equipmentService ?? EquipmentService(widget.session);
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

  int get _totalPages {
    final pages = (_total + _pageSize - 1) ~/ _pageSize;
    return pages > 0 ? pages : 1;
  }

  Future<void> _loadItems({int? page}) async {
    final targetPage = page ?? _page;
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _equipmentService.listMaintenanceItems(
        page: targetPage,
        pageSize: _pageSize,
        keyword: _keywordController.text.trim(),
        enabled: _enabledFilter,
        category: _categoryFilter,
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
        _message = '加载保养项目失败: ${_errorMessage(error)}';
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
    final durationController = TextEditingController(
      text:
          item?.defaultDurationMinutes != null &&
              item!.defaultDurationMinutes > 0
          ? '${item.defaultDurationMinutes}'
          : '',
    );
    final cycleDaysController = TextEditingController(
      text: item != null ? '${item.defaultCycleDays}' : '',
    );
    final standardDescController = TextEditingController(
      text: item?.standardDescription ?? '',
    );
    final formKey = GlobalKey<FormState>();
    const categoryOptions = ['', '点检', '润滑', '校准', '清洁'];
    var selectedCategory = item?.category ?? '';
    if (!categoryOptions.contains(selectedCategory)) {
      selectedCategory = '';
    }

    final saved = await showLockedFormDialog<bool>(
      context: pageContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setInnerState) {
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
                          controller: cycleDaysController,
                          decoration: const InputDecoration(
                            labelText: '默认周期天数',
                            helperText: '常用值：7 / 30 / 90 / 365',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final normalized = value?.trim() ?? '';
                            if (normalized.isEmpty) {
                              return '请输入默认周期天数';
                            }
                            final n = int.tryParse(normalized);
                            if (n == null || n < 1 || n > 3650) {
                              return '请输入1-3650之间的整数';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCategory,
                          items: categoryOptions
                              .map(
                                (c) => DropdownMenuItem<String>(
                                  value: c,
                                  child: Text(c.isEmpty ? '(不限)' : c),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setInnerState(() {
                              selectedCategory = value ?? '';
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: '类别',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: durationController,
                          decoration: const InputDecoration(
                            labelText: '默认时长(分钟)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              final n = int.tryParse(value.trim());
                              if (n == null || n < 1 || n > 1440) {
                                return '请输入1-1440之间的整数';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: standardDescController,
                          decoration: const InputDecoration(
                            labelText: '标准描述',
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
                    final cycleDays = int.parse(
                      cycleDaysController.text.trim(),
                    );
                    final durationText = durationController.text.trim();
                    final duration = durationText.isNotEmpty
                        ? int.tryParse(durationText)
                        : null;
                    try {
                      if (isCreate) {
                        await _equipmentService.createMaintenanceItem(
                          name: nameController.text.trim(),
                          defaultCycleDays: cycleDays,
                          category: selectedCategory,
                          defaultDurationMinutes: duration,
                          standardDescription: standardDescController.text
                              .trim(),
                        );
                      } else {
                        await _equipmentService.updateMaintenanceItem(
                          itemId: item.id,
                          name: nameController.text.trim(),
                          defaultCycleDays: cycleDays,
                          category: selectedCategory,
                          defaultDurationMinutes: duration,
                          standardDescription: standardDescController.text
                              .trim(),
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
                            content: Text('保存保养项目失败: ${_errorMessage(error)}'),
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

    nameController.dispose();
    durationController.dispose();
    cycleDaysController.dispose();
    standardDescController.dispose();

    if (saved == true) {
      await _loadItems();
    }
  }

  Future<void> _toggleItem(MaintenanceItemEntry item) async {
    final nextEnabled = !item.isEnabled;
    final action = nextEnabled ? '启用' : '停用';
    if (!mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$action保养项目'),
        content: Text('确认$action项目“${item.name}”吗？'),
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
      await _equipmentService.toggleMaintenanceItem(
        itemId: item.id,
        enabled: nextEnabled,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保养项目已$action')));
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
        SnackBar(content: Text('$action保养项目失败: ${_errorMessage(error)}')),
      );
    }
  }

  Future<void> _deleteItem(MaintenanceItemEntry item) async {
    if (!mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除保养项目'),
        content: Text('确认删除项目“${item.name}”吗？此操作不可恢复。'),
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
      await _equipmentService.deleteMaintenanceItem(itemId: item.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保养项目已删除')));
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
        SnackBar(content: Text('删除保养项目失败: ${_errorMessage(error)}')),
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
              Expanded(
                child: CrudPageHeader(
                  title: '保养项目',
                  onRefresh: _loading ? null : () => _loadItems(page: _page),
                ),
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
                    labelText: '搜索项目名称',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _loadItems(page: 1),
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
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String?>(
                  initialValue: _categoryFilter,
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('全部类别')),
                    DropdownMenuItem<String?>(value: '点检', child: Text('点检')),
                    DropdownMenuItem<String?>(value: '润滑', child: Text('润滑')),
                    DropdownMenuItem<String?>(value: '校准', child: Text('校准')),
                    DropdownMenuItem<String?>(value: '清洁', child: Text('清洁')),
                  ],
                  onChanged: (value) {
                    setState(() => _categoryFilter = value);
                  },
                  decoration: const InputDecoration(
                    labelText: '类别',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loading ? null : () => _loadItems(page: 1),
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
              emptyText: '暂无保养项目',
              enableUnifiedHeaderStyle: true,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('项目名称')),
                  DataColumn(label: Text('项目分类')),
                  DataColumn(label: Text('默认周期天数')),
                  DataColumn(label: Text('默认预计时长')),
                  DataColumn(label: Text('状态')),
                  DataColumn(label: Text('创建时间')),
                  DataColumn(label: Text('更新时间')),
                  DataColumn(label: Text('操作')),
                ],
                rows: _items.map((item) {
                  return DataRow(
                    cells: [
                      DataCell(Text(item.name)),
                      DataCell(
                        Text(item.category.isEmpty ? '-' : item.category),
                      ),
                      DataCell(Text('${item.defaultCycleDays}')),
                      DataCell(
                        Text(
                          item.defaultDurationMinutes > 0
                              ? '${item.defaultDurationMinutes} 分钟'
                              : '-',
                        ),
                      ),
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
                              onPressed: widget.canWrite
                                  ? () => _toggleItem(item)
                                  : null,
                              child: Text(item.isEnabled ? '停用' : '启用'),
                            ),
                            TextButton(
                              onPressed: widget.canWrite
                                  ? () => _deleteItem(item)
                                  : null,
                              child: const Text('删除'),
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
