import 'package:flutter/material.dart';

import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';
import 'package:mes_client/features/equipment/presentation/maintenance_category_options.dart';
import 'package:mes_client/features/equipment/services/equipment_service.dart';

Future<bool?> showMaintenanceItemFormDialog({
  required BuildContext context,
  required EquipmentService equipmentService,
  MaintenanceItemEntry? item,
}) {
  return showMesLockedFormDialog<bool>(
    context: context,
    wrapMesDialog: false,
    builder: (dialogContext) {
      return MaintenanceItemFormDialog(
        equipmentService: equipmentService,
        item: item,
      );
    },
  );
}

class MaintenanceItemFormDialog extends StatefulWidget {
  const MaintenanceItemFormDialog({
    super.key,
    required this.equipmentService,
    this.item,
  });

  final EquipmentService equipmentService;
  final MaintenanceItemEntry? item;

  @override
  State<MaintenanceItemFormDialog> createState() =>
      _MaintenanceItemFormDialogState();
}

class _MaintenanceItemFormDialogState extends State<MaintenanceItemFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _durationController;
  late final TextEditingController _cycleDaysController;
  late final TextEditingController _standardDescController;
  late String _selectedCategory;
  bool _submitting = false;

  bool get _isCreate => widget.item == null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _durationController = TextEditingController(
      text:
          widget.item?.defaultDurationMinutes != null &&
              widget.item!.defaultDurationMinutes > 0
          ? '${widget.item!.defaultDurationMinutes}'
          : '',
    );
    _cycleDaysController = TextEditingController(
      text: widget.item != null ? '${widget.item!.defaultCycleDays}' : '',
    );
    _standardDescController = TextEditingController(
      text: widget.item?.standardDescription ?? '',
    );
    _selectedCategory = widget.item?.category ?? '';
    if (!maintenanceItemCategoryOptions.contains(_selectedCategory)) {
      _selectedCategory = '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _cycleDaysController.dispose();
    _standardDescController.dispose();
    super.dispose();
  }

  String _errorMessage(Object error) {
    if (error is ApiException) return error.message;
    return error.toString();
  }

  Future<void> _submit() async {
    final normalizedCycle = _cycleDaysController.text.trim();
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入项目名称')));
      return;
    }
    if (normalizedCycle.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入默认周期天数')));
      return;
    }
    final cycleDays = int.tryParse(normalizedCycle);
    if (cycleDays == null || cycleDays < 1 || cycleDays > 3650) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入1-3650之间的整数')));
      return;
    }
    final durationText = _durationController.text.trim();
    final duration = durationText.isNotEmpty
        ? int.tryParse(durationText)
        : null;
    if (durationText.isNotEmpty &&
        (duration == null || duration < 1 || duration > 1440)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入1-1440之间的整数')));
      return;
    }
    setState(() => _submitting = true);
    try {
      if (_isCreate) {
        await widget.equipmentService.createMaintenanceItem(
          name: _nameController.text.trim(),
          defaultCycleDays: cycleDays,
          category: _selectedCategory,
          defaultDurationMinutes: duration,
          standardDescription: _standardDescController.text.trim(),
        );
      } else {
        await widget.equipmentService.updateMaintenanceItem(
          itemId: widget.item!.id,
          name: _nameController.text.trim(),
          defaultCycleDays: cycleDays,
          category: _selectedCategory,
          defaultDurationMinutes: duration,
          standardDescription: _standardDescController.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存保养项目失败: ${_errorMessage(error)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MesDialog(
      title: Text(_isCreate ? '新增保养项目' : '编辑保养项目'),
      width: 760,
      content: SizedBox(
        key: const ValueKey('maintenance-item-form-dialog'),
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
                  Text(
                    '项目配置',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: '项目名称'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _cycleDaysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '默认周期天数',
                      helperText: '常用值：7 / 30 / 90 / 365',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('(不限)'),
                      ),
                      ...maintenanceItemCategoryOptions.map(
                        (category) => DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        ),
                      ),
                    ].toList(),
                    onChanged: _submitting
                        ? null
                        : (value) =>
                              setState(() => _selectedCategory = value ?? ''),
                    decoration: const InputDecoration(labelText: '类别'),
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
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                    50,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '周期与说明',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '默认时长(分钟)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _standardDescController,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: '标准描述'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
