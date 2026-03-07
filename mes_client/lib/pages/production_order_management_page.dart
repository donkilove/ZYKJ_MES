import 'package:flutter/material.dart';

import '../models/app_session.dart';
import '../models/craft_models.dart';
import '../models/production_models.dart';
import '../services/api_exception.dart';
import '../services/craft_service.dart';
import '../services/production_service.dart';
import '../widgets/adaptive_table_container.dart';
import '../widgets/locked_form_dialog.dart';

enum _ManagementOrderAction { detail, edit, delete, complete }

class _OrderProcessStepDraft {
  _OrderProcessStepDraft({required this.stageId, required this.processId});

  int stageId;
  int processId;
}

class _StageOption {
  _StageOption({required this.id, required this.code, required this.name});

  final int id;
  final String code;
  final String name;
}

class ProductionOrderManagementPage extends StatefulWidget {
  const ProductionOrderManagementPage({
    super.key,
    required this.session,
    required this.onLogout,
    required this.canWrite,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final bool canWrite;

  @override
  State<ProductionOrderManagementPage> createState() =>
      _ProductionOrderManagementPageState();
}

class _ProductionOrderManagementPageState
    extends State<ProductionOrderManagementPage> {
  late final ProductionService _service;
  late final CraftService _craftService;
  final TextEditingController _keywordController = TextEditingController();

  bool _loading = false;
  String _message = '';
  int _total = 0;
  String? _statusFilter;
  List<ProductionOrderItem> _items = const [];
  List<ProductionProductOption> _products = const [];
  List<ProductionProcessOption> _processes = const [];
  List<CraftTemplateItem> _templates = const [];
  final Map<int, CraftTemplateDetail> _templateDetailCache = {};

  @override
  void initState() {
    super.initState();
    _service = ProductionService(widget.session);
    _craftService = CraftService(widget.session);
    _loadReferenceData();
    _loadOrders();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  List<_StageOption> _stageOptions() {
    final byId = <int, _StageOption>{};
    for (final process in _processes) {
      if (process.stageId == null ||
          process.stageName == null ||
          process.stageName!.trim().isEmpty ||
          process.stageCode == null ||
          process.stageCode!.trim().isEmpty) {
        continue;
      }
      byId.putIfAbsent(
        process.stageId!,
        () => _StageOption(
          id: process.stageId!,
          code: process.stageCode!,
          name: process.stageName!,
        ),
      );
    }
    final items = byId.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  List<ProductionProcessOption> _processesByStage(int stageId) {
    final items = _processes.where((item) => item.stageId == stageId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  List<CraftTemplateItem> _templatesByProduct(int productId) {
    final items =
        _templates
            .where((item) => item.productId == productId && item.isEnabled)
            .toList()
          ..sort((a, b) {
            if (a.isDefault && !b.isDefault) {
              return -1;
            }
            if (!a.isDefault && b.isDefault) {
              return 1;
            }
            return b.updatedAt.compareTo(a.updatedAt);
          });
    return items;
  }

  List<_OrderProcessStepDraft> _buildStepsFromProcessCodes(List<String> codes) {
    final steps = <_OrderProcessStepDraft>[];
    for (final code in codes) {
      final index = _processes.indexWhere((item) => item.code == code);
      if (index < 0) {
        continue;
      }
      final row = _processes[index];
      if (row.stageId == null) {
        continue;
      }
      steps.add(
        _OrderProcessStepDraft(stageId: row.stageId!, processId: row.id),
      );
    }
    return steps;
  }

  Future<CraftTemplateDetail> _loadTemplateDetail(int templateId) async {
    final cached = _templateDetailCache[templateId];
    if (cached != null) {
      return cached;
    }
    final detail = await _craftService.getTemplateDetail(
      templateId: templateId,
    );
    _templateDetailCache[templateId] = detail;
    return detail;
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

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final sec = local.second.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min:$sec';
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  bool _canEditOrder(ProductionOrderItem item) {
    return widget.canWrite && item.status == 'pending';
  }

  bool _canDeleteOrder(ProductionOrderItem item) {
    return widget.canWrite && item.status == 'pending';
  }

  bool _canCompleteOrderAction(ProductionOrderItem item) {
    return widget.canWrite && item.status != 'completed';
  }

  List<PopupMenuEntry<_ManagementOrderAction>> _buildOrderActionMenuItems(
    ProductionOrderItem item,
  ) {
    return [
      const PopupMenuItem<_ManagementOrderAction>(
        value: _ManagementOrderAction.detail,
        child: Text('详情'),
      ),
      PopupMenuItem<_ManagementOrderAction>(
        value: _ManagementOrderAction.edit,
        enabled: _canEditOrder(item),
        child: const Text('编辑'),
      ),
      PopupMenuItem<_ManagementOrderAction>(
        value: _ManagementOrderAction.delete,
        enabled: _canDeleteOrder(item),
        child: const Text('删除'),
      ),
      PopupMenuItem<_ManagementOrderAction>(
        value: _ManagementOrderAction.complete,
        enabled: _canCompleteOrderAction(item),
        child: const Text('完工'),
      ),
    ];
  }

  void _onOrderActionSelected(
    _ManagementOrderAction action,
    ProductionOrderItem item,
  ) {
    switch (action) {
      case _ManagementOrderAction.detail:
        _showOrderDetail(item);
        break;
      case _ManagementOrderAction.edit:
        _showOrderDialog(existing: item);
        break;
      case _ManagementOrderAction.delete:
        _deleteOrder(item);
        break;
      case _ManagementOrderAction.complete:
        _completeOrder(item);
        break;
    }
  }

  Widget _buildOrderActionMenu(ProductionOrderItem item) {
    return PopupMenuButton<_ManagementOrderAction>(
      tooltip: '操作',
      onSelected: (action) => _onOrderActionSelected(action, item),
      itemBuilder: (_) => _buildOrderActionMenuItems(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('操作'),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _loadReferenceData() async {
    try {
      final products = await _service.listProductOptions();
      final processes = await _service.listProcessOptions();
      final templates = await _craftService.listTemplates(
        page: 1,
        pageSize: 500,
        enabled: null,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _products = products;
        _processes = processes;
        _templates = templates.items;
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
        _message = '加载产品/工序选项失败：${_errorMessage(error)}';
      });
    }
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _message = '';
    });
    try {
      final result = await _service.listOrders(
        page: 1,
        pageSize: 200,
        keyword: _keywordController.text.trim(),
        status: _statusFilter,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _items = result.items;
        _total = result.total;
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
        _message = '加载订单失败：${_errorMessage(error)}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime?> onChanged,
  }) async {
    final initial = current ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      initialDate: initial,
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '纭畾',
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  Future<void> _showOrderDialog({ProductionOrderItem? existing}) async {
    if (!widget.canWrite) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无权限管理订单。')));
      return;
    }
    if (_products.isEmpty || _processes.isEmpty) {
      await _loadReferenceData();
      if (_products.isEmpty || _processes.isEmpty) {
        return;
      }
    }
    if (!mounted) {
      return;
    }

    final stageOptions = _stageOptions();
    if (stageOptions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先配置工段与小工序。')));
      return;
    }

    final isEdit = existing != null;
    final existingOrderId = existing?.id;
    final orderCodeController = TextEditingController(
      text: existing?.orderCode ?? '',
    );
    final quantityController = TextEditingController(
      text: existing?.quantity.toString() ?? '1',
    );
    final remarkController = TextEditingController(
      text: existing?.remark ?? '',
    );
    final newTemplateNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    DateTime? startDate = existing?.startDate;
    DateTime? dueDate = existing?.dueDate;
    int selectedProductId = existing?.productId ?? _products.first.id;
    int? selectedTemplateId = existing?.processTemplateId;
    bool saveAsTemplate = false;
    bool newTemplateSetDefault = false;
    bool applyingTemplate = false;
    List<_OrderProcessStepDraft> routeSteps = const [];

    List<_OrderProcessStepDraft> mapTemplateSteps(CraftTemplateDetail detail) {
      return detail.steps
          .map(
            (item) => _OrderProcessStepDraft(
              stageId: item.stageId,
              processId: item.processId,
            ),
          )
          .toList();
    }

    if (isEdit) {
      try {
        final detail = await _service.getOrderDetail(orderId: existingOrderId!);
        final sorted = detail.processes.toList()
          ..sort((a, b) => a.processOrder.compareTo(b.processOrder));
        final processCodes = sorted.map((e) => e.processCode).toList();
        routeSteps = _buildStepsFromProcessCodes(processCodes);
        selectedTemplateId = detail.order.processTemplateId;
      } catch (error) {
        if (_isUnauthorized(error)) {
          widget.onLogout();
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载订单详情失败：${_errorMessage(error)}')),
          );
        }
        return;
      }
    } else {
      final templates = _templatesByProduct(selectedProductId);
      if (templates.isNotEmpty) {
        final defaultTemplate =
            templates.where((item) => item.isDefault).isNotEmpty
            ? templates.firstWhere((item) => item.isDefault)
            : templates.first;
        selectedTemplateId = defaultTemplate.id;
        try {
          final detail = await _loadTemplateDetail(defaultTemplate.id);
          routeSteps = mapTemplateSteps(detail);
        } catch (_) {
          selectedTemplateId = null;
        }
      }
    }

    if (routeSteps.isEmpty) {
      final firstStage = stageOptions.first;
      final firstStageProcesses = _processesByStage(firstStage.id);
      if (firstStageProcesses.isNotEmpty) {
        routeSteps = [
          _OrderProcessStepDraft(
            stageId: firstStage.id,
            processId: firstStageProcesses.first.id,
          ),
        ];
      }
    }

    if (!mounted) {
      return;
    }

    final saved = await showLockedFormDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> applyTemplateById(int templateId) async {
              setDialogState(() {
                applyingTemplate = true;
              });
              try {
                final detail = await _loadTemplateDetail(templateId);
                if (!context.mounted) {
                  return;
                }
                setDialogState(() {
                  routeSteps = mapTemplateSteps(detail);
                });
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('加载模板失败：${_errorMessage(error)}')),
                  );
                }
              } finally {
                if (context.mounted) {
                  setDialogState(() {
                    applyingTemplate = false;
                  });
                }
              }
            }

            void addStep() {
              final stage = stageOptions.first;
              final processRows = _processesByStage(stage.id);
              if (processRows.isEmpty) {
                return;
              }
              setDialogState(() {
                routeSteps = [
                  ...routeSteps,
                  _OrderProcessStepDraft(
                    stageId: stage.id,
                    processId: processRows.first.id,
                  ),
                ];
              });
            }

            final productTemplates = _templatesByProduct(selectedProductId);

            return AlertDialog(
              title: Text(isEdit ? '编辑订单' : '创建订单'),
              content: SizedBox(
                width: 860,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: orderCodeController,
                          enabled: !isEdit,
                          maxLength: 64,
                          decoration: const InputDecoration(
                            labelText: '订单号',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (isEdit) {
                              return null;
                            }
                            if (value == null || value.trim().isEmpty) {
                              return '订单号不能为空';
                            }
                            final normalized = value.trim();
                            if (normalized.length < 2) {
                              return '订单号至少 2 个字符';
                            }
                            if (normalized.length > 64) {
                              return '订单号不能超过 64 个字符';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: selectedProductId,
                          decoration: const InputDecoration(
                            labelText: '产品',
                            border: OutlineInputBorder(),
                          ),
                          items: _products
                              .map(
                                (item) => DropdownMenuItem<int>(
                                  value: item.id,
                                  child: Text(item.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            if (value == null) {
                              return;
                            }
                            setDialogState(() {
                              selectedProductId = value;
                              selectedTemplateId = null;
                            });
                            final nextTemplates = _templatesByProduct(value);
                            if (nextTemplates.isEmpty) {
                              return;
                            }
                            final defaultTemplate =
                                nextTemplates
                                    .where((item) => item.isDefault)
                                    .isNotEmpty
                                ? nextTemplates.firstWhere(
                                    (item) => item.isDefault,
                                  )
                                : nextTemplates.first;
                            setDialogState(() {
                              selectedTemplateId = defaultTemplate.id;
                            });
                            await applyTemplateById(defaultTemplate.id);
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int?>(
                          initialValue: selectedTemplateId,
                          decoration: const InputDecoration(
                            labelText: '工序模板',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('不使用模板（手动配置）'),
                            ),
                            ...productTemplates.map(
                              (item) => DropdownMenuItem<int?>(
                                value: item.id,
                                child: Text(
                                  '${item.templateName} v${item.version}${item.isDefault ? '（默认）' : ''}',
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) async {
                            setDialogState(() {
                              selectedTemplateId = value;
                            });
                            if (value == null) {
                              return;
                            }
                            await applyTemplateById(value);
                          },
                        ),
                        if (applyingTemplate)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '数量',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final quantity = int.tryParse(value?.trim() ?? '');
                            if (quantity == null || quantity <= 0) {
                              return '数量必须大于 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _pickDate(
                                  current: startDate,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      startDate = value;
                                    });
                                  },
                                ),
                                child: Text('开始日期：${_formatDate(startDate)}'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _pickDate(
                                  current: dueDate,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      dueDate = value;
                                    });
                                  },
                                ),
                                child: Text('交期：${_formatDate(dueDate)}'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: remarkController,
                          maxLines: 2,
                          maxLength: 1024,
                          decoration: const InputDecoration(
                            labelText: '备注',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null) {
                              return null;
                            }
                            if (value.trim().length > 1024) {
                              return '备注不能超过 1024 个字符';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              '工序路线（工段 -> 小工序）',
                              style: Theme.of(context).textTheme.titleMedium,
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
                        ...List.generate(routeSteps.length, (index) {
                          final step = routeSteps[index];
                          final processRows = _processesByStage(step.stageId);
                          if (processRows.isNotEmpty &&
                              !processRows.any(
                                (item) => item.id == step.processId,
                              )) {
                            step.processId = processRows.first.id;
                          }
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
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
                                      items: stageOptions
                                          .map(
                                            (stage) => DropdownMenuItem<int>(
                                              value: stage.id,
                                              child: Text(
                                                '${stage.name} (${stage.code})',
                                              ),
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
                                          : (processRows.any(
                                                  (item) =>
                                                      item.id == step.processId,
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
                                            (item) => DropdownMenuItem<int>(
                                              value: item.id,
                                              child: Text(
                                                '${item.name} (${item.code})',
                                              ),
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
                                    onPressed: routeSteps.length <= 1
                                        ? null
                                        : () {
                                            setDialogState(() {
                                              routeSteps = [...routeSteps]
                                                ..removeAt(index);
                                            });
                                          },
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text('将当前流程另存为新模板'),
                          value: saveAsTemplate,
                          onChanged: (value) {
                            setDialogState(() {
                              saveAsTemplate = value ?? false;
                              if (!saveAsTemplate) {
                                newTemplateNameController.clear();
                                newTemplateSetDefault = false;
                              }
                            });
                          },
                        ),
                        if (saveAsTemplate) ...[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: newTemplateNameController,
                            maxLength: 128,
                            decoration: const InputDecoration(
                              labelText: '新模板名称',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (!saveAsTemplate) {
                                return null;
                              }
                              if (value == null || value.trim().isEmpty) {
                                return '请输入新模板名称';
                              }
                              if (value.trim().length > 128) {
                                return '新模板名称不能超过 128 个字符';
                              }
                              return null;
                            },
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text('设为该产品默认模板'),
                            value: newTemplateSetDefault,
                            onChanged: (value) {
                              setDialogState(() {
                                newTemplateSetDefault = value ?? false;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: applyingTemplate
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }
                          if (routeSteps.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('至少选择一道工序。')),
                            );
                            return;
                          }
                          final payloadSteps =
                              <ProductionOrderProcessStepInput>[];
                          final processCodes = <String>[];
                          for (var i = 0; i < routeSteps.length; i++) {
                            final step = routeSteps[i];
                            final processIndex = _processes.indexWhere(
                              (item) => item.id == step.processId,
                            );
                            if (processIndex < 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('存在无效工序，请重新选择。')),
                              );
                              return;
                            }
                            final process = _processes[processIndex];
                            payloadSteps.add(
                              ProductionOrderProcessStepInput(
                                stepOrder: i + 1,
                                stageId: step.stageId,
                                processId: step.processId,
                              ),
                            );
                            processCodes.add(process.code);
                          }
                          final quantity = int.parse(
                            quantityController.text.trim(),
                          );
                          final normalizedTemplateName =
                              newTemplateNameController.text.trim();
                          try {
                            if (isEdit) {
                              await _service.updateOrder(
                                orderId: existingOrderId!,
                                productId: selectedProductId,
                                quantity: quantity,
                                processCodes: processCodes,
                                templateId: selectedTemplateId,
                                processSteps: payloadSteps,
                                saveAsTemplate: saveAsTemplate,
                                newTemplateName: saveAsTemplate
                                    ? normalizedTemplateName
                                    : null,
                                newTemplateSetDefault: newTemplateSetDefault,
                                startDate: startDate,
                                dueDate: dueDate,
                                remark: remarkController.text.trim().isEmpty
                                    ? null
                                    : remarkController.text.trim(),
                              );
                            } else {
                              await _service.createOrder(
                                orderCode: orderCodeController.text.trim(),
                                productId: selectedProductId,
                                quantity: quantity,
                                processCodes: processCodes,
                                templateId: selectedTemplateId,
                                processSteps: payloadSteps,
                                saveAsTemplate: saveAsTemplate,
                                newTemplateName: saveAsTemplate
                                    ? normalizedTemplateName
                                    : null,
                                newTemplateSetDefault: newTemplateSetDefault,
                                startDate: startDate,
                                dueDate: dueDate,
                                remark: remarkController.text.trim().isEmpty
                                    ? null
                                    : remarkController.text.trim(),
                              );
                            }
                            if (context.mounted) {
                              Navigator.of(context).pop(true);
                            }
                          } catch (error) {
                            if (_isUnauthorized(error)) {
                              widget.onLogout();
                              return;
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(_errorMessage(error))),
                              );
                            }
                          }
                        },
                  child: Text(isEdit ? '保存' : '创建'),
                ),
              ],
            );
          },
        );
      },
    );

    orderCodeController.dispose();
    quantityController.dispose();
    remarkController.dispose();
    newTemplateNameController.dispose();

    if (saved == true) {
      await _loadReferenceData();
      await _loadOrders();
    }
  }

  Future<void> _deleteOrder(ProductionOrderItem order) async {
    if (!widget.canWrite) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除订单'),
        content: Text('确认删除订单 ${order.orderCode} 吗？'),
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
      await _service.deleteOrder(orderId: order.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('订单已删除。')));
      }
      await _loadOrders();
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  Future<void> _completeOrder(ProductionOrderItem order) async {
    if (!widget.canWrite) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('手工完工'),
        content: Text('确认将订单 ${order.orderCode} 标记为完工吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('完工'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      await _service.completeOrder(orderId: order.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('订单已标记为完工。')));
      }
      await _loadOrders();
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    }
  }

  Future<void> _showOrderDetail(ProductionOrderItem order) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          child: SizedBox(
            width: 1100,
            height: 700,
            child: FutureBuilder<ProductionOrderDetail>(
              future: _service.getOrderDetail(orderId: order.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('加载订单详情失败'),
                        const SizedBox(height: 8),
                        Text(snapshot.error.toString()),
                        const Spacer(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('关闭'),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final detail = snapshot.data!;
                final sortedProcesses = detail.processes.toList()
                  ..sort((a, b) => a.processOrder.compareTo(b.processOrder));
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '订单详情：${detail.order.orderCode}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('关闭'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          Text('产品：${detail.order.productName}'),
                          Text('数量：${detail.order.quantity}'),
                          Text(
                            '状态：${productionOrderStatusLabel(detail.order.status)}',
                          ),
                          Text(
                            '当前工序：${detail.order.currentProcessName ?? '-'}',
                          ),
                          Text('开始日期：${_formatDate(detail.order.startDate)}'),
                          Text('交期：${_formatDate(detail.order.dueDate)}'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: DefaultTabController(
                          length: 3,
                          child: Column(
                            children: [
                              const TabBar(
                                tabs: [
                                  Tab(text: '工序'),
                                  Tab(text: '记录'),
                                  Tab(text: '事件'),
                                ],
                              ),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    Card(
                                      child: AdaptiveTableContainer(
                                        child: DataTable(
                                          columns: const [
                                            DataColumn(label: Text('顺序')),
                                            DataColumn(label: Text('工序编码')),
                                            DataColumn(label: Text('工序名称')),
                                            DataColumn(label: Text('状态')),
                                            DataColumn(label: Text('可见数量')),
                                            DataColumn(label: Text('完成数量')),
                                          ],
                                          rows: sortedProcesses.map((item) {
                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  Text('${item.processOrder}'),
                                                ),
                                                DataCell(
                                                  Text(item.processCode),
                                                ),
                                                DataCell(
                                                  Text(item.processName),
                                                ),
                                                DataCell(
                                                  Text(
                                                    productionProcessStatusLabel(
                                                      item.status,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    '${item.visibleQuantity}',
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    '${item.completedQuantity}',
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                    Card(
                                      child: AdaptiveTableContainer(
                                        child: DataTable(
                                          columns: const [
                                            DataColumn(label: Text('时间')),
                                            DataColumn(label: Text('工序')),
                                            DataColumn(label: Text('操作员')),
                                            DataColumn(label: Text('类型')),
                                            DataColumn(label: Text('数量')),
                                          ],
                                          rows: detail.records.map((item) {
                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  Text(
                                                    _formatDateTime(
                                                      item.createdAt,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(item.processName),
                                                ),
                                                DataCell(
                                                  Text(item.operatorUsername),
                                                ),
                                                DataCell(Text(item.recordType)),
                                                DataCell(
                                                  Text(
                                                    '${item.productionQuantity}',
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                    Card(
                                      child: ListView.separated(
                                        itemCount: detail.events.length,
                                        separatorBuilder: (_, _) =>
                                            const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final item = detail.events[index];
                                          return ListTile(
                                            title: Text(item.eventTitle),
                                            subtitle: Text(
                                              '${_formatDateTime(item.createdAt)}  ${item.eventDetail ?? ''}',
                                            ),
                                            trailing: Text(
                                              item.operatorUsername ?? '-',
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
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '生产订单管理',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '刷新',
                onPressed: _loading ? null : _loadOrders,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _keywordController,
                  decoration: const InputDecoration(
                    labelText: '搜索订单号/产品',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _loadOrders(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String?>(
                  initialValue: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: '状态',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem<String?>(value: null, child: Text('全部')),
                    DropdownMenuItem<String?>(
                      value: 'pending',
                      child: Text('待生产'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'in_progress',
                      child: Text('生产中'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'completed',
                      child: Text('已完成'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _statusFilter = value;
                    });
                    _loadOrders();
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loading ? null : _loadOrders,
                icon: const Icon(Icons.search),
                label: const Text('查询'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _loading || !widget.canWrite
                    ? null
                    : () => _showOrderDialog(),
                icon: const Icon(Icons.add),
                label: const Text('创建'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('总数：$_total', style: theme.textTheme.titleMedium),
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
                : _items.isEmpty
                ? const Center(child: Text('暂无生产订单。'))
                : Card(
                    child: AdaptiveTableContainer(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('订单号')),
                          DataColumn(label: Text('产品')),
                          DataColumn(label: Text('数量')),
                          DataColumn(label: Text('状态')),
                          DataColumn(label: Text('当前工序')),
                          DataColumn(label: Text('开始日期')),
                          DataColumn(label: Text('交期')),
                          DataColumn(label: Text('更新时间')),
                          DataColumn(label: Text('操作')),
                        ],
                        rows: _items.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(Text(item.orderCode)),
                              DataCell(Text(item.productName)),
                              DataCell(Text('${item.quantity}')),
                              DataCell(
                                Text(productionOrderStatusLabel(item.status)),
                              ),
                              DataCell(Text(item.currentProcessName ?? '-')),
                              DataCell(Text(_formatDate(item.startDate))),
                              DataCell(Text(_formatDate(item.dueDate))),
                              DataCell(Text(_formatDateTime(item.updatedAt))),
                              DataCell(_buildOrderActionMenu(item)),
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
