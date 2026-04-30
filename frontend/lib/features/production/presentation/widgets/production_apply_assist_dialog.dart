import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/features/production/models/production_models.dart';

class ProductionApplyAssistDialogResult {
  const ProductionApplyAssistDialogResult({
    required this.targetOperatorUserId,
    required this.helperUserId,
    required this.reason,
  });

  final int targetOperatorUserId;
  final int helperUserId;
  final String? reason;
}

Future<ProductionApplyAssistDialogResult?> showProductionApplyAssistDialog({
  required BuildContext context,
  required MyOrderItem order,
  required List<AssistUserOptionItem> targetOperators,
  required List<AssistUserOptionItem> assistUsers,
}) {
  return showMesLockedFormDialog<ProductionApplyAssistDialogResult?>(
    context: context,
    wrapMesDialog: false,
    builder: (dialogContext) {
      return ProductionApplyAssistDialog(
        order: order,
        targetOperators: targetOperators,
        assistUsers: assistUsers,
      );
    },
  );
}

class ProductionApplyAssistDialog extends StatefulWidget {
  const ProductionApplyAssistDialog({
    super.key,
    required this.order,
    required this.targetOperators,
    required this.assistUsers,
  });

  final MyOrderItem order;
  final List<AssistUserOptionItem> targetOperators;
  final List<AssistUserOptionItem> assistUsers;

  @override
  State<ProductionApplyAssistDialog> createState() =>
      _ProductionApplyAssistDialogState();
}

class _ProductionApplyAssistDialogState
    extends State<ProductionApplyAssistDialog> {
  late int? _targetOperatorUserId;
  int? _helperUserId;
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _targetOperatorUserId = widget.order.operatorUserId;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_targetOperatorUserId == null || _helperUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择目标操作员和代班人')));
      return;
    }
    final reason = _reasonController.text.trim();
    Navigator.of(context).pop(
      ProductionApplyAssistDialogResult(
        targetOperatorUserId: _targetOperatorUserId!,
        helperUserId: _helperUserId!,
        reason: reason.isEmpty ? null : reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MesDialog(
      title: const Text('发起代班'),
      width: 700,
      content: SizedBox(
        key: const ValueKey('production-apply-assist-dialog'),
        width: 700,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '代班安排',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _targetOperatorUserId,
                    decoration: const InputDecoration(
                      labelText: '目标操作员',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.targetOperators
                        .map(
                          (it) => DropdownMenuItem<int>(
                            value: it.id,
                            child: Text(
                              it.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    selectedItemBuilder: (context) => widget.targetOperators
                        .map(
                          (it) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              it.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _targetOperatorUserId = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _helperUserId,
                    decoration: const InputDecoration(
                      labelText: '代班人',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.assistUsers
                        .map(
                          (it) => DropdownMenuItem<int>(
                            value: it.id,
                            child: Text(
                              it.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    selectedItemBuilder: (context) => widget.assistUsers
                        .map(
                          (it) => Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              it.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _helperUserId = value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '补充说明',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reasonController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: '代班原因（可选）',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '提交后会立即为当前工序建立代班授权。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('发起代班'),
        ),
      ],
    );
  }
}
