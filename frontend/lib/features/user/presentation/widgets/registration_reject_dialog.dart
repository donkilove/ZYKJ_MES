import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/features/user/models/user_models.dart';

class RegistrationRejectDialog extends StatefulWidget {
  const RegistrationRejectDialog({
    super.key,
    required this.item,
    required this.onReject,
  });

  final RegistrationRequestItem item;
  final Future<void> Function({String? reason}) onReject;

  @override
  State<RegistrationRejectDialog> createState() => _RegistrationRejectDialogState();
}

class _RegistrationRejectDialogState extends State<RegistrationRejectDialog> {
  final _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final reason = _reasonController.text.trim();
    await widget.onReject(reason: reason.isEmpty ? null : reason);
    if (mounted) {
      setState(() => _submitting = false);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MesDialog(
      title: const Text('驳回注册申请'),
      width: 520,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withAlpha(50),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.error.withAlpha(100)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '确认驳回账号 “${widget.item.account}” 的注册申请吗？',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            readOnly: _submitting,
            decoration: const InputDecoration(
              labelText: '驳回原因（可选）',
              filled: true,
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '驳回中...' : '确认驳回'),
        ),
      ],
    );
  }
}
