import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/equipment_models.dart';
import '../services/api_exception.dart';
import '../services/equipment_service.dart';
import '../widgets/adaptive_table_container.dart';

class MaintenancePlanPage extends StatefulWidget {
  const MaintenancePlanPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canWrite,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canWrite;

  @override
  State<MaintenancePlanPage> createState() => _MaintenancePlanPageState();
}

class _MaintenancePlanPageState extends State<MaintenancePlanPage> {
  late final EquipmentService _equipmentService;

  bool _loading = false;
  String _message = '';
  int _total = 0;
  List<MaintenancePlanItem> _plans = const [];
  List<EquipmentLedgerItem> _equipmentOptions = const [];
  List<MaintenanceItemEntry> _itemOptions = const [];
  int? _equipmentFilterId;
  int? _itemFilterId;

  @override
  void initState() {
    super.initState();
    _equipmentService = EquipmentService(widget.session);
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

  Future<void> _loadAll({bool reloadOptions = false}) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _message = '';
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
        _equipmentOptions = equipmentResult.items;
        _itemOptions = itemResult.items;

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
        page: 1,
        pageSize: 200,
        equipmentId: _equipmentFilterId,
        itemId: _itemFilterId,
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
        _message = '加载保养计划失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<DateTime?> _pickDate({
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2000, 1, 1),
      lastDate: lastDate ?? DateTime(2100, 12, 31),
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
    );
  }

  Future<void> _showPlanEditDialog({MaintenancePlanItem? plan}) async {
    if (!mounted) {
      return;
    }
    final pageContext = context;
    if (_equipmentOptions.isEmpty || _itemOptions.isEmpty) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(content: Text('请先维护设备台账和保养项目')),
      );
      return;
    }

    final isCreate = plan == null;
    final formKey = GlobalKey<FormState>();
    final cycleController = TextEditingController(
      text: (plan?.cycleDays ?? 30).toString(),
    );
    final durationController = TextEditingController(
      text: (plan?.estimatedDurationMinutes ?? 60).toString(),
    );
    var selectedEquipmentId = plan?.equipmentId ?? _equipmentOptions.first.id;
    var selectedItemId = plan?.itemId ?? _itemOptions.first.id;
    var startDate = plan?.startDate ?? DateTime.now();
    var nextDueDate = plan?.nextDueDate;

    final saved = await showDialog<bool>(
      context: pageContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setInnerState) {
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
                          key: ValueKey(
                            'eq-$selectedEquipmentId-${_equipmentOptions.length}',
                          ),
                          initialValue: selectedEquipmentId,
                          items: _equipmentOptions
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
                          key: ValueKey(
                            'item-$selectedItemId-${_itemOptions.length}',
                          ),
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
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: cycleController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '周期(天)',
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
                                  labelText: '预计时长(分钟)',
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
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await _pickDate(
                                    initialDate: startDate,
                                  );
                                  if (picked != null) {
                                    setInnerState(() {
                                      startDate = picked;
                                      nextDueDate ??= picked;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.calendar_today),
                                label: Text('起始日期：${_formatDate(startDate)}'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final initial = nextDueDate ?? startDate;
                                  final picked = await _pickDate(
                                    initialDate: initial,
                                  );
                                  if (picked != null) {
                                    setInnerState(() {
                                      nextDueDate = picked;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.event_available),
                                label: Text(
                                  '下次到期：${nextDueDate == null ? '-' : _formatDate(nextDueDate!)}',
                                ),
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
                    try {
                      final cycleDays = int.parse(cycleController.text.trim());
                      final durationMinutes = int.parse(
                        durationController.text.trim(),
                      );
                      if (isCreate) {
                        await _equipmentService.createMaintenancePlan(
                          equipmentId: selectedEquipmentId,
                          itemId: selectedItemId,
                          cycleDays: cycleDays,
                          startDate: startDate,
                          estimatedDurationMinutes: durationMinutes,
                          nextDueDate: nextDueDate,
                          defaultExecutorUserId: null,
                        );
                      } else {
                        await _equipmentService.updateMaintenancePlan(
                          planId: plan.id,
                          equipmentId: selectedEquipmentId,
                          itemId: selectedItemId,
                          cycleDays: cycleDays,
                          startDate: startDate,
                          estimatedDurationMinutes: durationMinutes,
                          nextDueDate: nextDueDate,
                          defaultExecutorUserId: null,
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
                          SnackBar(content: Text('保存保养计划失败：${_errorMessage(error)}')),
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

    cycleController.dispose();
    durationController.dispose();

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
        SnackBar(content: Text('更新计划状态失败：${_errorMessage(error)}')),
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
                  ? '执行单已生成（ID: ${result.workOrderId}）'
                  : '已存在待执行单（ID: ${result.workOrderId}）',
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
        SnackBar(content: Text('生成执行单失败：${_errorMessage(error)}')),
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
                '保养计划',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '刷新',
                onPressed: _loading ? null : () => _loadAll(reloadOptions: true),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  key: ValueKey('filter-eq-${_equipmentFilterId ?? 0}-${_equipmentOptions.length}'),
                  initialValue: _equipmentFilterId,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('全部设备'),
                    ),
                    ..._equipmentOptions.map(
                      (entry) => DropdownMenuItem<int?>(
                        value: entry.id,
                        child: Text(entry.name),
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
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  key: ValueKey('filter-item-${_itemFilterId ?? 0}-${_itemOptions.length}'),
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
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _loadAll,
                icon: const Icon(Icons.search),
                label: const Text('查询'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: (_loading || !widget.canWrite)
                    ? null
                    : () => _showPlanEditDialog(),
                icon: const Icon(Icons.add),
                label: const Text('新增计划'),
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
                : _plans.isEmpty
                ? const Center(child: Text('暂无保养计划'))
                : Card(
                    child: AdaptiveTableContainer(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('设备')),
                          DataColumn(label: Text('项目')),
                          DataColumn(label: Text('周期(天)')),
                          DataColumn(label: Text('起始日期')),
                          DataColumn(label: Text('下次到期')),
                          DataColumn(label: Text('执行人')),
                          DataColumn(label: Text('状态')),
                          DataColumn(label: Text('操作')),
                        ],
                        rows: _plans.map((plan) {
                          return DataRow(
                            cells: [
                              DataCell(Text(plan.equipmentName)),
                              DataCell(Text(plan.itemName)),
                              DataCell(Text('${plan.cycleDays}')),
                              DataCell(Text(_formatDate(plan.startDate))),
                              DataCell(Text(_formatDate(plan.nextDueDate))),
                              DataCell(Text(plan.defaultExecutorUsername ?? '-')),
                              DataCell(Text(plan.isEnabled ? '启用' : '停用')),
                              DataCell(
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed: widget.canWrite
                                          ? () => _showPlanEditDialog(plan: plan)
                                          : null,
                                      child: const Text('编辑'),
                                    ),
                                    TextButton(
                                      onPressed: widget.canWrite
                                          ? () => _togglePlan(plan)
                                          : null,
                                      child: Text(plan.isEnabled ? '停用' : '启用'),
                                    ),
                                    TextButton(
                                      onPressed: (widget.canWrite && plan.isEnabled)
                                          ? () => _generateWorkOrder(plan)
                                          : null,
                                      child: const Text('生成执行单'),
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
