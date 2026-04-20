import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_tokens.dart';

enum MesSurfaceTone { normal, subtle, raised }

class MesSurface extends StatelessWidget {
  const MesSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.tone = MesSurfaceTone.normal,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final MesSurfaceTone tone;
  final BorderSide? border;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<MesTokens>();
    final background = switch (tone) {
      MesSurfaceTone.normal =>
        tokens?.colors.surface ?? theme.colorScheme.surfaceContainerLow,
      MesSurfaceTone.subtle =>
        tokens?.colors.surfaceSubtle ??
            theme.colorScheme.surfaceContainerLowest,
      MesSurfaceTone.raised =>
        tokens?.colors.surfaceRaised ?? theme.colorScheme.surfaceContainerHigh,
    };

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: tokens?.radius.md ?? BorderRadius.circular(16),
        border: Border.fromBorderSide(
          border ??
              BorderSide(
                color:
                    tokens?.colors.border ?? theme.colorScheme.outlineVariant,
              ),
        ),
      ),
      child: child,
    );
  }
}
