import 'package:flutter/material.dart';

@immutable
class MesColors {
  const MesColors({
    required this.background,
    required this.surface,
    required this.surfaceSubtle,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  final Color background;
  final Color surface;
  final Color surfaceSubtle;
  final Color surfaceRaised;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  factory MesColors.fromScheme(ColorScheme scheme) {
    return MesColors(
      background: scheme.surface,
      surface: scheme.surfaceContainerLow,
      surfaceSubtle: scheme.surfaceContainerLowest,
      surfaceRaised: scheme.surfaceContainerHigh,
      border: scheme.outlineVariant,
      borderStrong: scheme.outline,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      success: const Color(0xFF1B8A5A),
      warning: const Color(0xFFB97100),
      danger: scheme.error,
      info: scheme.primary,
    );
  }
}
