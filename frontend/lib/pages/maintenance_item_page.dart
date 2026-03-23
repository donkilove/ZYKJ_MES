import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/equipment_models.dart';
import '../services/api_exception.dart';
import '../services/equipment_service.dart';
import '../widgets/adaptive_table_container.dart';
import '../widgets/locked_form_dialog.dart';
import '../widgets/simple_pagination_bar.dart';
import '../widgets/unified_list_table_header_style.dart';

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
  late final EquipmentService _equipmentService;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  bool _exporting = false;
  String _message = '';
  int _page = 1;
  int _pageSize = 20;
  int _total = 0;
  List<MaintenanceItemEntry> _items = const [];
  bool? _enabledFilter;
  String? _categoryFilter;

  static const List<int> _pageSizeOptions = [20, 50, 100];

  int get _totalPages => _total == 0 ? 1 : (_total / _pageSize).ceil();

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

  Future<void> _loadItems({int? page, int? pageSize}) async {
    if (!mounted) {
      return;
    }
    final nextPage = page ?? _page;
    final nextPageSize = pageSize ?? _pageSize;
    setState(() {
      _loading = true;
      _message = '';
      _page = nextPage;
      _pageSize = nextPageSize;
    });
    try {
      final result = await _equipmentService.listMaintenanceItems(
        page: nextPage,
        pageSize: nextPageSize,
        keyword: _keywordController.text.trim(),
        enabled: _enabledFilter,
        category: _categoryFilter,
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

  Future<void> _exportCsv() async {
    setState(() {
      _exporting = true;
      _message = '';
    });
    try {
      final csvBase64 = await _equipmentService.exportMaintenanceItems(
        keyword: _keywordController.text.trim(),
        enabled: _enabledFilter,
        category: _categoryFilter,
      );
      if (!mounted) return;
      if (csvBase64.isEmpty) {
        setState(() => _message = '导出失败：服务端返回空数据');
        return;
      }
      final bytes = base64Decode(csvBase64);
      final location = await getSaveLocation(
        suggestedName: 'maintenance_items.csv',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (location == null || !mounted) return;
      await XFile.fromData(
        bytes,
        mimeType: 'text/csv',
        name: 'maintenance_items.csv',
      ).saveTo(location.path);
      if (!mounted) return;
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
    final toolbarButtonStyle =
        UnifiedListTableHeaderStyle.toolbarActionButtonStyle(theme);
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
                onPressed: _loading ? null : _loadItems,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 360,
                    child: TextField(
                      controller: _keywordController,
                      decoration: const InputDecoration(
                        labelText: '搜索项目名称',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _loadItems(page: 1),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<bool?>(
                      initialValue: _enabledFilter,
                      items: const [
                        DropdownMenuItem<bool?>(
                          value: null,
                          child: Text('全部状态'),
                        ),
                        DropdownMenuItem<bool?>(value: true, child: Text('启用')),
                        DropdownMenuItem<bool?>(
                          value: false,
                          child: Text('停用'),
                        ),
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
                  SizedBox(
                    width: 160,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _categoryFilter,
                      items: const [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('全部类别'),
                        ),
                        DropdownMenuItem<String?>(
                          value: '点检',
                          child: Text('点检'),
                        ),
                        DropdownMenuItem<String?>(
                          value: '润滑',
                          child: Text('润滑'),
                        ),
                        DropdownMenuItem<String?>(
                          value: '校准',
                          child: Text('校准'),
                        ),
                        DropdownMenuItem<String?>(
                          value: '清洁',
                          child: Text('清洁'),
                        ),
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
                  FilledButton.icon(
                    onPressed: _loading ? null : () => _loadItems(page: 1),
                    icon: const Icon(Icons.search),
                    label: const Text('搜索'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () {
                            _keywordController.clear();
                            setState(() {
                              _enabledFilter = null;
                              _categoryFilter = null;
                            });
                            _loadItems(page: 1);
                          },
                    style: toolbarButtonStyle,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('重置筛选'),
                  ),
                  if (widget.canWrite)
                    FilledButton.icon(
                      onPressed: _loading ? null : () => _showEditDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('新增项目'),
                    ),
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
          Text('总数：$_total', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(child: Text('暂无保养项目'))
                : Card(
                    clipBehavior: Clip.antiAlias,
                    child: AdaptiveTableContainer(
                      minTableWidth: 1380,
                      child: UnifiedListTableHeaderStyle.wrap(
                        theme: theme,
                        child: DataTable(
                          dataRowMinHeight: 60,
                          dataRowMaxHeight: 80,
                          columns: [
                            UnifiedListTableHeaderStyle.column(context, '项目名称'),
                            UnifiedListTableHeaderStyle.column(context, '项目分类'),
                            UnifiedListTableHeaderStyle.column(
                              context,
                              '默认周期天数',
                            ),
                            UnifiedListTableHeaderStyle.column(
                              context,
                              '默认预计时长',
                            ),
                            UnifiedListTableHeaderStyle.column(context, '状态'),
                            UnifiedListTableHeaderStyle.column(context, '创建时间'),
                            UnifiedListTableHeaderStyle.column(context, '更新时间'),
                            UnifiedListTableHeaderStyle.column(
                              context,
                              '操作',
                              textAlign: TextAlign.center,
                            ),
                          ],
                          rows: _items.map((item) {
                            return DataRow(
                              cells: [
                                DataCell(Text(item.name)),
                                DataCell(
                                  Text(
                                    item.category.isEmpty ? '-' : item.category,
                                  ),
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
                                  widget.canWrite
                                      ? UnifiedListTableHeaderStyle.actionMenuButton<
                                          String
                                        >(
                                          theme: theme,
                                          onSelected: (action) {
                                            switch (action) {
                                              case 'edit':
                                                _showEditDialog(item: item);
                                                return;
                                              case 'toggle':
                                                _toggleItem(item);
                                                return;
                                              case 'delete':
                                                _deleteItem(item);
                                                return;
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem<String>(
                                              value: 'edit',
                                              child: Text('编辑'),
                                            ),
                                            PopupMenuItem<String>(
                                              value: 'toggle',
                                              child: Text(
                                                item.isEnabled ? '停用' : '启用',
                                              ),
                                            ),
                                            const PopupMenuItem<String>(
                                              value: 'delete',
                                              child: Text('删除'),
                                            ),
                                          ],
                                        )
                                      : const Text('-'),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SimplePaginationBar(
                page: _page,
                totalPages: _totalPages,
                total: _total,
                loading: _loading,
                pageSize: _pageSize,
                pageSizeOptions: _pageSizeOptions,
                onPrevious: _page > 1
                    ? () => _loadItems(page: _page - 1)
                    : null,
                onNext: _page < _totalPages
                    ? () => _loadItems(page: _page + 1)
                    : null,
                onPageChanged: (value) => _loadItems(page: value),
                onPageSizeChanged: (value) =>
                    _loadItems(page: 1, pageSize: value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
