import 'package:flutter/material.dart';
import 'package:mes_client/features/product/models/product_models.dart';

class ProductParameterHistorySnapshotDialog extends StatelessWidget {
  const ProductParameterHistorySnapshotDialog({
    super.key,
    required this.item,
    required this.onClose,
  });

  final ProductParameterHistoryItem item;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('变更前后快照'),
      content: SizedBox(
        width: 680,
        height: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '变更前：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              SelectableText(item.beforeSnapshot),
              const SizedBox(height: 12),
              const Text(
                '变更后：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              SelectableText(item.afterSnapshot),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(onPressed: onClose, child: const Text('关闭')),
      ],
    );
  }
}
