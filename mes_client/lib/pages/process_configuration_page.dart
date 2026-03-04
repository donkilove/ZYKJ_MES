
import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/craft_models.dart';
import '../models/production_models.dart';
import '../services/api_exception.dart';
import '../services/craft_service.dart';
import '../services/production_service.dart';
import '../widgets/adaptive_table_container.dart';

class _TemplateStepDraft {
  _TemplateStepDraft({required this.stageId, required this.processId});

  int stageId;
  int processId;
}

enum _TemplateAction { edit, delete }

class ProcessConfigurationPage extends StatefulWidget {
  const ProcessConfigurationPage({
    super.key,
    required this.session,
    required this.onLogout,
  });

  final AppSession session;
  final VoidCallback onLogout;

  @override
  State<ProcessConfigurationPage> createState() =>
      _ProcessConfigurationPageState();
}

class _ProcessConfigurationPageState extends State<ProcessConfigurationPage> {
  late final CraftService _craftService;
  late final ProductionService _productionService;

  bool _loading = false;
  String _message = '';
  int? _productFilterId;

  List<ProductionProductOption> _products = const [];
  List<CraftStageItem> _stages = const [];
  List<CraftProcessItem> _processes = const [];
  List<CraftTemplateItem> _templates = const [];
  final Map<int, CraftTemplateDetail> _detailCache = {};

  @override
  void initState() {
    super.initState();
    _craftService = CraftService(widget.session);
    _productionService = ProductionService(widget.session);
    _loadData();
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

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final products = await _productionService.listProductOptions();
      final stageResult = await _craftService.listStages(pageSize: 500, enabled: true);
      final processResult = await _craftService.listProcesses(pageSize: 500, enabled: true);
      final templateResult = await _craftService.listTemplates(pageSize: 500, enabled: null);
      if (!mounted) {
        return;
      }
      setState(() {
        _products = [...products]..sort((a, b) => a.name.compareTo(b.name));
        _stages = [...stageResult.items]
          ..sort((a, b) {
            final orderCompare = a.sortOrder.compareTo(b.sortOrder);
            if (orderCompare != 0) {
              return orderCompare;
            }
            return a.id.compareTo(b.id);
          });
        _processes = [...processResult.items]
          ..sort((a, b) => a.id.compareTo(b.id));
        _templates = [...templateResult.items]
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        if (_productFilterId != null &&
            !_products.any((item) => item.id == _productFilterId)) {
          _productFilterId = null;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      setState(() {
        _message = '加载工序配置失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<CraftTemplateItem> get _filteredTemplates {
    if (_productFilterId == null) {
      return _templates;
    }
    return _templates.where((item) => item.productId == _productFilterId).toList();
  }

  List<CraftProcessItem> _processesByStage(int stageId) {
    return _processes.where((item) => item.stageId == stageId).toList();
  }

  Future<CraftTemplateDetail> _getTemplateDetail(int templateId) async {
    final cached = _detailCache[templateId];
    if (cached != null) {
      return cached;
    }
    final detail = await _craftService.getTemplateDetail(templateId: templateId);
    _detailCache[templateId] = detail;
    return detail;
  }

  Future<void> _showTemplateDialog({CraftTemplateItem? existing}) async {
    if (_products.isEmpty || _stages.isEmpty || _processes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先配置产品、工段和小工序')),
      );
      return;
    }

    final isEdit = existing != null;
    final formKey = GlobalKey<FormState>();
    final templateNameController = TextEditingController(
      text: existing?.templateName ?? '',
    );

    int selectedProductId =
        existing?.productId ?? _productFilterId ?? _products.first.id;
    bool isDefault = existing?.isDefault ?? false;
    bool isEnabled = existing?.isEnabled ?? true;
    bool syncOrders = true;

    List<_TemplateStepDraft> steps = [];
    if (isEdit) {
      final detail = await _getTemplateDetail(existing.id);
      steps = detail.steps
          .map((item) => _TemplateStepDraft(stageId: item.stageId, processId: item.processId))
          .toList();
    }
    if (steps.isEmpty) {
      final stage = _stages.first;
      final processRows = _processesByStage(stage.id);
      if (processRows.isNotEmpty) {
        steps = [
          _TemplateStepDraft(stageId: stage.id, processId: processRows.first.id),
        ];
      }
    }
    if (!mounted) {
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void addStep() {
              final stage = _stages.first;
              final processRows = _processesByStage(stage.id);
              if (processRows.isEmpty) {
                return;
              }
              setDialogState(() {
                steps = [
                  ...steps,
                  _TemplateStepDraft(
                    stageId: stage.id,
                    processId: processRows.first.id,
                  ),
                ];
              });
            }

            return AlertDialog(
              title: Text(isEdit ? '编辑模板' : '新建模板'),
              content: SizedBox(
                width: 860,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: selectedProductId,
                          decoration: const InputDecoration(
                            labelText: '产品',
                            border: OutlineInputBorder(),
                          ),
                          items: _products
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.id,
                                  child: Text(item.name),
                                ),
                              )
                              .toList(),
                          onChanged: isEdit
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setDialogState(() {
                                    selectedProductId = value;
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: templateNameController,
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
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('设为默认模板'),
                          value: isDefault,
                          onChanged: (value) {
                            setDialogState(() {
                              isDefault = value;
                            });
                          },
                        ),
                        if (isEdit)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('启用模板'),
                            value: isEnabled,
                            onChanged: (value) {
                              setDialogState(() {
                                isEnabled = value;
                              });
                            },
                          ),
                        if (isEdit)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('同步未完成订单'),
                            value: syncOrders,
                            onChanged: (value) {
                              setDialogState(() {
                                syncOrders = value;
                              });
                            },
                          ),
                        Row(
                          children: [
                            const Text('步骤', style: TextStyle(fontWeight: FontWeight.w600)),
                            const Spacer(),
                            OutlinedButton.icon(
                              onPressed: addStep,
                              icon: const Icon(Icons.add),
                              label: const Text('新增步骤'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(steps.length, (index) {
                          final step = steps[index];
                          final processRows = _processesByStage(step.stageId);
                          if (!processRows.any((item) => item.id == step.processId) && processRows.isNotEmpty) {
                            step.processId = processRows.first.id;
                          }
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  SizedBox(width: 48, child: Text('#${index + 1}')),
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      initialValue: step.stageId,
                                      decoration: const InputDecoration(
                                        labelText: '工段',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: _stages
                                          .map((item) => DropdownMenuItem(value: item.id, child: Text(item.name)))
                                          .toList(),
                                      onChanged: (value) {
                                        if (value == null) {
                                          return;
                                        }
                                        final nextRows = _processesByStage(value);
                                        setDialogState(() {
                                          step.stageId = value;
                                          if (nextRows.isNotEmpty) {
                                            step.processId = nextRows.first.id;
                                          }
                                        });
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
                                        labelText: '小工序',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: processRows
                                          .map((item) => DropdownMenuItem(value: item.id, child: Text(item.name)))
                                          .toList(),
                                      onChanged: processRows.isEmpty
                                          ? null
                                          : (value) {
                                              if (value == null) {
                                                return;
                                              }
                                              setDialogState(() {
                                                step.processId = value;
                                              });
                                            },
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '删除',
                                    onPressed: steps.length <= 1
                                        ? null
                                        : () {
                                            setDialogState(() {
                                              steps = [...steps]..removeAt(index);
                                            });
                                          },
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    final payloadSteps = <CraftTemplateStepPayload>[];
                    for (var i = 0; i < steps.length; i++) {
                      payloadSteps.add(
                        CraftTemplateStepPayload(
                          stepOrder: i + 1,
                          stageId: steps[i].stageId,
                          processId: steps[i].processId,
                        ),
                      );
                    }
                    try {
                      if (isEdit) {
                        await _craftService.updateTemplate(
                          templateId: existing.id,
                          templateName: templateNameController.text.trim(),
                          isDefault: isDefault,
                          isEnabled: isEnabled,
                          steps: payloadSteps,
                          syncOrders: syncOrders,
                        );
                      } else {
                        await _craftService.createTemplate(
                          productId: selectedProductId,
                          templateName: templateNameController.text.trim(),
                          isDefault: isDefault,
                          steps: payloadSteps,
                        );
                      }
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    } catch (error) {
                      if (_isUnauthorized(error)) {
                        widget.onLogout();
                        return;
                      }
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(_errorMessage(error))),
                        );
                      }
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    templateNameController.dispose();

    if (saved == true) {
      if (existing != null) {
        _detailCache.remove(existing.id);
      }
      await _loadData();
    }
  }

  Future<void> _deleteTemplate(CraftTemplateItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除模板'),
        content: Text('确认删除模板 ${item.templateName} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await _craftService.deleteTemplate(templateId: item.id);
      _detailCache.remove(item.id);
      await _loadData();
    } catch (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage(error))),
        );
      }
    }
  }

  Future<void> _handleTemplateAction(
    _TemplateAction action,
    CraftTemplateItem item,
  ) async {
    switch (action) {
      case _TemplateAction.edit:
        await _showTemplateDialog(existing: item);
        return;
      case _TemplateAction.delete:
        await _deleteTemplate(item);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final templates = _filteredTemplates;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '生产工序配置数据',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _loading ? null : () => _showTemplateDialog(),
                icon: const Icon(Icons.add),
                label: const Text('新增模板'),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '刷新',
                onPressed: _loading ? null : _loadData,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 320,
                child: DropdownButtonFormField<int?>(
                  initialValue: _productFilterId,
                  decoration: const InputDecoration(
                    labelText: '按产品筛选',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('全部产品'),
                    ),
                    ..._products.map(
                      (item) => DropdownMenuItem<int?>(
                        value: item.id,
                        child: Text(item.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _productFilterId = value;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : templates.isEmpty
                ? const Center(child: Text('暂无模板数据'))
                : Card(
                    child: AdaptiveTableContainer(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('产品')),
                          DataColumn(label: Text('模板名称')),
                          DataColumn(label: Text('版本')),
                          DataColumn(label: Text('默认')),
                          DataColumn(label: Text('状态')),
                          DataColumn(label: Text('更新时间')),
                          DataColumn(label: Text('操作')),
                        ],
                        rows: templates.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(Text(item.productName)),
                              DataCell(Text(item.templateName)),
                              DataCell(Text('${item.version}')),
                              DataCell(Text(item.isDefault ? '是' : '否')),
                              DataCell(Text(item.isEnabled ? '启用' : '停用')),
                              DataCell(Text(item.updatedAt.toLocal().toString())),
                              DataCell(
                                PopupMenuButton<_TemplateAction>(
                                  onSelected: (action) {
                                    _handleTemplateAction(action, item);
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: _TemplateAction.edit,
                                      child: Text('编辑'),
                                    ),
                                    PopupMenuItem(
                                      value: _TemplateAction.delete,
                                      child: Text('删除'),
                                    ),
                                  ],
                                  child: const Text('操作'),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
