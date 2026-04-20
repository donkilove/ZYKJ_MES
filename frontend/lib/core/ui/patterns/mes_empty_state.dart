import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';

class MesEmptyState extends StatelessWidget {
  const MesEmptyState({super.key, required this.title, this.description});

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<MesTokens>();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            style:
                tokens?.typography.bodyStrong ??
                theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(
              description!,
              style: tokens?.typography.caption ?? theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
