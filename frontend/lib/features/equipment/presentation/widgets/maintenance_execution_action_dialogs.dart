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
        child: Text(
          '确认取消工单"${workOrder.equipmentName} / ${workOrder.itemName}"吗？',
        ),
      ),
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
  return confirmed == true;
}

Future<bool> showMaintenanceExecutionStartDialog({
  required BuildContext context,
  required MaintenanceWorkOrderItem workOrder,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => MesActionDialog(
      title: const Text('开始执行确认'),
      width: 420,
      content: Text(
        '确认开始执行工单“${workOrder.equipmentName} / ${workOrder.itemName}”吗？',
      ),
      confirmLabel: '开始执行',
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
  return confirmed == true;
}
