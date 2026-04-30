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

String _lifecycleLabel(String value) {
  switch (value) {
    case 'active':
      return '启用';
    case 'draft':
      return '草稿';
    case 'pending_review':
      return '待审核';
    case 'effective':
      return '启用';
    case 'inactive':
      return '停用';
    case 'obsolete':
      return '已废弃';
    default:
      return value;
  }
}

Future<void> showProductFormDialog({
  required BuildContext context,
  required ProductService productService,
  required List<String> categoryOptions,
  ProductItem? product,
  required VoidCallback onLogout,
  required Future<void> Function() onSuccess,
}) async {
  final isEdit = product != null;
  final nameController = TextEditingController(text: product?.name);
  final remarkController = TextEditingController(text: product?.remark);
  final formKey = GlobalKey<FormState>();
  String? selectedCategory = isEdit && categoryOptions.contains(product.category)
      ? product.category
      : null;

  var submitting = false;

  final saved = await showMesLockedFormDialog<bool>(
    context: context,
    wrapMesDialog: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return MesDialog(
            title: Text(isEdit ? '编辑产品' : '添加产品'),
            width: 860,
            content: SizedBox(
              width: 860,
              child: Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 左侧：基本信息
                    Expanded(
                      flex: 5,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '基础信息',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          InputDecorator(
                            decoration: const InputDecoration(
                              labelText: '当前状态',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              isEdit ? _lifecycleLabel(product.lifecycleStatus) : '启用 (默认)',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: nameController,
                            maxLength: 128,
                            enabled: !submitting,
                            decoration: const InputDecoration(
                              labelText: '产品名称',
                              hintText: '请输入 1-128 个字符',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final trimmed = value?.trim() ?? '';
                              if (trimmed.isEmpty) return '产品名称不能为空';
                              if (trimmed.length > 128) return '产品名称不能超过 128 个字符';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: '产品分类',
                              border: OutlineInputBorder(),
                            ),
                            items: categoryOptions
                                .map((category) => DropdownMenuItem(
                                      value: category,
                                      child: Text(category),
                                    ))
                                .toList(),
                            onChanged: submitting
                                ? null
                                : (value) {
                                    setDialogState(() => selectedCategory = value);
                                  },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return '请选择产品分类';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    // 右侧：备注与辅助信息
                    Expanded(
                      flex: 6,
                      child: Container(
                        height: 380,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(12),
                          color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '附加信息',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: TextFormField(
                                controller: remarkController,
                                maxLines: null,
                                expands: true,
                                maxLength: 500,
                                enabled: !submitting,
                                textAlignVertical: TextAlignVertical.top,
                                decoration: const InputDecoration(
                                  labelText: '备注说明',
                                  hintText: '最多 500 个字符，可在此记录产品的研发代号、关键特征或特殊注意事项等。',
                                  border: OutlineInputBorder(),
                                  alignLabelWithHint: true,
                                ),
                                validator: (value) {
                                  if ((value?.trim() ?? '').length > 500) {
                                    return '备注不能超过 500 个字符';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            if (isEdit) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 20, color: theme.colorScheme.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '修改基础信息不会影响已生效的版本参数，仅对未来新建的生产订单生效。',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: submitting ? null : () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: submitting
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => submitting = true);
                        try {
                          if (isEdit) {
                            await productService.updateProduct(
                              productId: product.id,
                              name: nameController.text.trim(),
                              category: selectedCategory!,
                              remark: remarkController.text.trim(),
                            );
                          } else {
                            await productService.createProduct(
                              name: nameController.text.trim(),
                              category: selectedCategory!,
                              remark: remarkController.text.trim(),
                            );
                          }
                          if (context.mounted) {
                            Navigator.of(context).pop(true);
                          }
                        } catch (error) {
                          if (context.mounted) {
                            setDialogState(() => submitting = false);
                          }
                          if (_isUnauthorized(error)) {
                            onLogout();
                            return;
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${isEdit ? '编辑' : '添加'}产品失败：${_errorMessage(error)}'),
                              ),
                            );
                          }
                        }
                      },
                child: Text(submitting ? '保存中...' : '保存'),
              ),
            ],
          );
        },
      );
    },
  );

  if (saved == true) {
    await onSuccess();
  }
}
