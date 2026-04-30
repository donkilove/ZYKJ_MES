import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_action_dialog.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';

Future<bool> showMaintenanceExecutionCancelDialog({
  required BuildContext context,
  required MaintenanceWorkOrderItem workOrder,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => MesActionDialog(
      title: const Text('取消工单'),
      content: Container(
        key: const ValueKey('maintenance-execution-cancel-dialog'),
        child: Text('确认取消工单"${workOrder.equipmentName} / ${workOrder.itemName}"吗？'),
      ),
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
  return confirmed == true;
}
