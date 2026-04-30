import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';

Future<bool> showFunctionPermissionDiscardDialog({
  required BuildContext context,
}) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (context) {
      return MesDialog(
        title: const Text('切换模块'),
        width: 420,
        content: const Text('当前有未保存改动，是否放弃并切换？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃并切换'),
          ),
        ],
      );
    },
  );
  return discard == true;
}

Future<bool> showFunctionPermissionSaveDialog({
  required BuildContext context,
}) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) {
      return MesDialog(
        title: const Text('确认保存'),
        width: 420,
        content: const Text('将保存当前模块的权限配置，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认保存'),
          ),
        ],
      );
    },
  );
  return confirm == true;
}
