import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';

class ProductVersionNoteDialog extends StatelessWidget {
  const ProductVersionNoteDialog({
    super.key,
    required this.versionLabel,
    required this.controller,
  });

  final String versionLabel;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return MesDialog(
      title: Text('编辑备注 - $versionLabel'),
      width: 420,
      content: SizedBox(
        key: const ValueKey('product-version-note-dialog'),
        width: 420,
        child: TextField(
          controller: controller,
          maxLength: 256,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '版本备注',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
