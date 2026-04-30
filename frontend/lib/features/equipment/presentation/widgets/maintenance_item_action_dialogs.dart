import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_action_dialog.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';

Future<bool> showMaintenanceItemToggleDialog({
  required BuildContext context,
  required MaintenanceItemEntry item,
  required bool nextEnabled,
}) async {
  final action = nextEnabled ? '启用' : '停用';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => MesActionDialog(
      title: Text('$action保养项目'),
      content: Text('确认$action项目“${item.name}”吗？'),
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
  return confirmed == true;
}

Future<bool> showMaintenanceItemDeleteDialog({
  required BuildContext context,
  required MaintenanceItemEntry item,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => MesActionDialog(
      title: const Text('删除保养项目'),
      content: Text('确认删除项目“${item.name}”吗？此操作不可恢复。'),
      confirmLabel: '删除',
      isDestructive: true,
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
  return confirmed == true;
}
