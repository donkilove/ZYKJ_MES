import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_action_dialog.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';

Future<bool> showStageToggleDialog({
  required BuildContext context,
  required CraftStageItem stage,
  required bool nextEnabled,
}) async {
  final action = nextEnabled ? '启用' : '停用';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => MesActionDialog(
      title: Text('$action工段确认'),
      width: 420,
      content: Text('确认$action工段“${stage.name}”吗？该变更会影响工艺配置中的可选状态。'),
      confirmLabel: action,
      isDestructive: !nextEnabled,
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
  return confirmed == true;
}

Future<bool> showProcessToggleDialog({
  required BuildContext context,
  required CraftProcessItem process,
  required bool nextEnabled,
}) async {
  final action = nextEnabled ? '启用' : '停用';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => MesActionDialog(
      title: Text('$action工序确认'),
      width: 420,
      content: Text('确认$action工序“${process.name}”吗？该变更会影响模板配置中的可选状态。'),
      confirmLabel: action,
      isDestructive: !nextEnabled,
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
  return confirmed == true;
}
