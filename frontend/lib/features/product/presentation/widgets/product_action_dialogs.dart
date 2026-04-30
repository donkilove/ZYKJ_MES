import 'package:flutter/material.dart';
import 'package:mes_client/core/network/api_exception.dart';
import 'package:mes_client/core/ui/patterns/mes_dialog.dart';
import 'package:mes_client/core/ui/patterns/mes_locked_form_dialog.dart';
import 'package:mes_client/features/product/models/product_models.dart';
import 'package:mes_client/features/product/services/product_service.dart';

bool _isUnauthorized(Object error) {
  return error is ApiException && error.statusCode == 401;
}

String _errorMessage(Object error) {
  if (error is ApiException) {
    return error.message;
  }
  return error.toString();
}

Future<bool> showConfirmImpactDialog({
  required BuildContext context,
  required ProductImpactAnalysisResult impact,
  required String title,
}) async {
  if (!impact.requiresConfirmation) {
    return false;
  }
  final confirmed = await showMesLockedFormDialog<bool>(
    context: context,
    wrapMesDialog: false,
    builder: (context) {
      return MesDialog(
        title: Text(title),
        width: 520,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer.withAlpha(128),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.error),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '存在 ${impact.totalOrders} 条未完工订单（待开工 ${impact.pendingOrders}，生产中 ${impact.inProgressOrders}）。\n继续操作将按你的确认强制执行。',
                      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (impact.items.isNotEmpty) ...[
              const Text('受影响订单示例：', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(77),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: impact.items.length > 20 ? 20 : impact.items.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = impact.items[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${item.orderCode} / ${item.orderStatus} ${item.reason ?? ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认继续'),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

Future<String?> showInactiveReasonDialog({
  required BuildContext context,
}) async {
  final reasonController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final result = await showMesLockedFormDialog<String>(
    context: context,
    wrapMesDialog: false,
    builder: (context) {
      return MesDialog(
        title: const Text('停用产品'),
        width: 460,
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('停用后，该产品将无法用于新建订单，请填写停用原因以供追溯。'),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '停用原因',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入停用原因';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) {
                return;
              }
              Navigator.of(context).pop(reasonController.text.trim());
            },
            child: const Text('确认停用'),
          ),
        ],
      );
    },
  );
  reasonController.dispose();
  return result;
}

Future<void> showConfirmDeleteProductDialog({
  required BuildContext context,
  required ProductService productService,
  required ProductItem product,
  required VoidCallback onLogout,
  required Future<void> Function() onSuccess,
}) async {
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  var submitting = false;

  final confirmed = await showMesLockedFormDialog<bool>(
    context: context,
    wrapMesDialog: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return MesDialog(
            title: const Text('删除产品'),
            width: 440,
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '确认删除产品“${product.name}”吗？\n删除为物理删除，不可恢复。',
                    style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    enabled: !submitting,
                    decoration: const InputDecoration(
                      labelText: '请输入当前账号密码',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入密码';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: submitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) {
                          return;
                        }
                        setDialogState(() => submitting = true);
                        try {
                          await productService.deleteProduct(
                            productId: product.id,
                            password: passwordController.text,
                          );
                          if (!dialogContext.mounted) return;
                          Navigator.of(dialogContext).pop(true);
                          
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('产品删除成功')),
                          );
                        } catch (error) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() => submitting = false);
                          
                          if (_isUnauthorized(error)) {
                            onLogout();
                            return;
                          }
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('删除产品失败：${_errorMessage(error)}'),
                            ),
                          );
                        }
                      },
                child: Text(submitting ? '删除中...' : '确认删除'),
              ),
            ],
          );
        },
      );
    },
  );

  if (confirmed == true) {
    await onSuccess();
  }
}
