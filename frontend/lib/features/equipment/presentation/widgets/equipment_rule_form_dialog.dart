import 'package:flutter/material.dart';

import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';
import 'package:mes_client/features/equipment/services/equipment_service.dart';

Future<bool?> showEquipmentRuleFormDialog({
  required BuildContext context,
  required EquipmentService service,
  required List<EquipmentLedgerItem> equipmentOptions,
  EquipmentRuleItem? item,
}) {
  return showMesLockedFormDialog<bool>(
    context: context,
    wrapMesDialog: false,
    builder: (dialogContext) {
      return EquipmentRuleFormDialog(
        service: service,
        equipmentOptions: equipmentOptions,
        item: item,
      );
    },
  );
}

class EquipmentRuleFormDialog extends StatefulWidget {
  const EquipmentRuleFormDialog({
    super.key,
    required this.service,
    required this.equipmentOptions,
    this.item,
  });

  final EquipmentService service;
  final List<EquipmentLedgerItem> equipmentOptions;
  final EquipmentRuleItem? item;

  @override
  State<EquipmentRuleFormDialog> createState() => _EquipmentRuleFormDialogState();
}

class _EquipmentRuleFormDialogState extends State<EquipmentRuleFormDialog> {
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _typeCtrl;
  late final TextEditingController _condCtrl;
  late final TextEditingController _remarkCtrl;
  late final TextEditingController _equipmentTypeCtrl;
  bool _isEnabled = true;
  int? _selectedEquipmentId;
  DateTime? _selectedEffectiveAt;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _codeCtrl = TextEditingController(text: item?.ruleCode ?? '');
    _nameCtrl = TextEditingController(text: item?.ruleName ?? '');
    _typeCtrl = TextEditingController(text: item?.ruleType ?? '');
    _condCtrl = TextEditingController(text: item?.conditionDesc ?? '');
    _remarkCtrl = TextEditingController(text: item?.remark ?? '');
    _equipmentTypeCtrl = TextEditingController(text: item?.equipmentType ?? '');
    _isEnabled = item?.isEnabled ?? true;
    _selectedEquipmentId = item?.equipmentId;
    _selectedEffectiveAt = item?.effectiveAt;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _typeCtrl.dispose();
    _condCtrl.dispose();
    _remarkCtrl.dispose();
    _equipmentTypeCtrl.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }

  String _errMsg(Object e) => e is ApiException ? e.message : e.toString();

  Future<void> _submit() async {
    if (_codeCtrl.text.trim().isEmpty || _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('规则编码和名称不能为空')));
      return;
    }
    if (_selectedEquipmentId == null && _equipmentTypeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少选择适用设备或填写设备类型')));
      return;
    }
    setState(() => _submitting = true);
    try {
      if (widget.item == null) {
        await widget.service.createEquipmentRule(
          equipmentId: _selectedEquipmentId,
          equipmentType: _equipmentTypeCtrl.text.trim().isEmpty
              ? null
              : _equipmentTypeCtrl.text.trim(),
          ruleCode: _codeCtrl.text.trim(),
          ruleName: _nameCtrl.text.trim(),
          ruleType: _typeCtrl.text.trim(),
          conditionDesc: _condCtrl.text.trim(),
          isEnabled: _isEnabled,
          effectiveAt: _selectedEffectiveAt,
          remark: _remarkCtrl.text.trim(),
        );
      } else {
        await widget.service.updateEquipmentRule(
          ruleId: widget.item!.id,
          equipmentId: _selectedEquipmentId,
          equipmentType: _equipmentTypeCtrl.text.trim().isEmpty
              ? null
              : _equipmentTypeCtrl.text.trim(),
          ruleCode: _codeCtrl.text.trim(),
          ruleName: _nameCtrl.text.trim(),
          ruleType: _typeCtrl.text.trim(),
          conditionDesc: _condCtrl.text.trim(),
          isEnabled: _isEnabled,
          effectiveAt: _selectedEffectiveAt,
          remark: _remarkCtrl.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errMsg(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MesDialog(
      title: Text(widget.item == null ? '新增设备规则' : '编辑设备规则'),
      width: 760,
      content: SizedBox(
        key: const ValueKey('equipment-rule-form-dialog'),
        width: 760,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('规则信息', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextField(controller: _codeCtrl, decoration: const InputDecoration(labelText: '规则编码 *')),
                  const SizedBox(height: 8),
                  TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '规则名称 *')),
                  const SizedBox(height: 8),
                  TextField(controller: _typeCtrl, decoration: const InputDecoration(labelText: '规则类型')),
                  const SizedBox(height: 8),
                  TextField(controller: _condCtrl, decoration: const InputDecoration(labelText: '触发条件'), maxLines: 3),
                  const SizedBox(height: 8),
                  TextField(controller: _remarkCtrl, decoration: const InputDecoration(labelText: '备注')),
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
                    Text('适用范围', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('启用'),
                      value: _isEnabled,
                      onChanged: _submitting ? null : (v) => setState(() => _isEnabled = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int?>(
                      initialValue: _selectedEquipmentId,
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('适用全部设备')),
                        ...widget.equipmentOptions.map(
                          (entry) => DropdownMenuItem<int?>(
                            value: entry.id,
                            child: Text('${entry.code} ${entry.name}'),
                          ),
                        ),
                      ],
                      onChanged: _submitting ? null : (value) => setState(() => _selectedEquipmentId = value),
                      decoration: const InputDecoration(labelText: '适用设备'),
                    ),
                    const SizedBox(height: 8),
                    TextField(controller: _equipmentTypeCtrl, decoration: const InputDecoration(labelText: '适用设备类型')),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _submitting
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedEffectiveAt ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() => _selectedEffectiveAt = picked);
                              }
                            },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: '生效时间'),
                        child: Text(_formatDateTime(_selectedEffectiveAt)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _submitting ? null : () => Navigator.pop(context, false), child: const Text('取消')),
        FilledButton(onPressed: _submitting ? null : _submit, child: const Text('保存')),
      ],
    );
  }
}
