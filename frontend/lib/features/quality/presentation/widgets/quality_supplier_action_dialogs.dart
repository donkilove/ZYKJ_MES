import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_action_dialog.dart';
import 'package:mes_client/features/quality/models/quality_models.dart';

Future<bool> showQualitySupplierDeleteDialog({
  required BuildContext context,
  required QualitySupplierItem item,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return MesActionDialog(
        title: const Text('确认删除'),
        content: Text('确认删除供应商 ${item.name} 吗？'),
        confirmLabel: '确认删除',
        isDestructive: true,
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      );
    },
  );
  return confirmed == true;
}
