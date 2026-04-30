import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_action_dialog.dart';
import 'package:mes_client/features/user/models/user_models.dart';

Future<bool> showForceOfflineSessionDialog({
  required BuildContext context,
  required OnlineSessionItem session,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => MesActionDialog(
      title: const Text('强制下线确认'),
      width: 440,
      content: Text('确认强制下线用户“${session.username}”的当前在线会话吗？操作后该会话需要重新登录。'),
      confirmLabel: '强制下线',
      isDestructive: true,
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
  return confirmed == true;
}

Future<bool> showBatchForceOfflineSessionDialog({
  required BuildContext context,
  required int sessionCount,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => MesActionDialog(
      title: const Text('批量强制下线确认'),
      width: 440,
      content: Text('确认强制下线选中的 $sessionCount 个在线会话吗？操作后这些会话需要重新登录。'),
      confirmLabel: '批量强制下线',
      isDestructive: true,
      onConfirm: () => Navigator.of(dialogContext).pop(true),
    ),
  );
  return confirmed == true;
}
