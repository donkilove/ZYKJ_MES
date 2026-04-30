import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/features/production/models/production_models.dart';

Future<bool> showProductionDisablePipelineDialog({
  required BuildContext context,
  required ProductionOrderItem order,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return MesDialog(
        title: const Text('关闭并行模式'),
        width: 420,
        content: SizedBox(
          key: const ValueKey('production-disable-pipeline-dialog'),
          width: 420,
          child: Text('确认关闭订单 ${order.orderCode} 的并行模式吗？'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确认关闭'),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}
