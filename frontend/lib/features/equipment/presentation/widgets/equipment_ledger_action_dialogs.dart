import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_action_dialog.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';

Future<bool> showEquipmentLedgerToggleDialog({
  required BuildContext context,
  required EquipmentLedgerItem item,
  required bool nextEnabled,
}) async {
  final action = nextEnabled ? '启用' : '停用';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => MesActionDialog(
      title: Text('$action设备'),
      content: Text('确认$action设备“${item.name}”吗？'),
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
  return confirmed == true;
}

Future<bool> showEquipmentLedgerDeleteDialog({
  required BuildContext context,
  required EquipmentLedgerItem item,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => MesActionDialog(
      title: const Text('删除设备'),
      content: Text('确认删除设备“${item.name}”吗？此操作不可恢复。'),
      confirmLabel: '删除',
      isDestructive: true,
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
  return confirmed == true;
}
