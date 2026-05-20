import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/features/production/models/defect_catalog.dart';
import 'package:mes_client/features/production/models/production_models.dart';

class ProductionEndProductionDialogResult {
  const ProductionEndProductionDialogResult({
    required this.quantity,
    required this.defectItems,
  });

  final int quantity;
  final List<ProductionDefectItemInput> defectItems;
}

Future<ProductionEndProductionDialogResult?> showProductionEndProductionDialog({
  required BuildContext context,
  required MyOrderItem order,
}) {
  return showMesLockedFormDialog<ProductionEndProductionDialogResult?>(
    context: context,
    wrapMesDialog: false,
    builder: (dialogContext) {
      return ProductionEndProductionDialog(order: order);
    },
  );
}

class ProductionEndProductionDialog extends StatefulWidget {
  const ProductionEndProductionDialog({super.key, required this.order});

  final MyOrderItem order;

  @override
  State<ProductionEndProductionDialog> createState() =>
      _ProductionEndProductionDialogState();
}

class _ProductionEndProductionDialogState
    extends State<ProductionEndProductionDialog> {
  late final TextEditingController _quantityController;
  final List<_DefectRowDraft> _defectRows = <_DefectRowDraft>[];
  bool _isSyncingQuantityText = false;

  int get _manualRepairQuantity =>
      widget.order.currentCycleManualRepairQuantity.clamp(0, 999999).toInt();

  int get _maxQuantity =>
      (widget.order.maxProducibleQuantity + _manualRepairQuantity)
          .clamp(0, 999999)
          .toInt();

  int get _inputQuantity =>
      int.tryParse(_quantityController.text.trim()) ?? 0;

  int get _defectTotal {
    var total = 0;
    for (final row in _defectRows) {
      total += int.tryParse(row.quantityController.text.trim()) ?? 0;
    }
    return total;
  }

  int get _estimatedTransferQuantity =>
      _inputQuantity - _manualRepairQuantity - _defectTotal;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: _maxQuantity > 0 ? '$_maxQuantity' : '',
    );
    _quantityController.addListener(_syncQuantityWithinLimit);
  }

  @override
  void dispose() {
    _quantityController.removeListener(_syncQuantityWithinLimit);
    _quantityController.dispose();
    for (final row in _defectRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _syncQuantityWithinLimit() {
    if (_isSyncingQuantityText) {
      return;
    }
    final rawValue = _quantityController.text.trim();
    if (rawValue.isEmpty) {
      return;
    }
    final quantity = int.tryParse(rawValue);
    if (quantity == null) {
      _replaceQuantityText('');
      setState(() {});
      return;
    }
    if (quantity > _maxQuantity) {
      _replaceQuantityText('$_maxQuantity');
    }
    setState(() {});
  }

  void _replaceQuantityText(String value) {
    _isSyncingQuantityText = true;
    _quantityController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _isSyncingQuantityText = false;
  }

  void _addRow() {
    setState(() {
      _defectRows.add(
        _DefectRowDraft(phenomenon: productionDefectPhenomena.first),
      );
    });
  }

  void _removeRow(int index) {
    setState(() {
      final removed = _defectRows.removeAt(index);
      removed.dispose();
    });
  }

  void _submit() {
    final qty = int.tryParse(_quantityController.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效结束生产数量')));
      return;
    }

    final defects = <ProductionDefectItemInput>[];
    for (final row in _defectRows) {
      final phenomenon = row.phenomenon.trim();
      final qtyText = row.quantityController.text.trim();
      if (qtyText.isEmpty) {
        continue;
      }
      final defectQty = int.tryParse(qtyText);
      if (phenomenon.isEmpty || defectQty == null || defectQty <= 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('不良明细需同时填写现象与正整数数量')));
        return;
      }
      defects.add(
        ProductionDefectItemInput(phenomenon: phenomenon, quantity: defectQty),
      );
    }

    final defectTotal = defects.fold<int>(
      0,
      (sum, entry) => sum + entry.quantity,
    );
    if (qty < _manualRepairQuantity + defectTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '本次生产数量不能小于已手工送修 ${_manualRepairQuantity} 件与本次报工送修 $defectTotal 件之和',
          ),
        ),
      );
      return;
    }

    final consumedQuantity = qty - _manualRepairQuantity;
    if (consumedQuantity > widget.order.maxProducibleQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '本次生产数量扣除已手工送修后不能超过当前可生产数量 ${widget.order.maxProducibleQuantity}',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      ProductionEndProductionDialogResult(quantity: qty, defectItems: defects),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estimatedTransferQuantity = _estimatedTransferQuantity;
    final transferText = estimatedTransferQuantity < 0
        ? '预计流转数：-（本次生产数量不足以覆盖已送修和本次异常）'
        : '预计流转至下一工序：$estimatedTransferQuantity 件';
    return MesDialog(
      title: const Text('结束生产'),
      width: 760,
      content: SizedBox(
        key: const ValueKey('production-end-production-dialog'),
        width: 760,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '生产结果',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: '本次生产数量',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withAlpha(50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      '当前可生产数量：${widget.order.maxProducibleQuantity}；'
                      '生产中已手工送修：$_manualRepairQuantity；'
                      '本次最多可填生产数量：$_maxQuantity。$transferText。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 6,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                    50,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '不良现象（可选）',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: _addRow,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('新增'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_defectRows.isEmpty)
                      Text(
                        '未填写时按纯良品结束生产处理。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ...List.generate(_defectRows.length, (index) {
                      final row = _defectRows[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                key: ValueKey(
                                  'production-end-defect-phenomenon-$index',
                                ),
                                initialValue: row.phenomenon,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: '现象',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: productionDefectPhenomena
                                    .map(
                                      (value) => DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setState(() {
                                    row.phenomenon = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: row.quantityController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  labelText: '数量',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeRow(index),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('提交')),
      ],
    );
  }
}

class _DefectRowDraft {
  _DefectRowDraft({String? phenomenon, int? quantity})
    : phenomenon = phenomenon ?? productionDefectPhenomena.first,
      quantityController = TextEditingController(
        text: quantity == null ? '' : '$quantity',
      );

  String phenomenon;
  final TextEditingController quantityController;

  void dispose() {
    quantityController.dispose();
  }
}
