import 'package:flutter/material.dart';
import 'package:mes_client/features/product/models/product_models.dart';

class ProductHistoryTimeline extends StatelessWidget {
  const ProductHistoryTimeline({
    super.key,
    required this.items,
    required this.formatTime,
    required this.changeTypeLabel,
  });

  final List<ProductParameterHistoryItem> items;
  final String Function(DateTime value) formatTime;
  final String Function(String value) changeTypeLabel;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const ValueKey('product-history-timeline'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '变更记录',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const Divider(),
          if (items.isEmpty)
            const Text('暂无变更记录', style: TextStyle(color: Colors.grey))
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        formatTime(item.createdAt),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(
                        item.operatorUsername,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        [
                          if (item.versionLabel?.trim().isNotEmpty == true)
                            item.versionLabel!,
                          changeTypeLabel(item.changeType),
                          item.remark,
                          if (item.changedKeys.isNotEmpty)
                            '参数：${item.changedKeys.join(', ')}',
                        ].join('｜'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
