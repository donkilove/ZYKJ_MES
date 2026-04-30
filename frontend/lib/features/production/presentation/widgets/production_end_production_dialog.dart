import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
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
  const ProductionEndProductionDialog({
    super.key,
    required this.order,
  });

  final MyOrderItem order;

  @override
  State<ProductionEndProductionDialog> createState() =>
      _ProductionEndProductionDialogState();
}

class _ProductionEndProductionDialogState
    extends State<ProductionEndProductionDialog> {
  late final TextEditingController _quantityController;
  final List<_DefectRowDraft> _defectRows = <_DefectRowDraft>[];

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: '${widget.order.maxProducibleQuantity.clamp(1, 999999)}',
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
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
      final phenomenon = row.phenomenonController.text.trim();
      final qtyText = row.quantityController.text.trim();
      if (phenomenon.isEmpty && qtyText.isEmpty) {
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
        ProductionDefectItemInput(
          phenomenon: phenomenon,
          quantity: defectQty,
        ),
      );
    }

    final defectTotal = defects.fold<int>(0, (sum, entry) => sum + entry.quantity);
    if (qty + defectTotal > widget.order.maxProducibleQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '结束生产数量与异常数量合计不能超过当前可生产数量 ${widget.order.maxProducibleQuantity}',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      ProductionEndProductionDialogResult(
        quantity: qty,
        defectItems: defects,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    decoration: const InputDecoration(
                      labelText: '有效流转数量',
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
                      '当前可生产数量：${widget.order.maxProducibleQuantity}。如存在不良，请在右侧补充异常明细。',
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
        FilledButton(
          onPressed: _submit,
          child: const Text('提交'),
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
