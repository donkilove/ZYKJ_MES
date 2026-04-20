import 'package:flutter/material.dart';
import 'package:mes_client/features/product/models/product_models.dart';

class ProductRelatedInfoSectionCard extends StatelessWidget {
  const ProductRelatedInfoSectionCard({
    super.key,
    required this.section,
  });

  final ProductRelatedInfoSection section;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey('product-related-info-section-${section.code}'),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey.shade50,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    section.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${section.total}项',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (section.items.isEmpty)
              Text(
                section.emptyMessage ?? '暂无关联数据',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              )
            else
              ...section.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    item.value == null || item.value!.trim().isEmpty
                        ? item.label
                        : '${item.label}｜${item.value}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
