import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/features/user/models/user_models.dart';

Future<bool> showRoleDeleteDialog({
  required BuildContext context,
  required RoleItem role,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return MesDialog(
        title: const Text('删除角色'),
        width: 420,
        content: SizedBox(
          key: const ValueKey('role-delete-dialog'),
          width: 420,
          child: Text('确认删除角色“${role.name}”吗？删除后不可恢复。'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}
