import 'package:flutter/material.dart';

import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';
import 'package:mes_client/features/quality/services/quality_supplier_service.dart';

Future<bool?> showQualitySupplierFormDialog({
  required BuildContext context,
  required QualitySupplierService supplierService,
  QualitySupplierItem? item,
}) {
  return showMesLockedFormDialog<bool>(
    context: context,
    wrapMesDialog: false,
    builder: (dialogContext) {
      return QualitySupplierFormDialog(
        supplierService: supplierService,
        item: item,
      );
    },
  );
}

class QualitySupplierFormDialog extends StatefulWidget {
  const QualitySupplierFormDialog({
    super.key,
    required this.supplierService,
    this.item,
  });

  final QualitySupplierService supplierService;
  final QualitySupplierItem? item;

  @override
  State<QualitySupplierFormDialog> createState() =>
      _QualitySupplierFormDialogState();
}

class _QualitySupplierFormDialogState extends State<QualitySupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _remarkController;
  late bool _isEnabled;
  bool _submitting = false;

  bool get _isCreate => widget.item == null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _remarkController = TextEditingController(text: widget.item?.remark ?? '');
    _isEnabled = widget.item?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _remarkController.dispose();
    super.dispose();
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
    final payload = QualitySupplierUpsertPayload(
      name: _nameController.text.trim(),
      remark: _remarkController.text.trim().isEmpty
          ? null
          : _remarkController.text.trim(),
      isEnabled: _isEnabled,
    );
    try {
      if (_isCreate) {
        await widget.supplierService.createSupplier(payload);
      } else {
        await widget.supplierService.updateSupplier(widget.item!.id, payload);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MesDialog(
      title: Text(_isCreate ? '新增供应商' : '编辑供应商'),
      width: 760,
      content: SizedBox(
        key: const ValueKey('quality-supplier-form-dialog'),
        width: 760,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
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
                      controller: _nameController,
                      enabled: !_submitting,
                      maxLength: 128,
                      decoration: const InputDecoration(
                        labelText: '名称',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入供应商名称';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _remarkController,
                      enabled: !_submitting,
                      maxLength: 300,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: '备注',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                      50,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
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
                      Text(
                        '当前状态',
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        value: _isEnabled,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('启用状态'),
                        subtitle: Text(_isEnabled ? '当前为启用' : '当前为停用'),
                        onChanged: _submitting
                            ? null
                            : (value) => setState(() => _isEnabled = value),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEnabled ? '当前为启用' : '当前为停用',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isCreate
                                  ? '新增供应商后会立即出现在质量与生产相关下拉项中。'
                                  : '编辑名称、备注和启停状态后，会同步影响后续引用选择。',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
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
