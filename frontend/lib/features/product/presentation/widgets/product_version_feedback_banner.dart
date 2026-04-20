import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_inline_banner.dart';
import 'package:mes_client/features/product/models/product_models.dart';

class ProductVersionFeedbackBanner extends StatelessWidget {
  const ProductVersionFeedbackBanner({
    super.key,
    required this.hasDraft,
    required this.product,
    required this.effectiveVersion,
    required this.formatDate,
    this.message,
  });

  final bool hasDraft;
  final ProductItem? product;
  final ProductVersionItem? effectiveVersion;
  final String Function(DateTime value) formatDate;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    final trimmedMessage = message?.trim() ?? '';

    if (trimmedMessage.isNotEmpty) {
      items.add(MesInlineBanner.error(message: trimmedMessage));
    }
    if (hasDraft) {
      items.add(
        const MesInlineBanner.warning(
          message: '已存在草稿版本，请先完成或删除当前草稿后再新建版本。',
        ),
      );
    }
    if (effectiveVersion != null) {
      final effective = effectiveVersion!;
      final timeText = effective.effectiveAt == null
          ? ''
          : '（${formatDate(effective.effectiveAt!)}）';
      items.add(
        MesInlineBanner.success(
          message: '最近一次生效结果：${effective.versionLabel} 已生效$timeText',
        ),
      );
    }
    if (product != null &&
        product!.lifecycleStatus == 'inactive' &&
        effectiveVersion == null) {
      items.add(
        MesInlineBanner.info(
          message:
              product!.inactiveReason?.trim().isNotEmpty == true
                  ? product!.inactiveReason!
                  : '当前无生效版本，请先将目标版本设为生效后再恢复启用。',
        ),
      );
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return KeyedSubtree(
      key: const ValueKey('product-version-feedback-banner'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            items[index],
          ],
        ],
      ),
    );
  }
}
