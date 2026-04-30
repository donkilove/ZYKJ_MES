import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';

Future<void> showCraftKanbanExportPreviewDialog({
  required BuildContext context,
  required String text,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => MesDialog(
      title: const Text('看板导出预览'),
      width: 920,
      content: SizedBox(
        key: const ValueKey('craft-kanban-export-preview-dialog'),
        height: 560,
        child: text.isEmpty
            ? const Center(child: Text('暂无可导出数据'))
            : SingleChildScrollView(child: SelectableText(text)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}
