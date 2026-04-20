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
    final tokens = Theme.of(context).extension<MesTokens>()!;
    final background = switch (tone) {
      MesSurfaceTone.normal => tokens.colors.surface,
      MesSurfaceTone.subtle => tokens.colors.surfaceSubtle,
      MesSurfaceTone.raised => tokens.colors.surfaceRaised,
    };

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: tokens.radius.md,
        border: Border.fromBorderSide(
          border ?? BorderSide(color: tokens.colors.border),
        ),
      ),
      child: child,
    );
  }
}
