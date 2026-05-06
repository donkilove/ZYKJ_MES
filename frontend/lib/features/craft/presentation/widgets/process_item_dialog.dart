import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';

class ProcessItemDialog extends StatefulWidget {
  const ProcessItemDialog({
    super.key,
    this.existing,
    required this.stages,
    this.initialCodeSuffix,
    this.resolveNextCodeSuffix,
    required this.onSubmit,
  });

  final CraftProcessItem? existing;
  final List<CraftStageItem> stages;
  final String? initialCodeSuffix;
  final Future<String?> Function(int stageId)? resolveNextCodeSuffix;
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
  String? _errorMessage;
  int _nextCodeRequestId = 0;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _stageId = widget.existing?.stageId ?? widget.stages.first.id;
    final initialSerial = _buildInitialSerial(_stageId);
    _legacyCodeInvalid = widget.existing != null && initialSerial.isEmpty;
    _codeSuffixController = TextEditingController(text: initialSerial);
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _remarkController = TextEditingController(
      text: widget.existing?.remark ?? '',
    );
    _isEnabled = widget.existing?.isEnabled ?? true;
    if (widget.existing == null && initialSerial.isEmpty) {
      unawaited(_prefillNextCodeSuffix(stageId: _stageId));
    }
  }

  String _buildInitialSerial(int stageId) {
    final existing = widget.existing;
    if (existing == null) {
      return widget.initialCodeSuffix ?? '';
    }
    final stage = widget.stages.firstWhere(
      (item) => item.id == stageId,
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
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
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
    } catch (error) {
      if (!mounted) {
        return;
      }
      final resolvedMessage = await _resolveSubmitErrorMessage(error);
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _errorMessage = resolvedMessage;
      });
    }
  }

  Future<String> _resolveSubmitErrorMessage(Object error) async {
    final text = error.toString().trim();
    if (widget.existing == null &&
        text.contains('Process code already exists')) {
      final nextSuffix = await _loadNextCodeSuffix(stageId: _stageId);
      if (nextSuffix != null) {
        _applyCodeSuffix(nextSuffix);
        return '当前工序编码已存在，已自动匹配到下一个可用序号 $nextSuffix。';
      }
      return '当前工序编码已存在，请更换其他序号。';
    }
    return text;
  }

  Future<void> _prefillNextCodeSuffix({
    required int stageId,
    bool force = false,
  }) async {
    final requestId = ++_nextCodeRequestId;
    final nextSuffix = await _loadNextCodeSuffix(stageId: stageId);
    if (!mounted || requestId != _nextCodeRequestId || nextSuffix == null) {
      return;
    }
    final current = _codeSuffixController.text.trim();
    if (!force && current.isNotEmpty) {
      return;
    }
    setState(() {
      _applyCodeSuffix(nextSuffix);
    });
  }

  Future<String?> _loadNextCodeSuffix({required int stageId}) async {
    final resolver = widget.resolveNextCodeSuffix;
    if (resolver == null) {
      return widget.initialCodeSuffix;
    }
    return resolver(stageId);
  }

  void _applyCodeSuffix(String value) {
    _codeSuffixController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.stages.firstWhere((item) => item.id == _stageId);
    final serialText = _codeSuffixController.text.trim();
    final fullCodePreview = serialText.isEmpty
        ? '${stage.code}-__'
        : '${stage.code}-$serialText';
    return MesDialog(
      title: Text(widget.existing == null ? '新增工序' : '编辑工序'),
      width: 520,
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
                    _errorMessage = null;
                    _legacyCodeInvalid = false;
                    if (widget.existing != null) {
                      _applyCodeSuffix(_buildInitialSerial(value));
                    } else {
                      _codeSuffixController.clear();
                    }
                  });
                  if (widget.existing == null) {
                    unawaited(
                      _prefillNextCodeSuffix(stageId: value, force: true),
                    );
                  }
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
                onChanged: (_) => setState(() => _errorMessage = null),
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
              if ((_errorMessage ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.red),
                ),
              ],
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
                onChanged: (_) => setState(() => _errorMessage = null),
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
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
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
