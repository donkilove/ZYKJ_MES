import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';

class MesInfoRow extends StatelessWidget {
  const MesInfoRow({super.key, required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<MesTokens>();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: (tokens?.spacing.xs ?? 8) / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style:
                  tokens?.typography.caption.copyWith(
                    color: tokens.colors.textSecondary,
                  ) ??
                  theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }
}
