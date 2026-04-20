import 'package:flutter/material.dart';

class ProductParameterEditorHeader extends StatelessWidget {
  const ProductParameterEditorHeader({
    super.key,
    required this.productName,
    required this.versionLabel,
    required this.lifecycleStatus,
    required this.hasUnsavedChanges,
    required this.onBack,
  });

  final String productName;
  final String versionLabel;
  final String lifecycleStatus;
  final bool hasUnsavedChanges;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-parameter-editor-header'),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            label: const Text('返回列表'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '编辑版本参数 - $productName（$versionLabel）',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (lifecycleStatus.isNotEmpty)
            Chip(
              label: Text(lifecycleStatus == 'draft' ? '草稿可编辑' : '非草稿只读'),
              visualDensity: VisualDensity.compact,
            ),
          if (hasUnsavedChanges) ...[
            const SizedBox(width: 8),
            const Chip(
              label: Text('有未保存修改'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}
