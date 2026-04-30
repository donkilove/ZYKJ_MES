import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_action_dialog.dart';
import 'package:mes_client/features/product/models/product_models.dart';

Future<bool> showProductVersionActivateDialog({
  required BuildContext context,
  required ProductVersionItem version,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => MesActionDialog(
      title: const Text('确认生效'),
      content: Text(
        '确认将版本 ${version.versionLabel} 设为生效版本？\n生效后，当前生效版本将自动变为已失效。',
      ),
      confirmLabel: '确认生效',
      onConfirm: () => Navigator.pop(ctx, true),
    ),
  );
  return confirmed == true;
}

Future<bool> showProductVersionDisableDialog({
  required BuildContext context,
  required ProductVersionItem version,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => MesActionDialog(
      title: const Text('确认停用'),
      content: Text(
        '确认停用版本 ${version.versionLabel}？停用后不可直接恢复，如需再次使用请复制出新草稿。',
      ),
      confirmLabel: '确认停用',
      isDestructive: true,
      onConfirm: () => Navigator.pop(ctx, true),
    ),
  );
  return confirmed == true;
}

Future<bool> showProductVersionDeleteDialog({
  required BuildContext context,
  required ProductVersionItem version,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => MesActionDialog(
      title: const Text('确认删除'),
      content: Text('确认删除草稿版本 ${version.versionLabel}？此操作不可撤销。'),
      confirmLabel: '确认删除',
      isDestructive: true,
      onConfirm: () => Navigator.pop(ctx, true),
    ),
  );
  return confirmed == true;
}
