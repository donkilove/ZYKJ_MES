import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/features/production/models/production_models.dart';

class ProductionRepairReturnToProductionDialogResult {
  const ProductionRepairReturnToProductionDialogResult({
    required this.password,
  });

  final String password;
}

Future<ProductionRepairReturnToProductionDialogResult?>
showProductionRepairReturnToProductionDialog({
  required BuildContext context,
  required RepairOrderItem repairOrder,
}) {
  return showMesLockedFormDialog<
    ProductionRepairReturnToProductionDialogResult?
  >(
    context: context,
    wrapMesDialog: false,
    builder: (dialogContext) {
      return ProductionRepairReturnToProductionDialog(repairOrder: repairOrder);
    },
  );
}

class ProductionRepairReturnToProductionDialog extends StatefulWidget {
  const ProductionRepairReturnToProductionDialog({
    super.key,
    required this.repairOrder,
  });

  final RepairOrderItem repairOrder;

  @override
  State<ProductionRepairReturnToProductionDialog> createState() =>
      _ProductionRepairReturnToProductionDialogState();
}

class _ProductionRepairReturnToProductionDialogState
    extends State<ProductionRepairReturnToProductionDialog> {
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入当前登录密码后再退回生产')));
      return;
    }
    Navigator.of(context).pop(
      ProductionRepairReturnToProductionDialogResult(
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MesDialog(
      title: const Text('退回生产'),
      width: 680,
      content: SizedBox(
        key: const ValueKey('production-repair-return-to-production-dialog'),
        width: 680,
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
                    '确认退回维修单 ${widget.repairOrder.repairOrderCode} 吗？',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '送修数量 ${widget.repairOrder.repairQuantity} 将回到送修工序继续生产。',
                  ),
                  const SizedBox(height: 8),
                  const Text('退回后保留维修记录和详情追溯，但不进入质量统计。'),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                    50,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '当前登录密码',
                    border: OutlineInputBorder(),
                  ),
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
        FilledButton(onPressed: _submit, child: const Text('退回生产')),
      ],
    );
  }
}
