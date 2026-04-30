import 'package:flutter/material.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';

class TemplateStepDraft {
  TemplateStepDraft({required this.stageId, required this.processId});

  int stageId;
  int processId;
}

Future<bool?> showTemplateFormDialog({
  required BuildContext context,
  required CraftService craftService,
  required List<ProductionProductOption> products,
  required List<CraftStageItem> stages,
  required List<CraftProcessItem> processes,
  required VoidCallback onLogout,
  required VoidCallback onSuccess,
  CraftTemplateItem? existing,
  int? initialProductId,
}) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _TemplateFormDialog(
      craftService: craftService,
      products: products,
      stages: stages,
      processes: processes,
      onLogout: onLogout,
      onSuccess: onSuccess,
      existing: existing,
      initialProductId: initialProductId,
    ),
  );
}

class _TemplateFormDialog extends StatefulWidget {
  const _TemplateFormDialog({
    required this.craftService,
    required this.products,
    required this.stages,
    required this.processes,
    required this.onLogout,
    required this.onSuccess,
    this.existing,
    this.initialProductId,
  });

  final CraftService craftService;
  final List<ProductionProductOption> products;
  final List<CraftStageItem> stages;
  final List<CraftProcessItem> processes;
  final VoidCallback onLogout;
  final VoidCallback onSuccess;
  final CraftTemplateItem? existing;
  final int? initialProductId;

  @override
  State<_TemplateFormDialog> createState() => _TemplateFormDialogState();
}

class _TemplateFormDialogState extends State<_TemplateFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _remarkController;

  late int _selectedProductId;
  late bool _isDefault;
  late bool _isEnabled;
  late bool _syncOrders;

  bool _loading = false;
  bool _submitting = false;
  String _error = '';

  List<TemplateStepDraft> _steps = [];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.templateName ?? '');
    _remarkController = TextEditingController(text: widget.existing?.remark ?? '');
    _selectedProductId = widget.existing?.productId ?? widget.initialProductId ?? widget.products.first.id;
    _isDefault = widget.existing?.isDefault ?? false;
    _isEnabled = widget.existing?.isEnabled ?? true;
    _syncOrders = true;

    if (_isEdit) {
      _loadDetail();
    } else {
      final draft = _firstStepDraft();
      if (draft != null) {
        _steps = [draft];
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _remarkController.dispose();
    super.dispose();
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

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final detail = await widget.craftService.getTemplateDetail(templateId: widget.existing!.id);
      if (!mounted) return;
      setState(() {
        _steps = detail.steps
            .map((item) => TemplateStepDraft(
                  stageId: item.stageId,
                  processId: item.processId,
                ))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (_isUnauthorized(e)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _error = _errorMessage(e);
        _loading = false;
      });
    }
  }

  List<CraftProcessItem> _processesByStage(int stageId) {
    return widget.processes.where((item) => item.stageId == stageId).toList();
  }

  TemplateStepDraft? _firstStepDraft() {
    for (final stage in widget.stages) {
      final processRows = _processesByStage(stage.id);
      if (processRows.isEmpty) continue;
      return TemplateStepDraft(stageId: stage.id, processId: processRows.first.id);
    }
    return null;
  }

  void _addStep() {
    final firstStep = _firstStepDraft();
    if (firstStep == null) return;
    setState(() {
      _steps.add(firstStep);
    });
  }

  List<CraftTemplateStepPayload> _buildPayloadSteps() {
    return List.generate(
      _steps.length,
      (i) => CraftTemplateStepPayload(
        stepOrder: i + 1,
        stageId: _steps[i].stageId,
        processId: _steps[i].processId,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少添加一个工艺步骤')),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final payloadSteps = _buildPayloadSteps();
      if (_isEdit) {
        await widget.craftService.updateTemplate(
          templateId: widget.existing!.id,
          templateName: _nameController.text.trim(),
          isDefault: _isDefault,
          isEnabled: _isEnabled,
          steps: payloadSteps,
          syncOrders: _syncOrders,
          remark: _remarkController.text.trim(),
        );
      } else {
        await widget.craftService.createTemplate(
          productId: _selectedProductId,
          templateName: _nameController.text.trim(),
          isDefault: _isDefault,
          remark: _remarkController.text.trim(),
          steps: payloadSteps,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
      });
      if (_isUnauthorized(e)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：${_errorMessage(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const MesDialog(
        title: Text('加载中'),
        width: 400,
        content: MesLoadingState(label: '正在加载模板详情...'),
      );
    }
    if (_error.isNotEmpty) {
      return MesDialog(
        title: Text(_isEdit ? '编辑模板' : '新建模板'),
        width: 400,
        content: Text(
          _error,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      );
    }

    return MesDialog(
      title: Text(_isEdit ? '编辑模板' : '新建模板'),
      width: 860,
      content: SizedBox(
        height: 560,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: _selectedProductId,
                        decoration: const InputDecoration(
                          labelText: '产品',
                          border: OutlineInputBorder(),
                        ),
                        items: widget.products
                            .map((item) => DropdownMenuItem(
                                  value: item.id,
                                  child: Text(item.name),
                                ))
                            .toList(),
                        onChanged: _submitting || _isEdit
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedProductId = value;
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        enabled: !_submitting,
                        decoration: const InputDecoration(
                          labelText: '模板名称',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入模板名称';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('设为默认模板'),
                        value: _isDefault,
                        onChanged: _submitting
                            ? null
                            : (value) => setState(() => _isDefault = value),
                      ),
                      if (_isEdit) ...[
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('启用模板'),
                          value: _isEnabled,
                          onChanged: _submitting
                              ? null
                              : (value) => setState(() => _isEnabled = value),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('同步未完成订单'),
                          value: _syncOrders,
                          onChanged: _submitting
                              ? null
                              : (value) => setState(() => _syncOrders = value),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _remarkController,
                        enabled: !_submitting,
                        maxLength: 500,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '备注（可选）',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 7,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(77),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '工艺步骤设置',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            SizedBox(
                              height: 32,
                              child: OutlinedButton.icon(
                                onPressed: _submitting ? null : _addStep,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('新增'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _steps.isEmpty
                            ? const Center(
                                child: Text('暂无工艺步骤，请点击右上角添加'),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _steps.length,
                                itemBuilder: (context, index) {
                                  final step = _steps[index];
                                  final processRows = _processesByStage(step.stageId);
                                  
                                  if (!processRows.any((item) => item.id == step.processId) && processRows.isNotEmpty) {
                                    step.processId = processRows.first.id;
                                  }

                                  return Card(
                                    elevation: 0,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.primaryContainer,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '${index + 1}',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: DropdownButtonFormField<int>(
                                              initialValue: step.stageId,
                                              decoration: const InputDecoration(
                                                labelText: '工段',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                              items: widget.stages
                                                  .map((item) => DropdownMenuItem(
                                                        value: item.id,
                                                        child: Text(item.name),
                                                      ))
                                                  .toList(),
                                              onChanged: _submitting
                                                  ? null
                                                  : (value) {
                                                      if (value != null) {
                                                        setState(() {
                                                          step.stageId = value;
                                                          final nextRows = _processesByStage(value);
                                                          if (nextRows.isNotEmpty) {
                                                            step.processId = nextRows.first.id;
                                                          }
                                                        });
                                                      }
                                                    },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: DropdownButtonFormField<int>(
                                              initialValue: processRows.isEmpty
                                                  ? null
                                                  : (processRows.any((item) => item.id == step.processId)
                                                      ? step.processId
                                                      : processRows.first.id),
                                              decoration: const InputDecoration(
                                                labelText: '工序',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                              items: processRows
                                                  .map((item) => DropdownMenuItem(
                                                        value: item.id,
                                                        child: Text(item.name),
                                                      ))
                                                  .toList(),
                                              onChanged: _submitting || processRows.isEmpty
                                                  ? null
                                                  : (value) {
                                                      if (value != null) {
                                                        setState(() {
                                                          step.processId = value;
                                                        });
                                                      }
                                                    },
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            tooltip: '删除',
                                            onPressed: _submitting || _steps.length <= 1
                                                ? null
                                                : () {
                                                    setState(() {
                                                      _steps.removeAt(index);
                                                    });
                                                  },
                                            icon: const Icon(Icons.delete_outline, size: 20),
                                            color: Theme.of(context).colorScheme.error,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          border: Border(
                            top: BorderSide(
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          _isEdit
                              ? '提示：保存编辑后模板会进入草稿状态，请在列表中执行“发布”使其生效。'
                              : '新建模板统一先保存为草稿，完成评审后再由列表中的“发布”入口生效。',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
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
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save, size: 18),
          label: Text(_submitting ? '保存中...' : '保存'),
        ),
      ],
    );
  }
}
