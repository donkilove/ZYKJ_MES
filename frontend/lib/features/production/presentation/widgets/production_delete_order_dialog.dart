import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/features/production/models/production_models.dart';

Future<bool> showProductionDeleteOrderDialog({
  required BuildContext context,
  required ProductionOrderItem order,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return ProductionDeleteOrderDialog(order: order);
    },
  );
  return confirmed == true;
}

class ProductionDeleteOrderDialog extends StatelessWidget {
  const ProductionDeleteOrderDialog({
    super.key,
    required this.order,
  });

  final ProductionOrderItem order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MesDialog(
      title: const Text('删除订单'),
      width: 520,
      content: SizedBox(
        key: const ValueKey('production-delete-order-dialog'),
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '确认删除',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text('确认删除订单 ${order.orderCode} 吗？'),
          ],
        ),
      ),
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
    );
  }
}
