import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';

class MesActionDialog extends StatelessWidget {
  const MesActionDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onConfirm,
    this.onCancel,
    this.confirmLabel = '确认',
    this.cancelLabel = '取消',
    this.width,
    this.isDestructive = false,
  });

  final Widget title;
  final Widget content;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final String confirmLabel;
  final String cancelLabel;
  final double? width;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return MesDialog(
      title: title,
      width: width,
      content: content,
      actions: [
        TextButton(
          onPressed: onCancel ?? () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style:
              isDestructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    )
                  : null,
          onPressed: onConfirm,
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
