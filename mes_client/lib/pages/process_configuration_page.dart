import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_session.dart';
import '../models/craft_models.dart';
import '../models/production_models.dart';
import '../services/api_exception.dart';
import '../services/craft_service.dart';
import '../services/production_service.dart';
import '../widgets/locked_form_dialog.dart';
import '../widgets/unified_list_table_header_style.dart';

class _TemplateStepDraft {
  _TemplateStepDraft({required this.stageId, required this.processId});

  int stageId;
  int processId;
}

enum _TemplateAction { edit, publish, impact, versions, delete }

class ProcessConfigurationPage extends StatefulWidget {
  const ProcessConfigurationPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canManageTemplates,
    required this.canManageSystemMasterTemplate,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canManageTemplates;
  final bool canManageSystemMasterTemplate;

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
  String? _lifecycleFilter;

  List<ProductionProductOption> _products = const [];
  List<CraftStageItem> _stages = const [];
  List<CraftProcessItem> _processes = const [];
  List<CraftTemplateItem> _templates = const [];
  CraftSystemMasterTemplateItem? _systemMasterTemplate;
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

  bool get _canManageSystemMasterTemplate {
    return widget.canManageSystemMasterTemplate;
  }

  bool get _canManageTemplates => widget.canManageTemplates;

  String _errorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  void _showNoPermission() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('当前账号没有操作权限')));
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final products = await _productionService.listProductOptions();
      final stageResult = await _craftService.listStages(
        pageSize: 500,
        enabled: true,
      );
      final processResult = await _craftService.listProcesses(
        pageSize: 500,
        enabled: true,
      );
      final templateResult = await _craftService.listTemplates(
        pageSize: 500,
        enabled: null,
        lifecycleStatus: _lifecycleFilter,
      );
      final systemMasterTemplate = await _craftService
          .getSystemMasterTemplate();
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
        _systemMasterTemplate = systemMasterTemplate;
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
    return _templates
        .where((item) => item.productId == _productFilterId)
        .toList();
  }

  List<CraftProcessItem> _processesByStage(int stageId) {
    return _processes.where((item) => item.stageId == stageId).toList();
  }

  _TemplateStepDraft? _firstStepDraft() {
    for (final stage in _stages) {
      final processRows = _processesByStage(stage.id);
      if (processRows.isEmpty) {
        continue;
      }
      return _TemplateStepDraft(
        stageId: stage.id,
        processId: processRows.first.id,
      );
    }
    return null;
  }

  List<CraftTemplateStepPayload> _buildPayloadSteps(
    List<_TemplateStepDraft> steps,
  ) {
    final payload = <CraftTemplateStepPayload>[];
    for (var i = 0; i < steps.length; i++) {
      payload.add(
        CraftTemplateStepPayload(
          stepOrder: i + 1,
          stageId: steps[i].stageId,
          processId: steps[i].processId,
        ),
      );
    }
    return payload;
  }

  Future<CraftTemplateDetail> _getTemplateDetail(int templateId) async {
    final cached = _detailCache[templateId];
    if (cached != null) {
      return cached;
    }
    final detail = await _craftService.getTemplateDetail(
      templateId: templateId,
    );
    _detailCache[templateId] = detail;
    return detail;
  }

  Future<void> _showTemplateDialog({CraftTemplateItem? existing}) async {
    if (!_canManageTemplates) {
      _showNoPermission();
      return;
    }
    if (_products.isEmpty || _stages.isEmpty || _processes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先配置产品、工段和小工序')));
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
    bool createAsPublished = false;

    List<_TemplateStepDraft> steps = [];
    if (isEdit) {
      final detail = await _getTemplateDetail(existing.id);
      steps = detail.steps
          .map(
            (item) => _TemplateStepDraft(
              stageId: item.stageId,
              processId: item.processId,
            ),
          )
          .toList();
    }
    if (steps.isEmpty) {
      final firstStep = _firstStepDraft();
      if (firstStep != null) {
        steps = [firstStep];
      }
    }
    if (!mounted) {
      return;
    }

    final saved = await showLockedFormDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void addStep() {
              final firstStep = _firstStepDraft();
              if (firstStep == null) {
                return;
              }
              setDialogState(() {
                steps = [...steps, firstStep];
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
                        if (!isEdit)
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('新建后直接发布'),
                            subtitle: const Text('关闭时将以草稿状态保存'),
                            value: createAsPublished,
                            onChanged: (value) {
                              setDialogState(() {
                                createAsPublished = value;
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
                        if (isEdit)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '提示：保存编辑后模板会进入草稿状态，请在列表中执行“发布”使其生效。',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        Row(
                          children: [
                            const Text(
                              '步骤',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
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
                          if (!processRows.any(
                                (item) => item.id == step.processId,
                              ) &&
                              processRows.isNotEmpty) {
                            step.processId = processRows.first.id;
                          }
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 48,
                                        child: Text('#${index + 1}'),
                                      ),
                                      Expanded(
                                        child: DropdownButtonFormField<int>(
                                          initialValue: step.stageId,
                                          decoration: const InputDecoration(
                                            labelText: '工段',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          items: _stages
                                              .map(
                                                (item) => DropdownMenuItem(
                                                  value: item.id,
                                                  child: Text(item.name),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (value) {
                                            if (value == null) {
                                              return;
                                            }
                                            final nextRows = _processesByStage(
                                              value,
                                            );
                                            setDialogState(() {
                                              step.stageId = value;
                                              if (nextRows.isNotEmpty) {
                                                step.processId =
                                                    nextRows.first.id;
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
                                              : (processRows.any(
                                                      (item) =>
                                                          item.id ==
                                                          step.processId,
                                                    )
                                                    ? step.processId
                                                    : processRows.first.id),
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
                                                  steps = [...steps]
                                                    ..removeAt(index);
                                                });
                                              },
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
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
                    final payloadSteps = _buildPayloadSteps(steps);
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
                          lifecycleStatus: createAsPublished
                              ? 'published'
                              : 'draft',
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

  Future<void> _showSystemMasterTemplateDialog() async {
    if (!_canManageSystemMasterTemplate) {
      _showNoPermission();
      return;
    }
    if (_stages.isEmpty || _processes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先配置工段和小工序')));
      return;
    }

    final isEdit = _systemMasterTemplate != null;
    final formKey = GlobalKey<FormState>();
    List<_TemplateStepDraft> steps = isEdit
        ? _systemMasterTemplate!.steps
              .map(
                (item) => _TemplateStepDraft(
                  stageId: item.stageId,
                  processId: item.processId,
                ),
              )
              .toList()
        : <_TemplateStepDraft>[];

    if (steps.isEmpty) {
      final firstStep = _firstStepDraft();
      if (firstStep != null) {
        steps = [firstStep];
      }
    }

    if (steps.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前工段下暂无可用小工序，请先配置小工序')));
      return;
    }

    final saved = await showLockedFormDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void addStep() {
              final firstStep = _firstStepDraft();
              if (firstStep == null) {
                return;
              }
              setDialogState(() {
                steps = [...steps, firstStep];
              });
            }

            return AlertDialog(
              title: Text(isEdit ? '编辑系统母版' : '新建系统母版'),
              content: SizedBox(
                width: 860,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isEdit)
                          Text(
                            '当前版本：v${_systemMasterTemplate!.version}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (isEdit) const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text(
                              '步骤',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
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
                          if (!processRows.any(
                                (item) => item.id == step.processId,
                              ) &&
                              processRows.isNotEmpty) {
                            step.processId = processRows.first.id;
                          }
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 48,
                                        child: Text('#${index + 1}'),
                                      ),
                                      Expanded(
                                        child: DropdownButtonFormField<int>(
                                          initialValue: step.stageId,
                                          decoration: const InputDecoration(
                                            labelText: '工段',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          items: _stages
                                              .map(
                                                (item) => DropdownMenuItem(
                                                  value: item.id,
                                                  child: Text(item.name),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (value) {
                                            if (value == null) {
                                              return;
                                            }
                                            final nextRows = _processesByStage(
                                              value,
                                            );
                                            setDialogState(() {
                                              step.stageId = value;
                                              if (nextRows.isNotEmpty) {
                                                step.processId =
                                                    nextRows.first.id;
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
                                              : (processRows.any(
                                                      (item) =>
                                                          item.id ==
                                                          step.processId,
                                                    )
                                                    ? step.processId
                                                    : processRows.first.id),
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
                                                  steps = [...steps]
                                                    ..removeAt(index);
                                                });
                                              },
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
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
                    if (!(formKey.currentState?.validate() ?? false)) {
                      return;
                    }
                    final payloadSteps = _buildPayloadSteps(steps);
                    if (payloadSteps.isEmpty) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('请至少配置一个步骤')),
                      );
                      return;
                    }
                    try {
                      if (isEdit) {
                        await _craftService.updateSystemMasterTemplate(
                          steps: payloadSteps,
                        );
                      } else {
                        await _craftService.createSystemMasterTemplate(
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

    if (saved == true) {
      await _loadData();
    }
  }

  Future<void> _deleteTemplate(CraftTemplateItem item) async {
    if (!_canManageTemplates) {
      _showNoPermission();
      return;
    }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
    }
  }

  String _lifecycleLabel(String lifecycleStatus) {
    switch (lifecycleStatus.toLowerCase()) {
      case 'published':
        return '已发布';
      case 'archived':
        return '已归档';
      default:
        return '草稿';
    }
  }

  int _parseIntSafe(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }

  List<CraftTemplateBatchImportItem> _parseImportItems(dynamic decoded) {
    final dynamic rawItems;
    if (decoded is List) {
      rawItems = decoded;
    } else if (decoded is Map<String, dynamic>) {
      rawItems = decoded['items'];
    } else {
      throw const FormatException('导入内容必须是数组或包含 items 的对象');
    }

    if (rawItems is! List) {
      throw const FormatException('导入内容中的 items 必须是数组');
    }

    final result = <CraftTemplateBatchImportItem>[];
    for (final entry in rawItems) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('每条模板必须是对象结构');
      }
      final stepsRaw = entry['steps'];
      if (stepsRaw is! List) {
        throw const FormatException('模板 steps 必须是数组');
      }
      final steps = <CraftTemplateStepPayload>[];
      for (final stepEntry in stepsRaw) {
        if (stepEntry is! Map<String, dynamic>) {
          throw const FormatException('步骤项必须是对象');
        }
        steps.add(
          CraftTemplateStepPayload(
            stepOrder: _parseIntSafe(stepEntry['step_order'], fallback: 0),
            stageId: _parseIntSafe(stepEntry['stage_id'], fallback: 0),
            processId: _parseIntSafe(stepEntry['process_id'], fallback: 0),
          ),
        );
      }

      final productIdRaw = entry['product_id'];
      int? productId;
      if (productIdRaw != null) {
        productId = _parseIntSafe(productIdRaw, fallback: 0);
      }
      final productNameRaw = entry['product_name'];
      final productName = productNameRaw is String
          ? productNameRaw.trim()
          : null;

      result.add(
        CraftTemplateBatchImportItem(
          productId: productId != null && productId > 0 ? productId : null,
          productName: (productName != null && productName.isNotEmpty)
              ? productName
              : null,
          templateName: (entry['template_name'] as String? ?? '').trim(),
          isDefault: (entry['is_default'] as bool?) ?? false,
          isEnabled: (entry['is_enabled'] as bool?) ?? true,
          lifecycleStatus: (entry['lifecycle_status'] as String? ?? 'draft')
              .trim()
              .toLowerCase(),
          steps: steps,
        ),
      );
    }
    return result;
  }

  Future<void> _showImpactAnalysisDialog(CraftTemplateItem item) async {
    try {
      final analysis = await _craftService.getTemplateImpactAnalysis(
        templateId: item.id,
      );
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('影响分析 - ${item.templateName}'),
          content: SizedBox(
            width: 820,
            height: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('总计 ${analysis.totalOrders}')),
                    Chip(label: Text('待开工 ${analysis.pendingOrders}')),
                    Chip(label: Text('生产中 ${analysis.inProgressOrders}')),
                    Chip(label: Text('可同步 ${analysis.syncableOrders}')),
                    Chip(label: Text('受阻 ${analysis.blockedOrders}')),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '订单明细',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: analysis.items.isEmpty
                      ? const Center(child: Text('暂无受影响订单'))
                      : ListView.separated(
                          itemCount: analysis.items.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final order = analysis.items[index];
                            return ListTile(
                              dense: true,
                              title: Text(order.orderCode),
                              subtitle: Text(
                                '状态：${order.orderStatus}${(order.reason ?? '').isNotEmpty ? '，原因：${order.reason}' : ''}',
                              ),
                              trailing: Text(
                                order.syncable ? '可同步' : '阻塞',
                                style: TextStyle(
                                  color: order.syncable
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.error,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
    }
  }

  Future<void> _showPublishDialog(CraftTemplateItem item) async {
    if (!_canManageTemplates) {
      _showNoPermission();
      return;
    }
    final noteController = TextEditingController();
    bool applyOrderSync = false;
    bool confirmed = false;
    CraftTemplateImpactAnalysis? analysis;

    try {
      analysis = await _craftService.getTemplateImpactAnalysis(
        templateId: item.id,
      );
    } catch (error) {
      noteController.dispose();
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
      return;
    }
    if (!mounted) {
      noteController.dispose();
      return;
    }

    final saved = await showLockedFormDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('发布模板 - ${item.templateName}'),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text('总计 ${analysis!.totalOrders}')),
                          Chip(label: Text('可同步 ${analysis.syncableOrders}')),
                          Chip(label: Text('受阻 ${analysis.blockedOrders}')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (analysis.items.any((item) => !item.syncable))
                        Text(
                          '存在无法同步的订单，发布时会自动跳过受阻订单。',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('同步未完成订单'),
                        subtitle: const Text('将模板变更同步到关联订单可同步工序'),
                        value: applyOrderSync,
                        onChanged: (value) {
                          setDialogState(() {
                            applyOrderSync = value;
                            if (!value) {
                              confirmed = false;
                            }
                          });
                        },
                      ),
                      if (applyOrderSync)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('我已确认上述影响并继续发布'),
                          value: confirmed,
                          onChanged: (value) {
                            setDialogState(() {
                              confirmed = value ?? false;
                            });
                          },
                        ),
                      TextField(
                        controller: noteController,
                        maxLength: 256,
                        decoration: const InputDecoration(
                          labelText: '发布说明（可选）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
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
                    if (applyOrderSync && !confirmed) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('请先确认影响后再发布')),
                      );
                      return;
                    }
                    try {
                      await _craftService.publishTemplate(
                        templateId: item.id,
                        applyOrderSync: applyOrderSync,
                        confirmed: !applyOrderSync || confirmed,
                        note: noteController.text.trim().isEmpty
                            ? null
                            : noteController.text.trim(),
                      );
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
                  child: const Text('确认发布'),
                ),
              ],
            );
          },
        );
      },
    );

    noteController.dispose();
    if (saved == true) {
      _detailCache.remove(item.id);
      await _loadData();
    }
  }

  Future<bool> _showRollbackDialog({
    required CraftTemplateItem item,
    required int targetVersion,
  }) async {
    bool applyOrderSync = false;
    bool confirmed = false;
    final noteController = TextEditingController(text: '回滚到版本 v$targetVersion');

    final done = await showLockedFormDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('回滚模板 - ${item.templateName}'),
              content: SizedBox(
                width: 620,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('目标版本：v$targetVersion'),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('同步未完成订单'),
                      value: applyOrderSync,
                      onChanged: (value) {
                        setDialogState(() {
                          applyOrderSync = value;
                          if (!value) {
                            confirmed = false;
                          }
                        });
                      },
                    ),
                    if (applyOrderSync)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('我已确认回滚影响'),
                        value: confirmed,
                        onChanged: (value) {
                          setDialogState(() {
                            confirmed = value ?? false;
                          });
                        },
                      ),
                    TextField(
                      controller: noteController,
                      maxLength: 256,
                      decoration: const InputDecoration(
                        labelText: '回滚说明（可选）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (applyOrderSync && !confirmed) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('请先确认影响后再回滚')),
                      );
                      return;
                    }
                    try {
                      await _craftService.rollbackTemplate(
                        templateId: item.id,
                        targetVersion: targetVersion,
                        applyOrderSync: applyOrderSync,
                        confirmed: !applyOrderSync || confirmed,
                        note: noteController.text.trim().isEmpty
                            ? null
                            : noteController.text.trim(),
                      );
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
                  child: const Text('确认回滚'),
                ),
              ],
            );
          },
        );
      },
    );

    noteController.dispose();
    if (done == true) {
      _detailCache.remove(item.id);
      await _loadData();
      return true;
    }
    return false;
  }

  Future<void> _showVersionDialog(CraftTemplateItem item) async {
    CraftTemplateVersionListResult versions;
    try {
      versions = await _craftService.listTemplateVersions(templateId: item.id);
    } catch (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
      return;
    }

    if (!mounted) {
      return;
    }
    if (versions.items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该模板暂无发布版本记录')));
      return;
    }

    int fromVersion = versions.items.length > 1
        ? versions.items[1].version
        : versions.items.first.version;
    int toVersion = versions.items.first.version;
    CraftTemplateVersionCompareResult? compareResult;

    Future<void> loadCompare() async {
      if (fromVersion == toVersion) {
        compareResult = CraftTemplateVersionCompareResult(
          fromVersion: fromVersion,
          toVersion: toVersion,
          addedSteps: 0,
          removedSteps: 0,
          changedSteps: 0,
          items: const [],
        );
        return;
      }
      compareResult = await _craftService.compareTemplateVersions(
        templateId: item.id,
        fromVersion: fromVersion,
        toVersion: toVersion,
      );
    }

    try {
      await loadCompare();
    } catch (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
      return;
    }

    if (!mounted) {
      return;
    }

    final done = await showLockedFormDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('版本管理 - ${item.templateName}'),
              content: SizedBox(
                width: 980,
                height: 620,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '版本对比',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: fromVersion,
                            decoration: const InputDecoration(
                              labelText: '基准版本',
                              border: OutlineInputBorder(),
                            ),
                            items: versions.items
                                .map(
                                  (item) => DropdownMenuItem<int>(
                                    value: item.version,
                                    child: Text(
                                      'v${item.version} · ${item.action}',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setDialogState(() {
                                fromVersion = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: toVersion,
                            decoration: const InputDecoration(
                              labelText: '目标版本',
                              border: OutlineInputBorder(),
                            ),
                            items: versions.items
                                .map(
                                  (item) => DropdownMenuItem<int>(
                                    value: item.version,
                                    child: Text(
                                      'v${item.version} · ${item.action}',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setDialogState(() {
                                toVersion = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: () async {
                            try {
                              await loadCompare();
                              if (dialogContext.mounted) {
                                setDialogState(() {});
                              }
                            } catch (error) {
                              if (_isUnauthorized(error)) {
                                widget.onLogout();
                                return;
                              }
                              if (dialogContext.mounted) {
                                ScaffoldMessenger.of(
                                  dialogContext,
                                ).showSnackBar(
                                  SnackBar(content: Text(_errorMessage(error))),
                                );
                              }
                            }
                          },
                          child: const Text('对比'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (compareResult != null)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text('新增 ${compareResult!.addedSteps}')),
                          Chip(
                            label: Text('删除 ${compareResult!.removedSteps}'),
                          ),
                          Chip(
                            label: Text('变更 ${compareResult!.changedSteps}'),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child:
                          compareResult == null || compareResult!.items.isEmpty
                          ? const Center(child: Text('当前版本组合无差异'))
                          : ListView.separated(
                              itemCount: compareResult!.items.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final diff = compareResult!.items[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    '步骤 ${diff.stepOrder} · ${diff.diffType}',
                                  ),
                                  subtitle: Text(
                                    'from: ${diff.fromProcessCode ?? '-'}  ->  to: ${diff.toProcessCode ?? '-'}',
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '历史版本（点击回滚）',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        itemCount: versions.items.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final version = versions.items[index];
                          return ListTile(
                            dense: true,
                            title: Text(
                              'v${version.version} · ${version.action}',
                            ),
                            subtitle: Text(
                              '${version.createdAt.toLocal()}'
                              '${version.note != null && version.note!.trim().isNotEmpty ? ' · ${version.note}' : ''}',
                            ),
                            trailing: FilledButton.tonal(
                              onPressed: () async {
                                final rolledBack = await _showRollbackDialog(
                                  item: item,
                                  targetVersion: version.version,
                                );
                                if (rolledBack && dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop(true);
                                }
                              },
                              child: const Text('回滚'),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );

    if (done == true) {
      _detailCache.remove(item.id);
      await _loadData();
    }
  }

  Future<void> _showExportDialog() async {
    if (!_canManageTemplates) {
      _showNoPermission();
      return;
    }
    try {
      final result = await _craftService.exportTemplates(
        productId: _productFilterId,
        lifecycleStatus: _lifecycleFilter,
      );
      if (!mounted) {
        return;
      }
      final text = const JsonEncoder.withIndent('  ').convert({
        'exported_at': result.exportedAt.toIso8601String(),
        'items': result.items.map((item) => item.toJson()).toList(),
      });

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('批量导出（${result.total} 条）'),
          content: SizedBox(
            width: 900,
            height: 560,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text('已复制到剪贴板')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('复制 JSON'),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(child: SelectableText(text)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
    }
  }

  Future<void> _showImportDialog() async {
    if (!_canManageTemplates) {
      _showNoPermission();
      return;
    }
    final payloadController = TextEditingController();
    bool overwriteExisting = false;
    bool publishAfterImport = false;

    final done = await showLockedFormDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('批量导入模板'),
              content: SizedBox(
                width: 900,
                height: 620,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('覆盖同名模板'),
                      value: overwriteExisting,
                      onChanged: (value) {
                        setDialogState(() {
                          overwriteExisting = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('导入后直接发布'),
                      value: publishAfterImport,
                      onChanged: (value) {
                        setDialogState(() {
                          publishAfterImport = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TextField(
                        controller: payloadController,
                        maxLines: null,
                        expands: true,
                        decoration: const InputDecoration(
                          labelText: '导入 JSON',
                          hintText: '粘贴导出的 items 数组或 {"items": [...]}',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () async {
                    final rawText = payloadController.text.trim();
                    if (rawText.isEmpty) {
                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(const SnackBar(content: Text('请先粘贴导入内容')));
                      return;
                    }

                    try {
                      final decoded = jsonDecode(rawText);
                      final items = _parseImportItems(decoded);
                      if (items.isEmpty) {
                        throw const FormatException('导入内容为空');
                      }
                      final result = await _craftService.importTemplates(
                        items: items,
                        overwriteExisting: overwriteExisting,
                        publishAfterImport: publishAfterImport,
                      );
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              '导入完成：创建 ${result.created}，更新 ${result.updated}，跳过 ${result.skipped}',
                            ),
                          ),
                        );
                        Navigator.of(dialogContext).pop(true);
                      }
                    } on FormatException catch (error) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('导入格式错误：${error.message}')),
                        );
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
                  child: const Text('开始导入'),
                ),
              ],
            );
          },
        );
      },
    );

    payloadController.dispose();
    if (done == true) {
      await _loadData();
    }
  }

  Future<void> _handleTemplateAction(
    _TemplateAction action,
    CraftTemplateItem item,
  ) async {
    if (!_canManageTemplates) {
      _showNoPermission();
      return;
    }
    switch (action) {
      case _TemplateAction.edit:
        await _showTemplateDialog(existing: item);
        return;
      case _TemplateAction.publish:
        await _showPublishDialog(item);
        return;
      case _TemplateAction.impact:
        await _showImpactAnalysisDialog(item);
        return;
      case _TemplateAction.versions:
        await _showVersionDialog(item);
        return;
      case _TemplateAction.delete:
        await _deleteTemplate(item);
        return;
    }
  }

  Widget _buildHeaderLabel(
    ThemeData theme,
    String text, {
    TextAlign textAlign = TextAlign.start,
  }) {
    return Text(
      text,
      textAlign: textAlign,
      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildTemplateHeaderRow(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.65,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 2, child: _buildHeaderLabel(theme, '产品')),
          Expanded(flex: 2, child: _buildHeaderLabel(theme, '模板名称')),
          Expanded(flex: 1, child: _buildHeaderLabel(theme, '版本/发布')),
          Expanded(flex: 1, child: _buildHeaderLabel(theme, '默认')),
          Expanded(flex: 1, child: _buildHeaderLabel(theme, '生命周期/状态')),
          Expanded(flex: 2, child: _buildHeaderLabel(theme, '更新时间')),
          SizedBox(
            width: 64,
            child: _buildHeaderLabel(theme, '操作', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
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
                '生产工序配置',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_canManageSystemMasterTemplate)
                FilledButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _showSystemMasterTemplateDialog(),
                  icon: Icon(
                    _systemMasterTemplate == null ? Icons.add_box : Icons.edit,
                  ),
                  label: Text(
                    _systemMasterTemplate == null ? '新建系统母版' : '编辑系统母版',
                  ),
                ),
              if (_canManageSystemMasterTemplate) const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: (_loading || !_canManageTemplates)
                    ? null
                    : () => _showTemplateDialog(),
                icon: const Icon(Icons.add),
                label: const Text('新增模板'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: (_loading || !_canManageTemplates)
                    ? null
                    : _showExportDialog,
                icon: const Icon(Icons.download),
                label: const Text('导出模板'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: (_loading || !_canManageTemplates)
                    ? null
                    : _showImportDialog,
                icon: const Icon(Icons.upload),
                label: const Text('批量导入'),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _systemMasterTemplate == null
                  ? '系统母版状态：未配置（新建产品将跳过自动绑定默认模板）'
                  : '系统母版状态：已配置（版本 v${_systemMasterTemplate!.version}，步骤 ${_systemMasterTemplate!.steps.length}）',
            ),
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
              const SizedBox(width: 12),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: _lifecycleFilter,
                  decoration: const InputDecoration(
                    labelText: '按生命周期筛选',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('全部状态')),
                    DropdownMenuItem<String?>(
                      value: 'draft',
                      child: Text('草稿'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'published',
                      child: Text('已发布'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'archived',
                      child: Text('已归档'),
                    ),
                  ],
                  onChanged: (value) async {
                    setState(() {
                      _lifecycleFilter = value;
                    });
                    await _loadData();
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
                : Column(
                    children: [
                      _buildTemplateHeaderRow(theme),
                      const SizedBox(height: 8),
                      Expanded(
                        child: templates.isEmpty
                            ? const Center(child: Text('暂无模板数据'))
                            : ListView.separated(
                                itemCount: templates.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = templates[index];
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 12,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(item.productName),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(item.templateName),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            '${item.version} / P${item.publishedVersion}',
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            item.isDefault ? '是' : '否',
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            '${_lifecycleLabel(item.lifecycleStatus)} / ${item.isEnabled ? '启用' : '停用'}',
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            item.updatedAt.toLocal().toString(),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 64,
                                          child:
                                              UnifiedListTableHeaderStyle.actionMenuButton<
                                                _TemplateAction
                                              >(
                                                theme: theme,
                                                onSelected: (action) {
                                                  _handleTemplateAction(
                                                    action,
                                                    item,
                                                  );
                                                },
                                                itemBuilder: (context) =>
                                                    const [
                                                      PopupMenuItem(
                                                        value: _TemplateAction
                                                            .edit,
                                                        child: Text('编辑'),
                                                      ),
                                                      PopupMenuItem(
                                                        value: _TemplateAction
                                                            .publish,
                                                        child: Text('发布'),
                                                      ),
                                                      PopupMenuItem(
                                                        value: _TemplateAction
                                                            .impact,
                                                        child: Text('影响分析'),
                                                      ),
                                                      PopupMenuItem(
                                                        value: _TemplateAction
                                                            .versions,
                                                        child: Text('版本管理'),
                                                      ),
                                                      PopupMenuItem(
                                                        value: _TemplateAction
                                                            .delete,
                                                        child: Text('删除'),
                                                      ),
                                                    ],
                                              ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
