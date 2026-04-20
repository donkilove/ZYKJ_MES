import 'package:flutter/material.dart';
import 'package:mes_client/features/product/models/product_models.dart';

class ProductVersionComparePanel extends StatelessWidget {
  const ProductVersionComparePanel({
    super.key,
    required this.result,
  });

  final ProductVersionCompareResult result;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-version-compare-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '对比结果：新增 ${result.addedItems}，移除 ${result.removedItems}，变更 ${result.changedItems}',
          ),
          const SizedBox(height: 6),
          ...result.items.take(50).map(
            (item) => Text(
              '[${item.diffType}] ${item.key} | ${item.fromValue ?? '-'} -> ${item.toValue ?? '-'}',
            ),
          ),
          const Divider(height: 20),
        ],
      ),
    );
  }
}
