import 'package:flutter/material.dart';

import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/features/production/models/production_models.dart';

class ProductionCompleteOrderDialogResult {
  const ProductionCompleteOrderDialogResult({
    required this.password,
  });

  final String password;
}

Future<ProductionCompleteOrderDialogResult?> showProductionCompleteOrderDialog({
  required BuildContext context,
  required ProductionOrderItem order,
}) {
  return showMesLockedFormDialog<ProductionCompleteOrderDialogResult?>(
    context: context,
    wrapMesDialog: false,
    builder: (dialogContext) {
      return ProductionCompleteOrderDialog(order: order);
    },
  );
}

class ProductionCompleteOrderDialog extends StatefulWidget {
  const ProductionCompleteOrderDialog({
    super.key,
    required this.order,
  });

  final ProductionOrderItem order;

  @override
  State<ProductionCompleteOrderDialog> createState() =>
      _ProductionCompleteOrderDialogState();
}

class _ProductionCompleteOrderDialogState
    extends State<ProductionCompleteOrderDialog> {
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入当前登录密码后再结束订单')));
      return;
    }
    Navigator.of(context).pop(
      ProductionCompleteOrderDialogResult(password: _passwordController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MesDialog(
      title: const Text('结束订单'),
      width: 640,
      content: SizedBox(
        key: const ValueKey('production-complete-order-dialog'),
        width: 640,
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
                    '完工确认',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('确认结束订单 ${widget.order.orderCode} 吗？'),
                  const SizedBox(height: 8),
                  const Text('该操作会强制释放相关生产状态。'),
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
                child: TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '当前登录密码',
                    border: OutlineInputBorder(),
                  ),
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
          child: const Text('结束'),
        ),
      ],
    );
  }
}
