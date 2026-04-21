import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/patterns/mes_inline_banner.dart';

class ProductParameterQueryFeedbackBanner extends StatelessWidget {
  const ProductParameterQueryFeedbackBanner({
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
      key: const ValueKey('product-parameter-query-feedback-banner'),
      child: MesInlineBanner.error(message: message),
    );
  }
}
