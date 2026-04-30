import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_loading_state.dart';

import 'package:mes_client/core/models/app_session.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';
import 'package:mes_client/features/production/models/production_models.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/features/craft/services/craft_service.dart';
import 'package:mes_client/features/production/services/production_service.dart';
import 'package:mes_client/features/quality/services/quality_supplier_service.dart';

class _OrderProcessStepDraft {
  _OrderProcessStepDraft({
    required this.rowId,
    required this.stageId,
    required this.processId,
  });

  final int rowId;
  int stageId;
  int processId;
}

class _StageOption {
  _StageOption({required this.id, required this.code, required this.name});

  final int id;
  final String code;
  final String name;
}

class ProductionOrderFormPage extends StatefulWidget {
  const ProductionOrderFormPage({
    super.key,
    required this.session,
    required this.onLogout,
    this.existing,
    this.initialProducts = const [],
    this.initialProcesses = const [],
    this.initialTemplates = const [],
    this.service,
    this.craftService,
    this.supplierService,
  });

  final AppSession session;
  final VoidCallback onLogout;
  final ProductionOrderItem? existing;
  final List<ProductionProductOption> initialProducts;
  final List<ProductionProcessOption> initialProcesses;
  final List<CraftTemplateItem> initialTemplates;
  final ProductionService? service;
  final CraftService? craftService;
  final QualitySupplierService? supplierService;

  @override
  State<ProductionOrderFormPage> createState() =>
      _ProductionOrderFormPageState();
}

class _ProductionOrderFormPageState extends State<ProductionOrderFormPage> {
  late final ProductionService _service;
  late final CraftService _craftService;
  late final QualitySupplierService _supplierService;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _orderCodeController;
  late final TextEditingController _quantityController;
  late final TextEditingController _remarkController;
  late final TextEditingController _newTemplateNameController;

  bool _initializing = false;
  bool _submitting = false;
  bool _applyingTemplate = false;
  String _message = '';

  List<ProductionProductOption> _products = const [];
  List<ProductionProcessOption> _processes = const [];
  List<CraftTemplateItem> _templates = const [];
  List<QualitySupplierItem> _suppliers = const [];
  final Map<int, CraftTemplateDetail> _templateDetailCache = {};

  DateTime? _startDate;
  DateTime? _dueDate;
  int? _selectedProductId;
  int? _selectedSupplierId;
  int? _selectedTemplateId;
  bool _saveAsTemplate = false;
  bool _newTemplateSetDefault = false;
  List<_OrderProcessStepDraft> _routeSteps = const [];
  int _routeStepIdSeed = 1;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProductionService(widget.session);
    _craftService = widget.craftService ?? CraftService(widget.session);
    _supplierService =
        widget.supplierService ?? QualitySupplierService(widget.session);

    _products = List<ProductionProductOption>.from(widget.initialProducts);
    _processes = List<ProductionProcessOption>.from(widget.initialProcesses);
    _templates = List<CraftTemplateItem>.from(widget.initialTemplates);

    _orderCodeController = TextEditingController(
      text: widget.existing?.orderCode ?? '',
    );
    _quantityController = TextEditingController(
      text: widget.existing?.quantity.toString() ?? '1',
    );
    _remarkController = TextEditingController(
      text: widget.existing?.remark ?? '',
    );
    _newTemplateNameController = TextEditingController();

    _startDate = widget.existing?.startDate;
    _dueDate = widget.existing?.dueDate;
    _selectedProductId = widget.existing?.productId;
    _selectedSupplierId = widget.existing?.supplierId;
    _selectedTemplateId = widget.existing?.processTemplateId;

    _initializeForm();
  }

  @override
  void dispose() {
    _orderCodeController.dispose();
    _quantityController.dispose();
    _remarkController.dispose();
    _newTemplateNameController.dispose();
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

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  int _nextRouteStepId() {
    final id = _routeStepIdSeed;
    _routeStepIdSeed += 1;
    return id;
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

  void _ensureCurrentSupplierOption({
    required int? supplierId,
    required String? supplierName,
  }) {
    if (supplierId == null) {
      return;
    }
    if (_suppliers.any((item) => item.id == supplierId)) {
      return;
    }
    _suppliers = [
      ..._suppliers,
      QualitySupplierItem(
        id: supplierId,
        name: supplierName?.trim().isNotEmpty == true
            ? supplierName!.trim()
            : '供应商#$supplierId',
        remark: null,
        isEnabled: false,
        createdAt: DateTime(1970, 1, 1),
        updatedAt: DateTime(1970, 1, 1),
      ),
    ];
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
        _OrderProcessStepDraft(
          rowId: _nextRouteStepId(),
          stageId: row.stageId!,
          processId: row.id,
        ),
      );
    }
    return steps;
  }

  List<_OrderProcessStepDraft> _mapTemplateSteps(CraftTemplateDetail detail) {
    return detail.steps
        .map(
          (item) => _OrderProcessStepDraft(
            rowId: _nextRouteStepId(),
            stageId: item.stageId,
            processId: item.processId,
          ),
        )
        .toList();
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

  Future<void> _loadReferenceDataIfNeeded() async {
    if (_products.isNotEmpty &&
        _processes.isNotEmpty &&
        _templates.isNotEmpty &&
        _suppliers.isNotEmpty) {
      return;
    }
    final products = _products.isNotEmpty
        ? _products
        : await _service.listProductOptions();
    final processes = _processes.isNotEmpty
        ? _processes
        : await _service.listProcessOptions();
    final templates = _templates.isNotEmpty
        ? _templates
        : (await _craftService.listTemplates(
            page: 1,
            pageSize: 500,
            enabled: null,
          )).items;
    final suppliers = _suppliers.isNotEmpty
        ? _suppliers
        : (await _supplierService.listSuppliers(enabled: true)).items;
    _products = products;
    _processes = processes;
    _templates = templates;
    _suppliers = suppliers;
  }

  Future<void> _initializeForm() async {
    setState(() {
      _initializing = true;
      _message = '';
    });
    try {
      await _loadReferenceDataIfNeeded();
      if (_products.isEmpty || _processes.isEmpty) {
        if (mounted) {
          setState(() {
            _message = '请先配置产品和工序后再创建订单。';
          });
        }
        return;
      }

      if (_isEdit) {
        final detail = await _service.getOrderDetail(
          orderId: widget.existing!.id,
        );
        _selectedProductId = detail.order.productId;
        _selectedSupplierId = detail.order.supplierId;
        _ensureCurrentSupplierOption(
          supplierId: detail.order.supplierId,
          supplierName: detail.order.supplierName,
        );
        final sorted = detail.processes.toList()
          ..sort((a, b) => a.processOrder.compareTo(b.processOrder));
        final processCodes = sorted.map((e) => e.processCode).toList();
        _routeSteps = _buildStepsFromProcessCodes(processCodes);
        _selectedTemplateId = detail.order.processTemplateId;
      } else {
        if (_suppliers.isEmpty) {
          if (mounted) {
            setState(() {
              _message = '请先配置启用中的供应商后再创建订单。';
            });
          }
          return;
        }
        _selectedProductId ??= _products.first.id;
        _selectedSupplierId ??= _suppliers.first.id;
        final templates = _templatesByProduct(_selectedProductId!);
        if (templates.isNotEmpty) {
          final defaultTemplate =
              templates.where((item) => item.isDefault).isNotEmpty
              ? templates.firstWhere((item) => item.isDefault)
              : templates.first;
          _selectedTemplateId = defaultTemplate.id;
          try {
            final detail = await _loadTemplateDetail(defaultTemplate.id);
            _routeSteps = _mapTemplateSteps(detail);
          } catch (error) {
            _selectedTemplateId = null;
            _message = '加载默认工艺模板失败：${_errorMessage(error)}';
          }
        }
      }

      if (_routeSteps.isEmpty) {
        final stages = _stageOptions();
        if (stages.isNotEmpty) {
          final firstStage = stages.first;
          final firstStageProcesses = _processesByStage(firstStage.id);
          if (firstStageProcesses.isNotEmpty) {
            _routeSteps = [
              _OrderProcessStepDraft(
                rowId: _nextRouteStepId(),
                stageId: firstStage.id,
                processId: firstStageProcesses.first.id,
              ),
            ];
          }
        }
      }
    } catch (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        setState(() {
          _message = '加载订单表单失败：${_errorMessage(error)}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _initializing = false;
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
      confirmText: '确认',
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  Future<void> _applyTemplateById(int templateId) async {
    setState(() {
      _applyingTemplate = true;
    });
    try {
      final detail = await _loadTemplateDetail(templateId);
      if (!mounted) {
        return;
      }
      setState(() {
        _routeSteps = _mapTemplateSteps(detail);
      });
    } catch (error) {
      _showSnackBar('加载模板失败：${_errorMessage(error)}');
    } finally {
      if (mounted) {
        setState(() {
          _applyingTemplate = false;
        });
      }
    }
  }

  void _addStep() {
    final stages = _stageOptions();
    if (stages.isEmpty) {
      _showSnackBar('请先配置工段与小工序。');
      return;
    }
    final stage = stages.first;
    final processRows = _processesByStage(stage.id);
    if (processRows.isEmpty) {
      _showSnackBar('所选工段没有可用工序。');
      return;
    }
    setState(() {
      _routeSteps = [
        ..._routeSteps,
        _OrderProcessStepDraft(
          rowId: _nextRouteStepId(),
          stageId: stage.id,
          processId: processRows.first.id,
        ),
      ];
    });
  }

  void _reorderRouteSteps(int oldIndex, int newIndex) {
    if (_submitting) {
      return;
    }
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _routeSteps.removeAt(oldIndex);
      _routeSteps.insert(newIndex, item);
    });
  }

  Widget _buildRouteStepDragHandle({required int index}) {
    final iconColor = _submitting
        ? Theme.of(context).disabledColor
        : Theme.of(context).iconTheme.color;
    return Tooltip(
      message: '按住拖动排序',
      child: ReorderableDelayedDragStartListener(
        index: index,
        enabled: !_submitting,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Icon(Icons.drag_indicator, size: 20, color: iconColor),
          ),
        ),
      ),
    );
  }

  Future<void> _onProductChanged(int value) async {
    setState(() {
      _selectedProductId = value;
      _selectedTemplateId = null;
    });
    final nextTemplates = _templatesByProduct(value);
    if (nextTemplates.isEmpty) {
      return;
    }
    final defaultTemplate =
        nextTemplates.where((item) => item.isDefault).isNotEmpty
        ? nextTemplates.firstWhere((item) => item.isDefault)
        : nextTemplates.first;
    setState(() {
      _selectedTemplateId = defaultTemplate.id;
    });
    await _applyTemplateById(defaultTemplate.id);
  }

  Future<void> _submit() async {
    if (_submitting || _applyingTemplate) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedProductId == null) {
      _showSnackBar('请选择产品。');
      return;
    }
    if (_selectedSupplierId == null) {
      _showSnackBar('请选择供应商。');
      return;
    }
    if (_routeSteps.isEmpty) {
      _showSnackBar('至少选择一道工序。');
      return;
    }

    final payloadSteps = <ProductionOrderProcessStepInput>[];
    final processCodes = <String>[];
    for (var i = 0; i < _routeSteps.length; i++) {
      final step = _routeSteps[i];
      final processIndex = _processes.indexWhere(
        (item) => item.id == step.processId,
      );
      if (processIndex < 0) {
        _showSnackBar('存在无效工序，请重新选择。');
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
    final quantity = int.parse(_quantityController.text.trim());
    final normalizedTemplateName = _newTemplateNameController.text.trim();

    setState(() {
      _submitting = true;
    });
    try {
      if (_isEdit) {
        await _service.updateOrder(
          orderId: widget.existing!.id,
          productId: _selectedProductId!,
          supplierId: _selectedSupplierId!,
          quantity: quantity,
          processCodes: processCodes,
          templateId: _selectedTemplateId,
          processSteps: payloadSteps,
          saveAsTemplate: _saveAsTemplate,
          newTemplateName: _saveAsTemplate ? normalizedTemplateName : null,
          newTemplateSetDefault: _newTemplateSetDefault,
          startDate: _startDate,
          dueDate: _dueDate,
          remark: _remarkController.text.trim().isEmpty
              ? null
              : _remarkController.text.trim(),
        );
      } else {
        await _service.createOrder(
          orderCode: _orderCodeController.text.trim(),
          productId: _selectedProductId!,
          supplierId: _selectedSupplierId!,
          quantity: quantity,
          processCodes: processCodes,
          templateId: _selectedTemplateId,
          processSteps: payloadSteps,
          saveAsTemplate: _saveAsTemplate,
          newTemplateName: _saveAsTemplate ? normalizedTemplateName : null,
          newTemplateSetDefault: _newTemplateSetDefault,
          startDate: _startDate,
          dueDate: _dueDate,
          remark: _remarkController.text.trim().isEmpty
              ? null
              : _remarkController.text.trim(),
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (_isUnauthorized(error)) {
        widget.onLogout();
        return;
      }
      _showSnackBar(_errorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '编辑订单' : '创建订单')),
      body: SafeArea(
        child: _initializing
            ? const MesLoadingState(label: '订单表单初始化中...')
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                          child: Form(
                            key: _formKey,
                            child: SingleChildScrollView(
                              child: _buildFormContent(theme),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _submitting
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                              child: const Text('取消'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: (_submitting || _applyingTemplate)
                                  ? null
                                  : _submit,
                              child: Text(_isEdit ? '保存' : '创建'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildFormContent(ThemeData theme) {
    final selectedProductId = _selectedProductId;
    final productTemplates = selectedProductId == null
        ? const <CraftTemplateItem>[]
        : _templatesByProduct(selectedProductId);
    final stageOptions = _stageOptions();
    final supplierItems = _suppliers.toList()
      ..sort((a, b) {
        if (a.isEnabled != b.isEnabled) {
          return a.isEnabled ? -1 : 1;
        }
        return a.name.compareTo(b.name);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _orderCodeController,
          enabled: !_isEdit,
          maxLength: 64,
          decoration: const InputDecoration(
            labelText: '订单号',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (_isEdit) {
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
          key: ValueKey<String>('product-${_selectedProductId ?? 'none'}'),
          initialValue: _selectedProductId,
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
          onChanged: _submitting
              ? null
              : (value) async {
                  if (value == null) {
                    return;
                  }
                  await _onProductChanged(value);
                },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: ValueKey<String>('supplier-${_selectedSupplierId ?? 'none'}'),
          initialValue: _selectedSupplierId,
          decoration: const InputDecoration(
            labelText: '供应商',
            border: OutlineInputBorder(),
          ),
          items: supplierItems
              .map(
                (item) => DropdownMenuItem<int>(
                  value: item.id,
                  child: Text(item.isEnabled ? item.name : '${item.name}（已停用）'),
                ),
              )
              .toList(),
          validator: (value) {
            if (value == null) {
              return '供应商不能为空';
            }
            return null;
          },
          onChanged: _submitting
              ? null
              : (value) {
                  setState(() {
                    _selectedSupplierId = value;
                  });
                },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int?>(
          key: ValueKey<String>('template-${_selectedTemplateId ?? 'none'}'),
          initialValue: _selectedTemplateId,
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
          onChanged: (_submitting || _applyingTemplate)
              ? null
              : (value) async {
                  setState(() {
                    _selectedTemplateId = value;
                  });
                  if (value == null) {
                    return;
                  }
                  await _applyTemplateById(value);
                },
        ),
        if (_applyingTemplate)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (_selectedTemplateId != null) ...[
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '已选择模板，下面的工序路线仍可继续手工调整；提交时以当前页面中的工序路线为准，手工调整优先，不再视为与原模板完全匹配。',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          controller: _quantityController,
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
                onPressed: _submitting
                    ? null
                    : () => _pickDate(
                        current: _startDate,
                        onChanged: (value) {
                          setState(() {
                            _startDate = value;
                          });
                        },
                      ),
                child: Text('开始日期：${_formatDate(_startDate)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting
                    ? null
                    : () => _pickDate(
                        current: _dueDate,
                        onChanged: (value) {
                          setState(() {
                            _dueDate = value;
                          });
                        },
                      ),
                child: Text('交期：${_formatDate(_dueDate)}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _remarkController,
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
            Text('工序路线（工段 -> 小工序）', style: theme.textTheme.titleMedium),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _submitting ? null : _addStep,
              icon: const Icon(Icons.add),
              label: const Text('新增步骤'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _routeSteps.length,
          onReorder: _reorderRouteSteps,
          itemBuilder: (context, index) {
            final step = _routeSteps[index];
            final processRows = _processesByStage(step.stageId);
            if (processRows.isNotEmpty &&
                !processRows.any((item) => item.id == step.processId)) {
              step.processId = processRows.first.id;
            }
            return Padding(
              key: ValueKey(step.rowId),
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      SizedBox(width: 48, child: Text('#${index + 1}')),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: ValueKey<String>(
                            'stage_${step.rowId}_${step.stageId}',
                          ),
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
                                  child: Text('${stage.name} (${stage.code})'),
                                ),
                              )
                              .toList(),
                          onChanged: _submitting
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  final nextRows = _processesByStage(value);
                                  setState(() {
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
                          key: ValueKey<String>(
                            'process_${step.rowId}_${step.processId}',
                          ),
                          initialValue: processRows.isEmpty
                              ? null
                              : (processRows.any(
                                      (item) => item.id == step.processId,
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
                                  child: Text('${item.name} (${item.code})'),
                                ),
                              )
                              .toList(),
                          onChanged: (_submitting || processRows.isEmpty)
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setState(() {
                                    step.processId = value;
                                  });
                                },
                        ),
                      ),
                      _buildRouteStepDragHandle(index: index),
                      IconButton(
                        tooltip: '删除',
                        onPressed: (_submitting || _routeSteps.length <= 1)
                            ? null
                            : () {
                                setState(() {
                                  _routeSteps = [..._routeSteps]
                                    ..removeAt(index);
                                });
                              },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('将当前流程另存为新模板'),
          value: _saveAsTemplate,
          onChanged: _submitting
              ? null
              : (value) {
                  setState(() {
                    _saveAsTemplate = value ?? false;
                    if (!_saveAsTemplate) {
                      _newTemplateNameController.clear();
                      _newTemplateSetDefault = false;
                    }
                  });
                },
        ),
        if (_saveAsTemplate) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _newTemplateNameController,
            maxLength: 128,
            decoration: const InputDecoration(
              labelText: '新模板名称',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (!_saveAsTemplate) {
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
            value: _newTemplateSetDefault,
            onChanged: _submitting
                ? null
                : (value) {
                    setState(() {
                      _newTemplateSetDefault = value ?? false;
                    });
                  },
          ),
        ],
      ],
    );
  }
}
