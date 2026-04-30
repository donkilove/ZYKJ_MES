import 'package:flutter/material.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/features/craft/presentation/widgets/template_form_dialog.dart'
    show TemplateStepDraft, resolveTemplateStepProcessId;

Future<bool?> showSystemMasterTemplateFormDialog({
  required BuildContext context,
  required CraftService craftService,
  required List<CraftStageItem> stages,
  required List<CraftProcessItem> processes,
  required VoidCallback onLogout,
  required VoidCallback onSuccess,
  CraftSystemMasterTemplateItem? existing,
}) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _SystemMasterTemplateFormDialog(
      craftService: craftService,
      stages: stages,
      processes: processes,
      onLogout: onLogout,
      onSuccess: onSuccess,
      existing: existing,
    ),
  );
}

class _SystemMasterTemplateFormDialog extends StatefulWidget {
  const _SystemMasterTemplateFormDialog({
    required this.craftService,
    required this.stages,
    required this.processes,
    required this.onLogout,
    required this.onSuccess,
    this.existing,
  });

  final CraftService craftService;
  final List<CraftStageItem> stages;
  final List<CraftProcessItem> processes;
  final VoidCallback onLogout;
  final VoidCallback onSuccess;
  final CraftSystemMasterTemplateItem? existing;

  @override
  State<_SystemMasterTemplateFormDialog> createState() =>
      _SystemMasterTemplateFormDialogState();
}

class _SystemMasterTemplateFormDialogState
    extends State<_SystemMasterTemplateFormDialog> {
  final _formKey = GlobalKey<FormState>();
  List<TemplateStepDraft> _steps = [];

  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _steps = widget.existing!.steps
          .map(
            (item) => TemplateStepDraft(
              stageId: item.stageId,
              processId: item.processId,
            ),
          )
          .toList();
    }
    if (_steps.isEmpty) {
      final draft = _firstStepDraft();
      if (draft != null) {
        _steps = [draft];
      }
    }
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

  List<CraftProcessItem> _processesByStage(int stageId) {
    return widget.processes.where((item) => item.stageId == stageId).toList();
  }

  TemplateStepDraft? _firstStepDraft() {
    for (final stage in widget.stages) {
      final processRows = _processesByStage(stage.id);
      if (processRows.isEmpty) continue;
      return TemplateStepDraft(
        stageId: stage.id,
        processId: processRows.first.id,
      );
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
    return List.generate(_steps.length, (i) {
      final step = _steps[i];
      final processRows = _processesByStage(step.stageId);
      final processId =
          resolveTemplateStepProcessId(step, processRows) ?? step.processId;
      return CraftTemplateStepPayload(
        stepOrder: i + 1,
        stageId: step.stageId,
        processId: processId,
      );
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final payloadSteps = _buildPayloadSteps();
    if (payloadSteps.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请至少配置一个工艺步骤')));
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      if (_isEdit) {
        await widget.craftService.updateSystemMasterTemplate(
          steps: payloadSteps,
        );
      } else {
        await widget.craftService.createSystemMasterTemplate(
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：${_errorMessage(e)}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MesDialog(
      title: Text(_isEdit ? '编辑系统母版' : '新建系统母版'),
      width: 860,
      content: SizedBox(
        height: 560,
        child: Form(
          key: _formKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withAlpha(50),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withAlpha(50),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_tree_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '系统母版说明',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '系统母版是全局唯一的标准工艺参考模型。',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '新建常规产品模板时，可以直接“从系统母版套版”，以快速继承基础工艺路线。',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withAlpha(77),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '标准步骤设置',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(
                              height: 32,
                              child: OutlinedButton.icon(
                                onPressed: _submitting ? null : _addStep,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('新增'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _steps.isEmpty
                            ? const Center(child: Text('暂无标准步骤，请点击右上角添加'))
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: _steps.length,
                                itemBuilder: (context, index) {
                                  final step = _steps[index];
                                  final processRows = _processesByStage(
                                    step.stageId,
                                  );
                                  final selectedProcessId =
                                      resolveTemplateStepProcessId(
                                        step,
                                        processRows,
                                      );

                                  return Card(
                                    elevation: 0,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      side: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                      ),
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
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primaryContainer,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '${index + 1}',
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimaryContainer,
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
                                                  .map(
                                                    (item) => DropdownMenuItem(
                                                      value: item.id,
                                                      child: Text(item.name),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged: _submitting
                                                  ? null
                                                  : (value) {
                                                      if (value != null) {
                                                        setState(() {
                                                          step.stageId = value;
                                                          final nextRows =
                                                              _processesByStage(
                                                                value,
                                                              );
                                                          if (nextRows
                                                              .isNotEmpty) {
                                                            step.processId =
                                                                nextRows
                                                                    .first
                                                                    .id;
                                                          }
                                                        });
                                                      }
                                                    },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: DropdownButtonFormField<int>(
                                              initialValue: selectedProcessId,
                                              decoration: const InputDecoration(
                                                labelText: '小工序',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                              items: processRows
                                                  .map(
                                                    (item) => DropdownMenuItem(
                                                      value: item.id,
                                                      child: Text(item.name),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged:
                                                  _submitting ||
                                                      processRows.isEmpty
                                                  ? null
                                                  : (value) {
                                                      if (value != null) {
                                                        setState(() {
                                                          step.processId =
                                                              value;
                                                        });
                                                      }
                                                    },
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            tooltip: '删除',
                                            onPressed:
                                                _submitting ||
                                                    _steps.length <= 1
                                                ? null
                                                : () {
                                                    setState(() {
                                                      _steps.removeAt(index);
                                                    });
                                                  },
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 20,
                                            ),
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
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
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save, size: 18),
          label: Text(_submitting ? '保存中...' : '保存'),
        ),
      ],
    );
  }
}
