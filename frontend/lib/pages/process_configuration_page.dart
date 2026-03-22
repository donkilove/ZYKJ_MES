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
  _TemplateStepDraft({
    required this.stageId,
    required this.processId,
    this.standardMinutes = 0,
    this.isKeyProcess = false,
    this.stepRemark = '',
  });

  int stageId;
  int processId;
  int standardMinutes;
  bool isKeyProcess;
  String stepRemark;
}

enum _TemplateAction {
  detail,
  edit,
  createDraft,
  publish,
  copy,
  copyToProduct,
  copyFromMaster,
  enable,
  disable,
  archive,
  unarchive,
  impact,
  versions,
  compare,
  rollback,
  delete,
}

class ProcessConfigurationPage extends StatefulWidget {
  const ProcessConfigurationPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canViewTemplates,
    required this.canManageTemplates,
    required this.canManageSystemMasterTemplate,
    this.craftService,
    this.productionService,
    this.templateId,
    this.version,
    this.systemMasterVersions = false,
    this.jumpRequestId = 0,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canViewTemplates;
  final bool canManageTemplates;
  final bool canManageSystemMasterTemplate;
  final CraftService? craftService;
  final ProductionService? productionService;
  final int? templateId;
  final int? version;
  final bool systemMasterVersions;
  final int jumpRequestId;

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
  final _templateKeywordController = TextEditingController();
  String _templateKeyword = '';
  String? _productCategoryFilter;
  bool? _defaultTemplateFilter;
  bool? _templateEnabledFilter;
  DateTime? _updatedFromDate;
  DateTime? _updatedToDate;

  List<ProductionProductOption> _products = const [];
  List<CraftStageItem> _stages = const [];
  List<CraftProcessItem> _processes = const [];
  List<CraftTemplateItem> _templates = const [];
  CraftSystemMasterTemplateItem? _systemMasterTemplate;
  final Map<int, CraftTemplateDetail> _detailCache = {};
  int? _focusedTemplateId;
  String _jumpNotice = '';
  int _lastHandledJumpRequestId = -1;

  @override
  void initState() {
    super.initState();
    _craftService = widget.craftService ?? CraftService(widget.session);
    _productionService =
        widget.productionService ?? ProductionService(widget.session);
    _loadData();
  }

  @override
  void dispose() {
    _templateKeywordController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProcessConfigurationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.jumpRequestId != oldWidget.jumpRequestId) {
      _tryApplyJumpTarget(force: true);
    }
  }

  bool _isUnauthorized(Object error) {
    return error is ApiException && error.statusCode == 401;
  }

  bool get _canManageSystemMasterTemplate {
    return widget.canManageSystemMasterTemplate;
  }

  bool get _canViewTemplates => widget.canViewTemplates;

  bool get _canViewSystemMasterVersions {
    return _canManageSystemMasterTemplate || _canViewTemplates;
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
        productId: _productFilterId,
        keyword: _templateKeyword.isEmpty ? null : _templateKeyword,
        productCategory: _productCategoryFilter,
        isDefault: _defaultTemplateFilter,
        enabled: _templateEnabledFilter,
        lifecycleStatus: _lifecycleFilter,
        updatedFrom: _updatedFromDate,
        updatedTo: _updatedToDate == null
            ? null
            : DateTime(
                _updatedToDate!.year,
                _updatedToDate!.month,
                _updatedToDate!.day,
                23,
                59,
                59,
                999,
                999,
              ),
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
        if (_productCategoryFilter != null &&
            !_productCategoryOptions.contains(_productCategoryFilter)) {
          _productCategoryFilter = null;
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
        _tryApplyJumpTarget(force: true);
      }
    }
  }

  CraftTemplateItem? get _focusedTemplate {
    final focusedTemplateId = _focusedTemplateId;
    if (focusedTemplateId == null) {
      return null;
    }
    for (final item in _templates) {
      if (item.id == focusedTemplateId) {
        return item;
      }
    }
    return null;
  }

  void _tryApplyJumpTarget({bool force = false}) {
    if (!mounted) {
      return;
    }
    if (!force && widget.jumpRequestId == _lastHandledJumpRequestId) {
      return;
    }
    if (widget.systemMasterVersions) {
      setState(() {
        _focusedTemplateId = null;
        _jumpNotice = '已承接到系统母版历史版本视图';
      });
      _lastHandledJumpRequestId = widget.jumpRequestId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showSystemMasterVersionDialog();
        }
      });
      return;
    }
    final templateId = widget.templateId;
    if (templateId == null || templateId <= 0) {
      _lastHandledJumpRequestId = widget.jumpRequestId;
      return;
    }
    CraftTemplateItem? matched;
    for (final item in _templates) {
      if (item.id == templateId) {
        matched = item;
        break;
      }
    }
    if (matched == null) {
      setState(() {
        _focusedTemplateId = null;
        _jumpNotice = '未找到目标模板记录 #$templateId';
      });
      _lastHandledJumpRequestId = widget.jumpRequestId;
      return;
    }
    final version = widget.version;
    setState(() {
      _productFilterId = matched!.productId;
      _templateKeyword = '';
      _templateKeywordController.clear();
      _productCategoryFilter = null;
      _defaultTemplateFilter = null;
      _templateEnabledFilter = null;
      _updatedFromDate = null;
      _updatedToDate = null;
      _focusedTemplateId = matched.id;
      _jumpNotice = version == null
          ? '已定位模板 #${matched.id} ${matched.templateName}'
          : '已定位模板 #${matched.id} ${matched.templateName}，准备查看版本 v$version';
    });
    _lastHandledJumpRequestId = widget.jumpRequestId;
    if (version != null && version > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showVersionDialog(matched!, initialTargetVersion: version);
        }
      });
    }
  }

  List<CraftTemplateItem> get _filteredTemplates {
    return _templates;
  }

  List<String> get _productCategoryOptions {
    final categories = <String>{
      for (final item in _templates)
        if (item.productCategory.trim().isNotEmpty) item.productCategory.trim(),
    };
    final sorted = categories.toList();
    sorted.sort();
    return sorted;
  }

  String _formatDateLabel(DateTime? value) {
    if (value == null) {
      return '未设置';
    }
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<void> _pickUpdatedDate({required bool isFrom}) async {
    final initialDate = isFrom
        ? (_updatedFromDate ?? DateTime.now())
        : (_updatedToDate ?? _updatedFromDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isFrom) {
        _updatedFromDate = picked;
        if (_updatedToDate != null && _updatedToDate!.isBefore(picked)) {
          _updatedToDate = picked;
        }
      } else {
        _updatedToDate = picked;
        if (_updatedFromDate != null && _updatedFromDate!.isAfter(picked)) {
          _updatedFromDate = picked;
        }
      }
    });
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
        standardMinutes: 0,
        isKeyProcess: false,
        stepRemark: '',
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
          standardMinutes: steps[i].standardMinutes,
          isKeyProcess: steps[i].isKeyProcess,
          stepRemark: steps[i].stepRemark,
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

  Future<void> _showTemplateDetailDialog(CraftTemplateItem item) async {
    if (!_canViewTemplates) {
      _showNoPermission();
      return;
    }
    try {
      final detail = await _getTemplateDetail(item.id);
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('模板详情 - ${item.templateName}'),
          content: SizedBox(
            width: 820,
            height: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('产品：${item.productName}'),
                Text('版本：${item.version} / 已发布 P${item.publishedVersion}'),
                Text('生命周期：${_lifecycleLabel(item.lifecycleStatus)}'),
                Text('状态：${item.isEnabled ? '启用' : '停用'}'),
                Text('来源：${_templateSourceLabel(item)}'),
                if (item.remark.trim().isNotEmpty)
                  Text('备注：${item.remark.trim()}'),
                const SizedBox(height: 10),
                const Text(
                  '步骤列表',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: detail.steps.isEmpty
                      ? const Center(child: Text('暂无步骤'))
                      : ListView.separated(
                          itemCount: detail.steps.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final step = detail.steps[index];
                            return ListTile(
                              dense: true,
                              leading: Text('#${step.stepOrder}'),
                              title: Text(
                                '${step.stageCode} ${step.stageName}',
                              ),
                              subtitle: Text(
                                '${step.processCode} ${step.processName}\n'
                                '标准工时：${step.standardMinutes} 分钟｜${step.isKeyProcess ? '关键工序' : '普通工序'}'
                                '${step.stepRemark.trim().isNotEmpty ? '｜说明：${step.stepRemark.trim()}' : ''}',
                              ),
                              isThreeLine: true,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                try {
                  final contentBase64 = await _craftService
                      .exportTemplateDetail(templateId: item.id);
                  if (!dialogContext.mounted) {
                    return;
                  }
                  await _showJsonPreviewDialog(
                    dialogContext,
                    title: '模板导出 - ${item.templateName}',
                    contentBase64: contentBase64,
                  );
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
              child: const Text('导出当前模板'),
            ),
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
    final remarkController = TextEditingController(
      text: existing?.remark ?? '',
    );

    int selectedProductId =
        existing?.productId ?? _productFilterId ?? _products.first.id;
    bool isDefault = existing?.isDefault ?? false;
    bool isEnabled = existing?.isEnabled ?? true;
    bool syncOrders = true;

    List<_TemplateStepDraft> steps = [];
    if (isEdit) {
      CraftTemplateDetail detail;
      try {
        detail = await _getTemplateDetail(existing.id);
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
      steps = detail.steps
          .map(
            (item) => _TemplateStepDraft(
              stageId: item.stageId,
              processId: item.processId,
              standardMinutes: item.standardMinutes,
              isKeyProcess: item.isKeyProcess,
              stepRemark: item.stepRemark,
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
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: remarkController,
                          maxLength: 500,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: '备注（可选）',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
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
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '新建模板统一先保存为草稿，完成评审后再由列表中的“发布”入口生效。',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
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
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 160,
                                        child: TextFormField(
                                          initialValue: step.standardMinutes
                                              .toString(),
                                          decoration: const InputDecoration(
                                            labelText: '标准工时(分钟)',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          onChanged: (value) {
                                            setDialogState(() {
                                              step.standardMinutes =
                                                  int.tryParse(value) ?? 0;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: step.stepRemark,
                                          decoration: const InputDecoration(
                                            labelText: '步骤说明',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          maxLength: 500,
                                          onChanged: (value) {
                                            setDialogState(() {
                                              step.stepRemark = value.trim();
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: const Text('关键工序'),
                                    value: step.isKeyProcess,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        step.isKeyProcess = value ?? false;
                                      });
                                    },
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
                          remark: remarkController.text.trim(),
                        );
                      } else {
                        await _craftService.createTemplate(
                          productId: selectedProductId,
                          templateName: templateNameController.text.trim(),
                          isDefault: isDefault,
                          remark: remarkController.text.trim(),
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
    remarkController.dispose();

    if (saved == true) {
      if (existing != null) {
        _detailCache.remove(existing.id);
      }
      await _loadData();
    }
  }

  Future<void> _createDraftThenEdit(CraftTemplateItem item) async {
    try {
      await _craftService.createTemplateDraft(templateId: item.id);
      _detailCache.remove(item.id);
      await _loadData();
      if (!mounted) {
        return;
      }
      CraftTemplateItem? refreshed;
      for (final row in _templates) {
        if (row.id == item.id) {
          refreshed = row;
          break;
        }
      }
      if (refreshed != null) {
        await _showTemplateDialog(existing: refreshed);
      }
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
                  standardMinutes: item.standardMinutes,
                  isKeyProcess: item.isKeyProcess,
                  stepRemark: item.stepRemark,
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
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: 160,
                                        child: TextFormField(
                                          initialValue: step.standardMinutes
                                              .toString(),
                                          decoration: const InputDecoration(
                                            labelText: '标准工时(分钟)',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          onChanged: (value) {
                                            setDialogState(() {
                                              step.standardMinutes =
                                                  int.tryParse(value) ?? 0;
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: step.stepRemark,
                                          decoration: const InputDecoration(
                                            labelText: '步骤说明',
                                            border: OutlineInputBorder(),
                                            isDense: true,
                                          ),
                                          maxLength: 500,
                                          onChanged: (value) {
                                            setDialogState(() {
                                              step.stepRemark = value.trim();
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: const Text('关键工序'),
                                    value: step.isKeyProcess,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        step.isKeyProcess = value ?? false;
                                      });
                                    },
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

  Future<void> _showSystemMasterVersionDialog() async {
    if (!_canViewSystemMasterVersions) {
      _showNoPermission();
      return;
    }
    try {
      final result = await _craftService.listSystemMasterTemplateVersions();
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('系统母版历史版本'),
            content: SizedBox(
              width: 920,
              height: 560,
              child: result.items.isEmpty
                  ? const Center(child: Text('暂无历史版本'))
                  : ListView.separated(
                      itemCount: result.items.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = result.items[index];
                        final subtitleParts = <String>[
                          item.createdAt.toLocal().toString(),
                          if ((item.createdByUsername ?? '').trim().isNotEmpty)
                            '操作人：${item.createdByUsername}',
                          if ((item.note ?? '').trim().isNotEmpty)
                            item.note!.trim(),
                        ];
                        return ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            12,
                          ),
                          title: Text('v${item.version} · ${item.action}'),
                          subtitle: Text(subtitleParts.join(' · ')),
                          children: [
                            if (item.steps.isEmpty)
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text('该版本无步骤数据'),
                              )
                            else
                              Column(
                                children: item.steps
                                    .map(
                                      (step) => ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: Text('#${step.stepOrder}'),
                                        title: Text(
                                          '${step.stageCode} ${step.stageName}',
                                        ),
                                        subtitle: Text(
                                          '${step.processCode} ${step.processName}',
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                          ],
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('关闭'),
              ),
            ],
          );
        },
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

  Future<void> _copyTemplate(CraftTemplateItem item) async {
    if (!_canManageTemplates) {
      _showNoPermission();
      return;
    }
    final nameController = TextEditingController(
      text: '${item.templateName} 副本',
    );
    final saved = await showLockedFormDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('复制模板'),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '新模板名称',
                border: OutlineInputBorder(),
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
                final newName = nameController.text.trim();
                if (newName.isEmpty) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(const SnackBar(content: Text('请输入新模板名称')));
                  return;
                }
                try {
                  await _craftService.copyTemplate(
                    templateId: item.id,
                    newName: newName,
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
              child: const Text('复制'),
            ),
          ],
        );
      },
    );
    nameController.dispose();
    if (saved == true) {
      await _loadData();
    }
  }

  Future<void> _copyTemplateToProduct(CraftTemplateItem item) async {
    if (!_canManageTemplates) {
      _showNoPermission();
      return;
    }
    if (_products.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无可用产品')));
      return;
    }
    final nameController = TextEditingController(
      text: '${item.templateName} 副本',
    );
    int selectedProductId = _products.first.id;
    final saved = await showLockedFormDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('跨产品复制模板'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedProductId,
                      decoration: const InputDecoration(
                        labelText: '目标产品',
                        border: OutlineInputBorder(),
                      ),
                      items: _products
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedProductId = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '新模板名称',
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
                    final newName = nameController.text.trim();
                    if (newName.isEmpty) {
                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(const SnackBar(content: Text('请输入新模板名称')));
                      return;
                    }
                    try {
                      await _craftService.copyTemplateToProduct(
                        templateId: item.id,
                        targetProductId: selectedProductId,
                        newName: newName,
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
                  child: const Text('复制'),
                ),
              ],
            );
          },
        );
      },
    );
    nameController.dispose();
    if (saved == true) await _loadData();
  }

  Future<void> _copyFromSystemMaster(CraftTemplateItem item) async {
    if (!_canManageTemplates) {
      _showNoPermission();
      return;
    }
    if (_products.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无可用产品')));
      return;
    }
    final nameController = TextEditingController(text: '系统母版套版');
    int selectedProductId = item.productId;
    final saved = await showLockedFormDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('从系统母版套版'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedProductId,
                      decoration: const InputDecoration(
                        labelText: '目标产品',
                        border: OutlineInputBorder(),
                      ),
                      items: _products
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedProductId = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: '新模板名称',
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
                    final newName = nameController.text.trim();
                    if (newName.isEmpty) {
                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(const SnackBar(content: Text('请输入新模板名称')));
                      return;
                    }
                    try {
                      await _craftService.copySystemMasterToProduct(
                        productId: selectedProductId,
                        newName: newName,
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
                  child: const Text('套版'),
                ),
              ],
            );
          },
        );
      },
    );
    nameController.dispose();
    if (saved == true) await _loadData();
  }

  Future<void> _archiveTemplate(CraftTemplateItem item) async {
    if (!_canManageTemplates) {
      _showNoPermission();
      return;
    }
    final confirmed = await _confirmTemplateActionWithImpact(
      item: item,
      title: '归档模板',
      confirmText: '归档',
      description: '确认归档模板 ${item.templateName} 吗？归档后将无法用于新订单。',
    );
    if (confirmed != true) {
      return;
    }
    try {
      await _craftService.archiveTemplate(templateId: item.id);
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

  Future<void> _unarchiveTemplate(CraftTemplateItem item) async {
    if (!_canManageTemplates) {
      _showNoPermission();
      return;
    }
    try {
      await _craftService.unarchiveTemplate(templateId: item.id);
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

  Future<void> _setTemplateEnabled(
    CraftTemplateItem item, {
    required bool enabled,
  }) async {
    if (!_canManageTemplates) {
      _showNoPermission();
      return;
    }
    if (item.isEnabled == enabled) {
      return;
    }
    if (!mounted) {
      return;
    }
    final actionText = enabled ? '启用' : '停用';
    final bool? confirmed;
    if (enabled) {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('$actionText模板'),
          content: Text('确认$actionText模板 ${item.templateName} 吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(actionText),
            ),
          ],
        ),
      );
    } else {
      confirmed = await _confirmTemplateActionWithImpact(
        item: item,
        title: '$actionText模板',
        confirmText: actionText,
        description: '确认$actionText模板 ${item.templateName} 吗？停用后模板将不能继续用于维护与新建流程。',
      );
    }
    if (confirmed != true) {
      return;
    }
    try {
      if (enabled) {
        await _craftService.enableTemplate(templateId: item.id);
      } else {
        await _craftService.disableTemplate(templateId: item.id);
      }
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

  Future<void> _deleteTemplate(CraftTemplateItem item) async {
    if (!_canManageTemplates) {
      _showNoPermission();
      return;
    }
    final confirmed = await _confirmTemplateActionWithImpact(
      item: item,
      title: '删除模板',
      confirmText: '删除',
      description:
          '确认删除模板 ${item.templateName} 吗？删除前已展示影响摘要；若存在订单、历史版本或下游复用模板，后端会继续拦截。',
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

  String _templateSourceLabel(CraftTemplateItem item) {
    switch (item.sourceType) {
      case 'template':
        return '同产品模板复制：${item.sourceTemplateName ?? '-'}${item.sourceTemplateVersion != null ? ' v${item.sourceTemplateVersion}' : ''}';
      case 'cross_product_template':
        return '跨产品模板复制：${item.sourceTemplateName ?? '-'}${item.sourceTemplateVersion != null ? ' v${item.sourceTemplateVersion}' : ''}';
      case 'system_master':
        return '系统母版套版${item.sourceSystemMasterVersion != null ? ' v${item.sourceSystemMasterVersion}' : ''}';
      default:
        return '手工创建';
    }
  }

  String _templateVersionActionLabel(CraftTemplateVersionItem version) {
    final recordTitle = version.recordTitle.trim();
    if (recordTitle.isNotEmpty) {
      return recordTitle;
    }
    if (version.action == 'publish') {
      return '发布记录 P${version.version}';
    }
    if (version.action == 'rollback') {
      return '回滚发布记录 P${version.version}';
    }
    return '版本记录 P${version.version}';
  }

  String _templateVersionSummary(CraftTemplateVersionItem version) {
    final recordSummary = version.recordSummary.trim();
    if (recordSummary.isNotEmpty) {
      return recordSummary;
    }
    if (version.action == 'publish') {
      return '该记录对应一次正式发布，版本已进入生效态。';
    }
    if (version.action == 'rollback') {
      return '该记录对应一次回滚后重新发布，已替换当前生效版本。';
    }
    return '该记录仅用于历史追溯，是否生效以发布记录为准。';
  }

  CraftTemplateItem? _requireFocusedTemplate(String actionLabel) {
    final focused = _focusedTemplate;
    if (focused != null) {
      return focused;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('请先在模板列表中定位后再执行“$actionLabel”')));
    return null;
  }

  Future<void> _showTopCopyFromMasterShortcut() async {
    if (!_canManageTemplates) {
      _showNoPermission();
      return;
    }
    final focused = _focusedTemplate;
    if (focused != null) {
      await _copyFromSystemMaster(focused);
      return;
    }
    if (_products.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无可用产品')));
      return;
    }
    final fallbackProductId = _productFilterId ?? _products.first.id;
    final fallbackProduct = _products.firstWhere(
      (item) => item.id == fallbackProductId,
      orElse: () => _products.first,
    );
    await _copyFromSystemMaster(
      CraftTemplateItem(
        id: 0,
        productId: fallbackProduct.id,
        productName: fallbackProduct.name,
        productCategory: '',
        templateName: '系统母版套版',
        version: 0,
        lifecycleStatus: 'draft',
        publishedVersion: 0,
        isDefault: false,
        isEnabled: true,
        createdByUserId: null,
        createdByUsername: null,
        updatedByUserId: null,
        updatedByUsername: null,
        remark: '',
        sourceType: 'manual',
        sourceTemplateId: null,
        sourceTemplateName: null,
        sourceTemplateVersion: null,
        sourceProductId: null,
        sourceSystemMasterVersion: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
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

  String _impactReferenceTitle(CraftTemplateImpactReferenceItem item) {
    final code = item.refCode?.trim();
    if (code != null && code.isNotEmpty && code != item.refName) {
      return '$code ${item.refName}';
    }
    return item.refName;
  }

  Widget _buildImpactSummaryWrap(CraftTemplateImpactAnalysis analysis) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(label: Text('总计 ${analysis.totalOrders}')),
        Chip(label: Text('待开工 ${analysis.pendingOrders}')),
        Chip(label: Text('生产中 ${analysis.inProgressOrders}')),
        Chip(label: Text('可同步 ${analysis.syncableOrders}')),
        Chip(label: Text('受阻 ${analysis.blockedOrders}')),
        if (analysis.totalReferences > 0)
          Chip(label: Text('关键引用 ${analysis.totalReferences}')),
        if (analysis.userStageReferenceCount > 0)
          Chip(label: Text('用户工段 ${analysis.userStageReferenceCount}')),
        if (analysis.templateReuseReferenceCount > 0)
          Chip(label: Text('模板复用 ${analysis.templateReuseReferenceCount}')),
      ],
    );
  }

  Widget _buildImpactReferenceSection(CraftTemplateImpactAnalysis analysis) {
    if (analysis.referenceItems.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Text('关键引用对象', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 168,
          child: ListView.separated(
            itemCount: analysis.referenceItems.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final ref = analysis.referenceItems[index];
              return ListTile(
                dense: true,
                title: Text(_impactReferenceTitle(ref)),
                subtitle: Text(
                  [
                    if ((ref.detail ?? '').isNotEmpty) ref.detail!,
                    if ((ref.riskNote ?? '').isNotEmpty) ref.riskNote!,
                  ].join('｜'),
                ),
                trailing: Text(ref.refStatus ?? '-'),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionImpactPreview(CraftTemplateImpactAnalysis analysis) {
    final previewOrders = analysis.items.take(3).toList();
    final previewReferences = analysis.referenceItems.take(3).toList();
    if (previewOrders.isEmpty && previewReferences.isEmpty) {
      return const Text('当前未发现受影响订单与关键引用。');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (previewOrders.isNotEmpty) ...[
          const Text('订单影响摘要', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...previewOrders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${order.orderCode} · ${order.orderStatus}${(order.reason ?? '').isNotEmpty ? ' · ${order.reason}' : ''}',
              ),
            ),
          ),
          if (analysis.items.length > previewOrders.length)
            Text('其余 ${analysis.items.length - previewOrders.length} 条请通过“影响分析”查看。'),
        ],
        if (previewReferences.isNotEmpty) ...[
          if (previewOrders.isNotEmpty) const SizedBox(height: 12),
          const Text('关键引用摘要', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...previewReferences.map(
            (ref) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${_impactReferenceTitle(ref)}${(ref.detail ?? '').isNotEmpty ? ' · ${ref.detail}' : ''}${(ref.riskNote ?? '').isNotEmpty ? ' · ${ref.riskNote}' : ''}',
              ),
            ),
          ),
          if (analysis.referenceItems.length > previewReferences.length)
            Text(
              '其余 ${analysis.referenceItems.length - previewReferences.length} 条关键引用请通过“影响分析”查看。',
            ),
        ],
      ],
    );
  }

  bool _isTemplateActionBlocked(CraftTemplateImpactAnalysis analysis) {
    return analysis.blockedOrders > 0;
  }

  Future<bool> _confirmTemplateActionWithImpact({
    required CraftTemplateItem item,
    required String title,
    required String confirmText,
    required String description,
  }) async {
    try {
      final analysis = await _craftService.getTemplateImpactAnalysis(
        templateId: item.id,
      );
      final isBlocked = _isTemplateActionBlocked(analysis);
      if (!mounted) {
        return false;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(description),
                  if (isBlocked) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(dialogContext).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '当前存在 ${analysis.blockedOrders} 条阻断级引用，后端会拦截本次$confirmText；请先处理进行中工单后再操作。',
                        style: TextStyle(
                          color: Theme.of(
                            dialogContext,
                          ).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildImpactSummaryWrap(analysis),
                  const SizedBox(height: 12),
                  _buildActionImpactPreview(analysis),
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
              onPressed: isBlocked
                  ? null
                  : () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmText),
            ),
          ],
        ),
      );
      return confirmed == true;
    } catch (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return false;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
      return false;
    }
  }

  Future<void> _showImpactAnalysisDialog(CraftTemplateItem item) async {
    if (!_canViewTemplates) {
      _showNoPermission();
      return;
    }
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
                _buildImpactSummaryWrap(analysis),
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
                _buildImpactReferenceSection(analysis),
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

  Future<void> _showJsonPreviewDialog(
    BuildContext context, {
    required String title,
    required String contentBase64,
  }) async {
    final content = contentBase64.trim().isEmpty
        ? '无导出内容'
        : utf8.decode(base64Decode(contentBase64));
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 760,
          height: 520,
          child: SingleChildScrollView(child: SelectableText(content)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
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
                      _buildImpactSummaryWrap(analysis!),
                      const SizedBox(height: 8),
                      if (analysis.items.any((item) => !item.syncable))
                        Text(
                          '存在无法同步的订单，发布时会自动跳过受阻订单。',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      if (analysis.referenceItems.isNotEmpty)
                        Text(
                          '已纳入用户工段引用与模板复用关系，请发布前同步确认关键引用对象。',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      _buildImpactReferenceSection(analysis),
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
                        expectedVersion: item.version,
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
    required List<int> availableVersions,
  }) async {
    bool applyOrderSync = false;
    bool confirmed = false;
    final versionOptions = availableVersions.toSet().toList()
      ..sort((left, right) => right.compareTo(left));
    int selectedTargetVersion = versionOptions.contains(targetVersion)
        ? targetVersion
        : versionOptions.first;
    bool loadingAnalysis = false;
    final noteController = TextEditingController(
      text: '回滚到版本 v$selectedTargetVersion',
    );
    CraftTemplateImpactAnalysis? analysis;

    try {
      analysis = await _craftService.getTemplateImpactAnalysis(
        templateId: item.id,
        targetVersion: selectedTargetVersion,
      );
      selectedTargetVersion = analysis.targetVersion;
    } catch (error) {
      noteController.dispose();
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return false;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
      return false;
    }
    if (!mounted) {
      noteController.dispose();
      return false;
    }

    final done = await showLockedFormDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentAnalysis = analysis!;

            Future<void> reloadImpactAnalysis(int nextTargetVersion) async {
              final previousVersion =
                  analysis?.targetVersion ?? selectedTargetVersion;
              setDialogState(() {
                loadingAnalysis = true;
                selectedTargetVersion = nextTargetVersion;
              });
              try {
                final nextAnalysis = await _craftService
                    .getTemplateImpactAnalysis(
                      templateId: item.id,
                      targetVersion: nextTargetVersion,
                    );
                if (!dialogContext.mounted) {
                  return;
                }
                setDialogState(() {
                  analysis = nextAnalysis;
                  selectedTargetVersion = nextAnalysis.targetVersion;
                  loadingAnalysis = false;
                  final currentNote = noteController.text.trim();
                  if (currentNote.isEmpty ||
                      currentNote == '回滚到版本 v$previousVersion') {
                    noteController.text =
                        '回滚到版本 v${nextAnalysis.targetVersion}';
                  }
                });
              } catch (error) {
                if (_isUnauthorized(error)) {
                  widget.onLogout();
                  return;
                }
                if (!dialogContext.mounted) {
                  return;
                }
                setDialogState(() {
                  loadingAnalysis = false;
                });
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
              }
            }

            return AlertDialog(
              title: Text('回滚模板 - ${item.templateName}'),
              content: SizedBox(
                width: 620,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedTargetVersion,
                      decoration: const InputDecoration(
                        labelText: '回滚目标版本',
                        border: OutlineInputBorder(),
                      ),
                      items: versionOptions
                          .map(
                            (version) => DropdownMenuItem(
                              value: version,
                              child: Text('v$version'),
                            ),
                          )
                          .toList(),
                      onChanged: loadingAnalysis
                          ? null
                          : (value) {
                              if (value == null ||
                                  value == selectedTargetVersion) {
                                return;
                              }
                              reloadImpactAnalysis(value);
                            },
                    ),
                    const SizedBox(height: 8),
                    Text('当前预览版本：v${currentAnalysis.targetVersion}'),
                    const SizedBox(height: 8),
                    if (loadingAnalysis) const LinearProgressIndicator(),
                    if (loadingAnalysis) const SizedBox(height: 8),
                    _buildImpactSummaryWrap(currentAnalysis),
                    const SizedBox(height: 8),
                    if (currentAnalysis.items.any((order) => !order.syncable))
                      Text(
                        '存在无法同步的订单，回滚时会自动跳过受阻订单。',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (currentAnalysis.referenceItems.isNotEmpty)
                      Text(
                        '已纳入用户工段引用与模板复用关系，请回滚前同步确认关键引用对象。',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
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
                    const SizedBox(height: 12),
                    const Text(
                      '订单明细',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 220,
                      child: currentAnalysis.items.isEmpty
                          ? const Center(child: Text('暂无受影响订单'))
                          : ListView.separated(
                              itemCount: currentAnalysis.items.length,
                              separatorBuilder: (_, separatorIndex) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final order = currentAnalysis.items[index];
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
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    _buildImpactReferenceSection(currentAnalysis),
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
                        targetVersion: selectedTargetVersion,
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

  Future<void> _showVersionDialog(
    CraftTemplateItem item, {
    int? initialTargetVersion,
  }) async {
    if (!_canViewTemplates) {
      _showNoPermission();
      return;
    }
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

    final hasInitialTargetVersion =
        initialTargetVersion != null &&
        versions.items.any((entry) => entry.version == initialTargetVersion);
    int fromVersion = versions.items.length > 1
        ? versions.items[1].version
        : versions.items.first.version;
    int toVersion = hasInitialTargetVersion
        ? initialTargetVersion
        : versions.items.first.version;
    if (hasInitialTargetVersion && versions.items.length > 1) {
      fromVersion = versions.items.first.version == initialTargetVersion
          ? versions.items[1].version
          : versions.items.first.version;
    }
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
                    Text(
                      _canManageTemplates ? '历史版本（点击回滚）' : '历史版本',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (hasInitialTargetVersion)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '已自动定位目标版本 v$initialTargetVersion',
                          style: Theme.of(dialogContext).textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        itemCount: versions.items.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final version = versions.items[index];
                          final isTargetVersion =
                              version.version == initialTargetVersion;
                          return ListTile(
                            dense: true,
                            tileColor: isTargetVersion
                                ? Theme.of(dialogContext)
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: 0.28)
                                : null,
                            title: Text(
                              isTargetVersion
                                  ? '${_templateVersionActionLabel(version)} · 目标版本'
                                  : _templateVersionActionLabel(version),
                            ),
                            subtitle: Text(
                              '${version.createdAt.toLocal()} · ${_templateVersionSummary(version)}'
                              '${version.note != null && version.note!.trim().isNotEmpty ? '\n说明：${version.note}' : ''}'
                              '${version.createdByUsername != null && version.createdByUsername!.trim().isNotEmpty ? '\n操作人：${version.createdByUsername}' : ''}'
                              '${version.sourceVersion != null ? '\n来源版本：v${version.sourceVersion}' : ''}',
                            ),
                            isThreeLine: true,
                            trailing: _canManageTemplates
                                ? Wrap(
                                    spacing: 8,
                                    children: [
                                      TextButton(
                                        onPressed: () async {
                                          try {
                                            final contentBase64 =
                                                await _craftService
                                                    .exportTemplateVersion(
                                                      templateId: item.id,
                                                      version: version.version,
                                                    );
                                            if (!dialogContext.mounted) {
                                              return;
                                            }
                                            await _showJsonPreviewDialog(
                                              dialogContext,
                                              title:
                                                  '版本导出 - ${item.templateName} v${version.version}',
                                              contentBase64: contentBase64,
                                            );
                                          } catch (error) {
                                            if (_isUnauthorized(error)) {
                                              widget.onLogout();
                                              return;
                                            }
                                            if (dialogContext.mounted) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    _errorMessage(error),
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        child: const Text('导出'),
                                      ),
                                      FilledButton.tonal(
                                        onPressed: () async {
                                          final rolledBack =
                                              await _showRollbackDialog(
                                                item: item,
                                                targetVersion: version.version,
                                                availableVersions: versions
                                                    .items
                                                    .map(
                                                      (entry) => entry.version,
                                                    )
                                                    .toList(),
                                              );
                                          if (rolledBack &&
                                              dialogContext.mounted) {
                                            Navigator.of(
                                              dialogContext,
                                            ).pop(true);
                                          }
                                        },
                                        child: const Text('回滚'),
                                      ),
                                    ],
                                  )
                                : TextButton(
                                    onPressed: () async {
                                      try {
                                        final contentBase64 =
                                            await _craftService
                                                .exportTemplateVersion(
                                                  templateId: item.id,
                                                  version: version.version,
                                                );
                                        if (!dialogContext.mounted) {
                                          return;
                                        }
                                        await _showJsonPreviewDialog(
                                          dialogContext,
                                          title:
                                              '版本导出 - ${item.templateName} v${version.version}',
                                          contentBase64: contentBase64,
                                        );
                                      } catch (error) {
                                        if (_isUnauthorized(error)) {
                                          widget.onLogout();
                                          return;
                                        }
                                        if (dialogContext.mounted) {
                                          ScaffoldMessenger.of(
                                            dialogContext,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                _errorMessage(error),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: const Text('导出'),
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

  Widget _buildJumpBanner(ThemeData theme) {
    final focusedTemplate = _focusedTemplate;
    if (_jumpNotice.isEmpty && focusedTemplate == null) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              focusedTemplate == null
                  ? _jumpNotice
                  : '$_jumpNotice，产品：${focusedTemplate.productName}，当前版本：v${focusedTemplate.version}',
            ),
          ),
          if (focusedTemplate != null && _canViewTemplates)
            TextButton(
              onPressed: () => _showTemplateDetailDialog(focusedTemplate),
              child: const Text('查看详情'),
            ),
        ],
      ),
    );
  }

  Future<void> _showExportDialog() async {
    if (!_canManageTemplates) {
      _showNoPermission();
      return;
    }
    try {
      final result = await _craftService.exportTemplates(
        productId: _productFilterId,
        keyword: _templateKeyword.isEmpty ? null : _templateKeyword,
        productCategory: _productCategoryFilter,
        isDefault: _defaultTemplateFilter,
        enabled: _templateEnabledFilter,
        lifecycleStatus: _lifecycleFilter,
        updatedFrom: _updatedFromDate,
        updatedTo: _updatedToDate == null
            ? null
            : DateTime(
                _updatedToDate!.year,
                _updatedToDate!.month,
                _updatedToDate!.day,
                23,
                59,
                59,
                999,
                999,
              ),
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
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '说明：导入成功后统一生成草稿模板，不允许直接绕过发布流程。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
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
                      );
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              '导入完成：创建 ${result.created}，更新 ${result.updated}，跳过 ${result.skipped}',
                            ),
                          ),
                        );
                        if (result.errors.isNotEmpty) {
                          await showDialog<void>(
                            context: dialogContext,
                            builder: (errorContext) => AlertDialog(
                              title: Text('导入错误明细（${result.errors.length} 条）'),
                              content: SizedBox(
                                width: 720,
                                height: 420,
                                child: ListView.separated(
                                  itemCount: result.errors.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) => ListTile(
                                    dense: true,
                                    title: Text(result.errors[index]),
                                  ),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(errorContext).pop(),
                                  child: const Text('关闭'),
                                ),
                              ],
                            ),
                          );
                        }
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
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
    switch (action) {
      case _TemplateAction.detail:
        if (!_canViewTemplates) {
          _showNoPermission();
          return;
        }
        await _showTemplateDetailDialog(item);
        return;
      case _TemplateAction.copy:
        if (!_canManageTemplates) {
          _showNoPermission();
          return;
        }
        await _copyTemplate(item);
        return;
      case _TemplateAction.copyToProduct:
        if (!_canManageTemplates) {
          _showNoPermission();
          return;
        }
        await _copyTemplateToProduct(item);
        return;
      case _TemplateAction.copyFromMaster:
        if (!_canManageTemplates) {
          _showNoPermission();
          return;
        }
        await _copyFromSystemMaster(item);
        return;
      case _TemplateAction.enable:
        if (!_canManageTemplates) {
          _showNoPermission();
          return;
        }
        await _setTemplateEnabled(item, enabled: true);
        return;
      case _TemplateAction.disable:
        if (!_canManageTemplates) {
          _showNoPermission();
          return;
        }
        await _setTemplateEnabled(item, enabled: false);
        return;
      case _TemplateAction.archive:
        if (!_canManageTemplates) {
          _showNoPermission();
          return;
        }
        await _archiveTemplate(item);
        return;
      case _TemplateAction.unarchive:
        if (!_canManageTemplates) {
          _showNoPermission();
          return;
        }
        await _unarchiveTemplate(item);
        return;
      case _TemplateAction.edit:
        if (!_canManageTemplates) {
          _showNoPermission();
          return;
        }
        await _showTemplateDialog(existing: item);
        return;
      case _TemplateAction.createDraft:
        if (!_canManageTemplates) {
          _showNoPermission();
          return;
        }
        await _createDraftThenEdit(item);
        return;
      case _TemplateAction.publish:
        if (!_canManageTemplates) {
          _showNoPermission();
          return;
        }
        if (item.lifecycleStatus != 'draft') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('只有草稿模板可执行发布，请先创建草稿后再发布')),
          );
          return;
        }
        await _showPublishDialog(item);
        return;
      case _TemplateAction.impact:
        if (!_canViewTemplates) {
          _showNoPermission();
          return;
        }
        await _showImpactAnalysisDialog(item);
        return;
      case _TemplateAction.versions:
        if (!_canViewTemplates) {
          _showNoPermission();
          return;
        }
        await _showVersionDialog(item);
        return;
      case _TemplateAction.compare:
        if (!_canViewTemplates) {
          _showNoPermission();
          return;
        }
        await _showVersionDialog(item);
        return;
      case _TemplateAction.rollback:
        if (!_canManageTemplates) {
          _showNoPermission();
          return;
        }
        await _showVersionDialog(item);
        return;
      case _TemplateAction.delete:
        if (!_canManageTemplates) {
          _showNoPermission();
          return;
        }
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
          Expanded(flex: 1, child: _buildHeaderLabel(theme, '最近更新人')),
          Expanded(flex: 2, child: _buildHeaderLabel(theme, '更新时间')),
          SizedBox(
            width: 64,
            child: _buildHeaderLabel(theme, '操作', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMasterStepCell(
    String text, {
    int flex = 1,
    TextAlign textAlign = TextAlign.start,
    bool isHeader = false,
  }) {
    final theme = Theme.of(context);
    final style = isHeader
        ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
        : theme.textTheme.bodyMedium;
    return Expanded(
      flex: flex,
      child: Text(text, textAlign: textAlign, style: style),
    );
  }

  Widget _buildSystemMasterStepsSection(ThemeData theme) {
    final List<CraftSystemMasterTemplateStepItem> steps =
        _systemMasterTemplate?.steps ??
        const <CraftSystemMasterTemplateStepItem>[];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '系统母版步骤',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            steps.isEmpty ? '未配置系统母版，主页面暂无可展示步骤。' : '当前主页面直接展示系统母版完整步骤明细。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (steps.isEmpty)
            const Text('暂无系统母版步骤')
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.65),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(7),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildSystemMasterStepCell(
                          '序号',
                          textAlign: TextAlign.center,
                          isHeader: true,
                        ),
                        _buildSystemMasterStepCell(
                          '工段',
                          flex: 2,
                          isHeader: true,
                        ),
                        _buildSystemMasterStepCell(
                          '工序',
                          flex: 2,
                          isHeader: true,
                        ),
                        _buildSystemMasterStepCell(
                          '标准工时',
                          isHeader: true,
                          textAlign: TextAlign.center,
                        ),
                        _buildSystemMasterStepCell(
                          '关键工序',
                          isHeader: true,
                          textAlign: TextAlign.center,
                        ),
                        _buildSystemMasterStepCell(
                          '备注',
                          flex: 2,
                          isHeader: true,
                        ),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: steps.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: theme.dividerColor),
                      itemBuilder: (context, index) {
                        final step = steps[index];
                        final stageLabel = '${step.stageCode} ${step.stageName}'
                            .trim();
                        final processLabel =
                            '${step.processCode} ${step.processName}'.trim();
                        final remark = step.stepRemark.trim().isEmpty
                            ? '-'
                            : step.stepRemark.trim();
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSystemMasterStepCell(
                                '${step.stepOrder}',
                                textAlign: TextAlign.center,
                              ),
                              _buildSystemMasterStepCell(stageLabel, flex: 2),
                              _buildSystemMasterStepCell(processLabel, flex: 2),
                              _buildSystemMasterStepCell(
                                '${step.standardMinutes} 分钟',
                                textAlign: TextAlign.center,
                              ),
                              _buildSystemMasterStepCell(
                                step.isKeyProcess ? '是' : '否',
                                textAlign: TextAlign.center,
                              ),
                              _buildSystemMasterStepCell(remark, flex: 2),
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
              if (_canManageSystemMasterTemplate &&
                  _systemMasterTemplate != null)
                const SizedBox(width: 8),
              if (_canManageSystemMasterTemplate &&
                  _systemMasterTemplate != null)
                OutlinedButton.icon(
                  onPressed: _loading ? null : _showSystemMasterVersionDialog,
                  icon: const Icon(Icons.history),
                  label: const Text('母版历史版本'),
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
          _buildJumpBanner(theme),
          if (_canManageTemplates)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _showTopCopyFromMasterShortcut,
                    icon: const Icon(Icons.library_add),
                    label: const Text('从系统母版套版'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () async {
                            final item = _requireFocusedTemplate('从已有模板复制');
                            if (item == null) {
                              return;
                            }
                            await _copyTemplate(item);
                          },
                    icon: const Icon(Icons.copy_all),
                    label: const Text('从已有模板复制'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () async {
                            final item = _requireFocusedTemplate('导出版本参数');
                            if (item == null) {
                              return;
                            }
                            await _showVersionDialog(item);
                          },
                    icon: const Icon(Icons.tune),
                    label: const Text('导出版本参数'),
                  ),
                  if (_focusedTemplate != null)
                    Text(
                      '当前定位：${_focusedTemplate!.templateName}（${_focusedTemplate!.productName}）',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
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
                  : '系统母版状态：已配置（版本 v${_systemMasterTemplate!.version}，步骤 ${_systemMasterTemplate!.steps.length}，最近更新人 ${_systemMasterTemplate!.updatedByUsername ?? '-'}，最近更新时间 ${_systemMasterTemplate!.updatedAt.toLocal()}；自动套版门禁默认开启，可由后端配置 craft_auto_bind_default_template_enabled 关闭）',
            ),
          ),
          const SizedBox(height: 12),
          _buildSystemMasterStepsSection(theme),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
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
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _lifecycleFilter,
                      decoration: const InputDecoration(
                        labelText: '按生命周期筛选',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('全部状态'),
                        ),
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
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _templateKeywordController,
                      decoration: const InputDecoration(
                        labelText: '模板名称搜索',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _templateKeyword = value.trim();
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _productCategoryFilter,
                      decoration: const InputDecoration(
                        labelText: '产品分类筛选',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('全部分类'),
                        ),
                        ..._productCategoryOptions.map(
                          (category) => DropdownMenuItem<String?>(
                            value: category,
                            child: Text(category),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _productCategoryFilter = value;
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<bool?>(
                      initialValue: _defaultTemplateFilter,
                      decoration: const InputDecoration(
                        labelText: '默认模板筛选',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem<bool?>(
                          value: null,
                          child: Text('全部默认状态'),
                        ),
                        DropdownMenuItem<bool?>(
                          value: true,
                          child: Text('默认模板'),
                        ),
                        DropdownMenuItem<bool?>(
                          value: false,
                          child: Text('非默认模板'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _defaultTemplateFilter = value;
                        });
                      },
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<bool?>(
                      initialValue: _templateEnabledFilter,
                      decoration: const InputDecoration(
                        labelText: '启用状态筛选',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem<bool?>(
                          value: null,
                          child: Text('全部状态'),
                        ),
                        DropdownMenuItem<bool?>(value: true, child: Text('启用')),
                        DropdownMenuItem<bool?>(
                          value: false,
                          child: Text('停用'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _templateEnabledFilter = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickUpdatedDate(isFrom: true),
                    icon: const Icon(Icons.event),
                    label: Text('起始更新日：${_formatDateLabel(_updatedFromDate)}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickUpdatedDate(isFrom: false),
                    icon: const Icon(Icons.event_available),
                    label: Text('结束更新日：${_formatDateLabel(_updatedToDate)}'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _updatedFromDate = null;
                        _updatedToDate = null;
                        _templateKeyword = '';
                        _templateKeywordController.clear();
                        _productCategoryFilter = null;
                        _defaultTemplateFilter = null;
                        _templateEnabledFilter = null;
                      });
                    },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('清空本地筛选'),
                  ),
                ],
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
                                  final isFocused =
                                      item.id == _focusedTemplateId;
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        _focusedTemplateId = item.id;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 12,
                                      ),
                                      decoration: isFocused
                                          ? BoxDecoration(
                                              color: theme
                                                  .colorScheme
                                                  .primaryContainer
                                                  .withValues(alpha: 0.28),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            )
                                          : null,
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
                                          flex: 1,
                                          child: Text(
                                            item.updatedByUsername ?? '-',
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
                                                itemBuilder: (context) {
                                                  final items =
                                                      <
                                                        PopupMenuEntry<
                                                          _TemplateAction
                                                        >
                                                      >[];
                                                  if (_canManageTemplates) {
                                                    items.add(
                                                      PopupMenuItem(
                                                        value:
                                                            item.lifecycleStatus ==
                                                                'draft'
                                                            ? _TemplateAction
                                                                  .edit
                                                            : _TemplateAction
                                                                  .createDraft,
                                                        child: Text(
                                                          item.lifecycleStatus ==
                                                                  'draft'
                                                              ? '编辑'
                                                              : '创建草稿',
                                                        ),
                                                      ),
                                                    );
                                                    if (item.lifecycleStatus ==
                                                        'draft') {
                                                      items.add(
                                                        const PopupMenuItem(
                                                          value: _TemplateAction
                                                              .publish,
                                                          child: Text('发布'),
                                                        ),
                                                      );
                                                    }
                                                    items.add(
                                                      const PopupMenuItem(
                                                        value: _TemplateAction
                                                            .copy,
                                                        child: Text('复制（同产品）'),
                                                      ),
                                                    );
                                                    items.add(
                                                      const PopupMenuItem(
                                                        value: _TemplateAction
                                                            .copyToProduct,
                                                        child: Text('跨产品复制'),
                                                      ),
                                                    );
                                                    items.add(
                                                      const PopupMenuItem(
                                                        value: _TemplateAction
                                                            .copyFromMaster,
                                                        child: Text('从系统母版套版'),
                                                      ),
                                                    );
                                                    if (item.lifecycleStatus ==
                                                        'published') {
                                                      items.add(
                                                        const PopupMenuItem(
                                                          value: _TemplateAction
                                                              .archive,
                                                          child: Text('归档'),
                                                        ),
                                                      );
                                                    }
                                                    if (item.lifecycleStatus ==
                                                        'archived') {
                                                      items.add(
                                                        const PopupMenuItem(
                                                          value: _TemplateAction
                                                              .unarchive,
                                                          child: Text('取消归档'),
                                                        ),
                                                      );
                                                    }
                                                    items.add(
                                                      PopupMenuItem(
                                                        value: item.isEnabled
                                                            ? _TemplateAction
                                                                  .disable
                                                            : _TemplateAction
                                                                  .enable,
                                                        child: Text(
                                                          item.isEnabled
                                                              ? '停用'
                                                              : '启用',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                  if (_canViewTemplates) {
                                                    items.add(
                                                      const PopupMenuItem(
                                                        value: _TemplateAction
                                                            .detail,
                                                        child: Text('查看详情'),
                                                      ),
                                                    );
                                                    items.add(
                                                      const PopupMenuItem(
                                                        value: _TemplateAction
                                                            .impact,
                                                        child: Text('影响分析'),
                                                      ),
                                                    );
                                                    items.add(
                                                      const PopupMenuItem(
                                                        value: _TemplateAction
                                                            .versions,
                                                        child: Text('版本管理'),
                                                      ),
                                                    );
                                                    items.add(
                                                      const PopupMenuItem(
                                                        value: _TemplateAction
                                                            .compare,
                                                        child: Text('版本对比'),
                                                      ),
                                                    );
                                                  }
                                                  if (_canManageTemplates) {
                                                    items.add(
                                                      const PopupMenuItem(
                                                        value: _TemplateAction
                                                            .rollback,
                                                        child: Text('回滚模板'),
                                                      ),
                                                    );
                                                  }
                                                  if (_canManageTemplates) {
                                                    items.add(
                                                      const PopupMenuItem(
                                                        value: _TemplateAction
                                                            .delete,
                                                        child: Text('删除'),
                                                      ),
                                                    );
                                                  }
                                                  return items;
                                                },
                                              ),
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
        ],
      ),
    );
  }
}
