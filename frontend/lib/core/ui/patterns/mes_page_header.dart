import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';
import 'package:mes_client/core/ui/primitives/mes_gap.dart';

class MesPageHeader extends StatelessWidget {
  const MesPageHeader({
    super.key,
    this.title,
    this.subtitle,
    this.actionsBeforeTitle = const <Widget>[],
    this.actions = const <Widget>[],
  });

  final String? title;
  final String? subtitle;
  final List<Widget> actionsBeforeTitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<MesTokens>();
    final hasTitle = (title ?? '').trim().isNotEmpty;
    final hasSubtitle = (subtitle ?? '').trim().isNotEmpty;
    final hasLeadActions = actionsBeforeTitle.isNotEmpty;
    final hasTrailingActions = actions.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (hasLeadActions) ...[
          Wrap(
            spacing: tokens?.spacing.sm ?? 12,
            runSpacing: tokens?.spacing.sm ?? 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actionsBeforeTitle,
          ),
          if (hasTitle || hasSubtitle)
            MesGap.horizontal(tokens?.spacing.md ?? 16),
        ],
        if (hasTitle || hasSubtitle)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasTitle)
                  Text(
                    title!,
                    style:
                        tokens?.typography.pageTitle ??
                        theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                if (hasSubtitle) ...[
                  if (hasTitle) MesGap.vertical(tokens?.spacing.xs ?? 8),
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
        if (!hasTitle && !hasSubtitle && hasLeadActions && hasTrailingActions)
          const Spacer(),
        if (actions.isNotEmpty) ...[
          if (hasTitle || hasSubtitle)
            MesGap.horizontal(tokens?.spacing.md ?? 16),
          Wrap(
            spacing: tokens?.spacing.sm ?? 12,
            runSpacing: tokens?.spacing.sm ?? 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
        ],
      ],
    );
  }
}
