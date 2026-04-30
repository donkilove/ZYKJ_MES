import 'package:flutter/material.dart';

import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';
import 'package:mes_client/features/equipment/services/equipment_service.dart';

Future<bool?> showEquipmentLedgerFormDialog({
  required BuildContext context,
  required EquipmentService equipmentService,
  required List<EquipmentOwnerOption> ownerOptions,
  EquipmentLedgerItem? item,
}) {
  return showMesLockedFormDialog<bool>(
    context: context,
    wrapMesDialog: false,
    builder: (dialogContext) {
      return EquipmentLedgerFormDialog(
        equipmentService: equipmentService,
        ownerOptions: ownerOptions,
        item: item,
      );
    },
  );
}

class EquipmentLedgerFormDialog extends StatefulWidget {
  const EquipmentLedgerFormDialog({
    super.key,
    required this.equipmentService,
    required this.ownerOptions,
    this.item,
  });

  final EquipmentService equipmentService;
  final List<EquipmentOwnerOption> ownerOptions;
  final EquipmentLedgerItem? item;

  @override
  State<EquipmentLedgerFormDialog> createState() =>
      _EquipmentLedgerFormDialogState();
}

class _EquipmentLedgerFormDialogState extends State<EquipmentLedgerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _modelController;
  late final TextEditingController _locationController;
  late final TextEditingController _remarkController;
  late String _selectedOwner;
  bool _submitting = false;

  bool get _isCreate => widget.item == null;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.item?.code ?? '');
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _modelController = TextEditingController(text: widget.item?.model ?? '');
    _locationController = TextEditingController(text: widget.item?.location ?? '');
    _remarkController = TextEditingController(text: widget.item?.remark ?? '');
    _selectedOwner = (widget.item?.ownerName ?? '').trim();
    final ownerNames = widget.ownerOptions.map((owner) => owner.username).toSet();
    if (_selectedOwner.isNotEmpty && !ownerNames.contains(_selectedOwner)) {
      _selectedOwner = '';
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _modelController.dispose();
    _locationController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Widget _buildOwnerDropdownText(String text) {
    return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
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
    setState(() => _submitting = true);
    try {
      if (_isCreate) {
        await widget.equipmentService.createEquipment(
          code: _codeController.text.trim(),
          name: _nameController.text.trim(),
          model: _modelController.text.trim(),
          location: _locationController.text.trim(),
          ownerName: _selectedOwner,
          remark: _remarkController.text.trim(),
        );
      } else {
        await widget.equipmentService.updateEquipment(
          equipmentId: widget.item!.id,
          code: _codeController.text.trim(),
          name: _nameController.text.trim(),
          model: _modelController.text.trim(),
          location: _locationController.text.trim(),
          ownerName: _selectedOwner,
          remark: _remarkController.text.trim(),
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存设备失败: ${_errorMessage(error)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MesDialog(
      title: Text(_isCreate ? '新增设备' : '编辑设备'),
      width: 760,
      content: SizedBox(
        key: const ValueKey('equipment-ledger-form-dialog'),
        width: 760,
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
                      '基本信息',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _codeController,
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
                      controller: _nameController,
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
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: '型号',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _locationController,
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
                        '状态与说明',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedOwner.isEmpty ? null : _selectedOwner,
                        isExpanded: true,
                        items: widget.ownerOptions
                            .map(
                              (entry) => DropdownMenuItem<String>(
                                value: entry.username,
                                child: _buildOwnerDropdownText(entry.displayName),
                              ),
                            )
                            .toList(),
                        selectedItemBuilder: (context) {
                          return widget.ownerOptions
                              .map(
                                (entry) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: _buildOwnerDropdownText(entry.displayName),
                                ),
                              )
                              .toList();
                        },
                        onChanged: _submitting
                            ? null
                            : (value) => setState(() => _selectedOwner = value ?? ''),
                        decoration: const InputDecoration(
                          labelText: '负责人',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _remarkController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: '备注',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
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
