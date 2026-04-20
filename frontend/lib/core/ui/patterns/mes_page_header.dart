import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';
import 'package:mes_client/core/ui/primitives/mes_gap.dart';

class MesPageHeader extends StatelessWidget {
  const MesPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<MesTokens>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    tokens?.typography.pageTitle ??
                    theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (subtitle != null) ...[
                MesGap.vertical(tokens?.spacing.xs ?? 8),
                Text(
                  subtitle!,
                  style:
                      tokens?.typography.body.copyWith(
                        color: tokens.colors.textSecondary,
                      ) ??
                      theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          MesGap.horizontal(tokens?.spacing.md ?? 16),
          Wrap(
            spacing: tokens?.spacing.sm ?? 12,
            runSpacing: tokens?.spacing.sm ?? 12,
            children: actions,
          ),
        ],
      ],
    );
  }
}
