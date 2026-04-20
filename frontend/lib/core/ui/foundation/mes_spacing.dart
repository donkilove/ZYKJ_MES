import 'package:flutter/widgets.dart';

@immutable
class MesSpacing {
  const MesSpacing({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;

  static const MesSpacing comfortable = MesSpacing(
    xs: 8,
    sm: 12,
    md: 16,
    lg: 20,
    xl: 24,
  );
}
