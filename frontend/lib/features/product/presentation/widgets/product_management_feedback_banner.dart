import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_inline_banner.dart';

class ProductManagementFeedbackBanner extends StatelessWidget {
  const ProductManagementFeedbackBanner({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return KeyedSubtree(
      key: const ValueKey('product-management-feedback-banner'),
      child: MesInlineBanner.error(message: message),
    );
  }
}
