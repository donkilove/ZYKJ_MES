import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_action_dialog.dart';
import 'package:mes_client/features/craft/presentation/widgets/process_management_models.dart';

Future<bool> showDeleteDialog(
  BuildContext context, {
  required String title,
  required String targetName,
  required List<RefEntry> refs,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => MesActionDialog(
      title: Text(title),
      width: 520,
      isDestructive: true,
      confirmLabel: '删除',
      onConfirm: () => Navigator.of(context).pop(true),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('确认删除 $targetName 吗？'),
          if (refs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '该对象存在 ${refs.length} 条引用关系：',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: refs.length,
                itemBuilder: (context, index) {
                  final ref = refs[index];
                  return ListTile(
                    dense: true,
                    leading: Text(ref.refType),
                    title: Text(ref.refName),
                    subtitle: Text(ref.detail ?? ''),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    ),
  );
  return result ?? false;
}
