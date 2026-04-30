import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/features/craft/models/craft_models.dart';

Future<bool> showProcessConfigurationEnableDialog({
  required BuildContext context,
  required CraftTemplateItem item,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => MesDialog(
      title: const Text('启用模板'),
      width: 420,
      content: SizedBox(
        key: const ValueKey('process-configuration-enable-dialog'),
        width: 420,
        child: Text('确认启用模板 ${item.templateName} 吗？'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('启用'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
