import 'package:flutter/material.dart';

import 'package:mes_client/features/craft/models/craft_models.dart';

class ProcessItemDialog extends StatefulWidget {
  const ProcessItemDialog({
    super.key,
    this.existing,
    required this.stages,
    required this.onSubmit,
  });

  final CraftProcessItem? existing;
  final List<CraftStageItem> stages;
  final Future<void> Function({
    required String codeSuffix,
    required String name,
    required int stageId,
    required String remark,
    required bool isEnabled,
  })
  onSubmit;

  @override
  State<ProcessItemDialog> createState() => _ProcessItemDialogState();
}

class _ProcessItemDialogState extends State<ProcessItemDialog> {
  late final TextEditingController _codeSuffixController;
  late final TextEditingController _nameController;
  late final TextEditingController _remarkController;
  late int _stageId;
  late bool _isEnabled;
  bool _submitting = false;
  bool _legacyCodeInvalid = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _stageId = widget.existing?.stageId ?? widget.stages.first.id;
    final initialSerial = _buildInitialSerial();
    _legacyCodeInvalid = widget.existing != null && initialSerial.isEmpty;
    _codeSuffixController = TextEditingController(text: initialSerial);
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _remarkController = TextEditingController(text: widget.existing?.remark ?? '');
    _isEnabled = widget.existing?.isEnabled ?? true;
  }

  String _buildInitialSerial() {
    final existing = widget.existing;
    if (existing == null) {
      return '';
    }
    final stage = widget.stages.firstWhere(
      (item) => item.id == existing.stageId,
      orElse: () => widget.stages.first,
    );
    final prefix = '${stage.code}-';
    if (!existing.code.startsWith(prefix)) {
      return '';
    }
    final serial = existing.code.substring(prefix.length);
    if (serial.length != 2 || int.tryParse(serial) == null || serial == '00') {
      return '';
    }
    return serial;
  }

  @override
  void dispose() {
    _codeSuffixController.dispose();
    _nameController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _submitting = true);
    await widget.onSubmit(
      codeSuffix: _codeSuffixController.text.trim(),
      name: _nameController.text.trim(),
      stageId: _stageId,
      remark: _remarkController.text.trim(),
      isEnabled: _isEnabled,
    );
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.stages.firstWhere((item) => item.id == _stageId);
    final serialText = _codeSuffixController.text.trim();
    final fullCodePreview = serialText.isEmpty
        ? '${stage.code}-__'
        : '${stage.code}-$serialText';
    return AlertDialog(
      title: Text(widget.existing == null ? '新增工序' : '编辑工序'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _stageId,
                decoration: const InputDecoration(
                  labelText: '所属工段',
                  border: OutlineInputBorder(),
                ),
                items: widget.stages
                    .map(
                      (item) => DropdownMenuItem<int>(
                        value: item.id,
                        child: Text('${item.name} (${item.code})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _stageId = value;
                    _codeSuffixController.clear();
                    _legacyCodeInvalid = false;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _codeSuffixController,
                decoration: const InputDecoration(
                  labelText: '工序编码序号（两位）',
                  hintText: '例如 01',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final serial = (value ?? '').trim();
                  if (serial.isEmpty) {
                    return '请输入两位序号';
                  }
                  if (serial.length != 2 || int.tryParse(serial) == null) {
                    return '序号必须是两位数字';
                  }
                  if (serial == '00') {
                    return '序号必须是 01-99';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                '完整编码预览：$fullCodePreview',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_legacyCodeInvalid) ...[
                const SizedBox(height: 8),
                Text(
                  '历史编码不符合新规则，请按“工段编码-两位序号”重新填写。',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.orange),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '小工序名称',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '请输入工序名称' : null,
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
