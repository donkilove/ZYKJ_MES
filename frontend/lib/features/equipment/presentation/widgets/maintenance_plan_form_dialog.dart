import 'package:flutter/material.dart';

import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';
import 'package:mes_client/features/equipment/services/equipment_service.dart';

Future<bool?> showMaintenancePlanFormDialog({
  required BuildContext context,
  required EquipmentService equipmentService,
  required List<EquipmentLedgerItem> equipmentOptions,
  required List<MaintenanceItemEntry> itemOptions,
  required List<CraftStageItem> stageOptions,
  required List<EquipmentOwnerOption> ownerOptions,
  MaintenancePlanItem? plan,
}) {
  return showMesLockedFormDialog<bool>(
    context: context,
    wrapMesDialog: false,
    builder: (dialogContext) {
      return MaintenancePlanFormDialog(
        equipmentService: equipmentService,
        equipmentOptions: equipmentOptions,
        itemOptions: itemOptions,
        stageOptions: stageOptions,
        ownerOptions: ownerOptions,
        plan: plan,
      );
    },
  );
}

class MaintenancePlanFormDialog extends StatefulWidget {
  const MaintenancePlanFormDialog({
    super.key,
    required this.equipmentService,
    required this.equipmentOptions,
    required this.itemOptions,
    required this.stageOptions,
    required this.ownerOptions,
    this.plan,
  });

  final EquipmentService equipmentService;
  final List<EquipmentLedgerItem> equipmentOptions;
  final List<MaintenanceItemEntry> itemOptions;
  final List<CraftStageItem> stageOptions;
  final List<EquipmentOwnerOption> ownerOptions;
  final MaintenancePlanItem? plan;

  @override
  State<MaintenancePlanFormDialog> createState() =>
      _MaintenancePlanFormDialogState();
}

class _MaintenancePlanFormDialogState extends State<MaintenancePlanFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late int _selectedEquipmentId;
  late int _selectedItemId;
  late String _selectedExecutionProcessCode;
  late DateTime _selectedStartDate;
  DateTime? _selectedNextDueDate;
  int? _selectedDefaultExecutorUserId;
  late final TextEditingController _cycleDaysController;
  late final TextEditingController _estimatedDurationController;
  bool _submitting = false;

  bool get _isCreate => widget.plan == null;

  @override
  void initState() {
    super.initState();
    _selectedEquipmentId =
        widget.plan?.equipmentId ?? widget.equipmentOptions.first.id;
    _selectedItemId = widget.plan?.itemId ?? widget.itemOptions.first.id;
    _selectedExecutionProcessCode =
        widget.plan?.executionProcessCode ?? widget.stageOptions.first.code;
    if (!widget.stageOptions.any(
      (stage) => stage.code == _selectedExecutionProcessCode,
    )) {
      _selectedExecutionProcessCode = widget.stageOptions.first.code;
    }
    _selectedStartDate = widget.plan?.startDate ?? DateTime.now();
    _selectedNextDueDate = widget.plan?.nextDueDate;
    _selectedDefaultExecutorUserId = widget.plan?.defaultExecutorUserId;
    _cycleDaysController = TextEditingController(
      text: widget.plan?.cycleDays != null ? '${widget.plan!.cycleDays}' : '',
    );
    _estimatedDurationController = TextEditingController(
      text: widget.plan?.estimatedDurationMinutes != null
          ? '${widget.plan!.estimatedDurationMinutes}'
          : '',
    );
  }

  @override
  void dispose() {
    _cycleDaysController.dispose();
    _estimatedDurationController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final cycleDaysText = _cycleDaysController.text.trim();
    final cycleDays = cycleDaysText.isNotEmpty ? int.tryParse(cycleDaysText) : null;
    final durationText = _estimatedDurationController.text.trim();
    final duration = durationText.isNotEmpty ? int.tryParse(durationText) : null;
    setState(() => _submitting = true);
    try {
      if (_isCreate) {
        await widget.equipmentService.createMaintenancePlan(
          equipmentId: _selectedEquipmentId,
          itemId: _selectedItemId,
          executionProcessCode: _selectedExecutionProcessCode,
          startDate: _selectedStartDate,
          estimatedDurationMinutes: duration,
          nextDueDate: _selectedNextDueDate,
          defaultExecutorUserId: _selectedDefaultExecutorUserId,
          cycleDays: cycleDays,
        );
      } else {
        await widget.equipmentService.updateMaintenancePlan(
          planId: widget.plan!.id,
          equipmentId: _selectedEquipmentId,
          itemId: _selectedItemId,
          executionProcessCode: _selectedExecutionProcessCode,
          startDate: _selectedStartDate,
          estimatedDurationMinutes: duration,
          nextDueDate: _selectedNextDueDate,
          defaultExecutorUserId: _selectedDefaultExecutorUserId,
          cycleDays: cycleDays,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存保养计划失败: ${_errorMessage(error)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedItem = widget.itemOptions.firstWhere(
      (entry) => entry.id == _selectedItemId,
      orElse: () => widget.itemOptions.first,
    );
    return MesDialog(
      title: Text(_isCreate ? '新增保养计划' : '编辑保养计划'),
      width: 820,
      content: SizedBox(
        key: const ValueKey('maintenance-plan-form-dialog'),
        width: 820,
        child: Form(
          key: _formKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '计划配置',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedEquipmentId,
                      items: widget.equipmentOptions
                          .map(
                            (entry) => DropdownMenuItem<int>(
                              value: entry.id,
                              child: Text('${entry.code} - ${entry.name}'),
                            ),
                          )
                          .toList(),
                      onChanged: _submitting
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() => _selectedEquipmentId = value);
                            },
                      decoration: const InputDecoration(
                        labelText: '设备',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedItemId,
                      items: widget.itemOptions
                          .map(
                            (entry) => DropdownMenuItem<int>(
                              value: entry.id,
                              child: Text(entry.name),
                            ),
                          )
                          .toList(),
                      onChanged: _submitting
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() => _selectedItemId = value);
                            },
                      decoration: const InputDecoration(
                        labelText: '保养项目',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedExecutionProcessCode,
                      items: widget.stageOptions
                          .map(
                            (stage) => DropdownMenuItem<String>(
                              value: stage.code,
                              child: Text('${stage.name} (${stage.code})'),
                            ),
                          )
                          .toList(),
                      onChanged: _submitting
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() => _selectedExecutionProcessCode = value);
                            },
                      decoration: const InputDecoration(
                        labelText: '执行工段',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cycleDaysController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '周期(天，留空使用项目默认: ${selectedItem.defaultCycleDays}天)',
                        border: const OutlineInputBorder(),
                      ),
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
                    TextFormField(
                      controller: _estimatedDurationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '预计时长(分钟，可选)',
                        border: OutlineInputBorder(),
                      ),
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
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '执行与排期',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _submitting
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedStartDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2099),
                                );
                                if (picked != null) {
                                  setState(() => _selectedStartDate = picked);
                                }
                              },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '起始日期',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(_formatDate(_selectedStartDate)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _submitting
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedNextDueDate ?? _selectedStartDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2099),
                                );
                                if (picked != null) {
                                  setState(() => _selectedNextDueDate = picked);
                                }
                              },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '下次到期日（可选）',
                            helperText: '留空时由系统按开始日期与周期自动计算',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _selectedNextDueDate == null
                                ? '未指定'
                                : _formatDate(_selectedNextDueDate!),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _selectedNextDueDate == null
                              ? null
                              : () => setState(() => _selectedNextDueDate = null),
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('改为自动计算'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        initialValue: _selectedDefaultExecutorUserId,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('(不指定)'),
                          ),
                          ...widget.ownerOptions.map(
                            (u) => DropdownMenuItem<int?>(
                              value: u.userId,
                              child: Text(u.displayName),
                            ),
                          ),
                        ],
                        onChanged: _submitting
                            ? null
                            : (value) => setState(() => _selectedDefaultExecutorUserId = value),
                        decoration: const InputDecoration(
                          labelText: '默认执行人',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '保存中...' : '保存'),
        ),
      ],
    );
  }
}
