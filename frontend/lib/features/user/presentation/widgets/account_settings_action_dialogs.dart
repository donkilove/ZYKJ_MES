import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';

Future<void> showAccountSessionTimeoutDialog({
  required BuildContext context,
  required String remainingTimeLabel,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => MesDialog(
      title: const Text('会话即将过期'),
      width: 420,
      content: Container(
        key: const ValueKey('account-session-timeout-dialog'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.deepOrange,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              '当前会话将在 $remainingTimeLabel 后过期，请及时保存工作内容。如需继续使用，请重新登录。',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}
