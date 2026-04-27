import 'package:flutter/material.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/production/services/production_service.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';
import 'package:mes_client/core/ui/patterns/mes_refresh_page_header.dart';
import 'package:mes_client/core/ui/patterns/mes_crud_page_scaffold.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/core/widgets/unified_list_table_header_style.dart';

class _TemplateStepDraft {
  _TemplateStepDraft({required this.stageId, required this.processId});

  int stageId;
  int processId;
}

enum _TemplateAction {
  detail,
  edit,
  createDraft,
  publish,
  enable,
  disable,
  versions,
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
  static const int _productListVisibleCount = 6;
  static const double _productListItemHeight = 72;
  static const double _productListItemSpacing = 8;

  late final CraftService _craftService;
  late final ProductionService _productionService;

  bool _loading = false;
  String _message = '';
  int? _productFilterId;
  final ScrollController _productListScrollController = ScrollController();
  final _productKeywordController = TextEditingController();
  String _productKeyword = '';

  List<ProductionProductOption> _products = const [];
  List<CraftStageItem> _stages = const [];
  List<CraftProcessItem> _processes = const [];
  List<CraftTemplateItem> _templates = const [];
  CraftSystemMasterTemplateItem? _systemMasterTemplate;
  bool _systemMasterExpanded = true;
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
    _productListScrollController.dispose();
    _productKeywordController.dispose();
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
      final templateResult = await _craftService.listTemplates(pageSize: 500);
      final systemMasterTemplate = await _craftService
          .getSystemMasterTemplate();
      if (!mounted) {
        return;
      }
      final hadSystemMaster = _systemMasterTemplate != null;
      final hasSystemMaster = systemMasterTemplate != null;
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
        if (!hasSystemMaster) {
          _systemMasterExpanded = true;
        } else if (!hadSystemMaster) {
          _systemMasterExpanded = false;
        }
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
    var selectedProductId = _productFilterId;
    if (selectedProductId == null) {
      return const [];
    }
    return _templates
        .where((item) => item.productId == selectedProductId)
        .toList();
  }

  List<ProductionProductOption> get _visibleProducts {
    final keyword = _productKeyword.trim().toLowerCase();
    if (keyword.isEmpty) {
      return _products;
    }
    return _products
        .where((item) => item.name.toLowerCase().contains(keyword))
        .toList();
  }

  String _formatDateTimeLabel(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
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
        builder: (dialogContext) => MesDialog(
          title: Text('模板详情 - ${item.templateName}'),
          width: 820,
          content: SizedBox(
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
                                '${step.processCode} ${step.processName}',
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
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

    final saved = await showMesLockedFormDialog<bool>(
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

            return MesDialog(
              title: Text(isEdit ? '编辑模板' : '新建模板'),
              width: 860,
              content: Form(
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
                              ],
                            ),
                          ),
                        );
                      }),
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

    final saved = await showMesLockedFormDialog<bool>(
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

            return MesDialog(
              title: Text(isEdit ? '编辑系统母版' : '新建系统母版'),
              width: 860,
              content: Form(
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
          return MesDialog(
            title: const Text('系统母版历史版本'),
            width: 920,
            content: SizedBox(
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

  Future<void> _copyFromSystemMaster() async {
    if (!_canManageTemplates) {
      _showNoPermission();
      return;
    }
    var selectedProductId = _productFilterId;
    if (selectedProductId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择产品')));
      return;
    }
    if (_products.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无可用产品')));
      return;
    }
    final nameController = TextEditingController(text: '系统母版套版');
    final saved = await showMesLockedFormDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return MesDialog(
              title: const Text('从系统母版套版'),
              width: 420,
              content: Column(
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
                        productId: selectedProductId!,
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
        builder: (context) => MesDialog(
          title: Text('$actionText模板'),
          width: 420,
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
        description:
            '确认$actionText模板 ${item.templateName} 吗？停用后模板将不能继续用于维护与新建流程。',
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

  Future<void> _showTopCopyFromMasterShortcut() async {
    if (!_canManageTemplates) {
      _showNoPermission();
      return;
    }
    await _copyFromSystemMaster();
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
            Text(
              '其余 ${analysis.items.length - previewOrders.length} 条请通过“影响分析”查看。',
            ),
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
        builder: (dialogContext) => MesDialog(
          title: Text(title),
          width: 720,
          content: SingleChildScrollView(
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
                      color: Theme.of(
                        dialogContext,
                      ).colorScheme.errorContainer,
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

    final saved = await showMesLockedFormDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return MesDialog(
              title: Text('发布模板 - ${item.templateName}'),
              width: 720,
              content: SingleChildScrollView(
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

  Future<void> _showVersionDialog(
    CraftTemplateItem item, {
    int? initialTargetVersion,
  }) async {
    if (!_canViewTemplates) {
      _showNoPermission();
      return;
    }
    try {
      final versions = await _craftService.listTemplateVersions(
        templateId: item.id,
      );
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

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => MesDialog(
          title: Text('版本管理 - ${item.templateName}'),
          width: 860,
          content: SizedBox(
            height: 560,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前产品：${item.productName} · 当前版本 v${item.version} · 已发布 P${item.publishedVersion}',
                ),
                if (hasInitialTargetVersion)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '已自动定位目标版本 v$initialTargetVersion',
                      style: Theme.of(dialogContext).textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  '历史版本',
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
      case _TemplateAction.versions:
        if (!_canViewTemplates) {
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

  bool _hasDefaultTemplateConfigured(int productId) {
    return _templates.any(
      (item) => item.productId == productId && item.isDefault,
    );
  }

  Widget _buildProductDefaultStatus(
    ThemeData theme, {
    required bool configured,
  }) {
    final color = configured
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;
    final text = configured ? '已配置默认模板' : '未配置默认模板';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }

  Widget _buildProductPanel(ThemeData theme) {
    final visibleProducts = _visibleProducts;
    final productListHeight =
        (_productListItemHeight * _productListVisibleCount) +
        (_productListItemSpacing * (_productListVisibleCount - 1));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '产品列表',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _productKeywordController,
              decoration: const InputDecoration(
                labelText: '搜索产品',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _productKeyword = value;
                });
              },
            ),
            const SizedBox(height: 12),
            if (visibleProducts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('暂无匹配产品'),
              )
            else
              SizedBox(
                height: productListHeight,
                child: Scrollbar(
                  controller: _productListScrollController,
                  thumbVisibility:
                      visibleProducts.length > _productListVisibleCount,
                  child: ListView.separated(
                    key: const ValueKey('process-config-product-list-scroll'),
                    controller: _productListScrollController,
                    primary: false,
                    itemCount: visibleProducts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: _productListItemSpacing),
                    itemBuilder: (context, index) {
                      final product = visibleProducts[index];
                      final selected = product.id == _productFilterId;
                      final hasDefaultTemplate = _hasDefaultTemplateConfigured(
                        product.id,
                      );
                      return SizedBox(
                        height: _productListItemHeight,
                        child: ListTile(
                          dense: true,
                          selected: selected,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          selectedTileColor: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.4),
                          title: Text(product.name),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: _buildProductDefaultStatus(
                              theme,
                              configured: hasDefaultTemplate,
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              _productFilterId = product.id;
                              _focusedTemplateId = null;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
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
          Expanded(flex: 2, child: _buildHeaderLabel(theme, '模板名称')),
          Expanded(flex: 1, child: _buildHeaderLabel(theme, '版本/发布')),
          Expanded(flex: 1, child: _buildHeaderLabel(theme, '生命周期')),
          Expanded(flex: 1, child: _buildHeaderLabel(theme, '启用状态')),
          Expanded(flex: 1, child: _buildHeaderLabel(theme, '产品分类')),
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

  Widget _buildSummaryMetric(
    ThemeData theme, {
    required String label,
    required String value,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMasterMetaItem(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '$label$value',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMasterManagementCard(ThemeData theme) {
    final master = _systemMasterTemplate;
    final hasMaster = master != null;
    List<Widget> buildSummaryMetrics() {
      return [
        _buildSummaryMetric(
          theme,
          label: '配置状态',
          value: hasMaster ? '已配置' : '未配置',
          icon: hasMaster ? Icons.check_circle_outline : Icons.info_outline,
        ),
        _buildSummaryMetric(
          theme,
          label: '版本号',
          value: hasMaster ? 'v${master.version}' : '-',
          icon: Icons.layers_outlined,
        ),
        _buildSummaryMetric(
          theme,
          label: '步骤数',
          value: hasMaster ? '${master.steps.length} 步' : '0 步',
          icon: Icons.format_list_numbered,
        ),
      ];
    }

    List<Widget> buildMetaInfo() {
      final updatedBy = hasMaster
          ? ((master.updatedByUsername?.trim().isNotEmpty ?? false)
                ? master.updatedByUsername!.trim()
                : '-')
          : '-';
      return [
        _buildSystemMasterMetaItem(
          theme,
          icon: Icons.person_outline,
          label: '最近更新人：',
          value: updatedBy,
        ),
        _buildSystemMasterMetaItem(
          theme,
          icon: Icons.schedule,
          label: '最近更新时间：',
          value: _formatDateTimeLabel(master?.updatedAt),
        ),
      ];
    }

    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        key: const PageStorageKey<String>('system-master-management-tile'),
        initiallyExpanded: _systemMasterExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _systemMasterExpanded = expanded;
          });
        },
        tilePadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_tree_outlined,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '系统母版管理',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        children: _systemMasterExpanded
            ? [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final summaryWrap = Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: buildSummaryMetrics(),
                    );
                    final metaWrap = Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: buildMetaInfo(),
                    );

                    final actionWrap = Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        if (_canViewSystemMasterVersions)
                          OutlinedButton.icon(
                            onPressed: _loading
                                ? null
                                : _showSystemMasterVersionDialog,
                            icon: const Icon(Icons.history),
                            label: const Text('母版历史版本'),
                          ),
                        if (_canManageSystemMasterTemplate)
                          FilledButton.icon(
                            onPressed: _loading
                                ? null
                                : _showSystemMasterTemplateDialog,
                            icon: Icon(
                              hasMaster ? Icons.edit_outlined : Icons.add_box,
                            ),
                            label: Text(hasMaster ? '编辑系统母版' : '新建系统母版'),
                          ),
                      ],
                    );

                    final overviewCard = Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: constraints.maxWidth < 1180
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '系统母版管理',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                summaryWrap,
                                const SizedBox(height: 12),
                                actionWrap,
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '系统母版管理',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      summaryWrap,
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 260,
                                  ),
                                  child: actionWrap,
                                ),
                              ],
                            ),
                    );

                    final metaCard = Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                      child: metaWrap,
                    );

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              key: const Key('system-master-summary-section'),
                              child: overviewCard,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              key: const Key('system-master-meta-section'),
                              child: metaCard,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ]
            : const <Widget>[],
      ),
    );
  }

  Widget _buildTemplateList(
    ThemeData theme,
    List<CraftTemplateItem> templates,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTemplateHeaderRow(theme),
        const SizedBox(height: 8),
        if (templates.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('暂无模板数据')),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: templates.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = templates[index];
              final isFocused = item.id == _focusedTemplateId;
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
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.28,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 2, child: Text(item.templateName)),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${item.version} / P${item.publishedVersion}',
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(_lifecycleLabel(item.lifecycleStatus)),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(item.isEnabled ? '启用' : '停用'),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          item.productCategory.trim().isEmpty
                              ? '-'
                              : item.productCategory,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(item.updatedByUsername ?? '-'),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(item.updatedAt.toLocal().toString()),
                      ),
                      SizedBox(
                        width: 64,
                        child:
                            UnifiedListTableHeaderStyle.actionMenuButton<
                              _TemplateAction
                            >(
                              theme: theme,
                              onSelected: (action) {
                                _handleTemplateAction(action, item);
                              },
                              itemBuilder: (context) {
                                final items =
                                    <PopupMenuEntry<_TemplateAction>>[];
                                if (_canManageTemplates) {
                                  items.add(
                                    PopupMenuItem(
                                      value: item.lifecycleStatus == 'draft'
                                          ? _TemplateAction.edit
                                          : _TemplateAction.createDraft,
                                      child: Text(
                                        item.lifecycleStatus == 'draft'
                                            ? '编辑'
                                            : '创建草稿',
                                      ),
                                    ),
                                  );
                                  if (item.lifecycleStatus == 'draft') {
                                    items.add(
                                      const PopupMenuItem(
                                        value: _TemplateAction.publish,
                                        child: Text('发布'),
                                      ),
                                    );
                                  }
                                  items.add(
                                    PopupMenuItem(
                                      value: item.isEnabled
                                          ? _TemplateAction.disable
                                          : _TemplateAction.enable,
                                      child: Text(item.isEnabled ? '停用' : '启用'),
                                    ),
                                  );
                                }
                                if (_canViewTemplates) {
                                  items.add(
                                    const PopupMenuItem(
                                      value: _TemplateAction.detail,
                                      child: Text('查看详情'),
                                    ),
                                  );
                                  items.add(
                                    const PopupMenuItem(
                                      value: _TemplateAction.versions,
                                      child: Text('版本管理'),
                                    ),
                                  );
                                }
                                if (_canManageTemplates) {
                                  items.add(
                                    const PopupMenuItem(
                                      value: _TemplateAction.delete,
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
      ],
    );
  }

  Widget _buildTemplateWorkspace(
    ThemeData theme,
    List<CraftTemplateItem> templates,
  ) {
    String? selectedProductName;
    final selectedProductId = _productFilterId;
    if (selectedProductId != null) {
      for (final product in _products) {
        if (product.id == selectedProductId) {
          selectedProductName = product.name;
          break;
        }
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '模板工作区',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (selectedProductName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '当前产品：$selectedProductName',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.55,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '共 ${templates.length} 条模板',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed:
                      (_loading ||
                          !_canManageTemplates ||
                          _productFilterId == null)
                      ? null
                      : () => _showTemplateDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('新增模板'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      (_loading ||
                          !_canManageTemplates ||
                          _productFilterId == null)
                      ? null
                      : _showTopCopyFromMasterShortcut,
                  icon: const Icon(Icons.library_add),
                  label: const Text('从系统母版套版'),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
            if (_productFilterId == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    '未选择产品，当前不展示模板列表。',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )
            else if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: MesLoadingState(label: '模板列表加载中...'),
              )
            else
              _buildTemplateList(theme, templates),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final templates = _filteredTemplates;

    return MesCrudPageScaffold(
      header: MesRefreshPageHeader(
        title: '生产工序配置',
        onRefresh: _loading ? null : _loadData,
      ),
      content: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildJumpBanner(theme),
                  const SizedBox(height: 12),
                  _buildSystemMasterManagementCard(theme),
                  const SizedBox(height: 12),
                  constraints.maxWidth >= 1080
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 280,
                              child: _buildProductPanel(theme),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTemplateWorkspace(
                                theme,
                                templates,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProductPanel(theme),
                            const SizedBox(height: 12),
                            _buildTemplateWorkspace(theme, templates),
                          ],
                        ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
