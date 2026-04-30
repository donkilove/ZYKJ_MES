import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_action_dialog.dart';
import 'package:mes_client/features/equipment/models/equipment_models.dart';

Future<bool> showEquipmentRuleToggleDialog({
  required BuildContext context,
  required EquipmentRuleItem rule,
  required bool nextEnabled,
}) async {
  final action = nextEnabled ? '启用' : '停用';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => MesActionDialog(
      title: Text('$action设备规则确认'),
      width: 420,
      content: Text('确认$action规则“${rule.ruleName}”吗？该变更会影响设备规则后续判定。'),
      confirmLabel: action,
      isDestructive: !nextEnabled,
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
  return confirmed == true;
}

Future<bool> showEquipmentRuntimeParameterToggleDialog({
  required BuildContext context,
  required EquipmentRuntimeParameterItem parameter,
  required bool nextEnabled,
}) async {
  final action = nextEnabled ? '启用' : '停用';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => MesActionDialog(
      title: Text('$action运行参数确认'),
      width: 420,
      content: Text('确认$action参数“${parameter.paramName}”吗？该变更会影响运行参数后续采集。'),
      confirmLabel: action,
      isDestructive: !nextEnabled,
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
  return confirmed == true;
}

Future<bool> showEquipmentRuleDeleteDialog({
  required BuildContext context,
  required String ruleName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('确认删除'),
      content: Text('确定删除规则「$ruleName」？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

Future<bool> showEquipmentRuntimeParameterDeleteDialog({
  required BuildContext context,
  required String paramName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('确认删除'),
      content: Text('确定删除参数「$paramName」？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
