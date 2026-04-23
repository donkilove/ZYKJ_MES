import 'package:flutter/material.dart';

import 'package:mes_client/features/craft/models/craft_models.dart';

class ProcessStageDialog extends StatefulWidget {
  const ProcessStageDialog({
    super.key,
    this.existing,
    required this.onSubmit,
  });

  final CraftStageItem? existing;
  final Future<void> Function({
    required String code,
    required String name,
    required int sortOrder,
    required String remark,
    required bool isEnabled,
  })
  onSubmit;

  @override
  State<ProcessStageDialog> createState() => _ProcessStageDialogState();
}

class _ProcessStageDialogState extends State<ProcessStageDialog> {
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _sortController;
  late final TextEditingController _remarkController;
  late bool _isEnabled;
  bool _submitting = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.existing?.code ?? '');
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _sortController = TextEditingController(
      text: (widget.existing?.sortOrder ?? 0).toString(),
    );
    _remarkController = TextEditingController(text: widget.existing?.remark ?? '');
    _isEnabled = widget.existing?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _sortController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _submitting = true);
    await widget.onSubmit(
      code: _codeController.text.trim(),
      name: _nameController.text.trim(),
      sortOrder: int.parse(_sortController.text.trim()),
      remark: _remarkController.text.trim(),
      isEnabled: _isEnabled,
    );
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '新增工段' : '编辑工段'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: '工段编码',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入工段编码' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '工段名称',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入工段名称' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sortController,
                decoration: const InputDecoration(
                  labelText: '排序',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) => value == null || int.tryParse(value.trim()) == null
                    ? '请输入有效排序'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _remarkController,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLength: 500,
                maxLines: 3,
              ),
              if (widget.existing != null) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isEnabled,
                  onChanged: (value) => setState(() => _isEnabled = value),
                  title: const Text('启用'),
                ),
              ],
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
