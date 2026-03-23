import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/craft_models.dart';
import '../models/equipment_models.dart';
import '../services/api_exception.dart';
import '../services/craft_service.dart';
import '../services/equipment_service.dart';
import '../widgets/adaptive_table_container.dart';
import '../widgets/locked_form_dialog.dart';
import '../widgets/simple_pagination_bar.dart';
import '../widgets/unified_list_table_header_style.dart';

class MaintenancePlanPage extends StatefulWidget {
  const MaintenancePlanPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canWrite,
    this.equipmentService,
    this.craftService,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canWrite;
  final EquipmentService? equipmentService;
  final CraftService? craftService;

  @override
  State<MaintenancePlanPage> createState() => _MaintenancePlanPageState();
}

class _MaintenancePlanPageState extends State<MaintenancePlanPage> {
  late final EquipmentService _equipmentService;
  late final CraftService _craftService;

  bool _loading = false;
  bool _exporting = false;
  String _message = '';
  int _page = 1;
  int _pageSize = 20;
  int _total = 0;
  List<MaintenancePlanItem> _plans = const [];
  List<EquipmentLedgerItem> _equipmentOptions = const [];
  List<MaintenanceItemEntry> _itemOptions = const [];
  List<CraftStageItem> _stageOptions = const [];
  List<EquipmentOwnerOption> _ownerOptions = const [];
  int? _equipmentFilterId;
  int? _itemFilterId;
  bool? _enabledFilter;
  String? _executionStageCodeFilter;
  int? _defaultExecutorFilterId;

  static const List<int> _pageSizeOptions = [20, 50, 100];

  int get _totalPages => _total == 0 ? 1 : (_total / _pageSize).ceil();

  @override
  void initState() {
    super.initState();
    _equipmentService =
        widget.equipmentService ?? EquipmentService(widget.session);
    _craftService = widget.craftService ?? CraftService(widget.session);
    _loadAll(reloadOptions: true);
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

  Future<void> _loadAll({
    bool reloadOptions = false,
    int? page,
    int? pageSize,
  }) async {
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
      if (reloadOptions) {
        final equipmentResult = await _equipmentService.listEquipment(
          page: 1,
          pageSize: 200,
          enabled: true,
        );
        final itemResult = await _equipmentService.listMaintenanceItems(
          page: 1,
          pageSize: 200,
          enabled: true,
        );
        final stageResult = await _craftService.listStages(
          page: 1,
          pageSize: 500,
          enabled: true,
        );
        _equipmentOptions = equipmentResult.items;
        _itemOptions = itemResult.items;
        try {
          _ownerOptions = await _equipmentService.listAllOwners();
        } catch (_) {}
        _stageOptions = [...stageResult.items]
          ..sort((a, b) {
            final orderCompare = a.sortOrder.compareTo(b.sortOrder);
            if (orderCompare != 0) {
              return orderCompare;
            }
            return a.id.compareTo(b.id);
          });

        if (_equipmentFilterId != null &&
            !_equipmentOptions.any((e) => e.id == _equipmentFilterId)) {
          _equipmentFilterId = null;
        }
        if (_itemFilterId != null &&
            !_itemOptions.any((e) => e.id == _itemFilterId)) {
          _itemFilterId = null;
        }
      }

      final result = await _equipmentService.listMaintenancePlans(
        page: nextPage,
        pageSize: nextPageSize,
        equipmentId: _equipmentFilterId,
        itemId: _itemFilterId,
        enabled: _enabledFilter,
        executionProcessCode: _executionStageCodeFilter,
        defaultExecutorUserId: _defaultExecutorFilterId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _plans = result.items;
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
        _message = '加载保养计划失败: ${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showPlanEditDialog({MaintenancePlanItem? plan}) async {
    if (!mounted) {
      return;
    }
    final pageContext = context;
    if (_equipmentOptions.isEmpty ||
        _itemOptions.isEmpty ||
        _stageOptions.isEmpty) {
      ScaffoldMessenger.of(
        pageContext,
      ).showSnackBar(const SnackBar(content: Text('请先维护设备台账、保养项目和工艺工段')));
      return;
    }

    final isCreate = plan == null;
    final formKey = GlobalKey<FormState>();
    var selectedEquipmentId = plan?.equipmentId ?? _equipmentOptions.first.id;
    var selectedItemId = plan?.itemId ?? _itemOptions.first.id;
    var selectedExecutionProcessCode =
        plan?.executionProcessCode ?? _stageOptions.first.code;
    if (!_stageOptions.any(
      (stage) => stage.code == selectedExecutionProcessCode,
    )) {
      selectedExecutionProcessCode = _stageOptions.first.code;
    }
    var selectedStartDate = plan?.startDate ?? DateTime.now();
    DateTime? selectedNextDueDate = plan?.nextDueDate;
    var selectedDefaultExecutorUserId = plan?.defaultExecutorUserId;
    final cycleDaysController = TextEditingController(
      text: plan?.cycleDays != null ? '${plan!.cycleDays}' : '',
    );
    final estimatedDurationController = TextEditingController(
      text: plan?.estimatedDurationMinutes != null
          ? '${plan!.estimatedDurationMinutes}'
          : '',
    );

    final saved = await showLockedFormDialog<bool>(
      context: pageContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setInnerState) {
            final selectedItem = _itemOptions.firstWhere(
              (entry) => entry.id == selectedItemId,
              orElse: () => _itemOptions.first,
            );
            return AlertDialog(
              title: Text(isCreate ? '新增保养计划' : '编辑保养计划'),
              content: SizedBox(
                width: 680,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: selectedEquipmentId,
                          items: _equipmentOptions
                              .map(
                                (entry) => DropdownMenuItem<int>(
                                  value: entry.id,
                                  child: Text('${entry.code} - ${entry.name}'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setInnerState(() {
                              selectedEquipmentId = value;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: '设备',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: selectedItemId,
                          items: _itemOptions
                              .map(
                                (entry) => DropdownMenuItem<int>(
                                  value: entry.id,
                                  child: Text(entry.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setInnerState(() {
                              selectedItemId = value;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: '保养项目',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedExecutionProcessCode,
                          items: _stageOptions
                              .map(
                                (stage) => DropdownMenuItem<String>(
                                  value: stage.code,
                                  child: Text('${stage.name} (${stage.code})'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setInnerState(() {
                              selectedExecutionProcessCode = value;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: '执行工段',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: cycleDaysController,
                          decoration: InputDecoration(
                            labelText:
                                '周期(天，留空使用项目默认: ${selectedItem.defaultCycleDays}天)',
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty) {
                              final n = int.tryParse(value.trim());
                              if (n == null || n < 1 || n > 3650) {
                                return '请输入1-3650之间的整数';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: innerContext,
                              initialDate: selectedStartDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2099),
                            );
                            if (picked != null) {
                              setInnerState(() {
                                selectedStartDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: '起始日期',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(_formatDate(selectedStartDate)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: innerContext,
                              initialDate:
                                  selectedNextDueDate ?? selectedStartDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2099),
                            );
                            if (picked != null) {
                              setInnerState(() {
                                selectedNextDueDate = picked;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: '下次到期日（可选）',
                              helperText: '留空时由系统按开始日期与周期自动计算',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              selectedNextDueDate == null
                                  ? '未指定'
                                  : _formatDate(selectedNextDueDate!),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: selectedNextDueDate == null
                                ? null
                                : () {
                                    setInnerState(() {
                                      selectedNextDueDate = null;
                                    });
                                  },
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('改为自动计算'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: estimatedDurationController,
                          decoration: const InputDecoration(
                            labelText: '预计时长(分钟，可选)',
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
                        DropdownButtonFormField<int?>(
                          initialValue: selectedDefaultExecutorUserId,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('(不指定)'),
                            ),
                            ..._ownerOptions.map(
                              (u) => DropdownMenuItem<int?>(
                                value: u.userId,
                                child: Text(u.displayName),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setInnerState(() {
                              selectedDefaultExecutorUserId = value;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: '默认执行人',
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
                    final cycleDaysText = cycleDaysController.text.trim();
                    final cycleDays = cycleDaysText.isNotEmpty
                        ? int.tryParse(cycleDaysText)
                        : null;
                    final durationText = estimatedDurationController.text
                        .trim();
                    final duration = durationText.isNotEmpty
                        ? int.tryParse(durationText)
                        : null;
                    try {
                      if (isCreate) {
                        await _equipmentService.createMaintenancePlan(
                          equipmentId: selectedEquipmentId,
                          itemId: selectedItemId,
                          executionProcessCode: selectedExecutionProcessCode,
                          startDate: selectedStartDate,
                          estimatedDurationMinutes: duration,
                          nextDueDate: selectedNextDueDate,
                          defaultExecutorUserId: selectedDefaultExecutorUserId,
                          cycleDays: cycleDays,
                        );
                      } else {
                        await _equipmentService.updateMaintenancePlan(
                          planId: plan.id,
                          equipmentId: selectedEquipmentId,
                          itemId: selectedItemId,
                          executionProcessCode: selectedExecutionProcessCode,
                          startDate: selectedStartDate,
                          estimatedDurationMinutes: duration,
                          nextDueDate: selectedNextDueDate,
                          defaultExecutorUserId: selectedDefaultExecutorUserId,
                          cycleDays: cycleDays,
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
                            content: Text('保存保养计划失败: ${_errorMessage(error)}'),
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

    cycleDaysController.dispose();
    estimatedDurationController.dispose();

    if (saved == true) {
      await _loadAll();
    }
  }

  Future<void> _togglePlan(MaintenancePlanItem plan) async {
    try {
      await _equipmentService.toggleMaintenancePlan(
        planId: plan.id,
        enabled: !plan.isEnabled,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(plan.isEnabled ? '计划已停用' : '计划已启用')),
        );
      }
      await _loadAll();
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新计划状态失败: ${_errorMessage(error)}')),
      );
    }
  }

  Future<void> _generateWorkOrder(MaintenancePlanItem plan) async {
    try {
      final result = await _equipmentService.generateMaintenancePlan(
        planId: plan.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.created
                  ? '执行单已生成 (ID: ${result.workOrderId})'
                  : '已存在待执行单 (ID: ${result.workOrderId})',
            ),
          ),
        );
      }
      await _loadAll();
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成执行单失败: ${_errorMessage(error)}')),
      );
    }
  }

  Future<void> _deletePlan(MaintenancePlanItem plan) async {
    if (!mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除保养计划'),
        content: Text(
          '确认删除计划“${plan.equipmentName} / ${plan.itemName}”吗？此操作不可恢复。',
        ),
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
      await _equipmentService.deleteMaintenancePlan(planId: plan.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保养计划已删除')));
      }
      await _loadAll();
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除保养计划失败: ${_errorMessage(error)}')),
      );
    }
  }

  Future<void> _exportCsv() async {
    setState(() {
      _exporting = true;
      _message = '';
    });
    try {
      final csvBase64 = await _equipmentService.exportMaintenancePlans(
        equipmentId: _equipmentFilterId,
        itemId: _itemFilterId,
        enabled: _enabledFilter,
        executionProcessCode: _executionStageCodeFilter,
        defaultExecutorUserId: _defaultExecutorFilterId,
      );
      if (!mounted) return;
      if (csvBase64.isEmpty) {
        setState(() => _message = '导出失败：服务端返回空数据');
        return;
      }
      final bytes = base64Decode(csvBase64);
      final location = await getSaveLocation(
        suggestedName: 'maintenance_plans.csv',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (location == null || !mounted) return;
      await XFile.fromData(
        bytes,
        mimeType: 'text/csv',
        name: 'maintenance_plans.csv',
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
                '保养计划',
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
                    : () => _loadAll(reloadOptions: true),
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
                    width: 320,
                    child: DropdownButtonFormField<int?>(
                      initialValue: _equipmentFilterId,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('全部设备'),
                        ),
                        ..._equipmentOptions.map(
                          (entry) => DropdownMenuItem<int?>(
                            value: entry.id,
                            child: Text('${entry.code} - ${entry.name}'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _equipmentFilterId = value;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: '设备筛选',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: DropdownButtonFormField<int?>(
                      initialValue: _itemFilterId,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('全部项目'),
                        ),
                        ..._itemOptions.map(
                          (entry) => DropdownMenuItem<int?>(
                            value: entry.id,
                            child: Text(entry.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _itemFilterId = value;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: '项目筛选',
                        border: OutlineInputBorder(),
                      ),
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
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _executionStageCodeFilter,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('全部执行工段'),
                        ),
                        ..._stageOptions.map(
                          (entry) => DropdownMenuItem<String?>(
                            value: entry.code,
                            child: Text(entry.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _executionStageCodeFilter = value);
                      },
                      decoration: const InputDecoration(
                        labelText: '执行工段',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<int?>(
                      initialValue: _defaultExecutorFilterId,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('全部默认执行人'),
                        ),
                        ..._ownerOptions.map(
                          (entry) => DropdownMenuItem<int?>(
                            value: entry.userId,
                            child: Text(entry.displayName),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _defaultExecutorFilterId = value);
                      },
                      decoration: const InputDecoration(
                        labelText: '默认执行人',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _loading ? null : () => _loadAll(page: 1),
                    icon: const Icon(Icons.search),
                    label: const Text('查询'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _equipmentFilterId = null;
                              _itemFilterId = null;
                              _enabledFilter = null;
                              _executionStageCodeFilter = null;
                              _defaultExecutorFilterId = null;
                            });
                            _loadAll(page: 1, reloadOptions: true);
                          },
                    style: toolbarButtonStyle,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('重置筛选'),
                  ),
                  if (widget.canWrite)
                    FilledButton.icon(
                      onPressed: _loading ? null : () => _showPlanEditDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('新增计划'),
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
                : _plans.isEmpty
                ? const Center(child: Text('暂无保养计划'))
                : Card(
                    clipBehavior: Clip.antiAlias,
                    child: AdaptiveTableContainer(
                      minTableWidth: 1700,
                      child: UnifiedListTableHeaderStyle.wrap(
                        theme: theme,
                        child: DataTable(
                          dataRowMinHeight: 60,
                          dataRowMaxHeight: 80,
                          columns: [
                            UnifiedListTableHeaderStyle.column(context, '设备'),
                            UnifiedListTableHeaderStyle.column(context, '保养项目'),
                            UnifiedListTableHeaderStyle.column(context, '执行工段'),
                            UnifiedListTableHeaderStyle.column(context, '周期天数'),
                            UnifiedListTableHeaderStyle.column(context, '开始日期'),
                            UnifiedListTableHeaderStyle.column(
                              context,
                              '下次到期日',
                            ),
                            UnifiedListTableHeaderStyle.column(
                              context,
                              '默认执行人',
                            ),
                            UnifiedListTableHeaderStyle.column(context, '预计时长'),
                            UnifiedListTableHeaderStyle.column(context, '创建时间'),
                            UnifiedListTableHeaderStyle.column(context, '更新时间'),
                            UnifiedListTableHeaderStyle.column(context, '状态'),
                            UnifiedListTableHeaderStyle.column(
                              context,
                              '操作',
                              textAlign: TextAlign.center,
                            ),
                          ],
                          rows: _plans.map((plan) {
                            return DataRow(
                              cells: [
                                DataCell(Text(plan.equipmentName)),
                                DataCell(Text(plan.itemName)),
                                DataCell(Text(plan.executionProcessName)),
                                DataCell(Text('${plan.cycleDays}')),
                                DataCell(Text(_formatDate(plan.startDate))),
                                DataCell(Text(_formatDate(plan.nextDueDate))),
                                DataCell(
                                  Text(plan.defaultExecutorUsername ?? '-'),
                                ),
                                DataCell(
                                  Text(
                                    plan.estimatedDurationMinutes == null
                                        ? '-'
                                        : '${plan.estimatedDurationMinutes} 分钟',
                                  ),
                                ),
                                DataCell(Text(_formatDate(plan.createdAt))),
                                DataCell(Text(_formatDate(plan.updatedAt))),
                                DataCell(Text(plan.isEnabled ? '启用' : '停用')),
                                DataCell(
                                  widget.canWrite
                                      ? UnifiedListTableHeaderStyle.actionMenuButton<
                                          String
                                        >(
                                          theme: theme,
                                          onSelected: (action) {
                                            switch (action) {
                                              case 'edit':
                                                _showPlanEditDialog(plan: plan);
                                                return;
                                              case 'toggle':
                                                _togglePlan(plan);
                                                return;
                                              case 'delete':
                                                _deletePlan(plan);
                                                return;
                                              case 'generate':
                                                _generateWorkOrder(plan);
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
                                                plan.isEnabled ? '停用' : '启用',
                                              ),
                                            ),
                                            const PopupMenuItem<String>(
                                              value: 'delete',
                                              child: Text('删除'),
                                            ),
                                            if (plan.isEnabled)
                                              const PopupMenuItem<String>(
                                                value: 'generate',
                                                child: Text('生成执行单'),
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
                onPrevious: _page > 1 ? () => _loadAll(page: _page - 1) : null,
                onNext: _page < _totalPages
                    ? () => _loadAll(page: _page + 1)
                    : null,
                onPageChanged: (value) => _loadAll(page: value),
                onPageSizeChanged: (value) =>
                    _loadAll(page: 1, pageSize: value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
