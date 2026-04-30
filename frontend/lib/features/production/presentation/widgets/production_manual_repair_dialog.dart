import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/features/production/models/production_models.dart';

class ProductionManualRepairDialogResult {
  const ProductionManualRepairDialogResult({
    required this.productionQuantity,
    required this.defectItems,
  });

  final int productionQuantity;
  final List<ProductionDefectItemInput> defectItems;
}

Future<ProductionManualRepairDialogResult?> showProductionManualRepairDialog({
  required BuildContext context,
  required MyOrderItem order,
}) {
  return showMesLockedFormDialog<ProductionManualRepairDialogResult?>(
    context: context,
    wrapMesDialog: false,
    builder: (dialogContext) {
      return ProductionManualRepairDialog(order: order);
    },
  );
}

class ProductionManualRepairDialog extends StatefulWidget {
  const ProductionManualRepairDialog({
    super.key,
    required this.order,
  });

  final MyOrderItem order;

  @override
  State<ProductionManualRepairDialog> createState() =>
      _ProductionManualRepairDialogState();
}

class _ProductionManualRepairDialogState
    extends State<ProductionManualRepairDialog> {
  late final TextEditingController _productionQuantityController;
  final List<_DefectRowDraft> _defectRows = <_DefectRowDraft>[_DefectRowDraft()];

  @override
  void initState() {
    super.initState();
    _productionQuantityController = TextEditingController(
      text: '${widget.order.maxProducibleQuantity.clamp(1, 999999)}',
    );
  }

  @override
  void dispose() {
    _productionQuantityController.dispose();
    for (final row in _defectRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _defectRows.add(_DefectRowDraft());
    });
  }

  void _removeRow(int index) {
    if (_defectRows.length <= 1) {
      return;
    }
    setState(() {
      final removed = _defectRows.removeAt(index);
      removed.dispose();
    });
  }

  void _submit() {
    final productionQty = int.tryParse(_productionQuantityController.text.trim());
    if (productionQty == null || productionQty <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入本次生产数量')));
      return;
    }
    final defects = <ProductionDefectItemInput>[];
    for (final row in _defectRows) {
      final phenomenon = row.phenomenonController.text.trim();
      final defectQty = int.tryParse(row.quantityController.text.trim());
      if (phenomenon.isEmpty || defectQty == null || defectQty <= 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请完整填写不良现象明细')));
        return;
      }
      defects.add(
        ProductionDefectItemInput(
          phenomenon: phenomenon,
          quantity: defectQty,
        ),
      );
    }
    Navigator.of(context).pop(
      ProductionManualRepairDialogResult(
        productionQuantity: productionQty,
        defectItems: defects,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MesDialog(
      title: const Text('手工送修建单'),
      width: 760,
      content: SizedBox(
        key: const ValueKey('production-manual-repair-dialog'),
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
                    '建单信息',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _productionQuantityController,
                    keyboardType: TextInputType.number,
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
                      color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Text(
                      '本弹窗会直接生成维修单，请在右侧完整填写不良明细。',
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
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
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
                          '不良现象明细',
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
                    ...List.generate(_defectRows.length, (index) {
                      final row = _defectRows[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: row.phenomenonController,
                                decoration: const InputDecoration(
                                  labelText: '现象',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: row.quantityController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '数量',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _defectRows.length <= 1
                                  ? null
                                  : () => _removeRow(index),
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
        FilledButton(
          onPressed: _submit,
          child: const Text('提交建单'),
        ),
      ],
    );
  }
}

class _DefectRowDraft {
  _DefectRowDraft({String? phenomenon, int? quantity})
    : phenomenonController = TextEditingController(text: phenomenon ?? ''),
      quantityController = TextEditingController(
        text: quantity == null ? '' : '$quantity',
      );

  final TextEditingController phenomenonController;
  final TextEditingController quantityController;

  void dispose() {
    phenomenonController.dispose();
    quantityController.dispose();
  }
}
