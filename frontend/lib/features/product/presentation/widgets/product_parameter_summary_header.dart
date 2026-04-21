import 'package:flutter/material.dart';

class ProductParameterSummaryHeader extends StatelessWidget {
  const ProductParameterSummaryHeader({
    super.key,
    required this.productName,
    required this.versionLabel,
    required this.parameterCount,
    this.scopeHint = '仅展示当前生效版本参数',
  });

  final String productName;
  final String versionLabel;
  final int parameterCount;
  final String scopeHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KeyedSubtree(
      key: const ValueKey('product-parameter-summary-header'),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.45,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                productName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text('版本：${versionLabel.isEmpty ? '-' : versionLabel}'),
                  Text('参数总数：$parameterCount 项'),
                ],
              ),
              if (scopeHint.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  scopeHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
