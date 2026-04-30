import 'package:flutter/material.dart';

import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';
import 'package:mes_client/features/equipment/services/equipment_service.dart';

Future<bool?> showEquipmentRuntimeParameterFormDialog({
  required BuildContext context,
  required EquipmentService service,
  required List<EquipmentLedgerItem> equipmentOptions,
  EquipmentRuntimeParameterItem? item,
}) {
  return showMesLockedFormDialog<bool>(
    context: context,
    wrapMesDialog: false,
    builder: (dialogContext) {
      return EquipmentRuntimeParameterFormDialog(
        service: service,
        equipmentOptions: equipmentOptions,
        item: item,
      );
    },
  );
}

class EquipmentRuntimeParameterFormDialog extends StatefulWidget {
  const EquipmentRuntimeParameterFormDialog({
    super.key,
    required this.service,
    required this.equipmentOptions,
    this.item,
  });

  final EquipmentService service;
  final List<EquipmentLedgerItem> equipmentOptions;
  final EquipmentRuntimeParameterItem? item;

  @override
  State<EquipmentRuntimeParameterFormDialog> createState() =>
      _EquipmentRuntimeParameterFormDialogState();
}

class _EquipmentRuntimeParameterFormDialogState
    extends State<EquipmentRuntimeParameterFormDialog> {
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _stdCtrl;
  late final TextEditingController _upperCtrl;
  late final TextEditingController _lowerCtrl;
  late final TextEditingController _remarkCtrl;
  late final TextEditingController _equipmentTypeCtrl;
  int? _selectedEquipmentId;
  DateTime? _selectedEffectiveAt;
  bool _isEnabled = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _codeCtrl = TextEditingController(text: item?.paramCode ?? '');
    _nameCtrl = TextEditingController(text: item?.paramName ?? '');
    _unitCtrl = TextEditingController(text: item?.unit ?? '');
    _stdCtrl = TextEditingController(text: item?.standardValue ?? '');
    _upperCtrl = TextEditingController(text: item?.upperLimit ?? '');
    _lowerCtrl = TextEditingController(text: item?.lowerLimit ?? '');
    _remarkCtrl = TextEditingController(text: item?.remark ?? '');
    _equipmentTypeCtrl = TextEditingController(text: item?.equipmentType ?? '');
    _selectedEquipmentId = item?.equipmentId;
    _selectedEffectiveAt = item?.effectiveAt;
    _isEnabled = item?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _stdCtrl.dispose();
    _upperCtrl.dispose();
    _lowerCtrl.dispose();
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
      ).showSnackBar(const SnackBar(content: Text('参数编码和名称不能为空')));
      return;
    }
    final standardValue = _stdCtrl.text.trim();
    final upperLimit = _upperCtrl.text.trim();
    final lowerLimit = _lowerCtrl.text.trim();
    final parsedStandard = standardValue.isEmpty ? null : double.tryParse(standardValue);
    final parsedUpper = upperLimit.isEmpty ? null : double.tryParse(upperLimit);
    final parsedLower = lowerLimit.isEmpty ? null : double.tryParse(lowerLimit);
    if ((standardValue.isNotEmpty && parsedStandard == null) ||
        (upperLimit.isNotEmpty && parsedUpper == null) ||
        (lowerLimit.isNotEmpty && parsedLower == null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('默认值、上限、下限必须为有效数字')));
      return;
    }
    if (parsedUpper != null && parsedLower != null && parsedLower > parsedUpper) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('下限不能大于上限')));
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
        await widget.service.createRuntimeParameter(
          equipmentId: _selectedEquipmentId,
          equipmentType: _equipmentTypeCtrl.text.trim().isEmpty ? null : _equipmentTypeCtrl.text.trim(),
          paramCode: _codeCtrl.text.trim(),
          paramName: _nameCtrl.text.trim(),
          unit: _unitCtrl.text.trim(),
          standardValue: standardValue.isEmpty ? null : standardValue,
          upperLimit: upperLimit.isEmpty ? null : upperLimit,
          lowerLimit: lowerLimit.isEmpty ? null : lowerLimit,
          effectiveAt: _selectedEffectiveAt,
          isEnabled: _isEnabled,
          remark: _remarkCtrl.text.trim(),
        );
      } else {
        await widget.service.updateRuntimeParameter(
          paramId: widget.item!.id,
          equipmentId: _selectedEquipmentId,
          equipmentType: _equipmentTypeCtrl.text.trim().isEmpty ? null : _equipmentTypeCtrl.text.trim(),
          paramCode: _codeCtrl.text.trim(),
          paramName: _nameCtrl.text.trim(),
          unit: _unitCtrl.text.trim(),
          standardValue: standardValue.isEmpty ? null : standardValue,
          upperLimit: upperLimit.isEmpty ? null : upperLimit,
          lowerLimit: lowerLimit.isEmpty ? null : lowerLimit,
          effectiveAt: _selectedEffectiveAt,
          isEnabled: _isEnabled,
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
      title: Text(widget.item == null ? '新增运行参数' : '编辑运行参数'),
      width: 800,
      content: SizedBox(
        key: const ValueKey('equipment-runtime-parameter-form-dialog'),
        width: 800,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('参数信息', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextField(controller: _codeCtrl, decoration: const InputDecoration(labelText: '参数编码 *')),
                  const SizedBox(height: 8),
                  TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: '参数名称 *')),
                  const SizedBox(height: 8),
                  TextField(controller: _unitCtrl, decoration: const InputDecoration(labelText: '单位')),
                  const SizedBox(height: 8),
                  TextField(controller: _stdCtrl, decoration: const InputDecoration(labelText: '默认值'), keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  TextField(controller: _upperCtrl, decoration: const InputDecoration(labelText: '上限'), keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  TextField(controller: _lowerCtrl, decoration: const InputDecoration(labelText: '下限'), keyboardType: TextInputType.number),
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
                    TextField(controller: _remarkCtrl, decoration: const InputDecoration(labelText: '备注')),
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
                              if (picked != null) setState(() => _selectedEffectiveAt = picked);
                            },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: '生效时间'),
                        child: Text(_formatDateTime(_selectedEffectiveAt)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('启用'),
                      value: _isEnabled,
                      onChanged: _submitting ? null : (value) => setState(() => _isEnabled = value),
                      contentPadding: EdgeInsets.zero,
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
