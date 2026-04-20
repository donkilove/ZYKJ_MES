import 'package:flutter/material.dart';
import 'package:mes_client/core/ui/foundation/mes_colors.dart';
import 'package:mes_client/core/ui/foundation/mes_radius.dart';
import 'package:mes_client/core/ui/foundation/mes_spacing.dart';
import 'package:mes_client/core/ui/foundation/mes_typography.dart';

@immutable
class MesTokens extends ThemeExtension<MesTokens> {
  const MesTokens({
    required this.colors,
    required this.spacing,
    required this.radius,
    required this.typography,
  });

  final MesColors colors;
  final MesSpacing spacing;
  final MesRadius radius;
  final MesTypography typography;

  factory MesTokens.fromTheme(ThemeData theme) {
    return MesTokens(
      colors: MesColors.fromScheme(theme.colorScheme),
      spacing: MesSpacing.comfortable,
      radius: MesRadius.standard,
      typography: MesTypography.fromTextTheme(theme.textTheme),
    );
  }

  @override
  MesTokens copyWith({
    MesColors? colors,
    MesSpacing? spacing,
    MesRadius? radius,
    MesTypography? typography,
  }) {
    return MesTokens(
      colors: colors ?? this.colors,
      spacing: spacing ?? this.spacing,
      radius: radius ?? this.radius,
      typography: typography ?? this.typography,
    );
  }

  @override
  MesTokens lerp(ThemeExtension<MesTokens>? other, double t) {
    return t < 0.5 || other == null ? this : other as MesTokens;
  }
}
