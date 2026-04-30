import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_action_dialog.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';

Future<bool> showMaintenancePlanDeleteDialog({
  required BuildContext context,
  required MaintenancePlanItem plan,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => MesActionDialog(
      title: const Text('删除保养计划'),
      content: Text('确认删除计划“${plan.equipmentName} / ${plan.itemName}”吗？此操作不可恢复。'),
      confirmLabel: '删除',
      isDestructive: true,
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
  return confirmed == true;
}
