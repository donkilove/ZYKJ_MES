import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/features/production/models/production_models.dart';

class ProductionPipelineModeProcessOption {
  const ProductionPipelineModeProcessOption({
    required this.code,
    required this.name,
    required this.processOrder,
    required this.enabled,
  });

  final String code;
  final String name;
  final int processOrder;
  final bool enabled;
}

Future<List<String>?> showProductionPipelineModeDialog({
  required BuildContext context,
  required ProductionOrderItem order,
  required List<ProductionPipelineModeProcessOption> processOptions,
  required List<String> initialSelectedCodes,
}) {
  return showMesLockedFormDialog<List<String>?>(
    context: context,
    wrapMesDialog: false,
    builder: (dialogContext) {
      return ProductionPipelineModeDialog(
        order: order,
        processOptions: processOptions,
        initialSelectedCodes: initialSelectedCodes,
      );
    },
  );
}

class ProductionPipelineModeDialog extends StatefulWidget {
  const ProductionPipelineModeDialog({
    super.key,
    required this.order,
    required this.processOptions,
    required this.initialSelectedCodes,
  });

  final ProductionOrderItem order;
  final List<ProductionPipelineModeProcessOption> processOptions;
  final List<String> initialSelectedCodes;

  @override
  State<ProductionPipelineModeDialog> createState() =>
      _ProductionPipelineModeDialogState();
}

class _ProductionPipelineModeDialogState
    extends State<ProductionPipelineModeDialog> {
  late final Set<String> _selectedCodes = widget.initialSelectedCodes.toSet();

  void _submit() {
    Navigator.of(context).pop(_selectedCodes.toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MesDialog(
      title: Text('并行模式设置 - ${widget.order.orderCode}'),
      width: 620,
      content: SizedBox(
        key: const ValueKey('production-pipeline-mode-dialog'),
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '请选择参与并行的工序（至少 2 道）。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: ListView(
                children: widget.processOptions.map((row) {
                  return CheckboxListTile(
                    dense: true,
                    value: _selectedCodes.contains(row.code),
                    onChanged: row.enabled
                        ? (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedCodes.add(row.code);
                              } else {
                                _selectedCodes.remove(row.code);
                              }
                            });
                          }
                        : null,
                    title: Text('${row.name} (${row.code})'),
                    subtitle: Text('顺序 ${row.processOrder}'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '当前已选 ${_selectedCodes.length} 道。',
              style: theme.textTheme.bodySmall,
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
          child: const Text('保存'),
        ),
      ],
    );
  }
}
