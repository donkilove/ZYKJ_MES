import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';
import 'package:mes_client/core/ui/primitives/mes_gap.dart';
import 'package:mes_client/core/ui/primitives/mes_surface.dart';

class MesSectionCard extends StatelessWidget {
  const MesSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.expandChild = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<MesTokens>();
    return MesSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          tokens?.typography.sectionTitle ??
                          theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
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
              if (trailing != null) trailing!,
            ],
          ),
          MesGap.vertical(tokens?.spacing.md ?? 16),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }
}
